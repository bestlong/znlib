{*******************************************************************************
  ���ߣ�dmzn@163.com 2014-5-28
  ������������������ͨѶ��Ԫ
*******************************************************************************}
unit UMgrTruckProbe;

{.$DEFINE DEBUG}
interface

uses
  Windows, Classes, SysUtils, SyncObjs, IdTCPConnection, IdTCPClient, IdGlobal,
  NativeXml, UWaitItem, USysLoger, ULibFun;

const
  cProber_NullASCII           = $30;       //ASCII���ֽ�
  cProber_Flag_Begin          = $F0;       //��ʼ��ʶ
  
  cProber_Frame_QueryIO       = $10;       //״̬��ѯ(in out)
  cProber_Frame_RelaysOC      = $20;       //ͨ������(open close)
  cProber_Frame_DataForward   = $30;       //485����ת��
  cProber_Frame_IP            = $50;       //����IP
  cProber_Frame_MAC           = $60;       //����MAC

  cProber_Query_All           = $00;       //��ѯȫ��
  cProber_Query_In            = $01;       //��ѯ����
  cProber_Query_Out           = $02;       //��ѯ���
  cProber_Query_Interval      = 2000;      //��ѯ���

  cProber_Len_Frame           = $14;       //��ͨ֡��
  cProber_Len_FrameData       = 16;        //��ͨ��������
  cProber_Len_485Data         = 100;       //485ת������
    
type
  TProberIOAddress = array[0..7] of Byte;
  //in-out address

  TProberFrameData = array [0..cProber_Len_FrameData - 1] of Byte;
  TProber485Data   = array [0..cProber_Len_485Data - 1] of Byte;

  PProberFrameHeader = ^TProberFrameHeader;
  TProberFrameHeader = record
    FBegin  : Byte;                //��ʼ֡
    FLength : Byte;                //֡����
    FType   : Byte;                //֡����
    FExtend : Byte;                //֡��չ
  end;

  PProberFrameControl = ^TProberFrameControl;
  TProberFrameControl = record
    FHeader : TProberFrameHeader;   //֡ͷ
    FData   : TProberFrameData;     //����
    FVerify : Byte;                //У��λ
  end;

  PProberFrameDataForward = ^TProberFrameDataForward;
  TProberFrameDataForward = record
    FHeader : TProberFrameHeader;   //֡ͷ
    FData   : TProber485Data;       //����
    FVerify : Byte;                //У��λ
  end;  

  PProberHost = ^TProberHost;
  TProberHost = record
    FID      : string;               //��ʶ
    FName    : string;               //����
    FHost    : string;               //IP
    FPort    : Integer;              //�˿�
    FStatusI : TProberIOAddress;     //����״̬
    FStatusO : TProberIOAddress;     //���״̬
    FStatusL : Int64;                //״̬ʱ��
    FEnable  : Boolean;              //�Ƿ�����
  end;  

  PProberTunnel = ^TProberTunnel;
  TProberTunnel = record
    FID      : string;               //��ʶ
    FName    : string;               //����
    FHost    : PProberHost;          //��������
    FIn      : TProberIOAddress;     //�����ַ
    FOut     : TProberIOAddress;     //�����ַ
    FEnable  : Boolean;              //�Ƿ�����
  end;

  PProberTunnelCommand = ^TProberTunnelCommand;
  TProberTunnelCommand = record
    FTunnel  : PProberTunnel;
    FCommand : Integer;
    FData    : Pointer;
  end;

  TProberHosts = array of TProberHost;
  //array of host
  TProberTunnels = array of TProberTunnel;
  //array of tunnel

const
  cSize_Prober_IOAddr   = SizeOf(TProberIOAddress);
  cSize_Prober_Control  = SizeOf(TProberFrameControl);
  cSize_Prober_Display  = SizeOf(TProberFrameDataForward);

