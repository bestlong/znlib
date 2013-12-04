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
  Windows, Classes, Controls, SyncObjs, SysUtils, Forms, Messages,
  UMgrDBConn, UMgrControl, UMgrParam, UBusinessPacker, UBusinessWorker,
  ULibFun, UObjectList, USysLoger;

const
  PM_RestoreForm   = WM_User + $0001;                //�ָ�����
  PM_RefreshMenu   = WM_User + $0002;                //���²˵�

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

  PPlugMenuItem = ^TPlugMenuItem;
  TPlugMenuItem = record
    FModule     : string;        //ģ���ʶ
    FName       : string;        //�˵���
    FCaption    : string;        //�˵�����
    FFormID     : Integer;       //���ܴ���
  end;

  PPlugRunParameter = ^TPlugRunParameter;
  TPlugRunParameter = record
    FAppHandle : THandle;        //������
    FMainForm  : THandle;        //������
    FLocalIP   : string;         //����IP
    FLocalMAC  : string;         //����MAC
    FLocalName : string;         //��������
  end;

  PPlugEnvironment = ^TPlugEnvironment;
  TPlugEnvironment = record
    FApplication   : TApplication;
    FScreen        : TScreen;
    FSysLoger      : TSysLoger;

    FParamManager  : TParamManager;
    FCtrlManager   : TControlManager;
    FDBConnManger  : TDBConnManager;
    FPackerManager : TBusinessPackerManager;
    FWorkerManager : TBusinessWorkerManager;
  end;

  TPlugEventWorker = class(TObject)
  private
    FLibHandle: THandle;
    //ģ����
  protected
    procedure GetExtendMenu(const nList: TList); virtual;
    //�����������չ�˵���
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
    //����ر�֮ǰ����
    procedure AfterStopServer; virtual;
    //����ر�֮�����
  public
    constructor Create(const nHandle: THandle);
    destructor Destroy; override;
    //�����ͷ�
    class function ModuleInfo: TPlugModuleInfo; virtual;
    //ģ����Ϣ
    property ModuleHandle: THandle read FLibHandle;
    //�������
  end;

  TPlugEventWorkerClass = class of TPlugEventWorker;
  //��������������

  TPlugManager = class(TObject)
  private
    FWorkers: TObjectDataList;
    //�¼�����
    FMenuChanged: Boolean;
    FMenuList: TList;
    //�˵��б�
    FRunParam: TPlugRunParameter;
    //���в���
    FSyncLock: TCriticalSection;
    //ͬ������
    FIsDestroying: Boolean;
    FInitSystemObject: Boolean;
    FRunSystemObject: Boolean;
    FBeforeStartServer: Boolean;
    FAfterServerStarted: Boolean;
    //����״̬
  protected
    procedure ClearMenu(const nFree: Boolean; const nModule: string = '';
      const nLocked: Boolean = True);
    //������Դ
    function GetModuleInfoList: TPlugModuleInfos;
    //ģ����Ϣ�б�
    function LoadPlugFile(const nFile: string): string;
    //���ز��
    procedure BeforeUnloadModule(const nWorker: TPlugEventWorker);
    //����ģ����Դ
    function BroadcastEvent(const nEventID: Integer; const nParam: Pointer = nil;
      const nModule: string = ''; const nLocked: Boolean = True): Boolean;
    //�����б�㲥�¼�
  public
    constructor Create(const nParam: TPlugRunParameter);
    destructor Destroy; override;
    //�����ͷ�
    class procedure EnvAction(const nEnv: PPlugEnvironment; const nGet: Boolean);
    //��ȡ��������
    procedure InitSystemObject(const nModule: string = '');
    procedure RunSystemObject(const nModule: string = '');
    procedure FreeSystemObject(const nModule: string = '');
    //����������ͷ�
    procedure BeforeStartServer(const nModule: string = '');
    procedure AfterServerStarted(const nModule: string = '');
    procedure BeforeStopServer(const nModule: string = '');
    procedure AfterStopServer(const nModule: string = '');
    //������ͣҵ����
    procedure LoadPlugsInDirectory(nPath: string);
    function UpdatePlug(const nFile: string; var nHint: string): Boolean;
    function UnloadPlug(const nModule: string): string;
    procedure UnloadPlugsAll;
    //����ж�ز��
    procedure RefreshUIMenu;
    //���½���˵�
    property Menus: TList read FMenuList;
    property Modules: TPlugModuleInfos read GetModuleInfoList;
    //�������
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
  FLibHandle := nHandle;
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

procedure TPlugEventWorker.GetExtendMenu(const nList: TList);
begin

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

//------------------------------------------------------------------------------
constructor TPlugManager.Create(const nParam: TPlugRunParameter);
begin
  FRunParam := nParam;
  FIsDestroying := False;

  FInitSystemObject := False;
  FRunSystemObject := False;
  FBeforeStartServer := False;
  FAfterServerStarted := False;

  FMenuChanged := True;
  FMenuList := TList.Create;
  
  FSyncLock := TCriticalSection.Create;
  FWorkers := TObjectDataList.Create(dtObject); 
