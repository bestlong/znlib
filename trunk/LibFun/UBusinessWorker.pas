{*******************************************************************************
  ����: dmzn@163.com 2012-02-03
  ����: ҵ�������÷�װ��
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
    //���ñ��
    FPacker: TBusinessPackerBase;
    //��װ��
    FWorkTime: TDateTime;
    FWorkTimeInit: Cardinal;
    //��ʼʱ��
    function DoWork(var nData: string): Boolean; overload; virtual;
    function DoWork(const nIn,nOut: Pointer): Boolean; overload; virtual; 
    //���ദ��
    procedure WriteLog(const nEvent: string);
    //��¼��־
  public
    constructor Create; virtual;
    destructor Destroy; override;
    //�����ͷ�
    class function FunctionName: string; virtual;
    //������
    function GetFlagStr(const nFlag: Integer): string; virtual;
    //�������
    function WorkActive(var nData: string): Boolean; overload;
    function WorkActive(const nIn,nOut: Pointer): Boolean; overload;
    //ִ��ҵ��
  end;

  TBusinessWorkerSweetHeart = class(TBusinessWorkerBase)
  public
    class function FunctionName: string; override;
    function DoWork(var nData: string): Boolean; override;
    //ִ��ҵ��
    class procedure RegWorker(const nSrvURL: string);
    //ע�����
  end;

  TBusinessWorkerClass = class of TBusinessWorkerBase;
  //class type

  TBusinessWorkerManager = class(TObject)
  private
    FWorkerClass: array of TBusinessWorkerClass;
    //���б�
    FWorkerPool: array of TBusinessWorkerBase;
    //�����
    FNumLocked: Integer;
    //��������
    FSrvClosed: Integer;
    //����ر�
    FSyncLock: TCriticalSection;
    //ͬ����
  protected
    function GetWorker(const nFunName: string): TBusinessWorkerBase;
    //��ȡ��������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure RegisteWorker(const nWorker: TBusinessWorkerClass);
    //ע����
    function LockWorker(const nFunName: string): TBusinessWorkerBase;
    procedure RelaseWorkder(const nWorkder: TBusinessWorkerBase);
    //�����ͷ�
  end;

var
  gBusinessWorkerManager: TBusinessWorkerManager = nil;
  //ȫ��ʹ��

implementation

const
  cYes  = $0002;
  cNo   = $0005;

var
  gLocalServiceURL: string;
  //���ط����ַ�б�

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
//Parm: ����������
//Desc: ע��nWorker��
procedure TBusinessWorkerManager.RegisteWorker(
  const nWorker: TBusinessWorkerClass);
var nLen: Integer;
begin
  nLen := Length(FWorkerClass);
  SetLength(FWorkerClass, nLen + 1);
  FWorkerClass[nLen] := nWorker;
end;

//Date: 2012-3-7
//Parm: ������
//Desc: ��ȡ����ִ��nFunName�Ĺ�������
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

//Desc: ��ȡ��������
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

//Desc: �ͷŹ�������
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
  gSysLoger.AddLog(ClassType, 'ҵ��������', nEvent);
end;

//Date: 2012-3-9
//Parm: �������
//Desc: ִ����nDataΪ���ݵ�ҵ���߼�
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
        nData := 'Զ�̵���ʧ��(Packer Is Null).';
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
//Parm: ָ�����;ָ�����
//Desc: ִ����nDataΪ���ݵ�ҵ���߼�
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


