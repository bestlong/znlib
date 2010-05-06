{*******************************************************************************
  作者: dmzn@163.com 2007-11-23
  描述: 实现一个等待对象

  描述:
  &.TWaitObject在EnterWait后,所有的唤醒操作只是设置"等待标记",下一次进入等待后,
  发现"等待标记"直接退出,而不会执行WaitForSingleObject过程.
  &.EnterWait与LeaveWait是组函数,必须成对儿调用.
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
    {*等待事件*}
    FInterval: Cardinal;
    {*等待间隔*}
    FWaitResult: Cardinal;
    {*等待结果*}
    FIsBusy, FBusyMark: Boolean;
    {*是否等待*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    procedure EnterWait;
    procedure LeaveWait;
    {*等待组函数*}
    procedure WakeUP;
    {*唤醒等待*}
    procedure  ResetWait;
    {*重置等待状态*}
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