type
  TProberManager = class;
  TProberThread = class(TThread)
  private
    FOwner: TProberManager;
    //ӵ����
    FBuffer: TList;
    //����������
    FWaiter: TWaitObject;
    //�ȴ�����
    FClient: TIdTCPClient;
    //�ͻ���
    FQueryFrame: TProberFrameControl;
    //״̬��ѯ
  protected
    procedure DoExecute(const nHost: PProberHost);
    procedure Execute; override;
    //ִ���߳�
    procedure DisconnectClient;
    function SendData(const nHost: PProberHost; var nData: TIdBytes;
      const nRecvLen: Integer): string;
    //��������
  public
    constructor Create(AOwner: TProberManager);
    destructor Destroy; override;
    //�����ͷ�
    procedure Wakeup;
    procedure StopMe;
    //��ͣͨ��
  end;

  TProberManager = class(TObject)
  private
    FRetry: Byte;
    //���Դ���
    FInSignalOn: Byte;
    FInSignalOff: Byte;
    FOutSignalOn: Byte;
    FOutSignalOff: Byte;
    //��������ź�
    FCommand: TList;
    //�����б�
    FHosts: TProberHosts;
    FTunnels: TProberTunnels;
    //ͨ���б�
    FReader: TProberThread;
    //���Ӷ���
    FSyncLock: TCriticalSection;
    //ͬ������
  protected
    procedure ClearList(const nList: TList);
    //��������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure StartProber;
    procedure StopProber;
    //��ͣ�����
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    function OpenTunnel(const nTunnel: string): Boolean;
    function CloseTunnel(const nTunnel: string): Boolean;
    function TunnelOC(const nTunnel: string; nOC: Boolean): string;
    //����ͨ��
    function GetTunnel(const nTunnel: string): PProberTunnel;
    procedure EnableTunnel(const nTunnel: string; const nEnabled: Boolean);
    function QueryStatus(const nHost: PProberHost;
      var nIn,nOut: TProberIOAddress): string;
    function IsTunnelOK(const nTunnel: string): Boolean;
    //��ѯ״̬
    property Hosts: TProberHosts read FHosts;
    property RetryOnError: Byte read FRetry write FRetry;
    //�������
  end;

var
  gProberManager: TProberManager = nil;
  //ȫ��ʹ��

function ProberVerifyData(var nData: TIdBytes; const nDataLen: Integer;
  const nLast: Boolean): Byte;
procedure ProberStr2Data(const nStr: string; var nData: TProberFrameData);
//��ں���

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TProberManager, '����������', nEvent);
end;

//Desc: ��nData�����У��
function ProberVerifyData(var nData: TIdBytes; const nDataLen: Integer;
  const nLast: Boolean): Byte;
var nIdx,nLen: Integer;
begin
  Result := 0;
  if nDataLen < 1 then Exit;

  nLen := nDataLen - 2;
  //ĩλ���������
  Result := nData[0];

  for nIdx:=1 to nLen do
    Result := Result xor nData[nIdx];
  //xxxxx

  if nLast then
    nData[nDataLen - 1] := Result;
  //���ӵ�ĩβ
end;

//Date: 2014-05-30
//Parm: �ַ���;����
//Desc: ��nStr��䵽nData��
procedure ProberStr2Data(const nStr: string; var nData: TProberFrameData);
var nIdx,nLen: Integer;
begin
  nLen := Length(nStr);
  if nLen > cProber_Len_FrameData then
    nLen := cProber_Len_FrameData;
  //���Ƚ���

  for nIdx:=1 to nLen do
    nData[nIdx-1] := Ord(nStr[nIdx]);
  //xxxxx
end;

//Date: 2012-4-13
//Parm: �ַ�
//Desc: ��ȡnTxt������
function ConvertStr(const nTxt: WideString; var nBuf: array of Byte): Integer;
var nStr: string;
    nIdx: Integer;
begin
  Result := 0;
  for nIdx:=1 to Length(nTxt) do
  begin
    nStr := nTxt[nIdx];
    nBuf[Result] := Ord(nStr[1]);
    Inc(Result);

    if Length(nStr) = 2 then
    begin
      nBuf[Result] := Ord(nStr[2]);
      Inc(Result);
    end;

    if Result >= cProber_Len_485Data then Break;
  end;
end;

//Date��2014-5-13
//Parm����ַ�ṹ;��ַ�ַ���,����: 1,2,3
//Desc����nStr��,����nAddr�ṹ��
procedure SplitAddr(var nAddr: TProberIOAddress; const nStr: string);
var nIdx: Integer;
    nList: TStrings;
begin
  nList := TStringList.Create;
  try
    SplitStr(nStr, nList, 0 , ',');
    //���
    
    for nIdx:=Low(nAddr) to High(nAddr) do
    begin
      if nIdx < nList.Count then
           nAddr[nIdx] := StrToInt(nList[nIdx])
      else nAddr[nIdx] := cProber_NullASCII;
    end;
  finally
    nList.Free;
  end;
