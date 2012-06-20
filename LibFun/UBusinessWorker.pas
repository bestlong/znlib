{*******************************************************************************
  作者: dmzn@163.com 2012-02-03
  描述: 业务对象调用封装器
*******************************************************************************}
unit UBusinessWorker;

interface

uses
  Windows, Classes, SyncObjs, SysUtils, ULibFun, USysLoger, UBusinessPacker,
  UBusinessConst;

type
  TBusinessWorkerBase = class(TObject)
  protected
    FEnabled: Boolean;
    //可用标记
    FPacker: TBusinessPackerBase;
    //封装器
    FWorkTime: TDateTime;
    FWorkTimeInit: Cardinal;
    //开始时间
    function DoWork(var nData: string): Boolean; overload; virtual;
    function DoWork(const nIn,nOut: Pointer): Boolean; overload; virtual; 
    //子类处理
    procedure WriteLog(const nEvent: string);
    //记录日志
  public
    constructor Create; virtual;
    destructor Destroy; override;
    //创建释放
    class function FunctionName: string; virtual;
    //函数名
    function GetFlagStr(const nFlag: Integer): string; virtual;
    //标记内容
    function WorkActive(var nData: string): Boolean; overload;
    function WorkActive(const nIn,nOut: Pointer): Boolean; overload;
    //执行业务
  end;

  TBusinessWorkerSweetHeart = class(TBusinessWorkerBase)
  public
    class function FunctionName: string; override;
    function DoWork(var nData: string): Boolean; override;
    //执行业务
    class procedure RegWorker(const nSrvURL: string);
    //注册对象
  end;

  TBusinessWorkerClass = class of TBusinessWorkerBase;
  //class type

  TBusinessWorkerManager = class(TObject)
  private
    FWorkerClass: array of TBusinessWorkerClass;
    //类列表
    FWorkerPool: array of TBusinessWorkerBase;
    //对象池
    FNumLocked: Integer;
    //锁定对象
    FSrvClosed: Integer;
    //服务关闭
    FSyncLock: TCriticalSection;
    //同步锁
  protected
    function GetWorker(const nFunName: string): TBusinessWorkerBase;
    //获取工作对象
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure RegisteWorker(const nWorker: TBusinessWorkerClass);
    //注册类
    function LockWorker(const nFunName: string): TBusinessWorkerBase;
    procedure RelaseWorkder(const nWorkder: TBusinessWorkerBase);
    //锁定释放
  end;

var
  gBusinessWorkerManager: TBusinessWorkerManager = nil;
  //全局使用

implementation

const
  cYes  = $0002;
  cNo   = $0005;

var
  gLocalServiceURL: string;
  //本地服务地址列表

class function TBusinessWorkerSweetHeart.FunctionName: string;
begin
  Result := sSys_SweetHeart;
end;

function TBusinessWorkerSweetHeart.DoWork(var nData: string): Boolean;
begin
  nData := PackerEncodeStr(gLocalServiceURL);
  Result := True;
end;

class procedure TBusinessWorkerSweetHeart.RegWorker(const nSrvURL: string);
begin
  gLocalServiceURL := nSrvURL;
  if Assigned(gBusinessWorkerManager) then
    gBusinessWorkerManager.RegisteWorker(TBusinessWorkerSweetHeart);
  //registe
end;

//------------------------------------------------------------------------------
constructor TBusinessWorkerManager.Create;
begin
  FNumLocked := 0;
  FSrvClosed := cNo;

  FSyncLock := TCriticalSection.Create;
  SetLength(FWorkerPool, 0);

  SetLength(FWorkerClass, 1);
  FWorkerClass[0] := TBusinessWorkerBase;
end;

destructor TBusinessWorkerManager.Destroy;
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
    
    for nIdx:=Low(FWorkerPool) to High(FWorkerPool) do
      FreeAndNil(FWorkerPool[nIdx]);
    SetLength(FWorkerPool, 0);
  finally
    FSyncLock.Leave;
  end;

  FreeAndNil(FSyncLock);
  inherited;
end;

//Date: 2012-3-7
//Parm: 工作对象类
//Desc: 注册nWorker类
procedure TBusinessWorkerManager.RegisteWorker(
  const nWorker: TBusinessWorkerClass);
var nLen: Integer;
begin
  nLen := Length(FWorkerClass);
  SetLength(FWorkerClass, nLen + 1);
  FWorkerClass[nLen] := nWorker;
