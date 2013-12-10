{*******************************************************************************
  ����: dmzn@163.com 2013-11-20
  ����: �洢���б�ʶ�Ķ���������͵��б�

  ��ע:
  *.�б�֧��TObject,TClass��,����Ҳ��Ϊ��Ӧ�ļ���,��ȷ���б�ʹ����������ʱ,ֻ��
    �������Ͷ�Ӧ�ĺ���,���ɽ���ʹ��.
  *.��TObject���͵��б�,ֻ��ʹ�ú���TObject�ĺ���.
*******************************************************************************}
unit UObjectList;

interface

uses
  Classes, SysUtils;

type
  PObjectDataItem = ^TObjectDataItem;
  TObjectDataItem = record
    FItemID : string;            //�����ʶ
    FObject : TObject;           //����ָ��
    FClass  : TClass;            //����ָ��
    FComponent: TComponentClass; //����ָ��
    FData   : Pointer;           //��������
  end;

  TObjectDataType = (dtObject, dtClass, dtComponent);
  //��������
  TObjectDeleteAction = (daNone, daFree);
  //ɾ������

  TOnFreeObjectDataItemProc = procedure (const nItem: Pointer;
    const nType: TObjectDataType);
  TOnFreeObjectDataItemEvent = procedure (const nItem: Pointer;
    const nType: TObjectDataType) of object;
  //�¼�����

  TObjectDataList = class(TObject)
  private
    FDataList: TList;
    //�����б�
    FDataType: TObjectDataType;
    //��������
    FDelAction: TObjectDeleteAction;
    //ɾ��ִ��
    FFreeProc: TOnFreeObjectDataItemProc;
    FFreeEvent: TOnFreeObjectDataItemEvent;
    //�ͷŶ���
  protected
    procedure ClearList(const nFree: Boolean);
    //������Դ
    function GetObject(Index: Integer): TObject;
    function GetClass(Index: Integer): TClass;
    function GetComponent(Index: Integer): TComponentClass;
    function GetItemEx(Index: Integer): PObjectDataItem;
    //��������
    procedure CheckDataType(const nType: TObjectDataType);
    //��֤����
  public
    constructor Create(const nType: TObjectDataType);
    destructor Destroy; override;
    //�����ͷ�
    function AddItem(const nItem: TObject; const nID: string = '';
     const nData: Pointer = nil): Integer; overload;
    function AddItem(const nItem: TClass; const nID: string = '';
     const nData: Pointer = nil): Integer; overload;
    function AddItem(const nItem: TComponentClass; const nID: string = '';
     const nData: Pointer = nil): Integer; overload;
    //��Ӷ���
    procedure DeleteItem(const nItem: TObject); overload;
    procedure DeleteItem(const nItem: TClass); overload;
    procedure DeleteItem(const nItem: TComponentClass); overload;
    procedure DeleteItem(const nIdx: Integer); overload;
    procedure ClearAll;
    //ɾ������
    function Count: Integer;
    function ItemLow: Integer;
    function ItemHigh: Integer;
    //�����߽�
    function FindItem(const nItem: TObject): Integer; overload;
    function FindItem(const nItem: TClass): Integer; overload;
    function FindItem(const nItem: TComponentClass): Integer; overload;
    function FindItem(const nID: string): Integer; overload;
    //��������
    procedure MoveData(const nDest: TObjectDataList);
    //�ƶ�����
    property DataType: TObjectDataType read FDataType;
    property ObjectA[Index: Integer]: TObject read GetObject;
    property ClassA[Index: Integer]: TClass read GetClass;
    property ComponentA[Index: Integer]: TComponentClass read GetComponent;
    property Item[Index: Integer]: PObjectDataItem read GetItemEx; default;
    property DeleteAction: TObjectDeleteAction read FDelAction write FDelAction;
    property OnFreeProc: TOnFreeObjectDataItemProc read FFreeProc write FFreeProc;
    property OnFreeEvent: TOnFreeObjectDataItemEvent read FFreeEvent write FFreeEvent;
    //�������
  end;

implementation

constructor TObjectDataList.Create(const nType: TObjectDataType);
begin
  FDelAction := daFree;
  FDataType := nType;
  FDataList := TList.Create;
end;

destructor TObjectDataList.Destroy;
begin
  ClearList(True);
  inherited;
end;

function TObjectDataList.Count: Integer;
begin
  Result := FDataList.Count;
end;

function TObjectDataList.ItemLow: Integer;
begin
  Result := 0;
end;

function TObjectDataList.ItemHigh: Integer;
begin
  Result := FDataList.Count - 1;
end;

procedure TObjectDataList.ClearAll;
begin
  ClearList(False);
end;

//Desc: ɾ������ΪnIdx��������
procedure TObjectDataList.DeleteItem(const nIdx: Integer);
var nItem: PObjectDataItem;
begin
  if nIdx < ItemLow then Exit;
  nItem := FDataList[nIdx];

  if (FDataType = dtObject) and
     (FDelAction = daFree) and Assigned(nItem.FObject) then
    FreeAndNil(nItem.FObject);
  //xxxxx

  if Assigned(nItem.FData) then
  begin
    if Assigned(FFreeProc) then
      FFreeProc(nItem.FData, FDataType);
    //xxxxx

    if Assigned(FFreeEvent) then
      FFreeEvent(nItem.FData, FDataType);
    //xxxxx
  end;

  Dispose(nItem);
  FDataList.Delete(nIdx);
