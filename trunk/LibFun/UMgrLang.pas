{*******************************************************************************
  ����: dmzn@163.com 2010-4-22
  ����: �����Թ�����

  ��ע:
  *.��������xml��ʽ���,�ṹ����:

  <?xml version="1.0" encoding="UTF-16"?>
  <MultiLang>
    <Config>
      <default>en</default>
    </Config>
    <Langs>
      <Lang Name="��������" ID="cn"/>
      <Lang Name="��������" ID="tw"/>
      <Lang Name="English" ID="en"/>
    </Langs>
    <Sections>
      <Section Name="test">
        <Item>
          <cn>�ļ�</cn>
          <tw>�ļ�</tw>
          <en>file</en>
        </Item>
        <Item>
          <cn>�༭</cn>
          <tw>�༭</tw>
          <en>edit</en>
        </Item>
      </Section>
    </Sections>
  </MultiLang>

  *.ʹ�÷���:
    1.ʹ��LoadLangFile���������ļ�.
    2.����NowLangָ����ǰ����ʹ�õ����Ա��.
    3.����LangIDָ����Ҫ��������Ա��.
    4.����SectionIDָ��ʹ�õ���Դ����.
    5.ʹ��TranslateAllCtrl����ָ�����
*******************************************************************************}
unit UMgrLang;

interface

uses
  Windows, Classes, Controls, ComCtrls, SysUtils, Menus, NativeXml, ULibFun,
  UAdjustForm, TypInfo;

type
  TMultiLangItem = record
    FName: string;
    FLangID: string;
  end;

  TDynamicLangItem = array of TMultiLangItem;
  //������

  TMultiLangPropertyItem = record
    FClassName: string;
    FProperty: string;
  end;
  //�跭��Ķ���

  TOnTransItem = procedure (const nItem: TComponent; var nNext: Boolean) of object;
  //�¼�

  TMultiLangManager = class(TObject)
  private
    FXML: TNativeXml;
    //��������
    FLang: string;
    //���Ա�ʶ
    FLangFile: string;
    //�����ļ�
    FLangItems: TDynamicLangItem;
    //�����б�
    FNowLang: string;
    //��ǰ����
    FNowSection: string;
    //ѡ������
    FNowNode: TXmlNode;
    //ѡ�нڵ�
    FHasChanged: Boolean;
    FHasItemID: Boolean;
    FNewNode: Boolean;
    //�Զ��½�
    FPropItems: array of TMultiLangPropertyItem;
    //�ض�����
    FOnTrans: TOnTransItem;
    //�¼����
  protected
    procedure GetLangItems;
    procedure DefaultLang(var nLang: string; nGet: Boolean);
    //Ĭ������
    procedure SetLangID(const nID: string);
    //��������
    procedure SetNowSection(const nSection: string);
    //��������
    procedure NewLangItem(const nItemID,nLang: string);
    //�½��ڵ�
    function TranslateMenu(const nMenu: TComponent): Boolean;
    function TranslateToolBar(const nBar: TComponent): Boolean;
    function TranslateStatusBar(const nBar: TComponent): Boolean;
    function TranslateLableEdit(const nEdit: TComponent): Boolean;
    function TranslateCommCtrl(const nCtrl: TComponent): Boolean;
    //�������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    function LoadLangFile(const nFile: string): Boolean;
    function SaveLangFile(const nFile: string): Boolean;
    //���뱣��
    procedure RegItem(const nClassName,nProp: string);
    //ע�����
    procedure TranslateAllCtrl(const nItem: TComponent);
    //�������
    function GetTextByID(const nID: string): string;
    function GetTextByText(const nStr,nLang: string): string;
    //�ض�����
    property XMLObj: TNativeXml read FXML;
    property LangFile: string read FLangFile;
    property LangItems: TDynamicLangItem read FLangItems;
    property LangID: string read FLang write FLang;
    property NowLang: string read FNowLang write FNowLang;
    property AutoNewNode: Boolean read FNewNode write FNewNode;
    property HasItemID: Boolean read FHasItemID write FHasItemID;
    property SectionID: string read FNowSection write SetNowSection;
    property OnTransItem: TOnTransItem read FOnTrans write FOnTrans;
    //�������
  end;

var
  gMultiLangManager: TMultiLangManager = nil;
  //ȫ��ʹ��

