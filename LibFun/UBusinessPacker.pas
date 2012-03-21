{*******************************************************************************
  作者: dmzn@163.com 2012-02-03
  描述: 业务对象数据封装器
*******************************************************************************}
unit UBusinessPacker;

interface

uses
  Windows, Classes, SyncObjs, SysUtils, NativeXml, UBusinessConst, ULibFun;

type
  TBusinessPackerBase = class(TObject)
  protected
    FEnabled: Boolean;
    //可用标记
    FStrBuilder: TStrings;
    //字符构建器
    FXMLBuilder: TNativeXml;
    //XML构建器
    FCodeEnable: Boolean;
    //启用编码
    procedure DoInitIn(const nData: Pointer); virtual;
    procedure DoInitOut(const nData: Pointer); virtual;
    procedure DoPackIn(const nData: Pointer); virtual;
    procedure DoUnPackIn(const nData: Pointer); virtual;
    procedure DoPackOut(const nData: Pointer); virtual;
    procedure DoUnPackOut(const nData: Pointer); virtual;
    //子类实现
    function PackerEncode(const nStr: string): string; overload;
    function PackerEncode(const nDT: TDateTime): string; overload;
    procedure PackerDecode(const nStr: string; var nValue: string); overload;
    procedure PackerDecode(const nStr: string; var nValue: Integer); overload;
    procedure PackerDecode(const nStr: string; var nValue: Cardinal); overload;
    procedure PackerDecode(const nStr: string; var nValue: Int64); overload;
    procedure PackerDecode(const nStr: string; var nValue: Double); overload;
    procedure PackerDecode(const nStr: string; var nValue: TDateTime); overload;
    //打包函数
    procedure PackWorkerInfo(const nBuilder: TStrings; var nInfo: TBWWorkerInfo;
      const nPrefix: string; const nEncode: Boolean = True);
    //打包基数据
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    class function PackerName: string; virtual;
    //函数名
    procedure InitData(const nData: Pointer; const nIn: Boolean);
    //初始化
    function PackIn(const nData: Pointer; nCode: Boolean = True): string;
    procedure UnPackIn(const nStr: string; const nData: Pointer;
      nCode: Boolean = True);
    //入参处理
    function PackOut(const nData: Pointer; nCode: Boolean = True): string;
    procedure UnPackOut(const nStr: string; const nData: Pointer;
      nCode: Boolean = True);
    //出参处理
    property StrBuilder: TStrings read FStrBuilder;
    property XMLBuilder: TNativeXml read FXMLBuilder;
    //属性相关
  end;

  TBusinessPackerClass = class of TBusinessPackerBase;
  //class type

  TBusinessPackerManager = class(TObject)
  private
    FPackerClass: array of TBusinessPackerClass;
    //类列表
    FPackerPool: array of TBusinessPackerBase;
    //对象池
    FNumLocked: Integer;
    //锁定对象
    FSrvClosed: Integer;
    //服务关闭
    FSyncLock: TCriticalSection;
    //同步锁
  protected
    function GetPacker(const nName: string): TBusinessPackerBase;
    //获取工作对象
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure RegistePacker(const nPacker: TBusinessPackerClass);
    //注册类
    function LockPacker(const nName: string): TBusinessPackerBase;
    procedure RelasePacker(const nPacker: TBusinessPackerBase);
    //锁定释放
  end;

function PackerEncodeStr(const nStr: string): string;
function PackerDecodeStr(const nStr: string): string;
//字符编码

var
  gBusinessPackerManager: TBusinessPackerManager = nil;
  //全局使用

implementation

const
  cYes  = $0002;
  cNo   = $0005;

function PackerEncodeStr(const nStr: string): string;
begin
  Result := EncodeBase64(nStr);
end;

function PackerDecodeStr(const nStr: string): string;
begin
  Result := DecodeBase64(nStr);
end;

//------------------------------------------------------------------------------
constructor TBusinessPackerManager.Create;
begin
  FNumLocked := 0;
  FSrvClosed := cNo;
  
  FSyncLock := TCriticalSection.Create;
  SetLength(FPackerPool, 0);

  SetLength(FPackerClass, 1);
  FPackerClass[0] := TBusinessPackerBase;
