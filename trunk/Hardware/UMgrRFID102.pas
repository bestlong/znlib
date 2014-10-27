{*******************************************************************************
  作者: dmzn@163.com 2014-10-24
  描述: 深圳市中科华益科技有限公司 RFID102读取器驱动
*******************************************************************************}
unit UMgrRFID102;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, NativeXml, UWaitItem, UMgrRFID102_Head,
  USysLoger;

const
  cHYReader_Wait_Short     = 50;
  cHYReader_Wait_Long      = 2 * 1000;

type
  PHYReaderItem = ^THYReaderItem;
  THYReaderItem = record
    FID     : string;          //读头标识
    FHost   : string;          //地址
    FPort   : Integer;         //端口
    FHwnd   : LongInt;         //通讯句柄
    FCard   : string;          //卡号
    FEnable : Boolean;         //是否启用
    FLocked : Boolean;         //是否锁定
    FLastActive: Int64;        //上次活动
  end;

  THYReaderManager = class;
  THYRFIDReader = class(TThread)
  private
    FOwner: THYReaderManager;
    //拥有者
    FWaiter: TWaitObject;
    //等待对象
    FActiveReader: PHYReaderItem;
    //当前读头
    FBuffer: array [0..50] of Char;
    //读取缓存
  protected
    procedure DoExecute;
    procedure Execute; override;
    function ReadCard(const nReader: PHYReaderItem): Boolean;
    //执行线程
  public
    constructor Create(AOwner: THYReaderManager);
    destructor Destroy; override;
    //创建释放
    procedure StopMe;
    //停止线程
  end;

  THYReaderProc = procedure (const nItem: PHYReaderItem);
  THYReaderEvent = procedure (const nItem: PHYReaderItem) of Object;

  THYReaderManager = class(TObject)
  private
    FEnable: Boolean;
    //是否启用
    FReaderIndex: Integer;
    FReaders: TList;
    //读头列表
    FThreads: array[0..2] of THYRFIDReader;
    //读卡对象
    FSyncLock: TCriticalSection;
    //同步锁定
    FOnProc: THYReaderProc;
    FOnEvent: THYReaderEvent;
    //事件定义
  protected
    procedure ClearReaders(const nFree: Boolean);
    //清理资源
    procedure CloseReader(const nReader: PHYReaderItem);
    //关闭读头
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure LoadConfig(const nFile: string);
    //载入配置
    procedure StartReader;
    procedure StopReader;
    //启停读头
    property OnCardProc: THYReaderProc read FOnProc write FOnProc;
    property OnCardEvent: THYReaderEvent read FOnEvent write FOnEvent;
    //属性相关
  end;

var
  gHYReaderManager: THYReaderManager = nil;
  //全局使用
  
implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(THYReaderManager, '华益RFID读卡器', nEvent);
end;

constructor THYReaderManager.Create;
var nIdx: Integer;
begin
  for nIdx:=Low(FThreads) to High(FThreads) do
    FThreads[nIdx] := nil;
  //xxxxx
  
  FEnable := False;
  FReaders := TList.Create;
  FSyncLock := TCriticalSection.Create;
end;

destructor THYReaderManager.Destroy;
begin
  StopReader;
  ClearReaders(True);

  FSyncLock.Free;
  inherited;
end;

procedure THYReaderManager.ClearReaders(const nFree: Boolean);
var nIdx: Integer;
begin
  for nIdx:=FReaders.Count - 1 downto 0 do
  begin
    Dispose(PHYReaderItem(FReaders[nIdx]));
    FReaders.Delete(nIdx);
  end;

  if nFree then
    FReaders.Free;
  //xxxxx
end;

