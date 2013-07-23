{*******************************************************************************
  ����: dmzn@163.com 2012-2-13
  ����: ���ڼ�¼ϵͳ�����еĵ�����־

  ��ע:
  *.��־���ļ���ʽ�����ڱ���.
  *.��־�ļ�����������.
  *.��־������֧��д�ļ��ͽ������,�̰߳�ȫ.
*******************************************************************************}
unit USysLoger;

interface

uses
  Windows, SysUtils, Classes, UMgrSync, UMgrLog, ULibFun, UWaitItem;

type
  TSysLogEvent = procedure (const nStr: string) of object;
  //��־�¼�

  TSysLoger = class(TObject)
  private
    FPath: string;
    //��־·��
    FSyncLog: Boolean;
    //�Ƿ�ͬ��
    FSyner: TDataSynchronizer;
    //ͬ������
    FLoger: TLogManager;
    //��־����
    FSyncLock: TCrossProcWaitObject;
    //ͬ������
    FEvent: TSysLogEvent;
    //�¼����
  protected
    procedure OnLog(const nThread: TLogThread; const nLogs: TList);
    procedure OnSync(const nData: Pointer; const nSize: Cardinal);
    procedure OnFree(const nData: Pointer; const nSize: Cardinal);
  public
    constructor Create(const nPath: string; const nSyncLock: string = '');
    destructor Destroy; override;
    //�����ͷ�
    procedure AddLog(const nEvent: string); overload;
    procedure AddLog(const nLogItem: PLogItem); overload;
    procedure AddLog(const nObj: TObjectClass; nDesc,nEvent: string); overload;
    //�����־
    property LogSync: Boolean read FSyncLog write FSyncLog;
    property LogEvent: TSysLogEvent read FEvent write FEvent;
    //�������
  end;

var
  gSysLoger: TSysLoger = nil;
  //ȫ��ʹ��

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

//Desc: Ĭ����־
procedure TSysLoger.AddLog(const nEvent: string);
begin
  AddLog(TSysLoger, 'Ĭ����־����', nEvent);
end;

//Desc: ���һ��nObj��nEvent�¼�
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
//Parm: ��־�߳�;��־�б�
//Desc: ��nThread.nLogsд����־�ļ�
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

      nStr := DateTime2Str(nItem.FTime) + sLogField +        //ʱ��
              nItem.FWriter.FOjbect.ClassName + sLogField;   //����
      //xxxxx
      
      if nItem.FWriter.FDesc <> '' then
        nStr := nStr + nItem.FWriter.FDesc + sLogField;      //����
      nStr := nStr + nItem.FEvent;                           //�¼�
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
