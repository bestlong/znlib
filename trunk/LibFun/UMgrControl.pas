{*******************************************************************************
  ����: dmzn@163.com 2008-08-06
  ����: ͳһ����ؼ�(TWinControl)�Ĵ�������

  ��ע:
  &.����GetCtrls��ȡ��ע�������Ϣ,�б���ÿһ����PControlItem
  &.����GetInstances,GetAllInstance��ȡʵ��,ÿһ����TWinControl����
*******************************************************************************}
unit UMgrControl;

interface

uses
  Windows, Classes, SysUtils, Controls;

type
  PControlItem = ^TControlItem;
  TControlItem = record
    FClass: TWinControlClass;       //���
    FClassID: integer;              //��ʶ
    FInstance: TList;               //ʵ��
  end;

  TOnCtrlFree = procedure (const nClassID: integer; const nCtrl: TWinControl;
                             var nNext: Boolean) of Object;
  //ʵ���ͷ�

  TControlManager = class(TObject)
  private
    FCtrlList: array of TControlItem;
    {*�ؼ��б�*}
    FActiveItem: PControlItem;
    {*��ؼ�*}
    FOnCtrlFree: TOnCtrlFree;
    {*�ͷ��¼�*}
  protected
    procedure ClearCtrlList;
    {*�����б�*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure RegCtrl(const nClass: TWinControlClass; const nClassID: integer);
    {*ע��ؼ�*}
    function NewCtrl(const nClassID: integer; const nOwner: TComponent;
      var nIndex: integer): TWinControl;
    function NewCtrl2(const nClassID: integer; const nOwner: TComponent;
      const nAlign: TAlign = alClient): TWinControl;
    {*�����ؼ�*}
    procedure FreeCtrl(const nClassID: integer; const nFree: Boolean = True;
     const nIndex: integer = 0);
    procedure FreeAllCtrl(const nFree: Boolean = True);
    {*�ͷſؼ�*}
    function GetCtrl(const nClassID: integer): PControlItem;
    function GetCtrls(const nList: TList): Boolean;
    {*�����ؼ�*}
    function GetInstances(const nClassID: integer; const nList: TList): Boolean;
    function GetInstance(const nClassID: integer; const nIndex: integer = 0): TWinControl;
    function GetAllInstance(const nList: TList): Boolean;
    {*����ʵ��*}
    function IsInstanceExists(const nClassID: integer): Boolean;
    {*ʵ������*}
    property OnCtrlFree: TOnCtrlFree read FOnCtrlFree write FOnCtrlFree;
    {*����*}
  end;

var
  gControlManager: TControlManager = nil;
  //ȫ��ʹ��

implementation

constructor TControlManager.Create;
begin
  inherited;
  FActiveItem := nil;
  SetLength(FCtrlList, 0);
end;

destructor TControlManager.Destroy;
begin
  ClearCtrlList;
  inherited;
end;

//Desc: ��տؼ��б�
procedure TControlManager.ClearCtrlList;
var nIdx,nNum: integer;
begin
  nNum := High(FCtrlList);
  for nIdx:=Low(FCtrlList) to nNum do
   if Assigned(FCtrlList[nIdx].FInstance) then FCtrlList[nIdx].FInstance.Free;

  SetLength(FCtrlList, 0);
  FActiveItem := nil;
end;

//Date: 2008-8-6
//Parm: ����;��ʶ
//Desc: ע��һ����ʶΪnClassID����
procedure TControlManager.RegCtrl(const nClass: TWinControlClass;
  const nClassID: integer);
var nLen: integer;
begin
  if not Assigned(GetCtrl(nClassID))then
  begin
    nLen := Length(FCtrlList);
    SetLength(FCtrlList, nLen + 1);

    FCtrlList[nLen].FClass := nClass;
    FCtrlList[nLen].FClassID := nClassID;
    FCtrlList[nLen].FInstance := nil;
  end;
end;

//Date: 2008-8-6
//Parm: ��ʶ;�Ƿ��ͷ�;ָ������
//Desc: �ͷ�nClassID�е�nIndex��ʵ��
procedure TControlManager.FreeCtrl(const nClassID: integer;
  const nFree: Boolean; const nIndex: integer);
var nItem: PControlItem;
begin
  nItem := GetCtrl(nClassID);
  if Assigned(nItem) and Assigned(nItem.FInstance) and
     (nIndex >= 0) and (nIndex < nItem.FInstance.Count) and
     Assigned(nItem.FInstance[nIndex]) then
  begin
    if nFree then
      TWinControl(nItem.FInstance[nIndex]).Free;
    nItem.FInstance[nIndex] := nil;
  end;
end;

//Date: 2008-9-22
//Parm: �Ƿ��ͷ�
//Desc: �ͷŵ�ǰע����������ʵ��
procedure TControlManager.FreeAllCtrl(const nFree: Boolean);
var nNext: Boolean;
    m,nLen: integer;
    i,nCount: integer;
    nItem: TControlItem;
begin
  nLen := High(FCtrlList);
  for m:=Low(FCtrlList) to nLen do
  begin
    nItem := FCtrlList[m];
    if not Assigned(nItem.FInstance) then Continue;
    nCount := nItem.FInstance.Count - 1;

    for i:=0 to nCount do
    if Assigned(nItem.FInstance[i]) then
    begin
      nNext := True;
      if Assigned(FOnCtrlFree) then
        FOnCtrlFree(nItem.FClassID, nItem.FInstance[i], nNext);
      if not nNext then Continue;

      if nFree then
        TWinControl(nItem.FInstance[i]).Free;
      nItem.FInstance[i] := nil;
    end;
  end;
end;

//Date: 2008-8-6
//Parm: ���
//Desc: ���ر��ΪnClassID�Ŀؼ�
function TControlManager.GetCtrl(const nClassID: integer): PControlItem;
var nIdx,nNum: integer;
begin
  Result := nil;
  if Assigned(FActiveItem) and (FActiveItem.FClassID = nClassID) then
    Result := FActiveItem else
  begin
    nNum := High(FCtrlList);
    for nIdx:=Low(FCtrlList) to nNum do
    if FCtrlList[nIdx].FClassID = nClassID then
    begin
      Result := @FCtrlList[nIdx];
      FActiveItem := Result; Break;
    end;
  end;
end;

//Date: 2008-8-6
//Parm: �б�
//Desc: ö�ٵ�ǰע������пؼ�,����nList��
function TControlManager.GetCtrls(const nList: TList): Boolean;
var nIdx,nNum: integer;
begin
  nList.Clear;
  nNum := High(FCtrlList);

  for nIdx:=Low(FCtrlList) to nNum do
    nList.Add(@FCtrlList[nIdx]);
  Result := nList.Count > 0;
end;
            
//Date: 2008-8-6
//Parm: ��ʶ;����
//Desc: ������ʶΪnClassID���͵ĵ�nIndex��ʵ��
function TControlManager.GetInstance(const nClassID, nIndex: integer): TWinControl;
var nItem: PControlItem;
begin
  Result := nil;
  nItem := GetCtrl(nClassID);

  if Assigned(nItem) and Assigned(nItem.FInstance) and
     (nIndex >= 0) and (nIndex < nItem.FInstance.Count) then
  begin
    Result := TWinControl(nItem.FInstance[nIndex]);
  end;
end;

//Date: 2008-8-6
//Parm: ��ʶ;�б�
//Desc: ��ȡ��ʶΪnClassID���͵�����ʵ��,����nList��
function TControlManager.GetInstances(const nClassID: integer;
  const nList: TList): Boolean;
var i,nCount: integer;
    nItem: PControlItem;
begin
  nList.Clear;
  nItem := GetCtrl(nClassID);

  if Assigned(nItem) and Assigned(nItem.FInstance) then
  begin
    nCount := nItem.FInstance.Count - 1;
    for i:=0 to nCount do
    if Assigned(nItem.FInstance[i]) then nList.Add(nItem.FInstance[i]);
  end;

  Result := nList.Count > 0;
end;

//Date: 2008-8-6
//Parm: �б�
//Desc: ������ǰ��ע��������������ʵ��
function TControlManager.GetAllInstance(const nList: TList): Boolean;
var i,nCount: integer;
    nIdx,nNum: integer;
begin
  nList.Clear;
  nNum := High(FCtrlList);

  for nIdx:=Low(FCtrlList) to nNum do
  if Assigned(FCtrlList[nIdx].FInstance) then
  begin
    nCount := FCtrlList[nIdx].FInstance.Count - 1;
    for i:=0 to nCount do
     if Assigned(FCtrlList[nIdx].FInstance[i]) then
       nList.Add(FCtrlList[nIdx].FInstance[i]);
  end;

  Result := nList.Count > 0;
end;

//Date: 2008-8-6
//Parm: ��ʶ
//Desc: ��ʶΪnClassID�����Ƿ���ʵ��
function TControlManager.IsInstanceExists(const nClassID: integer): Boolean;
begin
  Result := Assigned(GetInstance(nClassID));
end;

//Date: 2008-8-6
//Parm: ��ʶ; ӵ����;ʵ������
//Desc: ����һ��nClassID���ʵ��,��������nIndex
function TControlManager.NewCtrl(const nClassID: integer;
  const nOwner: TComponent; var nIndex: integer): TWinControl;
var i,nCount: integer;
    nItem: PControlItem;
begin
  nIndex := -1;
  Result := nil;

  nItem := GetCtrl(nClassID);
  if not Assigned(nItem) then Exit;

  Result := nItem.FClass.Create(nOwner);
  if Assigned(nItem.FInstance) then
  begin
    nCount := nItem.FInstance.Count - 1;
    for i:=0 to nCount do
    if not Assigned(nItem.FInstance[i]) then
    begin
      nItem.FInstance[i] := Result;
      nIndex := i; Exit;
    end;

    nIndex := nItem.FInstance.Add(Result);
  end else
  begin
    nItem.FInstance := TList.Create;
    nIndex := nItem.FInstance.Add(Result);
  end;
end;

//Date: 2008-9-20
//Parm: ��ʶ;ӵ����;���з�ʽ
//Desc: ����nClasID��Ψһʵ��.��nOwner������,����õ�nOwer��
function TControlManager.NewCtrl2(const nClassID: integer;
  const nOwner: TComponent; const nAlign: TAlign = alClient): TWinControl;
var nIdx: integer;
begin
  Result := GetInstance(nClassID);
  if not Assigned(Result) then
  begin
    Result := NewCtrl(nClassID, nOwner, nIdx);
    if Assigned(Result) and (nOwner is TWinControl) then
    begin
      Result.Parent := TWinControl(nOwner);
      Result.Align := nAlign;
    end;
  end;
end;

initialization
  gControlManager := TControlManager.Create;
finalization
  gControlManager.Free;
end.
