{*******************************************************************************
  ���ߣ�dmzn@163.com 2014-5-28
  ������������������ͨѶ��Ԫ
*******************************************************************************}
unit UMgrTruckProbe;

{.$DEFINE DEBUG}
interface

uses
  Windows, Classes, SysUtils, SyncObjs, IdTCPConnection, IdTCPClient, IdGlobal,
  NativeXml, USysLoger, ULibFun;

const
  cProber_NullASCII           = $30;       //ASCII���ֽ�
  cProber_Flag_Begin          = $F0;       //��ʼ��ʶ
  
  cProber_Frame_QueryIO       = $10;       //״̬��ѯ(open close)
  cProber_Frame_RelaysOC      = $20;       //������(sweet heart)
  cProber_Frame_DataForward   = $30;       //485����ת��
  cProber_Frame_IP            = $50;       //����IP
  cProber_Frame_MAC           = $60;       //����MAC

  cProber_Query_All           = $00;       //��ѯȫ��
  cProber_Query_In            = $01;       //��ѯ����
  cProber_Query_Out           = $02;       //��ѯ���

  cProber_Len_Frame           = $14;       //��ͨ֡��
  cProber_Len_FrameData       = 16;        //��ͨ��������
  cProber_Len_485Data         = 100;       //485ת������
    
