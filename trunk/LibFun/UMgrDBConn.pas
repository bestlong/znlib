{*******************************************************************************
  ����: dmzn@163.com 2011-10-22
  ����: ���ݿ����ӹ�����

  ��ע:
  *.�������ӹ�����,ά��һ�����ݿ����Ӳ���,����̬�������Ӷ���.
  *.ÿ�����Ӳ���ʹ��һ��ID��ʶ,����ڸ��ٹ�ϣ����.
  *.ÿ�����Ӷ���ʹ��һ��ID��ʶ,��ʾ��ͬһ�����ݿ�,���ж����������.
  *.ÿ�����Ӷ�Ӧһ�����ݿ�,ÿ��������ӦN��Workerʵ�ʸ���Connection,������
    ����
*******************************************************************************}
unit UMgrDBConn;

interface

uses
  ActiveX, Windows, Classes, ADODB, DB, SysUtils, SyncObjs, UWaitItem,
  UMgrHashDict;

const
  cErr_GetConn_NoParam     = $0001;            //�����Ӳ���
  cErr_GetConn_NoAllowed   = $0002;            //��ֹ����
  cErr_GetConn_Closing     = $0003;            //�������Ͽ�
  cErr_GetConn_MaxConn     = $0005;            //���������

type
  PDBParam = ^TDBParam;
  TDBParam = record
    FID   : string;                             //������ʶ
    FHost : string;                             //������ַ
    FPort : Integer;                            //����˿�
    FDB   : string;                             //���ݿ���
    FUser : string;                             //�û���
    FPwd  : string;                             //�û�����
    FConn : string;                             //�����ַ�
  end;

  PDBWorker = ^TDBWorker;
  TDBWorker = record
    FConn : TADOConnection;                     //���Ӷ���
    FQuery: TADOQuery;                          //��ѯ����
    FExec : TADOQuery;                          //��������

    FWaiter: TWaitObject;                       //�ӳٶ���
    FUsed : Integer;                            //�ŶӼ���
    FLock : TCriticalSection;                   //ͬ������
  end;

  PDBConnItem = ^TDBConnItem;
  TDBConnItem = record
    FID   : string;                             //���ӱ�ʶ
    FUsed : Integer;                            //�ŶӼ���
    FLast : Cardinal;                           //�ϴ�ʹ��
    FWorker: array[0..2] of PDBWorker;          //��������
  end;

  PDBConnStatus = ^TDBConnStatus;
  TDBConnStatus = record
    FNumConnParam: Integer;                     //���������ݿ����
    FNumConnItem: Integer;                      //������(���ݿ�)����
    FNumConnObj: Integer;                       //���Ӷ���(Connection)����
    FNumObjConned: Integer;                     //�����Ӷ���(Connection)����
    FNumObjReUsed: Cardinal;                    //�����ظ�ʹ�ô���
    FNumObjRequestErr: Cardinal;                //����������
    FNumObjWait: Integer;                       //�Ŷ��ж���(Worker.FUsed)����
    FNumWaitMax: Integer;                       //�Ŷ�����������ж������
    FNumMaxTime: TDateTime;                     //�Ŷ����ʱ��
  end;

  TDBConnManager = class(TObject)
  private
    FMaxConn: Word;
    //���������
    FConnItems: TList;
    //�����б�
    FParams: THashDictionary;
    //�����б�
    FConnClosing: Integer;
    FAllowedRequest: Integer;
    FSyncLock: TCriticalSection;
    //ͬ����
    FStatus: TDBConnStatus;
    //����״̬
  protected
    procedure DoFreeDict(const nType: Word; const nData: Pointer);
    //�ͷ��ֵ�
    procedure ClearConnItems(const nFreeMe: Boolean);
    //��������
    function CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
    function CloseConnection(const nID: string; const nLock: Boolean): Integer;
    //�ر�����
    procedure DoAfterConnection(Sender: TObject);
    procedure DoAfterDisconnection(Sender: TObject);
    //ʱ���
    function GetRunStatus: TDBConnStatus;
    //��ȡ״̬
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure AddParam(const nParam: TDBParam);
    procedure DelParam(const nID: string = '');
    procedure ClearParam;
    //��������
    class function MakeDBConnection(const nParam: TDBParam): string;
    //��������
    function GetConnection(const nID: string; var nErrCode: Integer): PDBWorker;
    procedure ReleaseConnection(const nID: string; const nWorker: PDBWorker);
    //ʹ������
    function Disconnection(const nID: string = ''): Integer;
    //�Ͽ�����
    function WorkerQuery(const nWorker: PDBWorker; const nSQL: string): TDataSet;
    function WorkerExec(const nWorker: PDBWorker; const nSQL: string): Integer;
    //��������
    property Status: TDBConnStatus read GetRunStatus;
    property MaxConn: Word read FMaxConn write FMaxConn;
    //�������
  end;