function ML(const nStr: string; const nSecton: string = ''; const nID: string = '';
 const nRestore: Boolean = False; const nDefault: string = ''): string;
//�����Է���

implementation

const
  cHasText: array[0..2] of string = ('TEdit', 'TcxTextEdit', 'TcxButtonEdit');
  //has text property

  cHasTitle: array[0..0] of string = ('TZnTitleBar');
  //has title property

  cHasCaption: array[0..15] of string = ('TButton', 'TBitBtn', 'TSpeedButton',
               'TLabel', 'TStaticText', 'TPanel', 'TGroupbox', 'TRadioGroup',
               'TCheckbox', 'TRadioButton', 'TTabSheet',
               'TcxLabel', 'TcxRadioGroup', 'TcxCheckBox', 'TcxRadioButton',
               'TcxGroupBox');
  //has caption property

//------------------------------------------------------------------------------
//Date: 2010-4-23
//Parm: ������;���ڶ�;���;Ĭ��
//Desc: ʹ��ȫ�ֶ����Է���������nStr������
function ML(const nStr: string; const nSecton,nID: string; const nRestore: Boolean;
 const nDefault: string): string;
var nRID: string;
begin
  with gMultiLangManager do
  try
    FHasChanged := False;
    nRID := SectionID;

    if nSecton <> '' then
      SectionID := nSecton;
    //xxxxx

    if nID <> '' then
         Result := GetTextByID(nID)
    else Result := '';

    if Result = '' then
      Result := GetTextByText(nStr, NowLang);
    //xxxxx
    
    if Result = '' then
    begin
      if nDefault = '' then
           Result := nStr
      else Result := nDefault;

      NewLangItem(nID, nStr);
    end;

    if FHasChanged then
      SaveLangFile(FLangFile);
    //xxxxx
  finally
    if nRestore and (nRID <> '') then SectionID := nRID;
  end;
end;

//------------------------------------------------------------------------------
constructor TMultiLangManager.Create;
var i,nLen,nIdx: Integer;
begin
  FXML := nil;
  FLang := '';

  FNewNode := True;
  HasItemID := True;
  FNowNode := nil;
  FNowSection := '';

  nIdx := 0;
  nLen := Length(cHasCaption) + Length(cHasTitle) + Length(cHasText);
  SetLength(FPropItems, nLen);

  nLen := High(cHasCaption);
  for i:=Low(cHasCaption) to nLen do
  begin
    FPropItems[nIdx].FClassName := cHasCaption[i];
    FPropItems[nIdx].FProperty := 'Caption';
    Inc(nIdx);
  end;

  nLen := High(cHasTitle);
  for i:=Low(cHasTitle) to nLen do
  begin
    FPropItems[nIdx].FClassName := cHasTitle[i];
    FPropItems[nIdx].FProperty := 'Title';
    Inc(nIdx);
  end;

  nLen := High(cHasText);
  for i:=Low(cHasText) to nLen do
  begin
    FPropItems[nIdx].FClassName := cHasText[i];
    FPropItems[nIdx].FProperty := 'Text';
    Inc(nIdx);
  end;
end;

destructor TMultiLangManager.Destroy;
begin
  if Assigned(FXML) then
    FXML.Free;
  inherited;
end;

//Desc: ע��nClassName����,������nProp����
procedure TMultiLangManager.RegItem(const nClassName,nProp: string);
var i,nLen: Integer;
begin
  nLen := High(FPropItems);
  for i:=Low(FPropItems) to nLen do
   if (CompareText(nClassName, FPropItems[i].FClassName) = 0) and
      (CompareText(nProp, FPropItems[i].FProperty) = 0) then Exit;
  //xxxxx

  Inc(nLen);
  SetLength(FPropItems, nLen + 1);
  FPropItems[nLen].FClassName := nClassName;
  FPropItems[nLen].FProperty := nProp;
end;

//Desc: ��ȡnFile�����ļ�
function TMultiLangManager.LoadLangFile(const nFile: string): Boolean;
begin
  Result := True;
  try
    if not Assigned(FXML) then
      FXML := TNativeXml.Create;
    FXML.LoadFromFile(nFile);

    FHasChanged := False;
    FLangFile := nFile;
    SectionID := '';

    GetLangItems;
    DefaultLang(FLang, True);

    if FHasChanged then
      SaveLangFile(FLangFile);
    //xxxxx
  except
    FreeAndNil(FXML);
    Result := False;
  end;
