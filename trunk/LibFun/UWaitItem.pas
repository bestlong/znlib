{*******************************************************************************
  ����: dmzn@163.com 2007-11-23
  ����: ʵ�ֵȴ�����͸����ܵȴ�������

  ����:
  &.TWaitObject��EnterWait���������,ֱ��Wakeup����.
  &.�ö�����̰߳�ȫ,��A�߳�EnterWait,B�߳�Wakeup.
  &.TWaitTimerʵ��΢�뼶�������.
*******************************************************************************}
unit UWaitItem;

interface

uses
  Windows, Classes, SysUtils;

type
  TWaitObject = class(TObject)
  private
    FEvent: THandle;
    {*�ȴ��¼�*}
    FInterval: Cardinal;
    {*�ȴ����*}
    FStatus: Integer;
    {*�ȴ�״̬*}
    FWaitResult: Cardinal;
    {*�ȴ����*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    function EnterWait: Cardinal;
    procedure Wakeup;
    {*�ȴ�.����*}
    function IsWaiting: Boolean;
    function IsTimeout: Boolean;
    function IsWakeup: Boolean;
    {*�ȴ�״̬*}
    property WaitResult: Cardinal read FWaitResult;
    property Interval: Cardinal read FInterval write FInterval;
  end;

  TWaitTimer = class(TObject)
  private
    FFrequency: Int64;
    {*CPUƵ��*}
    FFlagFirst: Int64;
    {*��ʼ���*}
    FTimeResult: Int64;
    {*��ʱ���*}
  public
    constructor Create;
    procedure StartTime;
    {*��ʼ��ʱ*}
    function EndTime: Int64;
    {*������ʱ*}
    property TimeResult: Int64 read FTimeResult;
    {*�������*}
  end;

procedure StartHighResolutionTimer;
//��ʼ����
function GetHighResolutionTimerResult: Int64;
//��ȡ΢��������

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
  //�����ܼ�����

//Desc: ��ʼһ������
procedure StartHighResolutionTimer;
begin
  if not Assigned(gTimer) then
    gTimer := TWaitTimer.Create;
  gTimer.StartTime;
end;

//Desc: ���ؼ������
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