procedure THYReaderManager.StartReader;
var nIdx,nNum: Integer;
begin
  if not FEnable then Exit;
  nNum := 0;
  FReaderIndex := 0;

  for nIdx:=Low(FThreads) to High(FThreads) do
   if Assigned(FThreads[nIdx]) then
    Inc(nNum);
  //xxxxx

  for nIdx:=Low(FThreads) to High(FThreads) do
  begin
    if (nNum > 0) and (FReaders.Count < 2) then Exit;
    //一个读头单线程

    if not Assigned(FThreads[nIdx]) then
    begin
      FThreads[nIdx] := THYRFIDReader.Create(Self);
      Inc(nNum);
    end;
  end;
end;

procedure THYReaderManager.CloseReader(const nReader: PHYReaderItem);
var nHwnd: LongInt;
begin
  if Assigned(nReader) and (nReader.FHwnd > 0) then
  begin
    nHwnd := nReader.FHwnd;
    nReader.FHwnd := 0;
    CloseNetPort(nHwnd);
  end;
end;

procedure THYReaderManager.StopReader;
var nIdx: Integer;
begin
  for nIdx:=Low(FThreads) to High(FThreads) do
   if Assigned(FThreads[nIdx]) then
    FThreads[nIdx].Terminate;
  //设置退出标记

  for nIdx:=Low(FThreads) to High(FThreads) do
  if Assigned(FThreads[nIdx]) then
  begin
    FThreads[nIdx].StopMe;
    FThreads[nIdx] := nil;
  end;

  FSyncLock.Enter;
  try
    for nIdx:=FReaders.Count - 1 downto 0 do
      CloseReader(FReaders[nIdx]);
    //关闭读头
  finally
    FSyncLock.Leave;
  end;
end;

procedure THYReaderManager.LoadConfig(const nFile: string);
var nIdx: Integer;
    nXML: TNativeXml;
    nNode,nTmp: TXmlNode;
    nReader: PHYReaderItem;
begin
  FEnable := False;
  if not FileExists(nFile) then Exit;

  nXML := nil;
  try
    nXML := TNativeXml.Create;
    nXML.LoadFromFile(nFile);

    nNode := nXML.Root.FindNode('readers');
    if not Assigned(nNode) then Exit;
    ClearReaders(False);

    for nIdx:=0 to nNode.NodeCount - 1 do
    begin
      nTmp := nNode.Nodes[nIdx];
      New(nReader);
      FReaders.Add(nReader);

      with nTmp,nReader^ do
      begin
        FHwnd := 0;
        FLocked := False;
        FLastActive := GetTickCount;

        FID := AttributeByName['id'];
        FHost := NodeByName('ip').ValueAsString;
        FPort := NodeByName('port').ValueAsInteger; 
        FEnable := NodeByName('enable').ValueAsString <> 'N';

        if FEnable then
          Self.FEnable := True;
        //有效节点
      end;
    end;
  finally
    nXML.Free;
  end;
end;