end;

destructor TBusinessPackerManager.Destroy;
var nIdx: Integer;
begin
  InterlockedExchange(FSrvClosed, cYes);
  //set close float

  FSyncLock.Enter;
  try
    if FNumLocked > 0 then
    try
      FSyncLock.Leave;
      while FNumLocked > 0 do
        Sleep(1);
      //wait for relese
    finally
      FSyncLock.Enter;
    end;

    for nIdx:=Low(FPackerPool) to High(FPackerPool) do
      FreeAndNil(FPackerPool[nIdx]);
    SetLength(FPackerPool, 0);
  finally
    FSyncLock.Leave;
  end;

  FreeAndNil(FSyncLock);
  inherited;
end;

//Date: 2012-3-7
//Parm: 工作对象类
//Desc: 注册nPacker类
procedure TBusinessPackerManager.RegistePacker(
  const nPacker: TBusinessPackerClass);
var nLen: Integer;
begin
  nLen := Length(FPackerClass);
  SetLength(FPackerClass, nLen + 1);
  FPackerClass[nLen] := nPacker;
end;

//Date: 2012-3-7
//Parm: 函数名
//Desc: 获取可以执行nFunName的工作对象
function TBusinessPackerManager.GetPacker(
  const nName: string): TBusinessPackerBase;
var nIdx,nLen: Integer;
begin
  Result := nil;

  for nIdx:=Low(FPackerPool) to High(FPackerPool) do
  if FPackerPool[nIdx].FEnabled and
     (FPackerPool[nIdx].PackerName = nName) then
  begin
    Result := FPackerPool[nIdx];
    Result.FEnabled := False;
    Exit;
  end;

  for nIdx:=Low(FPackerClass) to High(FPackerClass) do
  if FPackerClass[nIdx].PackerName = nName then
  begin
    nLen := Length(FPackerPool);
    SetLength(FPackerPool, nLen + 1);
    FPackerPool[nLen] := FPackerClass[nIdx].Create;

    Result := FPackerPool[nLen];
    Result.FEnabled := False;
    Exit;
  end;
end;

//Desc: 获取工作对象
function TBusinessPackerManager.LockPacker(
  const nName: string): TBusinessPackerBase;
begin
  Result := nil;
  if FSrvClosed = cYes then Exit;
  
  FSyncLock.Enter;
  try
    if FSrvClosed = cYes then Exit;
    Result := GetPacker(nName);
    
    if not Assigned(Result) then
      Result := GetPacker('');
    //the default
  finally
    if Assigned(Result) then
      InterlockedIncrement(FNumLocked);
    FSyncLock.Leave;
  end;
end;

//Desc: 释放工作对象
procedure TBusinessPackerManager.RelasePacker(
  const nPacker: TBusinessPackerBase);
begin
  if Assigned(nPacker) then
  try
    FSyncLock.Enter;
    nPacker.FEnabled := True;
    InterlockedDecrement(FNumLocked);
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
constructor TBusinessPackerBase.Create;
begin
  FEnabled := True;
  FStrBuilder := TStringList.Create;
  FXMLBuilder := TNativeXml.Create;
end;

destructor TBusinessPackerBase.Destroy;
begin
  FStrBuilder.Free;
  FXMLBuilder.Free;
  inherited;
end;

class function TBusinessPackerBase.PackerName: string;
begin
  Result := '';
end;

//Date: 2012-3-14
//Parm: 参数;是否入参
//Desc: 初始化nData数据
procedure TBusinessPackerBase.InitData(const nData: Pointer; const nIn: Boolean);
begin
  with PBWDataBase(nData)^ do
  begin
    FFrom.FTime := Now;
    FFrom.FKpLong := 0;

    FVia.FTime := Now;
    FVia.FKpLong := 0;

    FFinal.FTime := Now;
    FFinal.FKpLong := 0;
    FResult := False;
  end;

  if nIn then
       DoInitIn(nData)
  else DoInitOut(nData);
end;

