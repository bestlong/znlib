{*******************************************************************************
  作者: dmzn@163.com 2007-11-23
  描述: 实现等待对象和高性能等待计数器

  描述:
  &.TWaitObject在EnterWait后进入阻塞,直到Wakeup唤醒.
  &.该对象多线程安全,即A线程EnterWait,B线程Wakeup.
  &.TWaitTimer实现微秒级间隔计数.
*******************************************************************************}
unit UWaitItem;

interface

uses
  Windows, Classes, SysUtils;

type
  TWaitObject = class(TObject)
  private
    FEvent: THandle;
    {*等待事件*}
    FInterval: Cardinal;
    {*等待间隔*}
    FStatus: Integer;
    {*等待状态*}
    FWaitResult: Cardinal;
    {*等待结果*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    function EnterWait: Cardinal;
    procedure Wakeup;
    {*等待.唤醒*}
    function IsWaiting: Boolean;
    function IsTimeout: Boolean;
    function IsWakeup: Boolean;
    {*等待状态*}
    property WaitResult: Cardinal read FWaitResult;
    property Interval: Cardinal read FInterval write FInterval;
  end;

  TWaitTimer = class(TObject)
  private
    FFrequency: Int64;
    {*CPU频率*}
    FFlagFirst: Int64;
    {*起始标记*}
    FTimeResult: Int64;
    {*计时结果*}
  public
    constructor Create;
    procedure StartTime;
    {*开始计时*}
    function EndTime: Int64;
    {*结束计时*}
    property TimeResult: Int64 read FTimeResult;
    {*属性相关*}
  end;

procedure StartHighResolutionTimer;
//开始计数
function GetHighResolutionTimerResult: Int64;
//获取微秒计数结果

implementation

const
  cIsIdle    = $02;
  cIsWaiting = $27;

constructor TWaitObject.Create;
begin
  inherited Create;
  FStatus := cIsIdle;

  FInterval := INFINITE;
  FEvent := CreateEvent(nil, False, False, nil);
end;

destructor TWaitObject.Destroy;
begin
  CloseHandle(FEvent);
  inherited;
end;

function TWaitObject.IsWaiting: Boolean;
begin
  Result := FStatus = cIsWaiting;
end;

function TWaitObject.IsTimeout: Boolean;
begin
  if IsWaiting then
       Result := False
  else Result := FWaitResult = WAIT_TIMEOUT;
end;

function TWaitObject.IsWakeup: Boolean;
begin
  if IsWaiting then
       Result := False
  else Result := FWaitResult = WAIT_OBJECT_0;
end;

function TWaitObject.EnterWait: Cardinal;
begin
  InterlockedExchange(FStatus, cIsWaiting);
  Result := WaitForSingleObject(FEvent, FInterval);

  FWaitResult := Result;
  InterlockedExchange(FStatus, cIsIdle);
end;

procedure TWaitObject.Wakeup;
begin
  if FStatus = cIsWaiting then
    SetEvent(FEvent);
  //do only waiting
end;

//------------------------------------------------------------------------------
constructor TWaitTimer.Create;
begin
  FTimeResult := 0;
  if not QueryPerformanceFrequency(FFrequency) then
    raise Exception.Create('not support high-resolution performance counter');
  //xxxxx
end;

procedure TWaitTimer.StartTime;
begin
  QueryPerformanceCounter(FFlagFirst);
end;

function TWaitTimer.EndTime: Int64;
var nNow: Int64;
begin
  QueryPerformanceCounter(nNow);
  Result := Trunc((nNow - FFlagFirst) / FFrequency * 1000 * 1000);
  FTimeResult := Result;
end;

//------------------------------------------------------------------------------
var
  gTimer: TWaitTimer = nil;
  //高性能计数器

//Desc: 开始一个计数
procedure StartHighResolutionTimer;
begin
  if not Assigned(gTimer) then
    gTimer := TWaitTimer.Create;
  gTimer.StartTime;
end;

//Desc: 返回计数结果
function GetHighResolutionTimerResult: Int64;
begin
  if Assigned(gTimer) then
       Result := gTimer.EndTime
  else Result := 0;
end;

initialization

finalization
  FreeAndNil(gTimer);
end.
