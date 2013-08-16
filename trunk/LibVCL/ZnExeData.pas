{*******************************************************************************
  ����: dmzn dmzn@163.com 2007-01-23
  ����: ʹ��WM_CopyData��Ϣ�����������д����ı�����

  ����: ����Ԫ����Դ��,����/��ҵ�����ʹ��,�����뱣���˴���˵������.�����
  �Ա���Ԫ���˺����޸�,���ʼ�֪ͨ��,лл!
*******************************************************************************}
unit ZnExeData;

interface

uses
  Windows, Classes, ComObj, ExtCtrls, Messages, SysUtils;

type
  TOnDataEvent = procedure (const nData: string) of object;
  TOnDataProcedure = procedure (const nData: string);
  //�յ�����

  TZnPostData = class(TComponent)
  private
    FHwnd: THandle;
    FNext: THandle;
    //��Ϣ�������
    FMsgStr: string;
    FMsgID: Cardinal;
    //��Ϣ��ʶ
    FNum: integer;
    FTimer: TTimer;
    //������
    FData: string;
    //����������
    FOnData: TOnDataEvent;
    FOnEnd: TNotifyEvent;
    FOnTimeout: TNotifyEvent;
    FOnData2: TOnDataProcedure;
    //�¼�
  protected
    procedure WndProc(var nMsg: TMessage);
    procedure DoOnTimer(Sender: TObject);
    procedure SetMsgStr(const nStr: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    //�����ͷ�
    procedure SendData(const nData: string);
    //��������
    property OnDataProc: TOnDataProcedure read FOnData2 write FOnData2;
    //�¼����
  published
    property MsgStr: string read FMsgStr write SetMsgStr;
    property Timeout: integer read FNum write FNum;
    //�������
    property OnData: TOnDataEvent read FOnData write FOnData;
    property OnDataEnd: TNotifyEvent read FOnEnd write FOnEnd;
    property OnTimeout: TNotifyEvent read FOnTimeout write FOnTimeout;
    //�¼����
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RunSoft', [TZnPostData]);
end;

const
  cSender = $0010;
  //���ͷ�
  cReceiver = $0025;
  //���շ�
  cSendOK = $0027;
  //�������
  
constructor TZnPostData.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FNum := 3;
  FMsgStr := CreateClassID;
  FHwnd := Classes.AllocateHWnd(WndProc);
end;

destructor TZnPostData.Destroy;
begin
  DeAllocateHwnd(FHwnd);
  if Assigned(FTimer) then FTimer.Free;
  inherited;
end;

procedure TZnPostData.SetMsgStr(const nStr: string);
begin
  if nStr <> FMsgStr then
  begin
    FMsgStr := nStr;
    if not (csDesigning in ComponentState) then
       FMsgID := RegisterWindowMessage(PChar(FMsgStr));
  end;
end;

procedure TZnPostData.DoOnTimer(Sender: TObject);
begin
  FTimer.Tag := FTimer.Tag + 1;
  if FTimer.Tag >= FNum then
  begin
    FTimer.Enabled := False;
    if Assigned(FOnTimeout) then FOnTimeout(Self);
  end;
end;

procedure TZnPostData.SendData(const nData: string);
begin
  if not Assigned(FTimer) then
  begin
    FTimer := TTimer.Create(nil);
    FTimer.OnTimer := DoOnTimer;
  end;

  FData := nData;
  FNext := 0;
  FTimer.Tag := 0;

  FTimer.Enabled := True;
  PostMessage(HWND_BROADCAST, FMsgID, FHwnd, cSender);
end;

procedure TZnPostData.WndProc(var nMsg: TMessage);
var nBuf: TCopyDataStruct;
begin
  if (nMsg.Msg = FMsgID) and (nMsg.LParam = cSender) and
     (nMsg.WParam <> Integer(FHwnd)) then
  begin
    FNext := nMsg.WParam;
    SendMessage(FNext, FMsgID, FHwnd, cReceiver);
    {------------------------ +Dmzn: 2007-01-24 --------------------
    ��ע: �㲥ʱ���ͷ��Լ�Ҳ���յ�,������Ҫ�Ȱ��Լ����˵�.
    ���շ��ᴦ�������Ϣ,����Ӧ���ͷ���ѯ��,�����Լ��ľ��.
    ----------------------------------------------------------------}
  end else

  if (nMsg.Msg = FMsgID) and (nMsg.LParam = cReceiver) then
  begin
    FTimer.Tag := -2;
    FNext := nMsg.WParam;

    nBuf.cbData := Length(FData);
    nBuf.lpData := PChar(FData);
    SendMessage(FNext, WM_COPYDATA, FHwnd, Cardinal(@nBuf));
    {------------------------ +Dmzn: 2007-01-24 --------------------
    ��ע: ���ͷ��յ����շ������,��ʼ��������,ͬʱ��ʼ���ͳ�ʱ�ļ���.
    ��λ����WParam�з��÷��Ͷ˾��,��Ϊ����ʶ��ı�־
    ----------------------------------------------------------------}
  end else

  if (nMsg.WParam = Integer(FNext)) and (nMsg.Msg = WM_COPYDATA) then
  begin
    SendMessage(nMsg.WParam, FMsgID, FHwnd, cSendOK);
    //�յ����ݺ��ͻ�ִ

    nBuf := TCopyDataStruct((Pointer(nMsg.LParam))^);
    FData := StrPas(nBuf.lpData);
    SetLength(FData, nBuf.cbData);

    if Assigned(FOnData) then FOnData(FData);
    if Assigned(FOnData2) then FOnData2(FData);
    {------------------------ +Dmzn: 2007-01-24 --------------------
    ��ע: ���շ��յ�����,��ִ���ͷ��������¼�.
    ��λ����WParam�з��÷��Ͷ˾��,��Ϊ����ʶ��ı�־
    ----------------------------------------------------------------}
  end else

  if (nMsg.Msg = FMsgID) and (nMsg.LParam = cSendOK) then
  begin
    FTimer.Enabled := False;
    if Assigned(FOnEnd) then FOnEnd(Self);
    {------------------------ +Dmzn: 2007-01-24 --------------------
    ��ע: ���ͷ��յ���ִ,ͣ����ʱ����
    ----------------------------------------------------------------}
  end;
end;


end.