//------------------------------------------------------------------------------
constructor THYRFIDReader.Create(AOwner: THYReaderManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := cHYReader_Wait_Short;
end;

destructor THYRFIDReader.Destroy;
begin
  FWaiter.Free;
  inherited;
end;

procedure THYRFIDReader.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure THYRFIDReader.Execute;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    DoExecute;
    //执行读卡
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
      Sleep(500);
    end;
  end; 
end;

procedure THYRFIDReader.DoExecute;
var nIdx: Integer;
    nReader: PHYReaderItem;
begin
  FActiveReader := nil;
  //init

  with FOwner do
  try
    FSyncLock.Enter;
    try
      for nIdx:=FReaders.Count - 1 downto 0 do
      begin
        nReader := FReaders[nIdx];
        if nReader.FEnable and (not nReader.FLocked) and
           (GetTickCount - nReader.FLastActive < cHYReader_Wait_Long) then
        //有卡号的读头优先
        begin
          FActiveReader := nReader;
          FActiveReader.FLocked := True;
          Break;
        end;
      end;

      if not Assigned(FActiveReader) then
      begin
        nIdx := 0;
        //init

        while True do
        begin
          if FReaderIndex >= FReaders.Count then
          begin
            FReaderIndex := 0;
            Inc(nIdx);

            if nIdx > 1 then Break;
            //扫描一轮,无效退出
          end;

          nReader := FReaders[FReaderIndex];
          Inc(FReaderIndex);
          if nReader.FLocked or (not nReader.FEnable) then Continue;

          FActiveReader := nReader;
          FActiveReader.FLocked := True;
          Break;
        end;
      end;
    finally
      FSyncLock.Leave;
    end;

    if Assigned(FActiveReader) and (not Terminated) then
    try
      if ReadCard(FActiveReader) then
      begin
        FWaiter.Interval := cHYReader_Wait_Short;
        FActiveReader.FLastActive := GetTickCount;
      end else
      begin
        if (FActiveReader.FLastActive > 0) and
           (GetTickCount - FActiveReader.FLastActive >= 3 * 1000) then
        begin
          FActiveReader.FLastActive := 0;
          FWaiter.Interval := cHYReader_Wait_Long;
        end;
      end;
    except
      CloseReader(FActiveReader);
      raise;
    end;
  finally
    if Assigned(FActiveReader) then
      FActiveReader.FLocked := False;
    //unlock
  end;
end;

function getStr(pStr: pchar; len: Integer): string;
var
  i: Integer;
begin
  result := '';
  for i := 0 to len - 1 do
    result := result + (pStr + i)^;
end;

function getHexStr(sBinStr: string): string; //获得十六进制字符串
var
  i: Integer;
begin
  result := '';
  for i := 1 to Length(sBinStr) do
    result := result + IntToHex(ord(sBinStr[i]), 2);
end;

function THYRFIDReader.ReadCard(const nReader: PHYReaderItem): Boolean;
var nStr,nData: string;
    nAddr: Byte;
    nRet,nHwnd: LongInt;
    m,nNum,nLen,nIdx:Integer;
begin
  Result := False;
  nAddr := StrToInt('$FF');

  if nReader.FHwnd = 0 then
  begin
    nRet := OpenNetPort(nReader.FPort, nReader.FHost, nAddr, nHwnd);
    if nRet <> 0 then
    begin
      nStr := '连接[ %s:%d on:%d ]失败.';
      WriteLog(Format(nStr, [nReader.FHost, nReader.FPort, ThreadID]));
      Exit;
    end;

    nReader.FHwnd := nHwnd;
    //new handle
  end;

  nRet := Inventory_G2(nAddr, 0, 0, 0, @FBuffer, nLen, nNum, nReader.FHwnd);
  //query card
  if Terminated then Exit;
  //thread exit

  if nRet = $30 then
  begin
    nStr := '读取[%s:%d.%s on:%d ]时异常.';
    nStr := Format(nStr, [nReader.FHost, nReader.FPort, nReader.FID, ThreadID]);
    raise Exception.Create(nStr);
  end;

  if nLen < 1 then Exit;
  //no data

  if (nRet = $01) or (nRet = $02) or (nRet = $03) or (nRet = $04) or
     (nRet = $FB) then  //代表已查找结束，并且内容有发生变化
  begin
    nData := getStr(FBuffer, nLen);
    m := 1;

    for nIdx:=1 to nNum do
    begin
      nLen := ord(nData[m]) + 1;
      nStr := Copy(nData, 1, nLen);
      m := m + nLen;

      if Length(nStr) <> nLen then Continue;
      Result := True;
      
      nStr := getHexStr(nStr);
      nReader.FCard := Copy(nStr, 3, Length(nStr));

      if Assigned(FOwner.FOnProc) then
        FOwner.FOnProc(nReader);
      //xxxxx

      if Assigned(FOwner.FOnEvent) then
        FOwner.FOnEvent(nReader);
      //xxxxx
    end;
  end;
end;

initialization
  gHYReaderManager := nil;
finalization
  FreeAndNil(gHYReaderManager);
end.
