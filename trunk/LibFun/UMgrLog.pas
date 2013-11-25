{*******************************************************************************
  作者: dmzn@163.com 2007-11-02
  描述: 实现对日志的缓存和管理

  备注:
  &.本单元实现了一个日志管理器LogManager.
  &.管理器维护一个Buffer列表,内部存放日志项LogItem.
  &.使用LogManager.AddNewLog添加日志项时,会触发OnNewLog事件,该事件用于普通的
  处理.日志项以指针方式传递,所以事件中可以修改LogItem.FAction,以决定是否要继
  续处理.若FAction=[],则不会分发给"写日志线程".
  &."写日志线程"不知道怎么处理日志,所以它留了一个事件给外部,就是OnWriteLog,传
  递日志项列表,外部可以实现它来决定日志如何处理.即使不作处理,调用完该事件后,日
  志项也会被释放掉.
  &.注意: OnWriteLog非线程安全,必要时需要线程同步.而且不要手工删除日志项,除非
  知道怎么释放.
*******************************************************************************}
unit UMgrLog;

interface

uses
  Windows, Classes, SysUtils, UWaitItem;

type
  TObjectClass = class of TObject;
  TLogTag = set of (ltWriteFile, ltWriteDB, ltWriteCMD);
  //日志标记

  TLogWriter = record
    FOjbect: TObjectClass;         //组件类型
    FDesc: string;                 //描述信息
  end;

  PLogItem = ^TLogItem;
  TLogItem = record
    FWriter: TLogWriter;           //日志作者
    FLogTag: TLogTag;              //日志标记
    FTime: TDateTime;              //日志时间
    FEvent: string;                //日志内容
  end;

  //****************************************************************************
  TLogManager = class;

  TLogThread = class(TThread)
  private
    FWaiter: TWaitObject;
    {*延迟对象*}
    FOwner: TLogManager;
    {*拥有者*}
    FBufferList: TList;
    {*缓冲区*}
  protected
    procedure Execute; override;
    {*执行*}
    procedure WriteErrorLog(const nList: TList);
    {*写入错误*}
  public
    constructor Create(AOwner: TLogManager);
    destructor Destroy; override;
    {*创建释放*}
    procedure Wakeup;
    {*线程唤醒*}
    property Terminated;
    {*属性相关*}
  end;

  TLogEvent = procedure (const nLogs: PLogItem) of Object;
  TWriteLogProcedure = procedure (const nThread: TLogThread; const nLogs: TList);
  TWriteLogEvent = procedure (const nThread: TLogThread; const nLogs: TList) of Object;
  //日志事件,回调函数
  
  TLogManager = class(TObject)
  private
    FBuffer: TThreadList;
    {*缓冲区*}
    FWriter: TLogThread;
    {*写日志线程*}
    FOnNewLog: TLogEvent;
    FEvent: TWriteLogEvent;
    FProcedure: TWriteLogProcedure;
    {*事件*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    function NewLogItem: PLogItem;
    {*申请资源*}
    procedure AddNewLog(const nItem: PLogItem);
    {*新日志*}
    function HasItem: Boolean;
    {*有未写入*}
    property OnNewLog: TLogEvent read FOnNewLog write FOnNewLog;
    property WriteEvent: TWriteLogEvent read FEvent write FEvent;
    property WriteProcedure: TWriteLogProcedure read FProcedure write FProcedure;
    {*属性事件*}
  end;

var
  gLogManager: TLogManager = nil;
  //全局使用,需手工创建

implementation

//Date: 2007-11-02
//Parm: 日志列表
//Desc: 释放nList日志列表
procedure FreeLogList(const nList: TList); overload;
var i,nCount: integer;
begin
  nCount := nList.Count - 1;
  for i:=0 to nCount do
    Dispose(PLogItem(nList[i]));
  nList.Clear;
end;

//Date: 2007-11-02
//Parm: 日志列表
//Desc: 释放nList日志列表
procedure FreeLogList(const nList: TThreadList); overload;
var nTmp: TList;
begin
  nTmp := nList.LockList;
  try
    FreeLogList(nTmp);
  finally
    nList.UnlockList;
  end;
end;

//******************************************************************************
constructor TLogThread.Create(AOwner: TLogManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FBufferList := TList.Create;
  FWaiter := TWaitObject.Create;
end;

destructor TLogThread.Destroy;
begin
  FreeLogList(FBufferList);
  FreeAndNil(FBufferList);

  FWaiter.Free; 
  inherited;
end;

//Desc: 唤醒
procedure TLogThread.Wakeup;
begin
  FWaiter.WakeUP;
end;

//Desc: 写日志线程
procedure TLogThread.Execute;
begin
  while True do
  try
    if Terminated then
    begin
      if not FOwner.HasItem then Break;
      //try save all when thread terminated
    end else
    begin
      FWaiter.EnterWait;
      if (not FOwner.HasItem) and Terminated then Break;
    end;

    if FBufferList.Count > 0 then
    begin
      if Assigned(FOwner.FEvent) then
         FOwner.FEvent(Self, FBufferList);
      if Assigned(FOwner.FProcedure) then
         FOwner.FProcedure(Self, FBufferList);
      FreeLogList(FBufferList);
    end;
  except
    WriteErrorLog(FBufferList);
    FreeLogList(FBufferList);
  end;
end;

//Date: 2007-11-25
//Parm: 日志列表
//Desc: 写日志错误
procedure TLogThread.WriteErrorLog(const nList: TList);
var nItem: PLogItem;
begin
  nItem := FOwner.NewLogItem;
  nItem.FLogTag := [ltWriteFile];
  nItem.FWriter.FOjbect := TLogThread;
  nItem.FWriter.FDesc := '日志线程';
  nItem.FEvent := '有' + IntToStr(nList.Count) + '笔日志写入失败,已丢弃';
  FOwner.AddNewLog(nItem);
end;

//******************************************************************************
//Desc: 创建
constructor TLogManager.Create;
begin
  FBuffer := TThreadList.Create;
  FWriter := TLogThread.Create(Self);
end;

//Desc: 释放
destructor TLogManager.Destroy;
begin
  FWriter.Terminate;
  FWriter.Wakeup;
  FWriter.WaitFor;
  FreeAndNil(FWriter);

  FreeLogList(FBuffer);
  FBuffer.Free;
  inherited;
end;

//Desc: 是否有未写入日志项
function TLogManager.HasItem: Boolean;
var nList: TList;
    nIdx,nCount: integer;
begin
  nList := FBuffer.LockList;
  try
    if FWriter.FBufferList.Count < 1 then
    begin
      nCount := nList.Count - 1;
      for nIdx:=0 to nCount do
        FWriter.FBufferList.Add(nList[nIdx]);
      nList.Clear;
    end;
  finally
    Result := FWriter.FBufferList.Count > 0;
    FBuffer.UnlockList;
  end;
end;

//Desc: 添加日志
procedure TLogManager.AddNewLog(const nItem: PLogItem);
var nList: TList;
begin
  if Assigned(FOnNewLog) then
    FOnNewLog(nItem);
  //基本处理,不用线程写入

  if nItem.FLogTag = [] then
  begin
    Dispose(nItem); Exit;
  end;

  nList := FBuffer.LockList;
  try
    nList.Add(nItem);
  finally
    FBuffer.UnlockList;
    FWriter.Wakeup;
  end;
end;

//Desc: 新日志项,需手工释放
function TLogManager.NewLogItem: PLogItem;
begin
  New(Result);
  Result.FLogTag := [];
  Result.FTime := Now();
end;

end.