end;

//Date: 2012-3-7
//Parm: 函数名
//Desc: 获取可以执行nFunName的工作对象
function TBusinessWorkerManager.GetWorker(
  const nFunName: string): TBusinessWorkerBase;
var nIdx,nLen: Integer;
begin
  Result := nil;

  for nIdx:=Low(FWorkerPool) to High(FWorkerPool) do
  if FWorkerPool[nIdx].FEnabled and
     (FWorkerPool[nIdx].FunctionName = nFunName) then
  begin
    Result := FWorkerPool[nIdx];
    Result.FEnabled := False;
    Exit;
  end;

  for nIdx:=Low(FWorkerClass) to High(FWorkerClass) do
  if FWorkerClass[nIdx].FunctionName = nFunName then
  begin
    nLen := Length(FWorkerPool);
    SetLength(FWorkerPool, nLen + 1);
    FWorkerPool[nLen] := FWorkerClass[nIdx].Create;

    Result := FWorkerPool[nLen];
    Result.FEnabled := False;
    Exit;
  end;
end;

//Desc: 获取工作对象
function TBusinessWorkerManager.LockWorker(
  const nFunName: string): TBusinessWorkerBase;
begin
  Result := nil;
  if FSrvClosed = cYes then Exit;

  FSyncLock.Enter;
  try
    if FSrvClosed = cYes then Exit;
    Result := GetWorker(nFunName);
    
    if not Assigned(Result) then
      Result := GetWorker('');
    //the default
  finally
    if Assigned(Result) then
      InterlockedIncrement(FNumLocked);
    FSyncLock.Leave;
  end;
end;

//Desc: 释放工作对象
procedure TBusinessWorkerManager.RelaseWorkder(
  const nWorkder: TBusinessWorkerBase);
begin
  if Assigned(nWorkder) then
  try
    FSyncLock.Enter;
    nWorkder.FEnabled := True;
    InterlockedDecrement(FNumLocked);
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
constructor TBusinessWorkerBase.Create;
begin
  FEnabled := True;
end;

destructor TBusinessWorkerBase.Destroy;
begin
  //nothing
  inherited;
end;

class function TBusinessWorkerBase.FunctionName: string;
begin
  Result := '';
end;

function TBusinessWorkerBase.GetFlagStr(const nFlag: Integer): string;
begin
  Result := '';
end;

function TBusinessWorkerBase.DoWork(var nData: string): Boolean;
begin
  Result := True;
end;

function TBusinessWorkerBase.DoWork(const nIn, nOut: Pointer): Boolean;
begin
  Result := True;
end;

procedure TBusinessWorkerBase.WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(ClassType, '业务工作对象', nEvent);
end;

//Date: 2012-3-9
//Parm: 入参数据
//Desc: 执行以nData为数据的业务逻辑
function TBusinessWorkerBase.WorkActive(var nData: string): Boolean;
var nStr: string;
begin
  FPacker := nil;
  try
    nStr := GetFlagStr(cWorker_GetPackerName);
    if nStr <> '' then
    begin
      FPacker := gBusinessPackerManager.LockPacker(nStr);
      if FPacker.PackerName <> nStr then
      begin
        nData := '远程调用失败(Packer Is Null).';
        Result := False;
        Exit;
      end;
    end;

    FWorkTime := Now;
    FWorkTimeInit := GetTickCount;
    Result := DoWork(nData);
  finally
    gBusinessPackerManager.RelasePacker(FPacker);
  end;
end;

//Date: 2012-3-11
//Parm: 指针入参;指针出参
//Desc: 执行以nData为数据的业务逻辑
function TBusinessWorkerBase.WorkActive(const nIn,nOut: Pointer): Boolean;
var nPacker: string;
begin
  FPacker := nil;
  try
    nPacker := GetFlagStr(cWorker_GetPackerName);
    if nPacker <> '' then
    begin
      FPacker := gBusinessPackerManager.LockPacker(nPacker);
      if FPacker.PackerName <> nPacker then
      begin
        Result := False;
        Exit;
      end;
    end;

    FWorkTime := Now;
    FWorkTimeInit := GetTickCount;
    Result := DoWork(nIn, nOut);
  finally
    gBusinessPackerManager.RelasePacker(FPacker);
  end;
end;

initialization
  gBusinessWorkerManager := TBusinessWorkerManager.Create;
finalization
  FreeAndNil(gBusinessWorkerManager);
end.


