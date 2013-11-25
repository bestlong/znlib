{*******************************************************************************
  ����: dmzn@163.com 2013-11-19
  ����: ����ӿںͲ�������

  ��ע:
  *.���������TPlugManagerͳһ������Ͳ���е�ȫ�ֱ����͹���������.
  *.�ڲ��Ŀ¼��,��"0_"��ͷ���ļ���ʾ�����ϲ��.
  *.���ʹ��TPlugEventWorker�����������Ĺ㲥����.
*******************************************************************************}
unit UMgrPlug;

interface

uses
  Windows, Classes, Controls, SyncObjs, SysUtils, Forms, ULibFun, UObjectList,
  UMgrDBConn, UBusinessPacker, UBusinessWorker, USysLoger;

const
  cPlugEvent_InitSystemObject     = $0001;
  cPlugEvent_RunSystemObject      = $0002;
  cPlugEvent_FreeSystemObject     = $0003;
  cPlugEvent_BeforeStartServer    = $0004;
  cPlugEvent_AfterServerStarted   = $0005;
  cPlugEvent_BeforeStopServer     = $0006;
  cPlugEvent_AfterStopServer      = $0007;
  cPlugEvent_BeforeUnloadModule   = $0008;

type
  TPlugModuleInfo = record
    FModuleID       : string;    //��ʶ
    FModuleName     : string;    //����
    FModuleAuthor   : string;    //����
    FModuleVersion  : string;    //�汾
    FModuleDesc     : string;    //����
    FModuleFile     : string;    //�ļ�
    FModuleBuildTime: TDateTime; //����ʱ��
  end;

  TPlugModuleInfos = array of TPlugModuleInfo;
  //ģ����Ϣ�б�

  PPlugRunParameter = ^TPlugRunParameter;
  TPlugRunParameter = record
    FAppHandle : THandle;        //������
    FMainForm  : THandle;        //������
  end;

  PPlugEnvironment = ^TPlugEnvironment;
  TPlugEnvironment = record
    FApplication   : TApplication;
    FScreen        : TScreen;
    FSysLoger      : TSysLoger;
    FDBConnManger  : TDBConnManager;
    FPackerManager : TBusinessPackerManager;
    FWorkerManager : TBusinessWorkerManager;
  end;

  TPlugEventWorker = class(TObject)
  private
    FHandle: THandle;
    //ģ����
  protected
    procedure BeforeUnloadModule; virtual;
    //ģ��ж��ǰ����
    procedure InitSystemObject; virtual;
    //����������ʱ��ʼ��
    procedure RunSystemObject(const nParam: PPlugRunParameter); virtual;
    //����������������
    procedure FreeSystemObject; virtual;
    //�������˳�ʱ�ͷ�
    procedure BeforeStartServer; virtual;
    //��������֮ǰ����
    procedure AfterServerStarted; virtual;
    //��������֮�����
    procedure BeforeStopServer; virtual;
    //��������֮ǰ����
    procedure AfterStopServer; virtual;
    //����ر�֮�����
  public
    constructor Create(const nHandle: THandle);
    destructor Destroy; override;
    //�����ͷ�
    class function ModuleInfo: TPlugModuleInfo; virtual;
    //ģ����Ϣ
    property ModuleHandle: THandle read FHandle;
    //�������
  end;

  TPlugEventWorkerClass = class of TPlugEventWorker;
  //��������������

  TPlugManager = class(TObject)
  private
    FWorkers: TObjectDataList;
    //�¼�����
    FSyncLock: TCriticalSection;
    //ͬ������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    class procedure EnvAction(const nEnv: PPlugEnvironment; const nGet: Boolean);
    //��ȡ��������
    procedure InitSystemObject;
    procedure RunSystemObject(const nParam: PPlugRunParameter);
    procedure FreeSystemObject;
    //����������ͷ�
    procedure BeforeStartServer;
    procedure AfterServerStarted;
    procedure BeforeStopServer;
    procedure AfterStopServer;
    //������ͣҵ����
    function LoadPlug(const nFile: string; var nHint: string): Boolean;
    procedure LoadPlugsInDirectory(nPath: string);
    function UnloadPlug(const nModule: string): string;
    procedure UnloadPlugsAll;
    //����ж�ز��
    function BroadcastEvent(const nEventID: Integer; const nParam: Pointer = nil;
      const nModule: string = ''; const nLocked: Boolean = True): Boolean;
    //�����б�㲥�¼�
    procedure GetModuleInfoList(var nInfo: TPlugModuleInfos);
    //ģ����Ϣ�б�
  end;