end;

//Desc: ���浽nFile�ļ�
function TMultiLangManager.SaveLangFile(const nFile: string): Boolean;
begin
  Result := True;
  if Assigned(FXML) then
  try
    FHasChanged := False;
    FXML.XmlFormat := xfReadable;
    FXML.SaveToFile(FLangFile);
  except
    Result := False;
  end;
end;

//Desc: ֧�ֵ������б�
procedure TMultiLangManager.GetLangItems;
var i,nCount: Integer;
    nNode,nTmp: TXmlNode;
begin
  nNode := FXML.Root.FindNode('Langs');
  SetLength(FLangItems, nNode.NodeCount);

  i := 0;
  nCount := nNode.NodeCount - 1;
  while i <= nCount do
  begin
    nTmp := nNode.Nodes[i];
    FLangItems[i].FName := nTmp.AttributeByName['Name'];
    FLangItems[i].FLangID := nTmp.AttributeByName['ID'];

    Inc(i);
  end;
end;

//Desc: Ĭ������
procedure TMultiLangManager.DefaultLang(var nLang: string; nGet: Boolean);
var nNode: TXmlNode;
begin
  nNode := FXML.Root.FindNode('Config').FindNode('default');
  if nGet then
       nLang := nNode.ValueAsString
  else nNode.ValueAsString := nLang;
end;

//Desc: �������Ա�ʶ
procedure TMultiLangManager.SetLangID(const nID: string);
begin
  if Assigned(FXML) and (nID <> FLang) then
  begin
    FLang := nID;
    DefaultLang(FLang, False);
    FHasChanged := True;
  end;
end;

//Desc: ����nSection����
procedure TMultiLangManager.SetNowSection(const nSection: string);
var nIdx: Integer;
    nNode,nTmp: TXmlNode;
begin
  if Assigned(FXML) and (nSection <> FNowSection) then
  begin
    FNowSection := nSection;
    FNowNode := nil;
    if nSection = '' then Exit;

    nNode := FXML.Root.FindNode('Sections');
    for nIdx:=nNode.NodeCount - 1 downto 0 do
    begin
      nTmp := nNode.Nodes[nIdx];
      if CompareText(nSection, nTmp.AttributeByName['Name']) = 0 then
      begin
        FNowNode := nTmp; Exit;
      end;
    end;

    if FNewNode then
    begin
      FNowNode := nNode.NodeNew('Section');
      FNowNode.AttributeAdd('Name', nSection);
      FHasChanged := True;
    end;
  end;
end;