end;

{$IFDEF DEBUG}
procedure LogHex(const nData: TIdBytes);
var nStr: string;
    nIdx: Integer;
begin
  nStr := '';
  for nIdx:=Low(nData) to High(nData) do
    nStr := nStr + IntToHex(nData[nIdx], 1) + ' ';
  WriteLog(nStr);
end;
{$ENDIF}

//------------------------------------------------------------------------------
constructor TProberManager.Create;
begin
  FRetry := 2;
  FCommand := TList.Create;
  FSyncLock := TCriticalSection.Create;
end;

destructor TProberManager.Destroy;
begin
  StopProber;
  ClearList(FCommand);
  FCommand.Free;
  
  FSyncLock.Free;
  inherited;
end;

//Desc: ��������
procedure TProberManager.ClearList(const nList: TList);
var nIdx: Integer;
    nData: PProberTunnelCommand;
begin
  for nIdx:=nList.Count - 1 downto 0 do
  begin
    nData := nList[nIdx];

    if nData.FCommand = cProber_Frame_DataForward then
         Dispose(PProberFrameDataForward(nData.FData))
    else Dispose(PProberFrameControl(nData.FData));

    Dispose(nData);
    nList.Delete(nIdx);
  end;
end;

//Desc: ����
procedure TProberManager.StartProber;
begin
  if not Assigned(FReader) then
    FReader := TProberThread.Create(Self);
  FReader.Wakeup;
end;

//Desc: ֹͣ
procedure TProberManager.StopProber;
begin
  if Assigned(FReader) then
    FReader.StopMe;
  FReader := nil;
end;

//Desc: ����nFile�����ļ�
procedure TProberManager.LoadConfig(const nFile: string);
var nXML: TNativeXml;
    nHost: PProberHost;
    nNode,nTmp: TXmlNode;
    i,nIdx,nNum: Integer;
begin
  SetLength(FHosts, 0);
  SetLength(FTunnels, 0);
  
  nXML := TNativeXml.Create;
  try
    nXML.LoadFromFile(nFile);
    //load config

    for nIdx:=0 to nXML.Root.NodeCount - 1 do
    begin
      nNode := nXML.Root.Nodes[nIdx];
      nNum := Length(FHosts);
      SetLength(FHosts, nNum + 1);

      with FHosts[nNum],nNode do
      begin
        FID    := AttributeByName['id'];
        FName  := AttributeByName['name'];
        FHost  := NodeByName('ip').ValueAsString;
        FPort  := NodeByName('port').ValueAsInteger;
        FEnable := NodeByName('enable').ValueAsInteger = 1;

        FStatusL := 0;
        //���һ�β�ѯ״̬ʱ��,��ʱϵͳ�᲻�Ͽɵ�ǰ״̬
      end;

      nTmp := nNode.FindNode('signal_in');
      if Assigned(nTmp) then
      begin
        FInSignalOn := StrToInt(nTmp.AttributeByName['on']);
        FInSignalOff := StrToInt(nTmp.AttributeByName['off']);
      end else
      begin
        FInSignalOn := $00;
        FInSignalOff := $01;
      end;

      nTmp := nNode.FindNode('signal_out');
      if Assigned(nTmp) then
      begin
        FOutSignalOn := StrToInt(nTmp.AttributeByName['on']);
        FOutSignalOff := StrToInt(nTmp.AttributeByName['off']);
      end else
      begin
        FOutSignalOn := $01;
        FOutSignalOff := $02;
      end;

      nTmp := nNode.FindNode('tunnels');
      if not Assigned(nTmp) then Continue;
      nHost := @FHosts[nNum];

      for i:=0 to nTmp.NodeCount - 1 do
      begin
        nNode := nTmp.Nodes[i];
        nNum := Length(FTunnels);
        SetLength(FTunnels, nNum + 1);

        with FTunnels[nNum],nNode do
        begin
          FID    := AttributeByName['id'];
          FName  := AttributeByName['name'];
          FHost  := nHost;
          
          SplitAddr(FIn, NodeByName('in').ValueAsString);
          SplitAddr(FOut, NodeByName('out').ValueAsString);

          nNode := nNode.FindNode('enable');
          FEnable := (not Assigned(nNode)) or (nNode.ValueAsString <> '0');
        end;
      end;
    end;
  finally
    nXML.Free;
  end;