var
  gPlugManager: TPlugManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TPlugManager, '���������', nEvent);
end;

//------------------------------------------------------------------------------
constructor TPlugEventWorker.Create(const nHandle: THandle);
begin
  FHandle := nHandle;
end;

destructor TPlugEventWorker.Destroy;
begin
  //nothing
  inherited;
end;

class function TPlugEventWorker.ModuleInfo: TPlugModuleInfo;
var nBuf: array[0..MAX_PATH-1] of Char;
begin
  with Result do
  begin
    FModuleID       := '{0EE5410B-9334-45DE-A186-713C11434392}';
    FModuleName     := 'ͨ�ÿ�ܲ������';
    FModuleAuthor   := 'dmzn@163.com';
    FModuleVersion  := '2013-11-20';
    FModuleDesc     := '���ͨ���̳и���,���Ի�ÿ�ܵĽӿ�.';
    FModuleBuildTime:= Str2DateTime('2013-11-22 15:01:01');

    FModuleFile := Copy(nBuf, 1, GetModuleFileName(HInstance, nBuf, MAX_PATH));
    //module full file name
  end;
end;

procedure TPlugEventWorker.InitSystemObject;
begin
end;

procedure TPlugEventWorker.RunSystemObject(const nParam: PPlugRunParameter);
begin
end;

procedure TPlugEventWorker.FreeSystemObject;
begin
end;

procedure TPlugEventWorker.BeforeStartServer;
begin
end;

procedure TPlugEventWorker.AfterServerStarted;
begin
end;

procedure TPlugEventWorker.BeforeStopServer;
begin
end;

procedure TPlugEventWorker.AfterStopServer;
begin
end;

//Date: 2013-11-22
//Desc: ж��ģ��ʱ������Դ(һ�㱻����������)
procedure TPlugEventWorker.BeforeUnloadModule;
var nStr: string;
begin
  with ModuleInfo do
  try
    nStr := 'ģ��[ %s ]��ʼж��,�ļ�:[ %s ]';
    nStr := Format(nStr, [FModuleName, ExtractFileName(FModuleFile) ]);
    WriteLog(nStr);

    nStr := Format('ģ��[ %s ]��ʼֹͣ����...', [FModuleName]);
    AfterStopServer;
    WriteLog(nStr + '���');

    nStr := Format('ģ��[ %s ]��ʼж��Worker...', [FModuleName]);
    gBusinessWorkerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '���');

    nStr := Format('ģ��[ %s ]��ʼж��Packer...', [FModuleName]);
    gBusinessPackerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '���');

    nStr := Format('ģ��[ %s ]��ʼ�ͷŶ���...', [FModuleName]);
    FreeSystemObject;
    WriteLog(nStr + '���');
  except
    on E:Exception do
    begin
      WriteLog(nStr + '����,����: ' + E.Message);
    end;
  end;
end;

//------------------------------------------------------------------------------
constructor TPlugManager.Create;
begin
  FWorkers := TObjectDataList.Create(dtObject);
  FSyncLock := TCriticalSection.Create;
end;

destructor TPlugManager.Destroy;
begin
  UnloadPlugsAll;
  FreeAndNil(FWorkers);

  FreeAndNil(FSyncLock);
  inherited;
end;

//Date: 2013-11-19
//Parm: �¼���ʾ;����;����
//Desc: �����б�㲥nEventID�¼�,����nParam��������
function TPlugManager.BroadcastEvent(const nEventID: Integer;
 const nParam: Pointer; const nModule: string; const nLocked: Boolean): Boolean;
var nIdx: Integer;
    nHwnd: THandle;
    nErr,nStr: string;
    nWorker: TPlugEventWorker;