var
  gDBConnManager: TDBConnManager = nil;
  //ȫ��ʹ��

implementation

const
  cTrue  = $1101;
  cFalse = $1105;
  //��������

constructor TDBConnManager.Create;
begin
  FMaxConn := 100;
  FConnClosing := cFalse;
  FAllowedRequest := cTrue;

  FConnItems := TList.Create;
  FSyncLock := TCriticalSection.Create;
  
  FParams := THashDictionary.Create(3);
  FParams.OnDataFree := DoFreeDict;
end;

destructor TDBConnManager.Destroy;
begin
  ClearConnItems(True);  
  FParams.Free;
  FSyncLock.Free;
  inherited;
end;

//Desc: �ͷ��ֵ���
procedure TDBConnManager.DoFreeDict(const nType: Word; const nData: Pointer);
begin
  Dispose(PDBParam(nData));
end;

//Desc: �ͷ����Ӷ���
procedure FreeDBConnItem(const nItem: PDBConnItem);
var nIdx: Integer;
begin
  for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
   if Assigned(nItem.FWorker[nIdx]) then
    with nItem.FWorker[nIdx]^ do
    begin
      FreeAndNil(FQuery);
      FreeAndNil(FExec);
      FreeAndNil(FConn);
      FreeAndNil(FLock);
      FreeAndNil(FWaiter);
      
      Dispose(nItem.FWorker[nIdx]);
      nItem.FWorker[nIdx] := nil;
    end;

  Dispose(nItem);
end;

//Desc: �������Ӷ���
procedure TDBConnManager.ClearConnItems(const nFreeMe: Boolean);
var nIdx: Integer;
begin
  if nFreeMe then
    InterlockedExchange(FAllowedRequest, cFalse);
  //����ر�

  FSyncLock.Enter;
  try
    CloseConnection('', False);
    //�Ͽ�ȫ������

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      FreeDBConnItem(FConnItems[nIdx]);
      FConnItems.Delete(nIdx);
    end;

    if nFreeMe then
      FreeAndNil(FConnItems);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: �Ͽ������ݿ������
function TDBConnManager.Disconnection(const nID: string): Integer;
begin
  Result := CloseConnection(nID, True);
end;

//Desc: �Ͽ�nWorker����������,�Ͽ��ɹ�����True.
function TDBConnManager.CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
begin
  //�ó���,�ȴ����������ͷ�
  FSyncLock.Leave;
  try
    while nWorker.FUsed > 0 do
      nWorker.FWaiter.EnterWait;
    //�ȴ������˳�
  finally
    FSyncLock.Enter;
  end;

  try
    nWorker.FConn.Connected := False;
  except
    //ignor any error
  end;

  Result := not nWorker.FConn.Connected;
end;

//Desc: �ر�ָ������,���عرո���.
function TDBConnManager.CloseConnection(const nID: string;
  const nLock: Boolean): Integer;
var nIdx,nInt: Integer;
    nItem: PDBConnItem;
begin
  Result := 0;
  if InterlockedExchange(FConnClosing, cTrue) = cTrue then Exit;

  if nLock then FSyncLock.Enter;
  try
    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nItem := FConnItems[nIdx];
      if (nID <> '') and (CompareText(nItem.FID, nID) <> 0) then Continue;

      nItem.FUsed := 0;
      //���ü���

      for nInt:=Low(nItem.FWorker) to High(nItem.FWorker) do
      if Assigned(nItem.FWorker[nInt]) then
      begin
        if CloseWorkerConnection(nItem.FWorker[nInt]) then
          Inc(Result);
        nItem.FWorker[nInt].FUsed := 0;
      end;
    end;
  finally
    InterlockedExchange(FConnClosing, cFalse);
    if nLock then FSyncLock.Leave;
  end;
end;

//Desc: �������ӳɹ�
procedure TDBConnManager.DoAfterConnection(Sender: TObject);
begin
  Inc(FStatus.FNumObjConned);
end;

