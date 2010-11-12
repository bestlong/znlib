{*******************************************************************************
  ����: dmzn@163.com 2007-11-23
  ����: ʵ��һ���ȴ�����

  ����:
  &.TWaitObject��EnterWait���������,ֱ��Wakeup����.
  &.�ö�����̰߳�ȫ,��A�߳�EnterWait,B�߳�Wakeup.

  *.ע��:
  &.����EnterWait��Wakeup�ɶԳ���,��ʹ���̲߳���,Ҳ��Ҫ��EnterWait->Wakeup.
    ����EnterWait->EnterWait,Wakeup->Wakeup�ǲ��ɹ���.
*******************************************************************************}
unit UWaitItem;

interface

uses
  Windows, Classes;

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