//Date: 2012-3-7
//Parm: 参数数据;是否编码
//Desc: 对输入数据nData打包处理
function TBusinessPackerBase.PackIn(const nData: Pointer; nCode: Boolean): string;
begin
  FStrBuilder.Clear;
  FCodeEnable := nCode;

  DoPackIn(nData);
  Result := FStrBuilder.Text;
end;

//Date: 2012-3-7
//Parm: 字符数据;解码
//Desc: 对nStr拆包处理
procedure TBusinessPackerBase.UnPackIn(const nStr: string; const nData: Pointer;
  nCode: Boolean);
begin
  FStrBuilder.Text := nStr;
  FCodeEnable := nCode;
  DoUnPackIn(nData);
end;

//Date: 2012-3-7
//Parm: 结构数据;是否编码
//Desc: 对结构数据nData打包处理
function TBusinessPackerBase.PackOut(const nData: Pointer; nCode: Boolean): string;
begin
  FStrBuilder.Clear;
  FCodeEnable := nCode;

  DoPackOut(nData);
  Result := FStrBuilder.Text;
end;

//Date: 2012-3-7
//Parm: 字符数据
//Desc: 对nStr拆包处理
procedure TBusinessPackerBase.UnPackOut(const nStr: string;
 const nData: Pointer; nCode: Boolean);
begin
  FStrBuilder.Text := nStr;
  FCodeEnable := nCode;
  DoUnPackOut(nData);
end;

//Date: 2012-3-7
//Parm: 构建器;信息;前缀;是否编码
//Desc: 处理nInfo的信息
procedure TBusinessPackerBase.PackWorkerInfo(const nBuilder: TStrings;
  var nInfo: TBWWorkerInfo; const nPrefix: string; const nEncode: Boolean);
begin
  with nBuilder,nInfo do
  begin
    if nEncode  then
    begin
      Values[nPrefix + '_User']    := PackerEncode(FUser);
      Values[nPrefix + '_MAC']     := PackerEncode(FMAC);
      Values[nPrefix + '_IP']      := PackerEncode(FIP);
      Values[nPrefix + '_Time']    := PackerEncode(FTime);
      Values[nPrefix + '_KpLong']  := IntToStr(FKpLong);
    end else
    begin
      PackerDecode(Values[nPrefix + '_User'], FUser);
      PackerDecode(Values[nPrefix + '_IP'], FIP);
      PackerDecode(Values[nPrefix + '_MAC'], FMAC);
      PackerDecode(Values[nPrefix + '_Time'], FTime);
      PackerDecode(Values[nPrefix + '_KpLong'], FKpLong);
    end;
  end;
end;

//------------------------------------------------------------------------------
//Desc: 对nStr编码
function TBusinessPackerBase.PackerEncode(const nStr: string): string;
begin
  if FCodeEnable then
       Result := PackerEncodeStr(nStr)
  else Result := nStr;
end;

function TBusinessPackerBase.PackerEncode(const nDT: TDateTime): string;
begin
  try
    Result := DateTime2Str(nDT);
  except
    Result := DateTime2Str(Now);
  end;
end;

//Desc: 字符串
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: string);
begin
  if nStr = '' then
  begin
    nValue := '';
  end else

  if FCodeEnable then
       nValue := PackerDecodeStr(nStr)
  else nValue := nStr;
end;

//Desc: 有符号整数
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Integer); 
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToInt(nStr)
end;

//Desc: 无符号整数
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Cardinal);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToInt(nStr)
end;

//Desc: 64符号整数
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Int64);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToInt64Def(nStr, 0)
end;

//Desc: 浮点数
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Double);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToFloat(nStr);
end;

//Desc: 日期
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: TDateTime);
begin
  if nStr = '' then
       nValue := 0
  else nValue := Str2DateTime(nStr);
end;

//------------------------------------------------------------------------------  
procedure TBusinessPackerBase.DoInitIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoInitOut(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoPackIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoPackOut(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoUnPackIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoUnPackOut(const nData: Pointer);
begin

end;

initialization
  gBusinessPackerManager := TBusinessPackerManager.Create;
finalization
  FreeAndNil(gBusinessPackerManager);
end.