//Desc: ���ݶϿ��ɹ�
procedure TDBConnManager.DoAfterDisconnection(Sender: TObject);
begin
  Dec(FStatus.FNumObjConned);
end;

//------------------------------------------------------------------------------
//Desc: ���ɱ��������ݿ�����
class function TDBConnManager.MakeDBConnection(const nParam: TDBParam): string;
begin
  with nParam do
  begin
    Result := FConn;
    Result := StringReplace(Result, '$DBName', FDB, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Host', FHost, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$User', FUser, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Pwd', FPwd, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Port', IntToStr(FPort), [rfReplaceAll, rfIgnoreCase]);
  end;
end;

//Desc: ��Ӳ���
procedure TDBConnManager.AddParam(const nParam: TDBParam);
var nPtr: PDBParam;
    nData: PDictData;
begin
  if nParam.FID = '' then Exit;

  FSyncLock.Enter;
  try
    nData := FParams.FindItem(nParam.FID);
    if not Assigned(nData) then
    begin
      New(nPtr);
      FParams.AddItem(nParam.FID, nPtr, 0, False);
      Inc(FStatus.FNumConnParam);
    end else nPtr := nData.FData;

    with nParam do
    begin
      nPtr.FID   := FID;
      nPtr.FHost := FHost;
      nPtr.FPort := FPort;
      nPtr.FDB := FDB;
      nPtr.FUser := FUser;
      nPtr.FPwd  := FPwd;
      nPtr.FConn := MakeDBConnection(nParam);
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: ɾ������
procedure TDBConnManager.DelParam(const nID: string);
begin
  FSyncLock.Enter;
  try
    if FParams.DelItem(nID) then
      Dec(FStatus.FNumConnParam);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: �������
procedure TDBConnManager.ClearParam;
begin
  FSyncLock.Enter;
  try
    FParams.ClearItem;
    FStatus.FNumConnParam := 0;
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2011-10-23
//Parm: ���ӱ�ʶ;������
//Desc: ����nID���õ��������Ӷ���
function TDBConnManager.GetConnection(const nID: string;
 var nErrCode: Integer): PDBWorker;
var nIdx: Integer;
    nParam: PDictData;
    nItem,nIdle,nTmp: PDBConnItem;