end;

destructor TPlugManager.Destroy;
begin
  FIsDestroying := True; 
  UnloadPlugsAll;
  ClearMenu(True);

  FreeAndNil(FWorkers);
  FreeAndNil(FSyncLock);
  inherited;
end;

//Desc: ����˵��б�
procedure TPlugManager.ClearMenu(const nFree: Boolean; const nModule: string;
  const nLocked: Boolean);
var nIdx: Integer;
    nMenu: PPlugMenuItem;
begin
  if nLocked then FSyncLock.Enter;
  try
    for nIdx:=FMenuList.Count - 1 downto 0 do
    begin
      nMenu := FMenuList[nIdx];
      if (nModule = '') or (nMenu.FModule = nModule) then
      begin
        Dispose(nMenu);
        FMenuList.Delete(nIdx);
        FMenuChanged := True;
      end;
    end;

    if nFree then
      FreeAndNil(FMenuList);
    //xxxxx
  finally
    if nLocked then FSyncLock.Leave;
  end;
end;

//Desc: �������˵�
procedure TPlugManager.RefreshUIMenu;
begin
  if (not FIsDestroying) and FMenuChanged then
  begin
    FMenuChanged := False;
    PostMessage(FRunParam.FMainForm, PM_RefreshMenu, 0, 0);
  end;
end;

//Date: 2013-11-22
//Desc: ж��ģ��ʱ������Դ
procedure TPlugManager.BeforeUnloadModule(const nWorker: TPlugEventWorker);
var nStr: string;
begin
  with nWorker.ModuleInfo do
  try
    nStr := 'ж��ģ��[ %s ],�ļ�:[ %s ]';
    nStr := Format(nStr, [FModuleName, ExtractFileName(FModuleFile) ]);
    WriteLog(nStr);

    nStr := '  1.��ʼж��Menu...';
    ClearMenu(False, FModuleID, False);
    WriteLog(nStr + '���');

    nStr := '  2.��ʼֹͣ����...';
    nWorker.AfterStopServer;
    WriteLog(nStr + '���');

    nStr := '  3.��ʼж��Worker...';
    gBusinessWorkerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '���');

    nStr := '  4.��ʼж��Packer...';
    gBusinessPackerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '���');

    nStr := '  5.��ʼ�ͷ�Control...';
    gControlManager.UnregCtrl(FModuleID, True);
    WriteLog(nStr + '���');

    nStr := '  6.��ʼ�ͷŶ���...';
    nWorker.FreeSystemObject;
    WriteLog(nStr + '���');
  except
    on E:Exception do
    begin
      WriteLog(nStr + '����,����: ' + E.Message);
    end;
  end;
end;

function Event2Str(const nEventID: Integer): string;
begin
  case nEventID of
   cPlugEvent_InitSystemObject   : Result := 'InitSystemObject';
   cPlugEvent_RunSystemObject    : Result := 'RunSystemObject';
   cPlugEvent_FreeSystemObject   : Result := 'FreeSystemObject';
   cPlugEvent_BeforeStartServer  : Result := 'BeforeStartServer';
   cPlugEvent_AfterServerStarted : Result := 'AfterServerStarted';
   cPlugEvent_BeforeStopServer   : Result := 'BeforeStopServer';
   cPlugEvent_AfterStopServer    : Result := 'AfterStopServer';
   cPlugEvent_BeforeUnloadModule : Result := 'BeforeUnloadModule'
   else Result := '';
  end;
end;

//Date: 2013-11-19
//Parm: �¼���ʾ;����;����
//Desc: �����б�㲥nEventID�¼�,����nParam��������
function TPlugManager.BroadcastEvent(const nEventID: Integer;
 const nParam: Pointer; const nModule: string; const nLocked: Boolean): Boolean;
var nErr: string;
    nIdx: Integer;
    nHwnd: THandle;
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
          BeforeUnloadModule(nWorker);
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
        if nErr = '' then
        begin
          nErr := '��[ %d ]��ģ��ִ��[ %s ]ʱ��ȡ����ʧ��,����: %s';
          nErr := Format(nErr, [nIdx, Event2Str(nEventID), E.Message]);
          WriteLog(nErr);
        end else
        begin
          nErr := Format('ģ��[ %s ]ִ��[ %s ]ʱ����,����: %s', [nErr,
            Event2Str(nEventID), E.Message]);       
          WriteLog(nErr);
        end;
      end;
    end;

    Result := True;
  finally
    if nLocked then FSyncLock.Leave;
  end;
end;

procedure TPlugManager.InitSystemObject(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_InitSystemObject, nil, nModule);
  FInitSystemObject := True;
end;

procedure TPlugManager.RunSystemObject(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_RunSystemObject, @FRunParam, nModule);
  FRunSystemObject := True;
end;