begin
  Result := False;
  if nLocked then FSyncLock.Enter;
  try     
    for nIdx:=FWorkers.ItemHigh downto FWorkers.ItemLow do
    try
      nErr := '';
      nWorker := TPlugEventWorker(FWorkers.ObjectA[nIdx]);
      nErr := nWorker.ModuleInfo.FModuleName;

      if (nModule <> '') and (nWorker.ModuleInfo.FModuleID <> nModule) then
        Continue;
      //filter

      case nEventID of
       cPlugEvent_InitSystemObject   : nWorker.InitSystemObject;
       cPlugEvent_RunSystemObject    : nWorker.RunSystemObject(nParam);
       cPlugEvent_FreeSystemObject   : nWorker.FreeSystemObject;
       cPlugEvent_BeforeStartServer  : nWorker.BeforeStartServer;
       cPlugEvent_AfterServerStarted : nWorker.AfterServerStarted;
       cPlugEvent_BeforeStopServer   : nWorker.BeforeStopServer;
       cPlugEvent_AfterStopServer    : nWorker.AfterStopServer;
       cPlugEvent_BeforeUnloadModule :
        begin
          nWorker.BeforeUnloadModule;
          //ж��ģ����Դ
          nHwnd := nWorker.ModuleHandle;
          FWorkers.DeleteItem(nIdx);
          //ɾ��ģ�鹤������
          FreeLibrary(nHwnd);
          //�ر�ģ����
        end else Exit;
      end;

      if nModule <> '' then
        Break;
      //fixed worker
    except
      on E: Exception do
      begin
        case nEventID of
         cPlugEvent_InitSystemObject   : nStr := 'InitSystemObject';
         cPlugEvent_RunSystemObject    : nStr := 'RunSystemObject';
         cPlugEvent_FreeSystemObject   : nStr := 'FreeSystemObject';
         cPlugEvent_BeforeStartServer  : nStr := 'BeforeStartServer';
         cPlugEvent_AfterServerStarted : nStr := 'AfterServerStarted';
         cPlugEvent_BeforeStopServer   : nStr := 'BeforeStopServer';
         cPlugEvent_AfterStopServer    : nStr := 'AfterStopServer';
         cPlugEvent_BeforeUnloadModule : nStr := 'BeforeUnloadModule';
        end;

        if nErr = '' then
        begin
          nErr := '��[ %d ]��ģ��ִ��[ %s ]ʱ��ȡ����ʧ��,����: %s';
          nErr := Format(nErr, [nIdx, nStr, E.Message]);
          WriteLog(nErr);
        end else
        begin
          nErr := Format('ģ��[ %s ]ִ��[ %s ]ʱ����,����: %s', [nErr, nStr, E.Message]);
          WriteLog(nErr);
        end;
      end;
    end;

    Result := True;
  finally
    if nLocked then FSyncLock.Leave;
  end;
end;

procedure TPlugManager.InitSystemObject;
begin
  BroadcastEvent(cPlugEvent_InitSystemObject)
end;

procedure TPlugManager.RunSystemObject(const nParam: PPlugRunParameter);
begin
  BroadcastEvent(cPlugEvent_RunSystemObject, nParam)
end;

procedure TPlugManager.FreeSystemObject;
begin
  BroadcastEvent(cPlugEvent_FreeSystemObject)
end;

procedure TPlugManager.BeforeStartServer;
begin
  BroadcastEvent(cPlugEvent_BeforeStartServer)
end;

procedure TPlugManager.AfterServerStarted;
begin
  BroadcastEvent(cPlugEvent_AfterServerStarted)
end;

procedure TPlugManager.BeforeStopServer;
begin
  BroadcastEvent(cPlugEvent_BeforeStopServer)
end;

procedure TPlugManager.AfterStopServer;
begin
  BroadcastEvent(cPlugEvent_AfterStopServer)
end;

//------------------------------------------------------------------------------
//Date: 2013-11-19
//Parm: ģ����Ϣ�б�
//Desc: ��ȡ��ע���ģ���б�
procedure TPlugManager.GetModuleInfoList(var nInfo: TPlugModuleInfos);
var nIdx,nNum: Integer;
begin
  FSyncLock.Enter;
  try
    nNum := 0;
    SetLength(nInfo, FWorkers.Count);

    for nIdx:=FWorkers.ItemLow to FWorkers.ItemHigh do
    begin
      nInfo[nNum] := TPlugEventWorker(FWorkers.ObjectA[nIdx]).ModuleInfo;
      Inc(nNum);
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2013-11-24
//Parm: ��������;��ȡor����
//Desc: ��ȡ����������nEnv,�����û�������ΪnEnv.
class procedure TPlugManager.EnvAction(const nEnv: PPlugEnvironment;
 const nGet: Boolean);
