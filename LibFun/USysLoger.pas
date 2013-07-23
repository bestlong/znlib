{*******************************************************************************
  作者: dmzn@163.com 2012-2-13
  描述: 用于记录系统运行中的调试日志

  备注:
  *.日志以文件方式保存于本地.
  *.日志文件以日期命名.
  *.日志管理器支持写文件和界面输出,线程安全.
*******************************************************************************}
unit USysLoger;

interface

uses
  Windows, SysUtils, Classes, UMgrSync, UMgrLog, ULibFun, UWaitItem;

type
  TSysLogEvent = procedure (const nStr: string) of object;
  //日志事件

  TSysLoger = class(TObject)
  private
    FPath: string;
    //日志路径
    FSyncLog: Boolean;
    //是否同步
    FSyner: TDataSynchronizer;
    //同步对象
    FLoger: TLogManager;
    //日志对象
    FSyncLock: TCrossProcWaitObject;
    //同步锁定
    FEvent: TSysLogEvent;
    //事件相关
  protected
    procedure OnLog(const nThread: TLogThread; const nLogs: TList);
    procedure OnSync(const nData: Pointer; const nSize: Cardinal);
    procedure OnFree(const nData: Pointer; const nSize: Cardinal);
  public
    constructor Create(const nPath: string; const nSyncLock: string = '');
    destructor Destroy; override;
    //创建释放
    procedure AddLog(const nEvent: string); overload;
    procedure AddLog(const nLogItem: PLogItem); overload;
    procedure AddLog(const nObj: TObjectClass; nDesc,nEvent: string); overload;
    //添加日志
    property LogSync: Boolean read FSyncLog write FSyncLog;
    property LogEvent: TSysLogEvent read FEvent write FEvent;
    //属性相关
  end;

var
  gSysLoger: TSysLoger = nil;
  //全局使用

implementation

resourcestring
  sFileExt   = '.log';
  sLogField  = #9;

//------------------------------------------------------------------------------
constructor TSysLoger.Create(const nPath,nSyncLock: string);
begin
  FSyncLock := TCrossProcWaitObject.Create(PChar(nSyncLock));
  //for thread or process sync

  FLoger := TLogManager.Create;
  FLoger.WriteEvent := OnLog;
  FSyncLog := False;
  
  FSyner := TDataSynchronizer.Create;
  FSyner.SyncEvent := OnSync;
  FSyner.SyncFreeEvent := OnFree;

  if not DirectoryExists(nPath) then
    ForceDirectories(nPath);
  FPath := nPath;
end;

destructor TSysLoger.Destroy;
begin
  FLoger.Free;
  FSyner.Free;

  FSyncLock.Free;
  inherited;
end;

procedure TSysLoger.AddLog(const nLogItem: PLogItem);
begin
  FLoger.AddNewLog(@nLogItem);
end;

//Desc: 默认日志
procedure TSysLoger.AddLog(const nEvent: string);
begin
  AddLog(TSysLoger, '默认日志对象', nEvent);
end;

//Desc: 添加一个nObj的nEvent事件
procedure TSysLoger.AddLog(const nObj: TObjectClass; nDesc, nEvent: string);
var nItem: PLogItem;
begin
  New(nItem);

  with nItem^ do
  begin
    FWriter.FOjbect := nObj;
    FWriter.FDesc := nDesc;

    FLogTag := [ltWriteFile];
    FTime := Now();
    FEvent := nEvent;
  end;

  FLoger.AddNewLog(nItem);
end;

//Date: 2012-2-13
//Parm: 日志线程;日志列表
//Desc: 将nThread.nLogs写入日志文件
procedure TSysLoger.OnLog(const nThread: TLogThread; const nLogs: TList);
var nStr: string;
    nBuf: PChar;
    nFile: TextFile;
    nItem: PLogItem;
    i,nCount,nLen,nNum: integer;
begin
  FSyncLock.SyncLockEnter(True);
  try
    nStr := FPath + Date2Str(Now) + sFileExt;
    AssignFile(nFile, nStr);
  
    if FileExists(nStr) then
         Append(nFile)
    else Rewrite(nFile);

    nNum := 0;
    nCount := nLogs.Count - 1;

    for i:=0 to nCount do
    begin
      if nThread.Terminated then Exit;
      nItem := nLogs[i];

      nStr := DateTime2Str(nItem.FTime) + sLogField +        //时间
              nItem.FWriter.FOjbect.ClassName + sLogField;   //类名
      //xxxxx
      
      if nItem.FWriter.FDesc <> '' then
        nStr := nStr + nItem.FWriter.FDesc + sLogField;      //描述
      nStr := nStr + nItem.FEvent;                           //事件
      WriteLn(nFile, nStr);

      if FSyncLog then
      begin
        nLen := Length(nStr) + 1;
        nBuf := GetMemory(nLen);

        StrPCopy(nBuf, nStr + #0);
        FSyner.AddData(nBuf, nLen);
        Inc(nNum);
      end;
    end;

    if nNum > 0 then
      FSyner.ApplySync;
    //xxxxx
  finally  
    CloseFile(nFile);
    FSyncLock.SyncLockLeave(True);
  end;
end;

procedure TSysLoger.OnSync(const nData: Pointer; const nSize: Cardinal);
begin
  if Assigned(FEvent) then FEvent(PChar(nData));
end;

procedure TSysLoger.OnFree(const nData: Pointer; const nSize: Cardinal);
begin
  FreeMem(nData, nSize);
end;

initialization
  gSysLoger := nil;
finalization
  FreeAndNil(gSysLoger);
end.