end;

//Desc: ����б�
procedure TObjectDataList.ClearList(const nFree: Boolean);
var nIdx: Integer;
begin
  for nIdx:=ItemHigh downto ItemLow do
    DeleteItem(nIdx);
  //xxxxx

  if nFree then
    FreeAndNil(FDataList);
  //xxxxx
end;

//------------------------------------------------------------------------------
//Desc: ��֤nType�����Ƿ��뵱ǰ�б�����ƥ��
procedure TObjectDataList.CheckDataType(const nType: TObjectDataType);
begin
  if nType <> FDataType then
    raise Exception.Create('�����������������б�ƥ��.');
  //xxxxx
end;

//Desc: ���nItem����
function TObjectDataList.AddItem(const nItem: TObject; const nID: string;
  const nData: Pointer): Integer;
var nP: PObjectDataItem;
begin
  CheckDataType(dtObject);
  Result := FindItem(nItem);

  if Result < 0 then
  begin
    New(nP);
    Result := FDataList.Add(nP);
  end else nP := FDataList[Result];

  with nP^ do
  begin
    FObject := nItem;
    FItemID := nID;
    FData := nData;
  end;
end;

//Desc: ���nItem����
function TObjectDataList.AddItem(const nItem: TClass; const nID: string;
  const nData: Pointer): Integer;
var nP: PObjectDataItem;
begin
  CheckDataType(dtClass);
  Result := FindItem(nItem);

  if Result < 0 then
  begin
    New(nP);
    Result := FDataList.Add(nP);
  end else nP := FDataList[Result];

  with nP^ do
  begin
    FClass := nItem;
    FItemID := nID;
    FData := nData;
  end;
end;

//Desc: ���nItem�������
function TObjectDataList.AddItem(const nItem: TComponentClass;
  const nID: string; const nData: Pointer): Integer;
var nP: PObjectDataItem;
begin
  CheckDataType(dtComponent);
  Result := FindItem(nItem);

  if Result < 0 then
  begin
    New(nP);
    Result := FDataList.Add(nP);
  end else nP := FDataList[Result];

  with nP^ do
  begin
    FClass := nItem;
    FItemID := nID;
    FData := nData;
  end;
end;

//Desc: ɾ��nItem����
procedure TObjectDataList.DeleteItem(const nItem: TObject);
begin
  CheckDataType(dtObject);
  DeleteItem(FindItem(nItem));
end;

//Desc: ɾ��nItem����
procedure TObjectDataList.DeleteItem(const nItem: TClass);
begin
  CheckDataType(dtClass);
  DeleteItem(FindItem(nItem));
end;

//Desc: ɾ��nItem�������
procedure TObjectDataList.DeleteItem(const nItem: TComponentClass);
begin
  CheckDataType(dtComponent);
  DeleteItem(FindItem(nItem));
end;

//------------------------------------------------------------------------------
//Desc: ����nItem���������
function TObjectDataList.FindItem(const nItem: TObject): Integer;
var nIdx: Integer;
begin
  CheckDataType(dtObject);
  Result := -1;

  for nIdx:=ItemLow to ItemHigh do
  if PObjectDataItem(FDataList[nIdx]).FObject = nItem then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Desc: ����nItem���͵�����
function TObjectDataList.FindItem(const nItem: TClass): Integer;
var nIdx: Integer;
begin
  CheckDataType(dtClass);
  Result := -1;

  for nIdx:=ItemLow to ItemHigh do
  if PObjectDataItem(FDataList[nIdx]).FClass = nItem then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Desc: ����nItem����������
function TObjectDataList.FindItem(const nItem: TComponentClass): Integer;
var nIdx: Integer;
begin
  CheckDataType(dtComponent);
  Result := -1;

  for nIdx:=ItemLow to ItemHigh do
  if PObjectDataItem(FDataList[nIdx]).FComponent = nItem then
  begin
    Result := nIdx;
    Break;
  end
end;

//Desc: ������ʶΪnID����������
function TObjectDataList.FindItem(const nID: string): Integer;
var nIdx: Integer;
begin
  Result := -1;

  for nIdx:=ItemLow to ItemHigh do
  if CompareText(nID, PObjectDataItem(FDataList[nIdx]).FItemID) = 0 then
  begin
    Result := nIdx;
    Break;
  end;  
end;

function TObjectDataList.GetObject(Index: Integer): TObject;
begin
  CheckDataType(dtObject);
  Result := PObjectDataItem(FDataList[Index]).FObject;
end;

function TObjectDataList.GetClass(Index: Integer): TClass;
begin
  CheckDataType(dtClass);
  Result := PObjectDataItem(FDataList[Index]).FClass;
end;

function TObjectDataList.GetComponent(Index: Integer): TComponentClass;
begin
  CheckDataType(dtComponent);
  Result := PObjectDataItem(FDataList[Index]).FComponent;
end;

function TObjectDataList.GetItemEx(Index: Integer): PObjectDataItem;
begin
  Result := FDataList[Index];
end;

//Desc: �������ƶ���nDest�б���
procedure TObjectDataList.MoveData(const nDest: TObjectDataList);
var nIdx: Integer;
begin
  CheckDataType(nDest.DataType);
  for nIdx:=ItemLow to ItemHigh do
    nDest.FDataList.Add(FDataList[nIdx]);
  FDataList.Clear;
end;

end.