begin
  with nEnv^ do
  begin
    if nGet then
    begin
      FApplication   := Application;
      FScreen        := Screen;
      FSysLoger      := gSysLoger;

      FDBConnManger  := gDBConnManager;
      FPackerManager := gBusinessPackerManager;
      FWorkerManager := gBusinessWorkerManager;
    end else
    begin
      Application    := FApplication;
      Screen         := FScreen;
      gSysLoger      := FSysLoger;

      gDBConnManager := FDBConnManger;
      gBusinessPackerManager := FPackerManager;
      gBusinessWorkerManager := FWorkerManager;
    end;
  end;
end;

//Date: 2013-11-22
//Parm: ģ����
//Desc: �ӹ�������ж��nModuleģ��
function TPlugManager.UnloadPlug(const nModule: string): string;
begin
  BroadcastEvent(cPlugEvent_BeforeUnloadModule, nil, nModule);
end;

//Date: 2013-11-22
//Desc: ж��ȫ��ģ��
procedure TPlugManager.UnloadPlugsAll;
begin
  BroadcastEvent(cPlugEvent_BeforeUnloadModule);
end;

//------------------------------------------------------------------------------
type
  TProcGetWorker = procedure (var nWorker: TPlugEventWorkerClass); stdcall;
  TProcBackupEnv = procedure (const nNewEnv: PPlugEnvironment); stdcall;

//Date: 2013-11-22
//Parm: ģ��·��
//Desc: ����nFileģ�鵽������
function TPlugManager.LoadPlug(const nFile: string; var nHint: string): Boolean;
var nHwnd: THandle;
    nLoad: TProcGetWorker;
    nBack: TProcBackupEnv;

    nEnv: TPlugEnvironment;
    nWorker: TPlugEventWorker;
    nClass: TPlugEventWorkerClass;
begin
  Result := False;
  nHint := Format('�ļ�[ %s ]�Ѷ�ʧ.', [nFile]);
  if not FileExists(nFile) then Exit;
     
  nHwnd := INVALID_HANDLE_VALUE;
  try
    nHwnd := LoadLibrary(PChar(nFile));
    nLoad := GetProcAddress(nHwnd, 'LoadModuleWorker');
    nBack := GetProcAddress(nHwnd, 'BackupEnvironment');

    if not (Assigned(nLoad) and Assigned(nBack)) then
    begin
      nHint := Format('�ļ�[ %s ]������Чģ��.', [nFile]);
      Exit;
    end;

    FSyncLock.Enter;
    try
      nLoad(nClass);
      if FWorkers.FindItem(nClass.ModuleInfo.FModuleID) < 0 then
      begin
        nWorker := nClass.Create(nHwnd);
        nHwnd := INVALID_HANDLE_VALUE;
        FWorkers.AddItem(nWorker, nWorker.ModuleInfo.FModuleID);

        EnvAction(@nEnv, True);            
        nBack(@nEnv);
        //��ʼ��ģ�黷������
      end;
    finally
      FSyncLock.Leave;
    end;

    Result := True;
  finally
    if nHwnd <> INVALID_HANDLE_VALUE then
      FreeLibrary(nHwnd);
    //free if need
  end;
end;

//Date: 2013-11-22
//Parm: ģ��Ŀ¼
//Desc: ����nPath����Ч��ģ�鵽������
procedure TPlugManager.LoadPlugsInDirectory(nPath: string);
var nStr: string;
    nRes: Integer;
    nRec: TSearchRec;
begin
  if Copy(nPath, Length(nPath), 1) <> '\' then
    nPath := nPath + '\';
  //regular path

  nRes := FindFirst(nPath + '*.dll', faAnyFile, nRec);
  try
    while nRes = 0 do
    begin
      if (Pos('0_', nRec.Name) <> 1) and
         (not LoadPlug(nPath + nRec.Name, nStr)) then
        WriteLog(nStr);
      nRes := FindNext(nRec);
    end;
  finally
    FindClose(nRec);
  end;
end;

initialization
  gPlugManager := nil;
finalization
  FreeAndNil(gPlugManager);
end.
