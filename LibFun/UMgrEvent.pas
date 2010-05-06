{*******************************************************************************
  作者: dmzn@ylsoft.com 2007-07-31
  描述: 事件管理管理器对象

  备注:
  &.实现事件管理器的类为TEventManager,用于动态绑定组件和已实现的事件.
  &.原理是:获取事件的指针,把它赋值给特定的组件.举例如下:
    1.由名称到组件: nEdit := FindComponent('Edit1');
    2.由名称到事件: nEvent := MethodAddress('Edit1_OnChange');
    3.动态绑定事件: SetMethodProp(nEdit, 'OnChange', nEvent);
*******************************************************************************}
unit UMgrEvent;

interface

uses
  Windows, Classes, Forms, SysUtils, TypInfo;

type
  TOnEmMsg = procedure (const nMsg: string) of object;
  {*提示消息*}

  TEventManager = Class
  private
    FParent: TForm;
    {*组件所在窗体*}
    FEventReg: TStrings;
    {*已注册事件*}
    FEventSet: TStrings;
    {*敏感事件*}
    FOnMsg: TOnEmMsg;
    {*提示消息*}
  protected
    procedure HintMsg(const nMsg: string);
    {*提示消息*}
  public
    constructor Create(AParent: TForm);
    destructor Destroy; override;
    {*创建与释放*}
    procedure RegEvent(const nEvent: string);
    procedure SetEvent(const nEvent: string);
    {*添加事件*}
    procedure ClearRegEvents;
    procedure ClearSetEvents;
    {*清空事件*}
    function BindEvent(const nIgnoreSet: Boolean = False): Boolean;
    {*绑定事件*}
    procedure SetActiveForm(const nForm: TForm);
    {*激活待绑定窗体*}
    property OnMsg: TOnEmMsg read FOnMsg write FOnMsg;
  end;

resourcestring
  Em_UnderLine      = '_';   //下划线
  Em_Comma          = '.';   //逗点
  Em_InvalidEvent   = '无效的事件格式';
  Em_NoImplement    = '未找到匹配的实现过程';
  Em_NoControl      = '未找到匹配的组件';
  Em_NoEvent        = '未找到匹配的事件';

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
//Parm: 消息字符串
//Desc: 触发事件,提示nMsg消息
procedure TEventManager.HintMsg(const nMsg: string);
begin
  if Assigned(FOnMsg) then FOnMsg(nMsg);
end;

//Date: 2007-08-01
//Parm: 注册事件,格式为: ObjName_Event
//Desc: 注册nEvent事件
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
//Parm: 敏感事件,格式为: ObjName.Event
//Desc: 添加nEvent事件
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

//Desc: 清空已注册的事件
procedure TEventManager.ClearRegEvents;
begin
  FEventReg.Clear;
end;

//Desc: 清空敏感事件
procedure TEventManager.ClearSetEvents;
begin
  FEventSet.Clear;
end;

//Desc: 将事件绑定到nForm窗体上
procedure TEventManager.SetActiveForm(const nForm: TForm);
begin
  ClearRegEvents;
  ClearSetEvents;
  FParent := nForm;
end;

//Date: 2007-08-01
//Parm: 是否忽略敏感事件的设置
//Desc: 若忽略,则关联所有已注册事件;否则只关联已注册且为敏感的事件.
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
    //好像没有意义哦
  finally
    nList.Free;
  end;
end;

end.
