{*******************************************************************************
  作者: dmzn@163.com 2007-11-23
  描述: 实现一个等待对象

  描述:
  &.TWaitObject在EnterWait后进入阻塞,直到Wakeup唤醒.
  &.该对象多线程安全,即A线程EnterWait,B线程Wakeup.

  *.注意:
  &.方法EnterWait与Wakeup成对出现,即使多线程操作,也需要先EnterWait->Wakeup.
    对于EnterWait->EnterWait,Wakeup->Wakeup是不成功的.
*******************************************************************************}
unit UWaitItem;

interface

uses
  Windows, Classes;

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
    property WaitResult: Cardinal read FWaitResult;
    property Interval: Cardinal read FInterval write FInterval;
  end;

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

function TWaitObject.EnterWait: Cardinal;
var nInt: Integer;
begin
  nInt := InterlockedExchange(FStatus, cIsWaiting);
  if nInt = cIsWaiting then Exit;
  //is waiting

  Result := WaitForSingleObject(FEvent, FInterval);
  FWaitResult := Result;    
  InterlockedExchange(FStatus, cIsIdle);
end;

procedure TWaitObject.Wakeup;
begin
  if FStatus = cIsWaiting then
    SetEvent(FEvent);
  //do this only waiting
end;

end.