end;

//------------------------------------------------------------------------------
//Date��2014-5-14
//Parm��ͨ����
//Desc����ȡnTunnel��ͨ������
function TProberManager.GetTunnel(const nTunnel: string): PProberTunnel;
var nIdx: Integer;
begin
  Result := nil;

  for nIdx:=Low(FTunnels) to High(FTunnels) do
  if CompareText(nTunnel, FTunnels[nIdx].FID) = 0 then
  begin
    Result := @FTunnels[nIdx];
    Break;
  end;
end;

//Date��2014-5-13
//Parm��ͨ����;True=Open,False=Close
//Desc����nTunnelִ�п��ϲ���,���д����򷵻�
function TProberManager.TunnelOC(const nTunnel: string; nOC: Boolean): string;
var i,j,nIdx: Integer;
    nPTunnel: PProberTunnel;
    nCmd: PProberTunnelCommand;
    nData: PProberFrameControl;
begin
  Result := '';
  if not Assigned(FReader) then Exit;
  nPTunnel := GetTunnel(nTunnel);

  if not Assigned(nPTunnel) then
  begin
    Result := 'ͨ��[ %s ]�����Ч.';
    Result := Format(Result, [nTunnel]); Exit;
  end;

  if not (nPTunnel.FEnable and nPTunnel.FHost.FEnable ) then Exit;
  //������,������

  i := 0;
  for nIdx:=Low(nPTunnel.FOut) to High(nPTunnel.FOut) do
    if nPTunnel.FOut[nIdx] <> cProber_NullASCII then Inc(i);
  //xxxxx

  if i < 1 then Exit;
  //�������ַ,��ʾ��ʹ���������

  FSyncLock.Enter;
  try
    New(nCmd);
    FCommand.Add(nCmd);
    nCmd.FTunnel := nPTunnel;
    nCmd.FCommand := cProber_Frame_RelaysOC;

    New(nData);
    nCmd.FData := nData;
    FillChar(nData^, cSize_Prober_Control, cProber_NullASCII);

    with nData.FHeader do
    begin
      FBegin := cProber_Flag_Begin;
      FLength := cProber_Len_Frame;
      FType := cProber_Frame_RelaysOC;

      if nOC then
           FExtend := FOutSignalOn
      else FExtend := FOutSignalOff;
    end;

    j := 0;
    for i:=Low(nPTunnel.FOut) to High(nPTunnel.FOut) do
    begin
      if nPTunnel.FOut[i] = cProber_NullASCII then Continue;
      //invalid out address

      nData.FData[j] := nPTunnel.FOut[i];
      Inc(j);
    end;

    FReader.Wakeup;
    //xxxxx
  finally

    FSyncLock.Leave;
  end;
end;

//Date��2014-5-13
//Parm��ͨ����
//Desc����nTunnelִ�����ϲ���
function TProberManager.OpenTunnel(const nTunnel: string): Boolean;
var nStr: string;
begin
  nStr := TunnelOC(nTunnel, False);
  Result := nStr = '';

  if not Result then
    WriteLog(nStr);
  //xxxxxx
end;

//Date��2014-5-13
//Parm��ͨ����
//Desc����nTunnelִ�жϿ�����
function TProberManager.CloseTunnel(const nTunnel: string): Boolean;
var nStr: string;
begin
  nStr := TunnelOC(nTunnel, True);
  Result := nStr = '';

  if not Result then
    WriteLog(nStr);
  //xxxxxx
end;

//Date: 2014-07-03
//Parm: ͨ����;����
//Desc: �Ƿ�����nTunnelͨ��
procedure TProberManager.EnableTunnel(const nTunnel: string;
  const nEnabled: Boolean);
var nPT: PProberTunnel;
begin
  nPT := GetTunnel(nTunnel);
  if Assigned(nPT) then
    nPT.FEnable := nEnabled;
  //xxxxx
end;

//Date��2014-5-14
//Parm������;��ѯ����;����������
//Desc����ѯnHost���������״̬,����nIn nOut.
function TProberManager.QueryStatus(const nHost: PProberHost;
  var nIn, nOut: TProberIOAddress): string;