begin
  Result := nil;
  nErrCode := cErr_GetConn_NoAllowed;
  if FAllowedRequest = cFalse then Exit;

  nErrCode := cErr_GetConn_Closing;
  if FConnClosing = cTrue then Exit;
  
  FSyncLock.Enter;
  try
    nErrCode := cErr_GetConn_NoAllowed;
    if FAllowedRequest = cFalse then Exit;

    nErrCode := cErr_GetConn_Closing;
    if FConnClosing = cTrue then Exit;
    //�ظ��ж�,����Get��close���������ص�(get.enter��close.enter�������ȴ�)

    nErrCode := cErr_GetConn_NoParam;
    nParam := FParams.FindItem(nID);
    if not Assigned(nParam) then Exit;

    nItem := nil;
    nIdle := nil;

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nTmp := FConnItems[nIdx];
      if CompareText(nID, nTmp.FID) = 0 then
      begin
        nItem := nTmp; Break;
      end;

      if nTmp.FUsed < 1 then
       if (not Assigned(nIdle)) or (nIdle.FLast > nTmp.FLast) then
        nIdle := nTmp;
      //����ʱ�������
    end;

    if not Assigned(nItem) then
    begin
      if (not Assigned(nIdle)) and (FConnItems.Count >= FMaxConn) then
      begin
        nErrCode := cErr_GetConn_MaxConn; Exit;
      end;

      if (FConnItems.Count >= FMaxConn) then
      begin
        nItem := nIdle;
        nItem.FID := nID;

        for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
         if Assigned(nItem.FWorker[nIdx]) then
          CloseWorkerConnection(nItem.Fworker[nIdx]);
        Inc(FStatus.FNumObjReUsed);
      end else
      begin
        New(nItem);
        FConnItems.Add(nItem);
        Inc(FStatus.FNumConnItem);

        nItem.FID := nID;
        nItem.FUsed := 0;
        
        for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
          nItem.FWorker[nIdx] := nil;
        //xxxxx
      end;
    end;

    //--------------------------------------------------------------------------
    with nItem^ do
    begin
      for nIdx:=Low(FWorker) to High(FWorker) do
      begin
        if Assigned(FWorker[nIdx]) then
        begin
          if not Assigned(Result) then
          begin
            Result := FWorker[nIdx];
            if Result.FUsed < 1 then Break;
          end else

          if FWorker[nIdx].FUsed < Result.FUsed then
          begin
            Result := FWorker[nIdx];
          end;                
          //�Ŷ����ٵĹ�������
        end else
        begin
          New(Result);
          FWorker[nIdx] := Result;
          FillChar(Result^, SizeOf(TDBWorker), #0);

          with Result^ do
          begin
            //ActiveX.CoInitialize(nil);
            FConn := TADOConnection.Create(nil);
            with FConn do
            begin
              ConnectionTimeout := 7;
              LoginPrompt := False;
              AfterConnect := DoAfterConnection;
              AfterDisconnect := DoAfterDisconnection;
            end;

            FQuery := TADOQuery.Create(nil);
            FQuery.Connection := FConn;
            FExec := TADOQuery.Create(nil);
            FExec.Connection := FConn;

            FWaiter := TWaitObject.Create;
            FWaiter.Interval := 2 * 10;

            Inc(FStatus.FNumConnObj);
            FLock := TCriticalSection.Create;
          end;

          Break;
          //�´�����������
        end;
      end;

      if Assigned(Result) then
      begin
        Inc(Result.FUsed);
        Inc(nItem.FUsed);
        Inc(FStatus.FNumObjWait);

        if nItem.FUsed > FStatus.FNumWaitMax then
        begin
          FStatus.FNumWaitMax := nItem.FUsed;
          FStatus.FNumMaxTime := Now;
        end;

        if not Result.FConn.Connected then
          Result.FConn.ConnectionString := PDBParam(nParam.FData).FConn;
        //xxxxx
      end;
    end;
  finally
    if not Assigned(Result) then
      Inc(FStatus.FNumObjRequestErr);
    FSyncLock.Leave;
  end;

  if Assigned(Result) then
  with Result^ do
  begin
    FLock.Enter;
    //������������Ŷ�

    if FConnClosing = cTrue then
    try
      Result := nil;
      nErrCode := cErr_GetConn_Closing;

      InterlockedDecrement(FUsed);
      InterlockedDecrement(FStatus.FNumObjWait);
      FWaiter.Wakeup;
    finally
      FLock.Leave;
    end;
  end;
end;

//Date: 2011-10-23
//Parm: ���ӱ�ʶ;���ݶ���
//Desc: �ͷ�nID.nWorker���Ӷ���
procedure TDBConnManager.ReleaseConnection(const nID: string;
  const nWorker: PDBWorker);
var nIdx: Integer;
    nItem: PDBConnItem;
begin
  if Assigned(nWorker) then
  begin
    FSyncLock.Enter;
    try
      for nIdx:=FConnItems.Count - 1 downto 0 do
      begin
        nItem := FConnItems[nIdx];

        if CompareText(nItem.FID, nID) = 0 then
        begin
          Dec(nItem.FUsed);
          nItem.FLast := GetTickCount;
          Break;
        end;
      end;
    finally
      nWorker.FLock.Leave;
      InterlockedDecrement(FStatus.FNumObjWait);
      InterlockedDecrement(nWorker.FUsed);

      if FConnClosing = cTrue then
        nWorker.FWaiter.Wakeup;
      FSyncLock.Leave;
    end;
  end;
end;

//Desc: ִ��д�������
function TDBConnManager.WorkerExec(const nWorker: PDBWorker;
  const nSQL: string): Integer;
begin
  with nWorker^ do
  begin
    FExec.Close;
    FExec.SQL.Text := nSQL;
    Result := FExec.ExecSQL;
  end;
end;

//Desc: ִ�в�ѯ���
function TDBConnManager.WorkerQuery(const nWorker: PDBWorker;
  const nSQL: string): TDataSet;
begin
  with nWorker^ do
  begin
    Result := FQuery;
    FQuery.Close;
    FQuery.SQL.Text := nSQL;
    FQuery.Open;
  end;
end;

//Desc: ��ȡ����״̬
function TDBConnManager.GetRunStatus: TDBConnStatus;
begin
  FSyncLock.Enter;
  try
    Result := FStatus;
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  CoInitializeEx(nil,COINIT_MULTITHREADED);
  gDBConnManager := TDBConnManager.Create;
finalization
  FreeAndNil(gDBConnManager);
  CoUninitialize;
end.
