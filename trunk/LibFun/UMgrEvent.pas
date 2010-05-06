{*******************************************************************************
  ����: dmzn@ylsoft.com 2007-07-31
  ����: �¼��������������

  ��ע:
  &.ʵ���¼�����������ΪTEventManager,���ڶ�̬���������ʵ�ֵ��¼�.
  &.ԭ����:��ȡ�¼���ָ��,������ֵ���ض������.��������:
    1.�����Ƶ����: nEdit := FindComponent('Edit1');
    2.�����Ƶ��¼�: nEvent := MethodAddress('Edit1_OnChange');
    3.��̬���¼�: SetMethodProp(nEdit, 'OnChange', nEvent);
*******************************************************************************}
unit UMgrEvent;

interface

uses
  Windows, Classes, Forms, SysUtils, TypInfo;

type
  TOnEmMsg = procedure (const nMsg: string) of object;
  {*��ʾ��Ϣ*}

  TEventManager = Class
  private
    FParent: TForm;
    {*������ڴ���*}
    FEventReg: TStrings;
    {*��ע���¼�*}
    FEventSet: TStrings;
    {*�����¼�*}
    FOnMsg: TOnEmMsg;
    {*��ʾ��Ϣ*}
  protected
    procedure HintMsg(const nMsg: string);
    {*��ʾ��Ϣ*}
  public
    constructor Create(AParent: TForm);
    destructor Destroy; override;
    {*�������ͷ�*}
    procedure RegEvent(const nEvent: string);
    procedure SetEvent(const nEvent: string);
    {*����¼�*}
    procedure ClearRegEvents;
    procedure ClearSetEvents;
    {*����¼�*}
    function BindEvent(const nIgnoreSet: Boolean = False): Boolean;
    {*���¼�*}
    procedure SetActiveForm(const nForm: TForm);
    {*������󶨴���*}
    property OnMsg: TOnEmMsg read FOnMsg write FOnMsg;
  end;

resourcestring
  Em_UnderLine      = '_';   //�»���
  Em_Comma          = '.';   //����
  Em_InvalidEvent   = '��Ч���¼���ʽ';
  Em_NoImplement    = 'δ�ҵ�ƥ���ʵ�ֹ���';
  Em_NoControl      = 'δ�ҵ�ƥ������';
  Em_NoEvent        = 'δ�ҵ�ƥ����¼�';

implementation

constructor TEventManager.Create(AParent: TForm);
begin
  FParent := AParent;
  FEventReg := TStringList.Create;
  FEventSet := TStringList.Create;
end;

destructor TEventManager.Destroy;
begin
  FEventReg.Free;
  FEventSet.Free;
  inherited;
end;

//Date: 2007-08-01
//Parm: ��Ϣ�ַ���
//Desc: �����¼�,��ʾnMsg��Ϣ
procedure TEventManager.HintMsg(const nMsg: string);
begin
  if Assigned(FOnMsg) then FOnMsg(nMsg);
end;

//Date: 2007-08-01
//Parm: ע���¼�,��ʽΪ: ObjName_Event
//Desc: ע��nEvent�¼�
procedure TEventManager.RegEvent(const nEvent: string);
var nStr: string;
    nPos: integer;
    nObj: TComponent;
begin
  if FParent.MethodAddress(nEvent) = nil then
  begin
    HintMsg(Em_NoImplement); Exit;
  end;

  nPos := Pos(Em_UnderLine, nEvent);
  if nPos < 2 then
  begin
    HintMsg(Em_InvalidEvent); Exit;
  end;

  nStr := Copy(nEvent, 1, nPos - 1);
  nObj := FParent.FindComponent(nStr);

  if Assigned(nObj) then
  begin
    nStr := nEvent;
    Delete(nStr, 1, nPos);

    if IsPublishedProp(nObj, nStr) then
    begin
      nStr := LowerCase(nEvent);
      if FEventReg.IndexOf(nStr) < 0 then FEventReg.Add(nStr);
    end else HintMsg(Em_NoEvent);
  end else HintMsg(Em_NoControl);
end;

//Date: 2007-08-01
//Parm: �����¼�,��ʽΪ: ObjName.Event
//Desc: ���nEvent�¼�
procedure TEventManager.SetEvent(const nEvent: string);
var nStr: string;
    nPos: integer;
    nObj: TComponent;
begin
  nPos := Pos(Em_Comma, nEvent);
  if nPos < 2 then
  begin
    HintMsg(Em_InvalidEvent); Exit;
  end;

  nStr := Copy(nEvent, 1, nPos - 1);
  nObj := FParent.FindComponent(nStr);

  if Assigned(nObj) then
  begin
    nStr := nEvent;
    Delete(nStr, 1, nPos);

    if IsPublishedProp(nObj, nStr) then
    begin
      nStr := LowerCase(nEvent);
      if FEventSet.IndexOf(nStr) < 0 then FEventSet.Add(nStr);
    end else HintMsg(Em_NoEvent);
  end else HintMsg(Em_NoControl);
end;

//Desc: �����ע����¼�
procedure TEventManager.ClearRegEvents;
begin
  FEventReg.Clear;
end;

//Desc: ��������¼�
procedure TEventManager.ClearSetEvents;
begin
  FEventSet.Clear;
end;

//Desc: ���¼��󶨵�nForm������
procedure TEventManager.SetActiveForm(const nForm: TForm);
begin
  ClearRegEvents;
  ClearSetEvents;
  FParent := nForm;
end;

//Date: 2007-08-01
//Parm: �Ƿ���������¼�������
//Desc: ������,�����������ע���¼�;����ֻ������ע����Ϊ���е��¼�.
function TEventManager.BindEvent(const nIgnoreSet: Boolean): Boolean;
var nStr: string;
    nPos: integer;
    nList: TStrings;
    nObj: TComponent;
    nMethod: TMethod;
    i,nCount: integer;
begin
  nList := TStringList.Create;
  try
    if nIgnoreSet then
       nList.AddStrings(FEventReg) else
    begin
      nCount := FEventSet.Count - 1;
      for i:=0 to nCount do
      begin
        nStr := FEventSet[i];
        nPos := Pos(Em_Comma, nStr);
        nStr[nPos] := Em_UnderLine[1]; 
        if FEventReg.IndexOf(nStr) > -1 then nList.Add(nStr);
      end;
    end;

    nCount := nList.Count - 1;
    for i:=0 to nCount do
    begin
      nPos := Pos(Em_UnderLine, nList[i]);
      nStr := Copy(nList[i], 1, nPos - 1);
      nObj := FParent.FindComponent(nStr);

      nMethod.Code := FParent.MethodAddress(nList[i]);
      nMethod.Data := FParent;

      nStr := nList[i];
      Delete(nStr, 1, nPos);
      SetMethodProp(nObj, nStr, nMethod);
    end;

    Result := True;
    //����û������Ŷ
  finally
    nList.Free;
  end;
end;

end.
