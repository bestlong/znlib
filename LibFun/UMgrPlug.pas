{*******************************************************************************
  作者: dmzn@163.com 2013-11-19
  描述: 插件接口和参数定义

  备注:
  *.插件管理器TPlugManager统一主程序和插件中的全局变量和管理器对象.
  *.在插件目录中,以"0_"开头的文件表示已作废插件.
  *.插件使用TPlugEventWorker来完成主程序的广播动作.
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
    FModuleID       : string;    //标识
    FModuleName     : string;    //名称
    FModuleAuthor   : string;    //作者
    FModuleVersion  : string;    //版本
    FModuleDesc     : string;    //描述
    FModuleFile     : string;    //文件
    FModuleBuildTime: TDateTime; //编译时间
  end;

  TPlugModuleInfos = array of TPlugModuleInfo;
  //模块信息列表

  PPlugRunParameter = ^TPlugRunParameter;
  TPlugRunParameter = record
    FAppHandle : THandle;        //程序句柄
    FMainForm  : THandle;        //窗体句柄
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
    //模块句柄
  protected
    procedure BeforeUnloadModule; virtual;
    //模块卸载前调用
    procedure InitSystemObject; virtual;
    //主程序启动时初始化
    procedure RunSystemObject(const nParam: PPlugRunParameter); virtual;
    //主程序启动后运行
    procedure FreeSystemObject; virtual;
    //主程序退出时释放
    procedure BeforeStartServer; virtual;
    //服务启动之前调用
    procedure AfterServerStarted; virtual;
    //服务启动之后调用
    procedure BeforeStopServer; virtual;
    //服务启动之前调用
    procedure AfterStopServer; virtual;
    //服务关闭之后调用
  public
    constructor Create(const nHandle: THandle);
    destructor Destroy; override;
    //创建释放
    class function ModuleInfo: TPlugModuleInfo; virtual;
    //模块信息
    property ModuleHandle: THandle read FHandle;
    //属性相关
  end;

  TPlugEventWorkerClass = class of TPlugEventWorker;
  //工作对象类类型

  TPlugManager = class(TObject)
  private
    FWorkers: TObjectDataList;
    //事件对象
    FSyncLock: TCriticalSection;
    //同步锁定
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    class procedure EnvAction(const nEnv: PPlugEnvironment; const nGet: Boolean);
    //获取环境变量
    procedure InitSystemObject;
    procedure RunSystemObject(const nParam: PPlugRunParameter);
    procedure FreeSystemObject;
    //对象申请和释放
    procedure BeforeStartServer;
    procedure AfterServerStarted;
    procedure BeforeStopServer;
    procedure AfterStopServer;
    //服务起停业务处理
    function LoadPlug(const nFile: string; var nHint: string): Boolean;
    procedure LoadPlugsInDirectory(nPath: string);
    function UnloadPlug(const nModule: string): string;
    procedure UnloadPlugsAll;
    //加载卸载插件
    function BroadcastEvent(const nEventID: Integer; const nParam: Pointer = nil;
      const nModule: string = ''; const nLocked: Boolean = True): Boolean;
    //向插件列表广播事件
    procedure GetModuleInfoList(var nInfo: TPlugModuleInfos);
    //模块信息列表
  end;

var
  gPlugManager: TPlugManager = nil;
  //全局使用

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TPlugManager, '插件管理器', nEvent);
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
    FModuleName     := '通用框架插件基类';
    FModuleAuthor   := 'dmzn@163.com';
    FModuleVersion  := '2013-11-20';
    FModuleDesc     := '插件通过继承该类,可以获得框架的接口.';
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
//Desc: 卸载模块时清理资源(一般被管理器调用)
procedure TPlugEventWorker.BeforeUnloadModule;
var nStr: string;
begin
  with ModuleInfo do
  try
    nStr := '模块[ %s ]开始卸载,文件:[ %s ]';
    nStr := Format(nStr, [FModuleName, ExtractFileName(FModuleFile) ]);
    WriteLog(nStr);

    nStr := Format('模块[ %s ]开始停止服务...', [FModuleName]);
    AfterStopServer;
    WriteLog(nStr + '完成');

    nStr := Format('模块[ %s ]开始卸载Worker...', [FModuleName]);
    gBusinessWorkerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '完成');

    nStr := Format('模块[ %s ]开始卸载Packer...', [FModuleName]);
    gBusinessPackerManager.UnRegistePacker(FModuleID);
    WriteLog(nStr + '完成');

    nStr := Format('模块[ %s ]开始释放对象...', [FModuleName]);
    FreeSystemObject;
    WriteLog(nStr + '完成');
  except
    on E:Exception do
    begin
      WriteLog(nStr + '错误,描述: ' + E.Message);
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
//Parm: 事件表示;参数;锁定
//Desc: 向插件列表广播nEventID事件,附带nParam参数调用
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
          //卸载模块资源
          nHwnd := nWorker.ModuleHandle;
          FWorkers.DeleteItem(nIdx);
          //删除模块工作对象
          FreeLibrary(nHwnd);
          //关闭模块句柄
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
          nErr := '第[ %d ]个模块执行[ %s ]时获取对象失败,描述: %s';
          nErr := Format(nErr, [nIdx, nStr, E.Message]);
          WriteLog(nErr);
        end else
        begin
          nErr := Format('模块[ %s ]执行[ %s ]时错误,描述: %s', [nErr, nStr, E.Message]);
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
//Parm: 模块信息列表
//Desc: 获取已注册的模块列表
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
//Parm: 变量参数;获取or设置
//Desc: 读取环境参数到nEnv,或设置环境参数为nEnv.
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
//Parm: 模块名
//Desc: 从管理器中卸载nModule模块
function TPlugManager.UnloadPlug(const nModule: string): string;
begin
  BroadcastEvent(cPlugEvent_BeforeUnloadModule, nil, nModule);
end;

//Date: 2013-11-22
//Desc: 卸载全部模块
procedure TPlugManager.UnloadPlugsAll;
begin
  BroadcastEvent(cPlugEvent_BeforeUnloadModule);
end;

//------------------------------------------------------------------------------
type
  TProcGetWorker = procedure (var nWorker: TPlugEventWorkerClass); stdcall;
  TProcBackupEnv = procedure (const nNewEnv: PPlugEnvironment); stdcall;

//Date: 2013-11-22
//Parm: 模块路径
//Desc: 载入nFile模块到管理器
function TPlugManager.LoadPlug(const nFile: string; var nHint: string): Boolean;
var nHwnd: THandle;
    nLoad: TProcGetWorker;
    nBack: TProcBackupEnv;

    nEnv: TPlugEnvironment;
    nWorker: TPlugEventWorker;
    nClass: TPlugEventWorkerClass;
begin
  Result := False;
  nHint := Format('文件[ %s ]已丢失.', [nFile]);
  if not FileExists(nFile) then Exit;
     
  nHwnd := INVALID_HANDLE_VALUE;
  try
    nHwnd := LoadLibrary(PChar(nFile));
    nLoad := GetProcAddress(nHwnd, 'LoadModuleWorker');
    nBack := GetProcAddress(nHwnd, 'BackupEnvironment');

    if not (Assigned(nLoad) and Assigned(nBack)) then
    begin
      nHint := Format('文件[ %s ]不是有效模块.', [nFile]);
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
        //初始化模块环境变量
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
//Parm: 模块目录
//Desc: 载入nPath下有效的模块到管理器
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
