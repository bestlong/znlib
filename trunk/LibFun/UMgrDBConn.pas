{*******************************************************************************
  作者: dmzn@163.com 2011-10-22
  描述: 数据库连接管理器

  备注:
  *.数据连接管理器,维护一组数据库连接参数,并动态分配连接对象.
  *.每组连接参数使用一个ID标识,存放于高速哈希表内.
  *.每组连接对象使用一个ID标识,表示到同一个数据库,含有多个工作对象.
  *.每组连接对应一个数据库,每个数组库对应N个Worker实际负责Connection,管理器
    负责
*******************************************************************************}
unit UMgrDBConn;

interface

uses
  ActiveX, ADODB, Classes, DB, Windows, SysUtils, SyncObjs, UMgrHashDict,
  UWaitItem, USysLoger;

const
  cErr_GetConn_NoParam     = $0001;            //无连接参数
  cErr_GetConn_NoAllowed   = $0002;            //阻止申请
  cErr_GetConn_Closing     = $0003;            //连接正断开
  cErr_GetConn_MaxConn     = $0005;            //最大连接数
  cErr_GetConn_BuildFail   = $0006;            //构建失败

type
  PDBParam = ^TDBParam;
  TDBParam = record
    FID        : string;                             //参数标识
    FHost      : string;                             //主机地址
    FPort      : Integer;                            //服务端口
    FDB        : string;                             //数据库名
    FUser      : string;                             //用户名
    FPwd       : string;                             //用户密码
    FConn      : string;                             //连接字符
    
    FEnable    : Boolean;                            //启用参数
    FNumWorker : Integer;                            //工作对象数
  end;

  PDBWorker = ^TDBWorker;
  TDBWorker = record
    FConn : TADOConnection;                     //连接对象
    FQuery: TADOQuery;                          //查询对象
    FExec : TADOQuery;                          //操作对象

    FWaiter: TWaitObject;                       //延迟对象
    FUsed : Integer;                            //排队计数
    FLock : TCriticalSection;                   //同步锁定
  end;

  PDBConnItem = ^TDBConnItem;
  TDBConnItem = record
    FID   : string;                             //连接标识
    FUsed : Integer;                            //排队计数
    FLast : Cardinal;                           //上次使用
    FWorker: array of PDBWorker;                //工作对象
  end;

  PDBConnStatus = ^TDBConnStatus;
  TDBConnStatus = record
    FNumConnParam: Integer;                     //可连接数据库个数
    FNumConnItem: Integer;                      //连接组(数据库)个数
    FNumConnObj: Integer;                       //连接对象(Connection)个数
    FNumObjConned: Integer;                     //已连接对象(Connection)个数
    FNumObjReUsed: Cardinal;                    //对象重复使用次数
    FNumObjRequest: Cardinal;                   //连接请求总数
    FNumObjRequestErr: Cardinal;                //请求错误次数
    FNumObjWait: Integer;                       //排队中对象(Worker.FUsed)个数
    FNumWaitMax: Integer;                       //排队最多的组队列中对象个数
    FNumMaxTime: TDateTime;                     //排队最多时间
  end;

  TDBConnManager = class;
  TDBConnWorkderBuilder = class(TThread)
  private
    FOwner: TDBConnManager;
    //拥有者
    FWaiterInner: TWaitObject;
    FWaiterOuter: TWaitObject;
    //等待对象
    FSyncLock: TCriticalSection;
    //同步对象
  protected
    FWorker: PDBWorker;
    //工作对象
    FBuildResult: Boolean;
    //创建结果
    procedure Execute; override;
    //线程体
  public
   constructor Create(AOwner: TDBConnManager);
   destructor Destroy; override;
   //创建释放
   procedure StopMe;
   //停止线程
   function BuildWorker(const nWorker: PDBWorker): Boolean;
   //构建对象
   end;
  
  TDBConnManager = class(TObject)
  private
    FMaxConn: Word;
    //最大连接数
    FConnItems: TList;
    //连接列表
    FParams: THashDictionary;
    //参数列表
    FConnClosing: Integer;
    FAllowedRequest: Integer;
    FSyncLock: TCriticalSection;
    //同步锁
    FBuilder: TDBConnWorkderBuilder;
    //对象厂
    FStatus: TDBConnStatus;
    //运行状态
  protected
    procedure DoFreeDict(const nType: Word; const nData: Pointer);
    //释放字典
    procedure ClearConnItems(const nFreeMe: Boolean);
    //清理连接
    function CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
    function CloseConnection(const nID: string; const nLock: Boolean): Integer;
    //关闭连接
    procedure DoAfterConnection(Sender: TObject);
    procedure DoAfterDisconnection(Sender: TObject);
    //时间绑定
    function GetRunStatus: TDBConnStatus;
    //读取状态
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure AddParam(const nParam: TDBParam);
    procedure DelParam(const nID: string = '');
    procedure ClearParam;
    //参数管理
    class function MakeDBConnection(const nParam: TDBParam): string;
    //创建连接
    function GetConnection(const nID: string; var nErrCode: Integer): PDBWorker;
    procedure ReleaseConnection(const nID: string; const nWorker: PDBWorker);
    //使用连接
    function Disconnection(const nID: string = ''): Integer;
    //断开连接
    function WorkerQuery(const nWorker: PDBWorker; const nSQL: string): TDataSet;
    function WorkerExec(const nWorker: PDBWorker; const nSQL: string): Integer;
    //操作连接
    property Status: TDBConnStatus read GetRunStatus;
    property MaxConn: Word read FMaxConn write FMaxConn;
    //属性相关
  end;