//Desc: ��nValue���б��봦��,���˻س��������������ַ�
function RegularValue(const nValue: string; const nEncode: Boolean): string;
begin
  if nEncode then
  begin
    Result := StringReplace(nValue, #13#10, '$DA;', [rfReplaceAll]);
    Result := StringReplace(Result, #13, '$D;', [rfReplaceAll]);
    Result := StringReplace(Result, #10, '$A;', [rfReplaceAll]);
    Result := StringReplace(Result, #32, '$B;', [rfReplaceAll]);
    Result := StringReplace(Result, '<', '$L;', [rfReplaceAll]);
    Result := StringReplace(Result, '>', '$G;', [rfReplaceAll]);
    Result := StringReplace(Result, '&', '$M;', [rfReplaceAll]);
    Result := StringReplace(Result, '''', '$P;', [rfReplaceAll]);
  end else
  begin
    Result := StringReplace(nValue, '$DA;', #13#10, [rfReplaceAll]);
    Result := StringReplace(Result, '$D;', #13, [rfReplaceAll]);
    Result := StringReplace(Result, '$A;', #10, [rfReplaceAll]);
    Result := StringReplace(Result, '$B;', #32, [rfReplaceAll]);
    Result := StringReplace(Result, '$L;', '<', [rfReplaceAll]);
    Result := StringReplace(Result, '$G;', '>', [rfReplaceAll]);
    Result := StringReplace(Result, '$M;', '&', [rfReplaceAll]);
    Result := StringReplace(Result, '$P;', '''', [rfReplaceAll]);
  end;
end;

//Desc: ��ȡnID��Ӧ��
function TMultiLangManager.GetTextByID(const nID: string): string;
var nNode: TXmlNode;
    i,nCount: integer;
begin
  Result := '';
  if not Assigned(FNowNode) then Exit;

  nCount := FNowNode.NodeCount - 1;
  for i:=0 to nCount do
  begin
    nNode := FNowNode.Nodes[i];
    if CompareText(nID, nNode.AttributeByName['ID']) = 0 then
    begin
      nNode := nNode.FindNode(FLang);
      if Assigned(nNode) then
        Result := RegularValue(nNode.ValueAsString, False);
      Exit;
    end;
  end;
end;

//Date: 2010-4-22
//Parm: ����,���Ա�ʶ
//Desc: ��ȡnLangʱ����ΪnStr�����ݶ�Ӧ�ĵ�ǰ��������
function TMultiLangManager.GetTextByText(const nStr,nLang: string): string;
var nTrim: string;
    i,nCount: integer;
    nNode,nTmp: TXmlNode;
begin
  Result := '';
  if not Assigned(FNowNode) then Exit;

  nTrim := RegularValue(nStr, True);
  nCount := FNowNode.NodeCount - 1;

  for i:=0 to nCount do
  begin
    nNode := FNowNode.Nodes[i];
    nTmp := nNode.FindNode(nLang);
    if not Assigned(nTmp) then Continue;

    if CompareText(nTrim, nTmp.ValueAsString) = 0 then
    begin
      nNode := nNode.FindNode(FLang);
      if Assigned(nNode) then
        Result := RegularValue(nNode.ValueAsString, False);
      Exit;
    end;
  end;
end;

//Date: 2010-4-28
//Parm: �ڵ�;����
//Desc: ��nItem�´�����֧�ֵĶ����Խڵ�,����ΪnLang
procedure TMultiLangManager.NewLangItem(const nItemID,nLang: string);
var nIdx: Integer;
    nNode: TXmlNode;
begin
  if FNewNode and (Trim(nLang) <> '') and Assigned(FNowNode)then
  begin
    nNode := FNowNode.NodeNew('Item');
    if FHasItemID then
      nNode.AttributeAdd('ID', nItemID);
    //xxxxx

    for nIdx:=Low(FLangItems) to High(FLangItems) do
      nNode.NodeNew(FLangItems[nIdx].FLangID).ValueAsString := RegularValue(nLang, True);
    FHasChanged := True;
  end;
end;

//------------------------------------------------------------------------------
//Desc: ö��nPItem�µ��������
procedure EnumSubComponentList(const nPItem: TComponent; const nList: TList);
var i,nCount: integer;
begin
  with nPItem do
  begin
    nCount := ComponentCount - 1;

    for i:=0 to nCount do
    if nList.IndexOf(Components[i]) < 1 then
    begin
      nList.Add(Components[i]);
      EnumSubComponentList(Components[i], nList);
    end;
  end;
end;

//Desc: ����nItemԪ�ص���ǰ����,������Ԫ��
procedure TMultiLangManager.TranslateAllCtrl(const nItem: TComponent);
var nList: TList;
    nNext: Boolean;
    nTemp: TComponent;
    i,nCount: Integer;
begin
  if Assigned(FXML) and Assigned(FNowNode) then
       FHasChanged := False
  else Exit;

  nList := TList.Create;
  try
    nList.Add(nItem);
    if nItem is TWinControl then
      EnumSubCtrlList(TWinControl(nItem), nList);
    EnumSubComponentList(nItem, nList);

    nCount := nList.Count - 1;
    for i:=0 to nCount do
    begin
      nTemp := TComponent(nList[i]);

      if Assigned(FOnTrans) then
      begin
        nNext := True;
        FOnTrans(nTemp, nNext);
        if not nNext then Continue;
      end;

      if TranslateMenu(nTemp) then Continue;
      if TranslateToolBar(nTemp) then Continue;
      if TranslateLableEdit(nTemp) then Continue;
      if TranslateStatusBar(nTemp) then Continue;
      if TranslateCommCtrl(nTemp) then Continue;
    end;
  finally
    nList.Free;
    if FHasChanged and Assigned(FXML) then SaveLangFile(FLangFile);
  end;
end;

//Desc: ������nPrefixΪǰ׺,nSuffixΪ��׺�Ľڵ�ID
function MakeID(const nPrefix,nName: string; const nSuffix: string = ''): string;
begin
  if nSuffix = '' then
       Result := Format('%s_%s', [nPrefix, nName])
  else Result := Format('%s_%s:%s', [nPrefix, nName, nSuffix]);
end;

//Desc: ö��nPMenu�������Ӳ˵���
procedure EnumSubMenuItem(const nPMenu: TMenuItem; const nList: TList);
var i,nCount: integer;
begin
  nCount := nPMenu.Count - 1;
  for i:=0 to nCount do
  begin
    nList.Add(nPMenu.Items[i]);
    if nPMenu.Items[i].Count > 0 then
      EnumSubMenuItem(nPMenu.Items[i], nList);
    //xxxxx
  end;
end;

//Desc: ����˵�
function TMultiLangManager.TranslateMenu(const nMenu: TComponent): Boolean;
var nStr: string;
    nList: TList;
    nItem: TMenuItem;
    i,nCount: integer;
begin
  Result := nMenu is TMenu;
  if not Result then Exit;

  nList := TList.Create;
  try
    nCount := TMenu(nMenu).Items.Count - 1;
    for i:=0 to nCount do
    begin
      nList.Add(TMenu(nMenu).Items[i]);
      EnumSubMenuItem(TMenu(nMenu).Items[i], nList);
    end;

    nCount := nList.Count - 1;
    for i:=0 to nCount do
    begin
      nItem := TMenuItem(nList[i]);
      nStr := GetTextByID(MakeID(nMenu.Name, nItem.Name));

      if nStr = '' then
        nStr := GetTextByText(nItem.Caption, FNowLang);
      //xxxxx

      if nStr = '' then
           NewLangItem(MakeID(nMenu.Name, nItem.Name), nItem.Caption)
      else nItem.Caption := nStr;
    end;
  finally
    nList.Free;
  end;
end;

//Desc: ���빤����
function TMultiLangManager.TranslateToolBar(const nBar: TComponent): Boolean;
var nStr: string;
    nList: TList;
    nBtn: TToolButton;
    i,nCount: integer;
begin
  Result := nBar is TToolBar;
  if not Result then Exit;

  nList := TList.Create;
  try
    nCount := TToolBar(nBar).ButtonCount - 1;
    for i:=0 to nCount do nList.Add(TToolBar(nBar).Buttons[i]);

    nCount := nList.Count - 1;
    for i:=0 to nCount do
    begin
      nBtn := TToolButton(nList[i]);
      nStr := GetTextByID(MakeID(nBar.Name, nBtn.Name));

      if nStr = '' then
        nStr := GetTextByText(nBtn.Caption, FNowLang);
      //xxxxx

      if nStr = '' then
           NewLangItem(MakeID(nBar.Name, nBtn.Name), nBtn.Caption)
      else nBtn.Caption := nStr;
    end;
  finally
    nList.Free;
  end;
end;

//Desc: ����״̬��
function TMultiLangManager.TranslateStatusBar(const nBar: TComponent): Boolean;
var nStr: string;
    nP: TStatusPanel;
    i,nCount: integer;
begin
  Result := nBar is TStatusBar;
  if not Result then Exit;

  nCount := TStatusBar(nBar).Panels.Count - 1;
  for i:=0 to nCount do
  begin
    nP := TStatusBar(nBar).Panels[i];
    nStr := GetTextByID(MakeID(nBar.Name, IntToStr(i)));

    if nStr = '' then
      nStr := GetTextByText(nP.Text, FNowLang);
    //xxxxx

    if nStr = '' then
         NewLangItem(MakeID(nBar.Name, IntToStr(i)), nP.Text)
    else nP.Text := nStr;
  end;
end;

//Desc: �����ǩ�ı���
function TMultiLangManager.TranslateLableEdit(const nEdit: TComponent): Boolean;
var nStr,nVal: string;
    nObj: TObject;
begin
  Result := CompareText(nEdit.ClassName, 'TLabeledEdit') = 0;
  if not Result then Exit;

  nStr := GetTextByID(MakeID('Edt', nEdit.Name));
  if nStr = '' then
  begin
    nVal := GetStrProp(nEdit, 'Text');
    nStr := GetTextByText(nVal, FNowLang);
  end;

  if nStr = '' then
       NewLangItem(MakeID('Edt', nEdit.Name), nVal)
  else SetStrProp(nEdit, 'Text', nStr);

  nObj := GetObjectProp(nEdit, 'EditLabel');
  nStr := GetTextByID(MakeID('Lbl', nEdit.Name));

  if nStr = '' then
  begin
    nVal := GetStrProp(nObj, 'Caption');
    nStr := GetTextByText(nVal, FNowLang);
  end;

  if nStr = '' then
       NewLangItem(MakeID('Lbl', nEdit.Name), nVal)
  else SetStrProp(nObj, 'Caption', nStr);
end;

//------------------------------------------------------------------------------
//Date: 2010-9-1
//Parm: ����;����(Ex:a.b.c)
//Desc: ����nProp�������ڵĶ���,֧����������(Ex:c��b������,����b)
function FindPropObj(const nCtrl: TObject; var nProp: string): TObject;
var nObj: TObject;
    nList: TStrings;
begin
  Result := nil;

  if Pos('.', nProp) < 2 then
  begin
    if IsPublishedProp(nCtrl, nProp) then
      Result := nCtrl;
    Exit;
  end;

  nList := TStringList.Create;
  try
    if SplitStr(nProp, nList, 0, '.') and IsPublishedProp(nCtrl, nList[0]) and
       (PropType(nCtrl, nList[0]) = tkClass) then
    begin
      nObj := GetObjectProp(nCtrl, nList[0]);
      if Assigned(nObj) then
      begin
        nList.Delete(0);
        nProp := CombinStr(nList, '.');
        Result := FindPropObj(nObj, nProp);
      end;
    end;
  finally
    nList.Free;
  end;
end;

//Desc: ��nValue����nList.Text,ֱ�ӵ�ֵ�ᵼ��nList.Objects[]��ʧ
procedure SetStringsValue(const nList: TStrings; const nValue: string);
var nIdx: Integer;
    nTmp: TStrings;
begin
  nTmp := TStringList.Create;
  try
    nIdx := 0;
    nTmp.Text := nValue;

    while (nIdx < nTmp.Count) and (nIdx < nList.Count) do
    begin
      nList[nIdx] := nTmp[nIdx];
      Inc(nIdx);
    end;
  finally
    nTmp.Free;
  end;
end;

//Date: 2010-9-1
//Parm: ����;����;ֵ;��orд
//Desc: ��дnCtrl.nProg��ֵ
procedure DoCtrlProg(const nCtrl: TObject; const nProg: string;
 var nValue: string; const nGet: Boolean = True);
var nObj: TObject;
begin
  if PropType(nCtrl, nProg) = tkClass then
  begin
    nObj := GetObjectProp(nCtrl, nProg);
    if nObj is TStrings then
    begin
      if nGet then
           nValue := (nObj as TStrings).Text
      else SetStringsValue(nObj as TStrings, RegularValue(nValue, False));
    end;

    Exit;
  end;

  if nGet then
       nValue := GetStrProp(nCtrl, nProg)
  else SetStrProp(nCtrl, nProg, nValue);
end;

//Desc: ���빫���������
function TMultiLangManager.TranslateCommCtrl(const nCtrl: TComponent): Boolean;
var nObj: TObject;
    i,nCount: Integer;
    nStr,nVal,nID,nProp: string;
begin
  Result := False;
  nCount := High(FPropItems);

  for i:=Low(FPropItems) to nCount do
  if CompareText(nCtrl.ClassName, FPropItems[i].FClassName) = 0 then
  begin
    nProp := FPropItems[i].FProperty;
    nObj := FindPropObj(nCtrl, nProp);
    if not Assigned(nObj) then Continue;

    nID := MakeID('COM', nCtrl.Name, FPropItems[i].FProperty);
    nStr := GetTextByID(nID);

    if nStr = '' then
    begin
      DoCtrlProg(nObj, nProp, nVal, True);
      nStr := GetTextByText(nVal, FNowLang);
    end;

    if nStr = '' then
         NewLangItem(nID, nVal)
    else DoCtrlProg(nObj, nProp, nStr, False);

    Result := True;
    //ͬ���������,�����˳�
  end;
end;

initialization
  gMultiLangManager := TMultiLangManager.Create;
finalization
  FreeAndNil(gMultiLangManager);
end.
