{*******************************************************************************
  ����: dmzn@163.com 2007-11-02
  ����: ʵ�ֶ���־�Ļ���͹���

  ��ע:
  &.����Ԫʵ����һ����־������LogManager.
  &.������ά��һ��Buffer�б�,�ڲ������־��LogItem.
  &.ʹ��LogManager.AddNewLog�����־��ʱ,�ᴥ��OnNewLog�¼�,���¼�������ͨ��
  ����.��־����ָ�뷽ʽ����,�����¼��п����޸�LogItem.FAction,�Ծ����Ƿ�Ҫ��
  ������.��FAction=[],�򲻻�ַ���"д��־�߳�".
  &."д��־�߳�"��֪����ô������־,����������һ���¼����ⲿ,����OnWriteLog,��
  ����־���б�,�ⲿ����ʵ������������־��δ���.��ʹ��������,��������¼���,��
  ־��Ҳ�ᱻ�ͷŵ�.
  &.ע��: OnWriteLog���̰߳�ȫ,��Ҫʱ��Ҫ�߳�ͬ��.���Ҳ�Ҫ�ֹ�ɾ����־��,����
  ֪����ô�ͷ�.
*******************************************************************************}
unit UMgrLog;

interface

uses
  Windows, Classes, SysUtils, UWaitItem;

type
  TObjectClass = class of TObject;
  TLogTag = set of (ltWriteFile, ltWriteDB, ltWriteCMD);
  //��־���

  TLogWriter = record
    FOjbect: TObjectClass;         //�������
    FDesc: string;                 //������Ϣ
  end;

  PLogItem = ^TLogItem;
  TLogItem = record
    FWriter: TLogWriter;           //��־����
    FLogTag: TLogTag;              //��־���
    FTime: TDateTime;              //��־ʱ��
    FEvent: string;                //��־����
  end;

  //****************************************************************************
  TLogManager = class;

  TLogThread = class(TThread)
  private
    FWaiter: TWaitObject;
    {*�ӳٶ���*}
    FOwner: TLogManager;
    {*ӵ����*}
  protected
    function GetLogList(const nList: TList): Boolean;
    {*��ȡ��־*}
    procedure Execute; override;
    {*ִ��*}
    procedure WriteErrorLog(const nList: TList);
    {*д�����*}
  public
    constructor Create(AOwner: TLogManager);
    procedure Wakeup;
    {*�̻߳���*}
    property Terminated;
    {*���游������*}
  end;

  TLogEvent = procedure (const nLogs: PLogItem) of Object;
  TWriteLogProcedure = procedure (const nThread: TLogThread; const nLogs: TList);
  TWriteLogEvent = procedure (const nThread: TLogThread; const nLogs: TList) of Object;
  //��־�¼�,�ص�����
  
  TLogManager = class(TObject)
  private
    FBuffer: TThreadList;
    {*������*}
    FWriter: TLogThread;
    {*д��־�߳�*}
    FOnNewLog: TLogEvent;
    FEvent: TWriteLogEvent;
    FProcedure: TWriteLogProcedure;
    {*�¼�*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}

    function NewLogItem: PLogItem;
    {*������Դ*}
    procedure AddNewLog(const nItem: PLogItem);
    {*����־*}
    property OnNewLog: TLogEvent read FOnNewLog write FOnNewLog;
    property WriteEvent: TWriteLogEvent read FEvent write FEvent;
    property WriteProcedure: TWriteLogProcedure read FProcedure write FProcedure;
    {*�����¼�*}
  end;

var
  gLogManager: TLogManager = nil;
  //ȫ��ʹ��,���ֹ�����

implementation

//Date: 2007-11-02
//Parm: ��־�б�
//Desc: �ͷ�nList��־�б�
procedure FreeLogList(const nList: TList); overload;
var i,nCount: integer;
begin
  nCount := nList.Count - 1;
  for i:=0 to nCount do
    Dispose(PLogItem(nList[i]));
  nList.Clear;
end;

//Date: 2007-11-02
//Parm: ��־�б�
//Desc: �ͷ�nList��־�б�
procedure FreeLogList(const nList: TThreadList); overload;
var nTmp: TList;
begin
  nTmp := nList.LockList;
  try
    FreeLogList(nTmp);
  finally
    nList.UnlockList;
  end;
end;

//******************************************************************************
constructor TLogThread.Create(AOwner: TLogManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create;
end;

//Desc: ����
procedure TLogThread.Wakeup;
begin
  FWaiter.WakeUP;
end;

//Desc: д��־�߳�
procedure TLogThread.Execute;
var nList: TList;
begin
  nList := TList.Create;
  try
    while not Terminated do
    begin
      FWaiter.EnterWait;
      try
        if Terminated then Break;
        if GetLogList(nList) then
        try
          if Assigned(FOwner.FEvent) then
             FOwner.FEvent(Self, nList);
          if Assigned(FOwner.FProcedure) then
             FOwner.FProcedure(Self, nList);
          Sleep(1200);
        except
          WriteErrorLog(nList);
          //IO�������ܳ���,����־д���̲߳�����ֹ
        end;
      finally
        FreeLogList(nList);
      end;
    end;
  finally
    FWaiter.Free; 
    FreeLogList(nList);
    nList.Free;
  end;
end;

//Date: 2007-11-02
//Parm: ��־�б�
//Desc: ��LogManager�л�ȡ��־,����nList��
function TLogThread.GetLogList(const nList: TList): Boolean;
var nTmp: TList;
    i,nCount: integer;
begin
  nTmp := FOwner.FBuffer.LockList;
  try
    nCount := nTmp.Count - 1;
    for i:=0 to nCount do
      nList.Add(nTmp[i]);
    nTmp.Clear;
  finally
    FOwner.FBuffer.UnlockList;
    Result := nList.Count > 0;
  end;
end;

//Date: 2007-11-25
//Parm: ��־�б�
//Desc: д��־����
procedure TLogThread.WriteErrorLog(const nList: TList);
var nItem: PLogItem;
begin
  nItem := FOwner.NewLogItem;
  nItem.FLogTag := [ltWriteFile];
  nItem.FWriter.FOjbect := TLogThread;
  nItem.FWriter.FDesc := '��־�߳�';
  nItem.FEvent := '��' + IntToStr(nList.Count) + '����־д��ʧ��,�Ѷ���';
  FOwner.AddNewLog(nItem);
end;

//******************************************************************************
//Desc: ����
constructor TLogManager.Create;
begin
  FBuffer := TThreadList.Create;
  FWriter := TLogThread.Create(Self);
end;

//Desc: �ͷ�
destructor TLogManager.Destroy;
begin
  FWriter.Terminate;
  FWriter.Wakeup;
  FWriter.WaitFor;
  FreeAndNil(FWriter);

  FreeLogList(FBuffer);
  FBuffer.Free;
  inherited;
end;

//Desc: �����־
procedure TLogManager.AddNewLog(const nItem: PLogItem);
var nList: TList;
begin
  if Assigned(FOnNewLog) then
    FOnNewLog(nItem);
  //��������,�����߳�д��

  if nItem.FLogTag = [] then
  begin
    Dispose(nItem); Exit;
  end;

  nList := FBuffer.LockList;
  try
    nList.Add(nItem);
  finally
    FBuffer.UnlockList;
    FWriter.Wakeup;
  end;
end;

//Desc: ����־��,���ֹ��ͷ�
function TLogManager.NewLogItem: PLogItem;
begin
  New(Result);
  Result.FLogTag := [];
  Result.FTime := Now();
end;

end.