var nIdx: Integer;
begin
  for nIdx:=Low(TProberIOAddress) to High(TProberIOAddress) do
  begin
    nIn[nIdx]  := FInSignalOn;
    nOut[nIdx] := FInSignalOn;
  end;

  for nIdx:=Low(FHosts) to High(FHosts) do
  if nHost.FID = FHosts[nIdx].FID then
  begin
    if GetTickCount - FHosts[nIdx].FStatusL >= 2 * cProber_Query_Interval then
    begin
      Result := Format('���������[ %s ]״̬��ѯ��ʱ.', [nHost.FName]);
      Exit;
    end;

    nIn := FHosts[nIdx].FStatusI;
    nOut := FHosts[nIdx].FStatusO;
    Result := ''; Exit;
  end;

  Result := Format('���������[ %s ]����Ч.', [nHost.FID]);
end;

//Date��2014-5-14
//Parm��ͨ����
//Desc����ѯnTunnel�������Ƿ�ȫ��Ϊ���ź�
function TProberManager.IsTunnelOK(const nTunnel: string): Boolean;
var nIdx,nNum: Integer;
    nPT: PProberTunnel;
begin
  Result := False;
  nPT := GetTunnel(nTunnel);

  if not Assigned(nPT) then
  begin
    WriteLog(Format('ͨ��[ %s ]��Ч.',  [nTunnel]));
    Exit;
  end;

  if not (nPT.FEnable and nPT.FHost.FEnable) then
  begin
    Result := True;
    Exit;
  end;

  nNum := 0;
  for nIdx:=Low(nPT.FIn) to High(nPT.FIn) do
   if nPT.FIn[nIdx] <> cProber_NullASCII then Inc(nNum);
  //xxxxx

  if nNum < 1 then //�������ַ,��ʶ��ʹ��������
  begin
    Result := True;
    Exit;
  end;

  if GetTickCount - nPT.FHost.FStatusL >= 2 * cProber_Query_Interval then
  begin
    WriteLog(Format('���������[ %s ]״̬��ѯ��ʱ.', [nPT.FHost.FName]));
    Exit;
  end;

  for nIdx:=Low(nPT.FIn) to High(nPT.FIn) do
  begin
    if nPT.FIn[nIdx] = cProber_NullASCII then Continue;
    //invalid addr

    if nPT.FHost.FStatusI[nPT.FIn[nIdx] - 1] = FInSignalOn then Exit;
    //ĳ·�������ź�,��Ϊ����δͣ��
  end;

  Result := True;
end;