type
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
    FEnable  : Boolean;              //�Ƿ�����
  end;

  TProberIOAddress = array[0..7] of Byte;
  //in-out address

  PProberTunnel = ^TProberTunnel;
  TProberTunnel = record
    FID      : string;               //��ʶ
    FName    : string;               //����
    FHost    : PProberHost;          //��������
    FIn      : TProberIOAddress;     //�����ַ
    FOut     : TProberIOAddress;     //�����ַ
    FEnable  : Boolean;              //�Ƿ�����
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
  TProberManager = class(TObject)
  private
    FHosts: TProberHosts;
    FTunnels: TProberTunnels;
    //ͨ���б�
    FRetry: Byte;
    FClient: TIdTCPClient;
    //�������
    FSyncLock: TCriticalSection;
    //ͬ������
  protected
    procedure DisconnectClient;
    function SendData(const nHost: PProberHost; var nData: TIdBytes;
      const nRecvLen: Integer): string;
    //��������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    function OpenTunnel(const nTunnel: string): Boolean;
    function CloseTunnel(const nTunnel: string): Boolean;
    function TunnelOC(const nTunnel: string; const nOC: Boolean): string;
    //����ͨ��
    function GetTunnel(const nTunnel: string): PProberTunnel;
    procedure EnableTunnel(const nTunnel: string; const nEnabled: Boolean);
    function QueryStatus(const nHost: PProberHost; const nQType: Byte;
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
    if nList.Count < 1 then Exit;

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

//------------------------------------------------------------------------------
constructor TProberManager.Create;
begin
  FRetry := 2;
  //retry times on error
  FSyncLock := TCriticalSection.Create;
  
  FClient := TIdTCPClient.Create;
  FClient.ReadTimeout := 3 * 1000;
  FClient.ConnectTimeout := 3 * 1000;
end;

destructor TProberManager.Destroy;
begin
  FClient.Disconnect;
  FClient.Free;

  FSyncLock.Free;
  inherited;
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
//Desc: �Ͽ��ͻ����׽���
procedure TProberManager.DisconnectClient;
begin
  FClient.Disconnect;
  if Assigned(FClient.IOHandler) then
    FClient.IOHandler.InputBuffer.Clear;
  //try to swtich connection
end;

//Date��2014-5-13
//Parm������;��������[in],Ӧ������[out];�����ճ���
//Desc����nHost����nData����,������Ӧ��
function TProberManager.SendData(const nHost: PProberHost; var nData: TIdBytes;
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

    DisconnectClient;
    //�Ͽ��ͻ���
    nIdx := 0;

    while nIdx < FRetry do
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

      if nIdx = FRetry then
      begin
        Result := 'δ��[ %s:%s.%d ]�յ���ͨ��У���Ӧ������.';
        Result := Format(Result, [nHost.FName, nHost.FHost, nHost.FPort]);
      end;
    except
      on E: Exception do
      begin
        Inc(nIdx);
        if nIdx < FRetry then
             Sleep(100)
        else raise;

        DisconnectClient;
        //�Ͽ�����
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

//Date��2014-5-13
//Parm��ͨ����;True=Open,False=Close
//Desc����nTunnelִ�п��ϲ���,���д����򷵻�
function TProberManager.TunnelOC(const nTunnel: string;
  const nOC: Boolean): string;
var i,j,nIdx: Integer;
    nBuf: TIdBytes;
    nData: TProberFrameControl;
begin
  Result := '';
  nIdx := -1;
  //default
  
  for i:=Low(FTunnels) to High(FTunnels) do
  if CompareText(nTunnel, FTunnels[i].FID) = 0 then
  begin
    nIdx := i;
    Break;
  end;

  if nIdx < 0 then
  begin
    Result := 'ͨ��[ %s ]�����Ч.';
    Result := Format(Result, [nTunnel]); Exit;
  end;

  with FTunnels[nIdx] do
  begin
    if not (FHost.FEnable and FEnable) then Exit;
    //������,������

    FillChar(nData, cSize_Prober_Control, cProber_NullASCII);
    //init
    
    with nData.FHeader do
    begin
      FBegin := cProber_Flag_Begin;
      FLength := cProber_Len_Frame;
      FType := cProber_Frame_RelaysOC;

      if nOC then
           FExtend := $01
      else FExtend := $02;
    end;

    j := 0;
    for i:=Low(FOut) to High(FOut) do
    begin
      if FOut[i] = cProber_NullASCII then Continue;
      //invalid out address

      nData.FData[j] := FOut[i];
      Inc(j);
    end;

    FSyncLock.Enter;
    try
      nBuf := RawToBytes(nData, cSize_Prober_Control);
      Result := SendData(FHost, nBuf, cSize_Prober_Control);
    finally
      FSyncLock.Leave;
    end;
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

//------------------------------------------------------------------------------
//Date��2014-5-14
//Parm������;��ѯ����;����������
//Desc����ѯnHost���������״̬,����nIn nOut.
function TProberManager.QueryStatus(const nHost: PProberHost; const nQType: Byte;
  var nIn, nOut: TProberIOAddress): string;
var nBuf: TIdBytes;
    nData: TProberFrameControl;
begin
  Result := '';
  FillChar(nIn, cSize_Prober_IOAddr, cProber_NullASCII);
  FillChar(nOut, cSize_Prober_IOAddr, cProber_NullASCII);

  if not nHost.FEnable then Exit;
  //������,������

  FillChar(nData, cSize_Prober_Control, cProber_NullASCII);
  //init
  
  with nData.FHeader do
  begin
    FBegin  := cProber_Flag_Begin;
    FLength := cProber_Len_Frame;
    FType   := cProber_Frame_QueryIO;
    FExtend := nQType;
  end;

  FSyncLock.Enter;
  try
    nBuf := RawToBytes(nData, cSize_Prober_Control);
    Result := SendData(nHost, nBuf, cSize_Prober_Control);
    if Result <> '' then Exit;

    BytesToRaw(nBuf, nData, cSize_Prober_Control);
    if (nQType = cProber_Query_All) or (nQType = cProber_Query_In) then
      Move(nData.FData[0], nIn[0], cSize_Prober_IOAddr);
    //in status

    if (nQType = cProber_Query_All) or (nQType = cProber_Query_Out) then
      Move(nData.FData[cSize_Prober_IOAddr], nOut[0], cSize_Prober_IOAddr);
    //out status
  finally
    FSyncLock.Leave;
  end;
end;

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
//Parm��ͨ����
//Desc����ѯnTunnel�������Ƿ�ȫ��Ϊ���ź�
function TProberManager.IsTunnelOK(const nTunnel: string): Boolean;
var nStr: string;
    nIdx: Integer;
    nPT: PProberTunnel;
    nIn,nOut: TProberIOAddress;
begin
  Result := False;
  nPT := GetTunnel(nTunnel);

  if Assigned(nPT) then
  try
    if not (nPT.FEnable and nPT.FHost.FEnable) then
    begin
      Result := True;
      Exit;
    end;

    nStr := QueryStatus(nPT.FHost, cProber_Query_In, nIn, nOut);
    //query all
    
    if nStr <> '' then
    begin
      WriteLog(nStr);
      Exit;
    end;

    for nIdx:=Low(nPT.FIn) to High(nPT.FIn) do
    begin
      if nPT.FIn[nIdx] = cProber_NullASCII then Continue;
      //invalid addr

      if nIn[nPT.FIn[nIdx] - 1] = $00 then Exit;
      //ĳ·�������ź�,��Ϊ����δͣ��
    end;

    Result := True;
  except
    on E: Exception do
    begin
      nStr := '����[ IsTunnelOK.%s ]����,����: %s';
      nStr := Format(nStr, [nTunnel, E.Message]);
      WriteLog(nStr);
    end;
  end;  
end;

initialization
  gProberManager := nil;
finalization
  FreeAndNil(gProberManager);
end.
