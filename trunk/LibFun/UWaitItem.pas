{*******************************************************************************
  ����: dmzn@163.com 2007-11-23
  ����: ʵ��һ���ȴ�����

  ����:
  &.TWaitObject��EnterWait��,���еĻ��Ѳ���ֻ������"�ȴ����",��һ�ν���ȴ���,
  ����"�ȴ����"ֱ���˳�,������ִ��WaitForSingleObject����.
  &.EnterWait��LeaveWait���麯��,����ɶԶ�����.
*******************************************************************************}
unit UWaitItem;

interface

uses
  Windows, Classes;

const
  Wait_BusyWait = $0000;

type
  TWaitObject = class(TObject)
  private
    FEvent: THandle;
    {*�ȴ��¼�*}
    FInterval: Cardinal;
    {*�ȴ����*}
    FWaitResult: Cardinal;
    {*�ȴ����*}
    FIsBusy, FBusyMark: Boolean;
    {*�Ƿ�ȴ�*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure EnterWait;
    procedure LeaveWait;
    {*�ȴ��麯��*}
    procedure WakeUP;
    {*���ѵȴ�*}
    procedure  ResetWait;
    {*���õȴ�״̬*}
    property WaitResult: Cardinal read FWaitResult;
    property Interval: Cardinal read FInterval write FInterval;
  end;

implementation

constructor TWaitObject.Create;
begin
  inherited Create;
  FInterval := INFINITE;
  FEvent := CreateEvent(nil, False, False, nil);
end;

destructor TWaitObject.Destroy;
begin
  CloseHandle(FEvent);
  inherited;
end;

procedure TWaitObject.EnterWait;
begin
  if FBusyMark then
  begin
    FBusyMark := False;
    FWaitResult := Wait_BusyWait;
  end else
  begin
    FWaitResult := WaitForSingleObject(FEvent, FInterval);
    FIsBusy := True;
    ResetEvent(FEvent);
  end;
end;

procedure TWaitObject.LeaveWait;
begin
  FIsBusy := False;
end;

procedure TWaitObject.ResetWait;
begin
  FBusyMark := False;
end;

procedure TWaitObject.WakeUP;
begin
  if FIsBusy then
       FBusyMark := True
  else SetEvent(FEvent);
end;

end.
