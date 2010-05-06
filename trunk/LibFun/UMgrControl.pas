{*******************************************************************************
  作者: dmzn@163.com 2008-08-06
  描述: 统一管理控件(TWinControl)的创建销毁

  备注:
  &.方法GetCtrls获取已注册类的信息,列表中每一项是PControlItem
  &.方法GetInstances,GetAllInstance获取实例,每一项是TWinControl对象
*******************************************************************************}
unit UMgrControl;

interface

uses
  Windows, Classes, SysUtils, Controls;

type
  PControlItem = ^TControlItem;
  TControlItem = record
    FClass: TWinControlClass;       //类别
    FClassID: integer;              //标识
    FInstance: TList;               //实例
  end;

  TOnCtrlFree = procedure (const nClassID: integer; const nCtrl: TWinControl;
                             var nNext: Boolean) of Object;
  //实例释放

  TControlManager = class(TObject)
  private
    FCtrlList: array of TControlItem;
    {*控件列表*}
    FActiveItem: PControlItem;
    {*活动控件*}
    FOnCtrlFree: TOnCtrlFree;
    {*释放事件*}
  protected
    procedure ClearCtrlList;
    {*清理列表*}
  public
    constructor Create;
    destructor Destroy; override;
    {*创建释放*}
    procedure RegCtrl(const nClass: TWinControlClass; const nClassID: integer);
    {*注册控件*}
    function NewCtrl(const nClassID: integer; const nOwner: TComponent;
      var nIndex: integer): TWinControl;
    function NewCtrl2(const nClassID: integer; const nOwner: TComponent;
      const nAlign: TAlign = alClient): TWinControl;
    {*创建控件*}
    procedure FreeCtrl(const nClassID: integer; const nFree: Boolean = True;
     const nIndex: integer = 0);
    procedure FreeAllCtrl(const nFree: Boolean = True);
    {*释放控件*}
    function GetCtrl(const nClassID: integer): PControlItem;
    function GetCtrls(const nList: TList): Boolean;
    {*检索控件*}
    function GetInstances(const nClassID: integer; const nList: TList): Boolean;
    function GetInstance(const nClassID: integer; const nIndex: integer = 0): TWinControl;
    function GetAllInstance(const nList: TList): Boolean;
    {*检索实例*}
    function IsInstanceExists(const nClassID: integer): Boolean;
    {*实例存在*}
    property OnCtrlFree: TOnCtrlFree read FOnCtrlFree write FOnCtrlFree;
    {*属性*}
  end;

var
  gControlManager: TControlManager = nil;
  //全局使用

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

//Desc: 清空控件列表
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
//Parm: 类型;标识
//Desc: 注册一个标识为nClassID的类
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
//Parm: 标识;是否释放;指定索引
//Desc: 释放nClassID中第nIndex个实例
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
//Parm: 是否释放
//Desc: 释放当前注册的所有类的实例
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
//Parm: 标记
//Desc: 返回标记为nClassID的控件
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
//Parm: 列表
//Desc: 枚举当前注册的所有控件,放入nList中
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
//Parm: 标识;索引
//Desc: 检索标识为nClassID类型的第nIndex个实例
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
//Parm: 标识;列表
//Desc: 获取标识为nClassID类型的所有实例,存入nList中
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
//Parm: 列表
//Desc: 检索当前已注册的所有类的所有实例
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
//Parm: 标识
//Desc: 标识为nClassID的类是否有实例
function TControlManager.IsInstanceExists(const nClassID: integer): Boolean;
begin
  Result := Assigned(GetInstance(nClassID));
end;

//Date: 2008-8-6
//Parm: 标识; 拥有者;实例索引
//Desc: 创建一个nClassID类的实例,返回索引nIndex
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
//Parm: 标识;拥有者;排列方式
//Desc: 创建nClasID的唯一实例.若nOwner是容器,则放置到nOwer上
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