procedure TPlugManager.FreeSystemObject(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_FreeSystemObject, nil, nModule);
  FInitSystemObject := False;
  FRunSystemObject := False;
end;

procedure TPlugManager.BeforeStartServer(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_BeforeStartServer, nil, nModule);
  FBeforeStartServer := True;
end;

procedure TPlugManager.AfterServerStarted(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_AfterServerStarted, nil, nModule);
  FAfterServerStarted := True;
end;

procedure TPlugManager.BeforeStopServer(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_BeforeStopServer, nil, nModule);
  FBeforeStartServer := False;
  FAfterServerStarted := False;
end;

procedure TPlugManager.AfterStopServer(const nModule: string = '');
begin
  BroadcastEvent(cPlugEvent_AfterStopServer, nil, nModule);
  FBeforeStartServer := False;
  FAfterServerStarted := False;
end;

//------------------------------------------------------------------------------
//Date: 2013-11-19
//Desc: ��ȡ��ע���ģ���б�
function TPlugManager.GetModuleInfoList: TPlugModuleInfos;
var nIdx,nNum: Integer;
begin
  FSyncLock.Enter;
  try
    nNum := 0;
    SetLength(Result, FWorkers.Count);

    for nIdx:=FWorkers.ItemLow to FWorkers.ItemHigh do
    begin
      Result[nNum] := TPlugEventWorker(FWorkers.ObjectA[nIdx]).ModuleInfo;
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

      FParamManager  := gParamManager;
      FCtrlManager   := gControlManager;
      FDBConnManger  := gDBConnManager;
      FPackerManager := gBusinessPackerManager;
      FWorkerManager := gBusinessWorkerManager;
    end else
    begin
      Application    := FApplication;
      Screen         := FScreen;
      gSysLoger      := FSysLoger;

      gParamManager  := FParamManager;
      gControlManager:= FCtrlManager;
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
  RefreshUIMenu;
end;

//Date: 2013-11-22
//Desc: ж��ȫ��ģ��
procedure TPlugManager.UnloadPlugsAll;
begin
  BroadcastEvent(cPlugEvent_BeforeUnloadModule);
  RefreshUIMenu;
end;

//------------------------------------------------------------------------------
type
  TProcGetWorker = procedure (var nWorker: TPlugEventWorkerClass); stdcall;
  TProcBackupEnv = procedure (const nNewEnv: PPlugEnvironment); stdcall;

//Date: 2013-11-22
//Parm: ģ��·��
//Desc: ����nFileģ�鵽������
function TPlugManager.LoadPlugFile(const nFile: string): string;
var nHwnd: THandle;
    nLoad: TProcGetWorker;
    nBack: TProcBackupEnv;

    nEnv: TPlugEnvironment;
    nWorker: TPlugEventWorker;
    nClass: TPlugEventWorkerClass;
begin
  Result := Format('�ļ�[ %s ]�Ѷ�ʧ.', [nFile]);
  if not FileExists(nFile) then Exit;
     
  nHwnd := INVALID_HANDLE_VALUE;
  try
    nHwnd := LoadLibrary(PChar(nFile));
    nLoad := GetProcAddress(nHwnd, 'LoadModuleWorker');
    nBack := GetProcAddress(nHwnd, 'BackupEnvironment');

    if not (Assigned(nLoad) and Assigned(nBack)) then
    begin
      Result := Format('�ļ�[ %s ]������Чģ��.', [nFile]);
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

        nWorker.GetExtendMenu(FMenuList);
        FMenuChanged := True;
        //��ģ���ṩ�Ĳ˵���չ
        
        if FInitSystemObject then
          InitSystemObject(nWorker.ModuleInfo.FModuleID);
        if FRunSystemObject then
          RunSystemObject(nWorker.ModuleInfo.FModuleID);
        if FBeforeStartServer then
          BeforeStartServer(nWorker.ModuleInfo.FModuleID);
        if FAfterServerStarted then
          AfterServerStarted(nWorker.ModuleInfo.FModuleID);
        //��ģ����������״̬ͬ��
      end;
    finally
      FSyncLock.Leave;
    end;

    Result := '';
  finally
    if nHwnd <> INVALID_HANDLE_VALUE then
      FreeLibrary(nHwnd);
    //free if need
  end;
end;

//Date: 2013-11-22
//Parm: ģ��·��
//Desc: ����nFileģ�鵽������
function TPlugManager.UpdatePlug(const nFile: string; var nHint: string): Boolean;
begin
  nHint := LoadPlugFile(nFile);
  Result := nHint = '';
  RefreshUIMenu;
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
      if (Pos('0_', nRec.Name) <> 1) then
      begin
        nStr := LoadPlugFile(nPath + nRec.Name);
        if nStr <> '' then
          WriteLog(nStr);
        //xxxxx
      end;

      nRes := FindNext(nRec);
    end;
  finally
    FindClose(nRec);
  end;

  RefreshUIMenu;
end;

initialization
  gPlugManager := nil;
finalization
  FreeAndNil(gPlugManager);
end.