//------------------------------------------------------------------------------
constructor TProberThread.Create(AOwner: TProberManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FBuffer := TList.Create;
  
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := cProber_Query_Interval;

  FClient := TIdTCPClient.Create(nil);
  FClient.ReadTimeout := 3 * 1000;
  FClient.ConnectTimeout := 3 * 1000;
end;

destructor TProberThread.Destroy;
begin
  FClient.Free;
  FWaiter.Free;

  FOwner.ClearList(FBuffer);
  FBuffer.Free;
  inherited;
end;

procedure TProberThread.Wakeup;
begin
  FWaiter.Wakeup;
end;

procedure TProberThread.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure TProberThread.Execute;
var nIdx: Integer;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    with FOwner do
    begin
      FSyncLock.Enter;
      try
        ClearList(FBuffer);
        for nIdx:=0 to FCommand.Count - 1 do
          FBuffer.Add(FCommand[nIdx]);
        FCommand.Clear;
      finally
        FSyncLock.Leave;
      end;

      for nIdx:=Low(FOwner.FHosts) to High(FOwner.FHosts) do
      begin
        DoExecute(@FOwner.FHosts[nIdx]);
        if Terminated then Exit;
      end;
    end;
  except
    on E:Exception do
    begin
      WriteLog(Format('Host:[ %s ] %s', [FClient.Host, E.Message]));
    end;
  end;
end;

procedure TProberThread.DoExecute(const nHost: PProberHost);
var nStr: string;
    nIdx,nSize: Integer;
    nBuf: TIdBytes;
    nCmd: PProberTunnelCommand;
begin
  try
    if FClient.Host <> nHost.FHost then
      DisconnectClient;
    //xxxxx

    if not FClient.Connected then
    begin
      FClient.Host := nHost.FHost;
      FClient.Port := nHost.FPort;
      FClient.Connect;
    end;
  except
    WriteLog(Format('����[ %s.%d ]ʧ��.', [FClient.Host, FClient.Port]));
    FClient.Disconnect;
    Exit;
  end;

  FillChar(FQueryFrame, cSize_Prober_Control, cProber_NullASCII);
  //init
  with FQueryFrame.FHeader do
  begin
    FBegin  := cProber_Flag_Begin;
    FLength := cProber_Len_Frame;
    FType   := cProber_Frame_QueryIO;
    FExtend := cProber_Query_All;
  end;

  nBuf := RawToBytes(FQueryFrame, cSize_Prober_Control);
  nStr := SendData(nHost, nBuf, cSize_Prober_Control);
  //��ѯ״̬

  if nStr <> '' then
  begin
    WriteLog(nStr);
    Exit;
  end;

  with FQueryFrame do
  begin
    BytesToRaw(nBuf, FQueryFrame, cSize_Prober_Control);
    Move(FData[0], nHost.FStatusI[0], cSize_Prober_IOAddr);
    Move(FData[cSize_Prober_IOAddr], nHost.FStatusO[0], cSize_Prober_IOAddr);

    nHost.FStatusL := GetTickCount;
    //����ʱ��
    Sleep(100);
  end;

  for nIdx:=FBuffer.Count - 1 downto 0 do
  begin
    nCmd := FBuffer[nIdx];
    if nCmd.FTunnel.FHost <> nHost then Continue;

    if nCmd.FCommand = cProber_Frame_DataForward then
    begin
      nSize := cSize_Prober_Display;
      nBuf := RawToBytes(PProberFrameDataForward(nCmd.FData)^, nSize);
    end else
    begin
      nSize := cSize_Prober_Control;
      nBuf := RawToBytes(PProberFrameControl(nCmd.FData)^, nSize);
    end;

    nStr := SendData(nHost, nBuf, cSize_Prober_Control);
    if nStr <> '' then
      WriteLog(nStr);
    Sleep(100);
  end;
end;

//Desc: �Ͽ��ͻ����׽���
procedure TProberThread.DisconnectClient;
begin
  FClient.Disconnect;
  if Assigned(FClient.IOHandler) then
    FClient.IOHandler.InputBuffer.Clear;
  //try to swtich connection
end;

//Date��2014-5-13
//Parm������;��������[in],Ӧ������[out];�����ճ���
//Desc����nHost����nData����,������Ӧ��
function TProberThread.SendData(const nHost: PProberHost; var nData: TIdBytes;
  const nRecvLen: Integer): string;
var nBuf: TIdBytes;
    nIdx,nLen: Integer;
begin
  Result := '';
  try
    nLen := Length(nData);
    ProberVerifyData(nData, nLen, True);
    //������У��

    SetLength(nBuf, nLen);
    CopyTIdBytes(nData, 0, nBuf, 0, nLen);
    //���ݴ���������

    nIdx := 0;
    while nIdx < FOwner.FRetry do
    try
      {$IFDEF DEBUG}
      LogHex(nBuf);
      {$ENDIF}

      if not FClient.Connected then
      begin
        FClient.Host := nHost.FHost;
        FClient.Port := nHost.FPort;
        FClient.Connect;
      end;

      Inc(nIdx);
      FClient.IOHandler.Write(nBuf);
      //send data

      if nRecvLen < 1 then Exit;
      //no data to receive

      FClient.IOHandler.ReadBytes(nData, nRecvLen, False);
      //read respond
      
      {$IFDEF DEBUG}
      LogHex(nData);
      {$ENDIF}

      nLen := Length(nData);
      if (nLen = nRecvLen) and
         (nData[nLen-1] = ProberVerifyData(nData, nLen, False)) then Exit;
      //У��ͨ��

      if nIdx = FOwner.FRetry then
      begin
        Result := 'δ��[ %s:%s.%d ]�յ���ͨ��У���Ӧ������.';
        Result := Format(Result, [nHost.FName, nHost.FHost, nHost.FPort]);
      end;
    except
      on E: Exception do
      begin
        DisconnectClient;
        //�Ͽ�����

        Inc(nIdx);
        if nIdx < FOwner.FRetry then
             Sleep(100)
        else raise;
      end;
    end;
  except
    on E: Exception do
    begin
      Result := '��[ %s:%s:%d ]��������ʧ��,����: %s';
      Result := Format(Result, [nHost.FName, nHost.FHost, nHost.FPort, E.Message]);
    end;
  end;
end;

initialization
  gProberManager := nil;
finalization
  FreeAndNil(gProberManager);
end.