var
  gDBConnManager: TDBConnManager = nil;
  //全局使用

implementation

const
  cTrue  = $1101;
  cFalse = $1105;
  //常量定义

resourcestring
  sNoAllowedWhenRequest = '连接池对象释放时收到请求,已拒绝.';
  sClosingWhenRequest   = '连接池对象关闭时收到请求,已拒绝.';
  sNoParamWhenRequest   = '连接池对象收到请求,但无匹配参数.';
  sBuildWorkerFailure   = '连接池对象创建DBWorker失败.';

//------------------------------------------------------------------------------
//Desc: 记录日志
procedure WriteLog(const nMsg: string);
begin
  if Assigned(gSysLoger) then
    gSysLoger.AddLog(TDBConnManager, '数据库连接池', nMsg);
  //xxxxx
end;

constructor TDBConnWorkderBuilder.Create(AOwner: TDBConnManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;

  FWaiterInner := TWaitObject.Create;
  FWaiterOuter := TWaitObject.Create;
  FSyncLock := TCriticalSection.Create;
end;

destructor TDBConnWorkderBuilder.Destroy;
begin
  FreeAndNil(FWaiterInner);
  FreeAndNil(FWaiterOuter);
  FreeAndNil(FSyncLock);
  inherited;
end;

//Desc: 停止线程
procedure TDBConnWorkderBuilder.StopMe;
begin
  Terminate;
  FWaiterInner.Wakeup;
  FWaiterOuter.Wakeup;
  
  WaitFor;
  Free;
end;

//Date: 2012-3-1
//Parm: 工作对象
//Desc: 创建nWorker对象的内容
function TDBConnWorkderBuilder.BuildWorker(const nWorker: PDBWorker): Boolean;
begin
  with nWorker^ do
    Result := Assigned(FConn) and Assigned(FQuery) and Assigned(FExec);
  if Result then Exit;

  FSyncLock.Enter;
  try
    FWorker := nWorker;
    FWaiterInner.Wakeup;

    FWaiterOuter.EnterWait;
    Result := FBuildResult;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2012-3-1
//Desc: 线程体
procedure TDBConnWorkderBuilder.Execute;
begin
  CoInitializeEx(nil, COINIT_MULTITHREADED);
  try
    while not Terminated do
    try
      FWaiterInner.EnterWait;
      FBuildResult := False;
      if Terminated then Exit;

      with FWorker^,FOwner do
      begin
        if not Assigned(FConn) then
        begin
          FConn := TADOConnection.Create(nil);
          InterlockedIncrement(FStatus.FNumConnObj);

          with FConn do
          begin
            ConnectionTimeout := 7;
            LoginPrompt := False;
            AfterConnect := DoAfterConnection;
            AfterDisconnect := DoAfterDisconnection;
          end;
        end;

        if not Assigned(FQuery) then
        begin
          FQuery := TADOQuery.Create(nil);
          FQuery.Connection := FConn;
        end;

        if not Assigned(FExec) then
        begin
          FExec := TADOQuery.Create(nil);
          FExec.Connection := FConn;
        end;

        if not Assigned(FWaiter) then
        begin
          FWaiter := TWaitObject.Create;
          FWaiter.Interval := 2 * 10;
        end;

        if not Assigned(FLock) then
          FLock := TCriticalSection.Create;
        //xxxxx
      end;

      FBuildResult := True;
      FWaiterOuter.Wakeup;
    except
      on E:Exception do
      begin
        FWaiterOuter.Wakeup;
        WriteLog(E.Message);
      end;
    end;
  finally
    FWaiterOuter.Wakeup;
    CoUninitialize;
  end;
end;

//------------------------------------------------------------------------------
constructor TDBConnManager.Create;
begin
  FMaxConn := 100;
  FConnClosing := cFalse;
  FAllowedRequest := cTrue;

  FConnItems := TList.Create;
  FSyncLock := TCriticalSection.Create;
  
  FParams := THashDictionary.Create(3);
  FParams.OnDataFree := DoFreeDict;
  FBuilder := TDBConnWorkderBuilder.Create(Self);
end;

destructor TDBConnManager.Destroy;
begin
  ClearConnItems(True);
  FParams.Free;
  FSyncLock.Free;

  FBuilder.StopMe;
  FBuilder := nil;
  inherited;
end;

//Desc: 释放字典项
procedure TDBConnManager.DoFreeDict(const nType: Word; const nData: Pointer);
begin
  Dispose(PDBParam(nData));
end;

//Desc: 释放连接对象
procedure FreeDBConnItem(const nItem: PDBConnItem);
var nIdx: Integer;
begin
  for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
   if Assigned(nItem.FWorker[nIdx]) then
    with nItem.FWorker[nIdx]^ do
    begin
      FreeAndNil(FQuery);
      FreeAndNil(FExec);
      FreeAndNil(FConn);
      FreeAndNil(FLock);
      FreeAndNil(FWaiter);
      
      Dispose(nItem.FWorker[nIdx]);
      nItem.FWorker[nIdx] := nil;
    end;

  Dispose(nItem);
end;

//Desc: 清理连接对象
procedure TDBConnManager.ClearConnItems(const nFreeMe: Boolean);
var nIdx: Integer;
begin
  if nFreeMe then
    InterlockedExchange(FAllowedRequest, cFalse);
  //请求关闭

  FSyncLock.Enter;
  try
    CloseConnection('', False);
    //断开全部连接

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      FreeDBConnItem(FConnItems[nIdx]);
      FConnItems.Delete(nIdx);
    end;

    if nFreeMe then
      FreeAndNil(FConnItems);
    FillChar(FStatus, SizeOf(FStatus), #0);
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: 断开到数据库的连接
function TDBConnManager.Disconnection(const nID: string): Integer;
begin
  Result := CloseConnection(nID, True);
end;

//Desc: 断开nWorker的数据连接,断开成功返回True.
function TDBConnManager.CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
begin
  //让出锁,等待工作对象释放
  FSyncLock.Leave;
  try
    while nWorker.FUsed > 0 do
      nWorker.FWaiter.EnterWait;
    //等待队列退出
  finally
    FSyncLock.Enter;
  end;

  try
    nWorker.FConn.Connected := False;
  except
    //ignor any error
  end;

  Result := not nWorker.FConn.Connected;
end;

//Desc: 关闭指定连接,返回关闭个数.
function TDBConnManager.CloseConnection(const nID: string;
  const nLock: Boolean): Integer;
var nIdx,nInt: Integer;
    nItem: PDBConnItem;
begin
  Result := 0;
  if InterlockedExchange(FConnClosing, cTrue) = cTrue then Exit;

  if nLock then FSyncLock.Enter;
  try
    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nItem := FConnItems[nIdx];
      if (nID <> '') and (CompareText(nItem.FID, nID) <> 0) then Continue;

      nItem.FUsed := 0;
      //重置计数

      for nInt:=Low(nItem.FWorker) to High(nItem.FWorker) do
      if Assigned(nItem.FWorker[nInt]) then
      begin
        if CloseWorkerConnection(nItem.FWorker[nInt]) then
          Inc(Result);
        nItem.FWorker[nInt].FUsed := 0;
      end;
    end;
  finally
    InterlockedExchange(FConnClosing, cFalse);
    if nLock then FSyncLock.Leave;
  end;
end;

//Desc: 数据连接成功
procedure TDBConnManager.DoAfterConnection(Sender: TObject);
begin
  InterlockedIncrement(FStatus.FNumObjConned);
end;

//Desc: 数据断开成功
procedure TDBConnManager.DoAfterDisconnection(Sender: TObject);
begin
  InterlockedDecrement(FStatus.FNumObjConned);
end;

//------------------------------------------------------------------------------
//Desc: 生成本方或数据库连接
class function TDBConnManager.MakeDBConnection(const nParam: TDBParam): string;
begin
  with nParam do
  begin
    Result := FConn;
    Result := StringReplace(Result, '$DBName', FDB, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Host', FHost, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$User', FUser, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Pwd', FPwd, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Port', IntToStr(FPort), [rfReplaceAll, rfIgnoreCase]);
  end;
end;

//Desc: 添加参数
procedure TDBConnManager.AddParam(const nParam: TDBParam);
var nPtr: PDBParam;
    nData: PDictData;
begin
  if nParam.FID = '' then Exit;

  FSyncLock.Enter;
  try
    nData := FParams.FindItem(nParam.FID);
    if not Assigned(nData) then
    begin
      New(nPtr);
      FParams.AddItem(nParam.FID, nPtr, 0, False);
      Inc(FStatus.FNumConnParam);
    end else nPtr := nData.FData;

    nPtr^ := nParam;
    nPtr.FConn := MakeDBConnection(nParam);

    if nPtr.FNumWorker < 1 then
      nPtr.FNumWorker := 3;
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: 删除参数
procedure TDBConnManager.DelParam(const nID: string);
begin
  FSyncLock.Enter;
  try
    if FParams.DelItem(nID) then
      Dec(FStatus.FNumConnParam);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: 清理参数
procedure TDBConnManager.ClearParam;
begin
  FSyncLock.Enter;
  try
    FParams.ClearItem;
    FStatus.FNumConnParam := 0;
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2011-10-23
//Parm: 连接标识;错误码
//Desc: 返回nID可用的数据连接对象
function TDBConnManager.GetConnection(const nID: string;
 var nErrCode: Integer): PDBWorker;
var nIdx: Integer;
    nParam: PDictData;
    nItem,nIdle,nTmp: PDBConnItem;
begin
  Result := nil;
  nErrCode := cErr_GetConn_NoAllowed;

  if FAllowedRequest = cFalse then
  begin
    WriteLog(sNoAllowedWhenRequest);
    Exit;
  end;

  nErrCode := cErr_GetConn_Closing;
  if FConnClosing = cTrue then
  begin
    WriteLog(sClosingWhenRequest);
    Exit;
  end;

  FSyncLock.Enter;
  try
    nErrCode := cErr_GetConn_NoAllowed;
    if FAllowedRequest = cFalse then
    begin
      WriteLog(sNoAllowedWhenRequest);
      Exit;
    end;

    nErrCode := cErr_GetConn_Closing;
    if FConnClosing = cTrue then
    begin
      WriteLog(sClosingWhenRequest);
      Exit;
    end;
    //重复判定,避免Get和close锁定机制重叠(get.enter在close.enter后面进入等待)

    Inc(FStatus.FNumObjRequest);
    nErrCode := cErr_GetConn_NoParam;
    nParam := FParams.FindItem(nID);
    
    if not Assigned(nParam) then
    begin
      WriteLog(sNoParamWhenRequest);
      Exit;
    end;

    //--------------------------------------------------------------------------
    nItem := nil;
    nIdle := nil;

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nTmp := FConnItems[nIdx];
      if CompareText(nID, nTmp.FID) = 0 then
      begin
        nItem := nTmp; Break;
      end;

      if nTmp.FUsed < 1 then
       if (not Assigned(nIdle)) or (nIdle.FLast > nTmp.FLast) then
        nIdle := nTmp;
      //空闲时间最长连接
    end;

    if not Assigned(nItem) then
    begin
      if (not Assigned(nIdle)) and (FConnItems.Count >= FMaxConn) then
      begin
        nErrCode := cErr_GetConn_MaxConn; Exit;
      end;

      if (FConnItems.Count >= FMaxConn) then
      begin
        nItem := nIdle;
        nItem.FID := nID;
        nItem.FUsed := 1;

        try
          for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
           if Assigned(nItem.FWorker[nIdx]) then
            CloseWorkerConnection(nItem.Fworker[nIdx]);
          Inc(FStatus.FNumObjReUsed);
        finally
          nItem.FUsed := 0;
        end;
      end else
      begin
        New(nItem);
        FConnItems.Add(nItem);
        Inc(FStatus.FNumConnItem);

        nItem.FID := nID;
        nItem.FUsed := 0;
        SetLength(nItem.FWorker, PDBParam(nParam.FData).FNumWorker);

        for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
          nItem.FWorker[nIdx] := nil;
        //xxxxx
      end;
    end;

    //--------------------------------------------------------------------------
    with nItem^ do
    begin
      for nIdx:=Low(FWorker) to High(FWorker) do
      begin
        if Assigned(FWorker[nIdx]) then
        begin
          if not Assigned(Result) then
          begin
            Result := FWorker[nIdx];
            if Result.FUsed < 1 then Break;
          end else

          if FWorker[nIdx].FUsed < Result.FUsed then
          begin
            Result := FWorker[nIdx];
          end; //排队最少的工作对象
        end else
        begin
          New(Result);
          FWorker[nIdx] := Result;
          FillChar(Result^, SizeOf(TDBWorker), #0);

          Break;
        end; //新创建工作对象
      end;

      if Assigned(Result) then
      begin
        if not FBuilder.BuildWorker(Result) then
        begin
          Result := nil;
          nErrCode := cErr_GetConn_BuildFail;

          WriteLog(sBuildWorkerFailure);
          Exit;
        end;

        Inc(Result.FUsed);
        Inc(nItem.FUsed);
        Inc(FStatus.FNumObjWait);

        if nItem.FUsed > FStatus.FNumWaitMax then
        begin
          FStatus.FNumWaitMax := nItem.FUsed;
          FStatus.FNumMaxTime := Now;
        end;

        if not Result.FConn.Connected then
          Result.FConn.ConnectionString := PDBParam(nParam.FData).FConn;
        //xxxxx
      end;
    end;
  finally
    if not Assigned(Result) then
      Inc(FStatus.FNumObjRequestErr);
    FSyncLock.Leave;
  end;

  if Assigned(Result) then
  with Result^ do
  begin
    FLock.Enter;
    //工作对象进入排队

    if FConnClosing = cTrue then
    try
      Result := nil;
      nErrCode := cErr_GetConn_Closing;

      InterlockedDecrement(FUsed);
      InterlockedDecrement(FStatus.FNumObjWait);
      FWaiter.Wakeup;
    finally
      FLock.Leave;
    end;
  end;
end;

//Date: 2011-10-23
//Parm: 连接标识;数据对象
//Desc: 释放nID.nWorker连接对象
procedure TDBConnManager.ReleaseConnection(const nID: string;
  const nWorker: PDBWorker);
var nIdx: Integer;
    nItem: PDBConnItem;
begin
  if Assigned(nWorker) then
  begin
    FSyncLock.Enter;
    try
      if nWorker.FQuery.Active then
        nWorker.FQuery.Close;
      //xxxxx
      
      for nIdx:=FConnItems.Count - 1 downto 0 do
      begin
        nItem := FConnItems[nIdx];

        if CompareText(nItem.FID, nID) = 0 then
        begin
          Dec(nItem.FUsed);
          nItem.FLast := GetTickCount;
          Break;
        end;
      end;
    finally
      Dec(nWorker.FUsed);
      nWorker.FLock.Leave;
      Dec(FStatus.FNumObjWait);

      if FConnClosing = cTrue then
        nWorker.FWaiter.Wakeup;
      FSyncLock.Leave;
    end;
  end;
end;

//------------------------------------------------------------------------------
//Desc: 执行写操作语句
function TDBConnManager.WorkerExec(const nWorker: PDBWorker;
  const nSQL: string): Integer;
begin
  with nWorker^ do
  begin
    FExec.Close;
    FExec.SQL.Text := nSQL;
    Result := FExec.ExecSQL;
  end;
end;

//Desc: 执行查询语句
function TDBConnManager.WorkerQuery(const nWorker: PDBWorker;
  const nSQL: string): TDataSet;
begin
  with nWorker^ do
  begin
    Result := FQuery;
    FQuery.Close;
    FQuery.SQL.Text := nSQL;
    FQuery.Open;
  end;
end;

//Desc: 读取运行状态
function TDBConnManager.GetRunStatus: TDBConnStatus;
begin
  FSyncLock.Enter;
  try
    Result := FStatus;
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  gDBConnManager := TDBConnManager.Create;
finalization
  FreeAndNil(gDBConnManager);
end.
