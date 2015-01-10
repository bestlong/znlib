{*******************************************************************************
  ����: dmzn@163.com 2014-06-11
  ����: ��վͨ��������
*******************************************************************************}
unit UMgrPoundTunnels;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, CPort, CPortTypes, IdComponent,
  IdTCPConnection, IdTCPClient, IdGlobal, IdSocketHandle, NativeXml, ULibFun,
  UWaitItem, USysLoger;

const
  cPTMaxCameraTunnel = 5;
  //֧�ֵ������ͨ����

  cPTWait_Short = 50;
  cPTWait_Long  = 2 * 1000; //����ͨѶʱˢ��Ƶ��

type
  TOnTunnelDataEvent = procedure (const nValue: Double) of object;
  //�¼�����

  TPoundTunnelManager = class;
  TPoundTunnelConnector = class;

  PPTPortItem = ^TPTPortItem;
  PPTCameraItem = ^TPTCameraItem;
  PPTTunnelItem = ^TPTTunnelItem;
  
  TPTTunnelItem = record
    FID: string;                     //��ʶ
    FName: string;                   //����
    FPort: PPTPortItem;              //ͨѶ�˿�
    FProber: string;                 //������
    FReader: string;                 //�ſ���ͷ
    FUserInput: Boolean;             //�ֹ�����

    FFactoryID: string;              //������ʶ
    FCardInterval: Integer;          //�������
    FSampleNum: Integer;             //��������
    FSampleFloat: Integer;           //��������

    FCamera: PPTCameraItem;          //�����
    FCameraTunnels: array[0..cPTMaxCameraTunnel-1] of Byte;
                                     //����ͨ��                                     
    FOnData: TOnTunnelDataEvent;     //�����¼�
    FOldEventTunnel: PPTTunnelItem;  //ԭ����ͨ��

    FEnable: Boolean;                //�Ƿ�����
    FLocked : Boolean;               //�Ƿ�����
    FLastActive: Int64;              //�ϴλ
  end;

  TPTCameraItem = record
    FID: string;                     //��ʶ
    FHost: string;                   //������ַ
    FPort: Integer;                  //�˿�
    FUser: string;                   //�û���
    FPwd: string;                    //����
    FPicSize: Integer;               //ͼ���С
    FPicQuality: Integer;            //ͼ������
  end;

  TPTConnType = (ctTCP, ctCOM);
  //��·����: ����,����
         
  TPTPortItem = record
    FID: string;                     //��ʶ
    FName: string;                   //����
    FType: string;                   //����
    FConn: TPTConnType;              //��·
    FPort: string;                   //�˿�
    FRate: TBaudRate;                //������
    FDatabit: TDataBits;             //����λ
    FStopbit: TStopBits;             //��ͣλ
    FParitybit: TParityBits;         //У��λ
    FParityCheck: Boolean;           //����У��
    FCharBegin: Char;                //��ʼ���
    FCharEnd: Char;                  //�������
    FPackLen: Integer;               //���ݰ���
    FSplitTag: string;               //�ֶα�ʶ
    FSplitPos: Integer;              //��Ч��
    FInvalidBegin: Integer;          //���׳���
    FInvalidEnd: Integer;            //��β����
    FDataMirror: Boolean;            //��������
    FDataEnlarge: Single;            //�Ŵ���

    FHostIP: string;
    FHostPort: Integer;              //������·

    FCOMPort: TComPort;              //��д����
    FCOMBuff: string;                //ͨѶ����
    FCOMData: string;                //ͨѶ����
    FEventTunnel: PPTTunnelItem;     //����ͨ��
  end;

  TPoundTunnelConnector = class(TThread)
  private
    FOwner: TPoundTunnelManager;
    //ӵ����
    FActiveTunnel: PPTTunnelItem;
    //��ǰͨ��
    FWaiter: TWaitObject;
    //�ȴ�����
    FClient: TIdTCPClient;
    //�������
  protected
    procedure DoExecute;
    procedure Execute; override;
    //ִ���߳�
    function ReadPound(const nTunnel: PPTTunnelItem): Boolean;
    //��ȡ����
  public
    constructor Create(AOwner: TPoundTunnelManager);
    destructor Destroy; override;
    //�����ͷ�
    procedure WakupMe;
    //�����߳�
    procedure StopMe;
    //ֹͣ�߳�
  end;

  TPoundTunnelManager = class(TObject)
  private
    FPorts: TList;
    //�˿��б�
    FCameras: TList;
    //�����
    FTunnelIndex: Integer;
    FTunnels: TList;
    //ͨ���б�
    FStrList: TStrings;
    //�ַ��б�
    FSyncLock: TCriticalSection;
    //ͬ������
  protected
    procedure ClearList(const nFree: Boolean);
    //������Դ
    function ParseWeight(const nPort: PPTPortItem): Boolean;
    procedure OnComData(Sender: TObject; Count: Integer);
    //��ȡ����
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    procedure ActivePort(const nTunnel: string; nEvent: TOnTunnelDataEvent;
      const nOpenPort: Boolean = False);
    procedure ClosePort(const nTunnel: string);
    //��ͣ�˿�
    function GetPort(const nID: string): PPTPortItem;
    function GetCamera(const nID: string): PPTCameraItem;
    function GetTunnel(const nID: string): PPTTunnelItem;
    //��������
    property Tunnels: TList read FTunnels;
    //�������
  end;

var
  gPoundTunnelManager: TPoundTunnelManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TPoundTunnelManager, '��վͨ������', nEvent);
end;

constructor TPoundTunnelManager.Create;
begin
  FPorts := TList.Create;
  FCameras := TList.Create;
  FTunnels := TList.Create;

  FStrList := TStringList.Create;
  FSyncLock := TCriticalSection.Create;
end;

destructor TPoundTunnelManager.Destroy;
begin
  ClearList(True);
  FStrList.Free;
  
  FSyncLock.Free;
  inherited;
end;

//Date: 2014-06-12
//Parm: �Ƿ��ͷ�
//Desc: �����б���Դ
procedure TPoundTunnelManager.ClearList(const nFree: Boolean);
var nIdx: Integer;
    nPort: PPTPortItem;
begin
  for nIdx:=FPorts.Count - 1 downto 0 do
  begin
    nPort := FPorts[nIdx];
    if Assigned(nPort.FCOMPort) then
    begin
      nPort.FCOMPort.Close;
      nPort.FCOMPort.Free;
    end;

    Dispose(nPort);
    FPorts.Delete(nIdx);
  end;

  for nIdx:=FCameras.Count - 1 downto 0 do
  begin
    Dispose(PPTCameraItem(FCameras[nIdx]));
    FCameras.Delete(nIdx);
  end;

  for nIdx:=FTunnels.Count - 1 downto 0 do
  begin
    Dispose(PPTTunnelItem(FTunnels[nIdx]));
    FTunnels.Delete(nIdx);
  end;

  if nFree then
  begin
    FPorts.Free;
    FCameras.Free;
    FTunnels.Free;
  end;
end;

//Date��2014-6-18
//Parm��ͨ��;��ַ�ַ���,����: 1,2,3
//Desc����nStr��,����nTunnel.FCameraTunnels�ṹ��
procedure SplitCameraTunnel(const nTunnel: PPTTunnelItem; const nStr: string);
var nIdx: Integer;
    nList: TStrings;
begin
  nList := TStringList.Create;
  try
    for nIdx:=Low(nTunnel.FCameraTunnels) to High(nTunnel.FCameraTunnels) do
      nTunnel.FCameraTunnels[nIdx] := MAXBYTE;
    //Ĭ��ֵ

    SplitStr(nStr, nList, 0 , ',');
    if nList.Count < 1 then Exit;

    nIdx := nList.Count - 1;
    if nIdx > High(nTunnel.FCameraTunnels) then
      nIdx := High(nTunnel.FCameraTunnels);
    //���߽�

    while nIdx>=Low(nTunnel.FCameraTunnels) do
    begin
      nTunnel.FCameraTunnels[nIdx] := StrToInt(nList[nIdx]);
      Dec(nIdx);
    end;
  finally
    nList.Free;
  end;
end;

//Date: 2014-06-12
//Parm: �����ļ�
//Desc: ����nFile����
procedure TPoundTunnelManager.LoadConfig(const nFile: string);
var nStr: string;
    nIdx: Integer;
    nXML: TNativeXml;
    nNode,nTmp: TXmlNode;
    nPort: PPTPortItem;
    nCamera: PPTCameraItem;
    nTunnel: PPTTunnelItem;
begin
  nXML := TNativeXml.Create;
  try
    nXML.LoadFromFile(nFile);
    nNode := nXML.Root.FindNode('ports');

    for nIdx:=0 to nNode.NodeCount - 1 do
    with nNode.Nodes[nIdx] do
    begin
      New(nPort);
      FPorts.Add(nPort);
      FillChar(nPort^, SizeOf(TPTPortItem), #0);

      nPort.FID := AttributeByName['id'];
      nPort.FName := AttributeByName['name'];
      nPort.FType := NodeByName('type').ValueAsString;

      nTmp := FindNode('conn');
      if Assigned(nTmp) then
           nStr := nTmp.ValueAsString
      else nStr := 'com';

      if CompareText('tcp', nStr) = 0 then
           nPort.FConn := ctTCP
      else nPort.FConn := ctCOM;

      nPort.FPort := NodeByName('port').ValueAsString;
      nPort.FRate := StrToBaudRate(NodeByName('rate').ValueAsString);
      nPort.FDatabit := StrToDataBits(NodeByName('databit').ValueAsString);
      nPort.FStopbit := StrToStopBits(NodeByName('stopbit').ValueAsString);
      nPort.FParitybit := StrToParity(NodeByName('paritybit').ValueAsString);
      nPort.FParityCheck := NodeByName('paritycheck').ValueAsString = 'Y';

      nPort.FCharBegin := Char(StrToInt(NodeByName('charbegin').ValueAsString));
      nPort.FCharEnd := Char(StrToInt(NodeByName('charend').ValueAsString));
      nPort.FPackLen := NodeByName('packlen').ValueAsInteger;

      nTmp := FindNode('invalidlen');
      if Assigned(nTmp) then //ֱ��ָ����ȡ����
      begin
        nPort.FInvalidBegin := 0;
        nPort.FInvalidEnd := nTmp.ValueAsInteger;
      end else
      begin
        nPort.FInvalidBegin := NodeByName('invalidbegin').ValueAsInteger;
        nPort.FInvalidEnd := NodeByName('invalidend').ValueAsInteger;
      end;

      nPort.FSplitTag := Char(StrToInt(NodeByName('splittag').ValueAsString));
      nPort.FSplitPos := NodeByName('splitpos').ValueAsInteger;
      nPort.FDataMirror := NodeByName('datamirror').ValueAsInteger = 1;
      nPort.FDataEnlarge := NodeByName('dataenlarge').ValueAsFloat;

      nTmp := FindNode('hostip');
      if Assigned(nTmp) then nPort.FHostIP := nTmp.ValueAsString;
      nTmp := FindNode('hostport');
      if Assigned(nTmp) then nPort.FHostPort := nTmp.ValueAsInteger;

      nPort.FCOMPort := nil;
      //Ĭ�ϲ�����
      nPort.FEventTunnel := nil;
    end;

    nNode := nXML.Root.FindNode('cameras');
    if Assigned(nNode) then
    begin
      for nIdx:=0 to nNode.NodeCount - 1 do
      with nNode.Nodes[nIdx] do
      begin
        New(nCamera);
        FCameras.Add(nCamera);
        FillChar(nCamera^, SizeOf(TPTCameraItem), #0);

        nCamera.FID := AttributeByName['id'];
        nCamera.FHost := NodeByName('host').ValueAsString;
        nCamera.FPort := NodeByName('port').ValueAsInteger;
        nCamera.FUser := NodeByName('user').ValueAsString;
        nCamera.FPwd := NodeByName('password').ValueAsString;
        nCamera.FPicSize := NodeByName('picsize').ValueAsInteger;
        nCamera.FPicQuality := NodeByName('picquality').ValueAsInteger;
      end;
    end;

    nNode := nXML.Root.FindNode('tunnels');
    for nIdx:=0 to nNode.NodeCount - 1 do
    with nNode.Nodes[nIdx] do
    begin
      New(nTunnel);
      FTunnels.Add(nTunnel);
      FillChar(nTunnel^, SizeOf(TPTTunnelItem), #0);

      nStr := NodeByName('port').ValueAsString;
      nTunnel.FPort := GetPort(nStr);
      if not Assigned(nTunnel.FPort) then
        raise Exception.Create(Format('ͨ��[ %s.Port ]��Ч.', [nTunnel.FName]));
      //xxxxxx

      nTunnel.FID := AttributeByName['id'];
      nTunnel.FName := AttributeByName['name'];
      nTunnel.FProber := NodeByName('prober').ValueAsString;
      nTunnel.FReader := NodeByName('reader').ValueAsString;
      nTunnel.FUserInput := NodeByName('userinput').ValueAsString = 'Y';

      nTunnel.FFactoryID := NodeByName('factory').ValueAsString;
      nTunnel.FCardInterval := NodeByName('cardInterval').ValueAsInteger;
      nTunnel.FSampleNum := NodeByName('sampleNum').ValueAsInteger;
      nTunnel.FSampleFloat := NodeByName('sampleFloat').ValueAsInteger;

      nTmp := FindNode('camera');
      if Assigned(nTmp) then
      begin
        nStr := nTmp.AttributeByName['id'];
        nTunnel.FCamera := GetCamera(nStr);
        SplitCameraTunnel(nTunnel, nTmp.ValueAsString);
      end else
      begin
        nTunnel.FCamera := nil;
        //no camera
      end;

      nTunnel.FEnable := False;
      nTunnel.FLocked := False;
      nTunnel.FLastActive := GetTickCount;
    end;
  finally
    nXML.Free;
  end;   
end;

//------------------------------------------------------------------------------
//Desc: ������ʶΪnID�Ķ˿�
function TPoundTunnelManager.GetPort(const nID: string): PPTPortItem;
var nIdx: Integer;
begin
  Result := nil;

  for nIdx:=FPorts.Count - 1 downto 0 do
  if CompareText(nID, PPTPortItem(FPorts[nIdx]).FID) = 0 then
  begin
    Result := FPorts[nIdx];
    Exit;
  end;
end;

//Desc: ������ʶΪnID�������
function TPoundTunnelManager.GetCamera(const nID: string): PPTCameraItem;
var nIdx: Integer;
begin
  Result := nil;

  for nIdx:=FCameras.Count - 1 downto 0 do
  if CompareText(nID, PPTCameraItem(FCameras[nIdx]).FID) = 0 then
  begin
    Result := FCameras[nIdx];
    Exit;
  end;
end;

//Desc: ������ʶΪnID��ͨ��
function TPoundTunnelManager.GetTunnel(const nID: string): PPTTunnelItem;
var nIdx: Integer;
begin
  Result := nil;

  for nIdx:=FTunnels.Count - 1 downto 0 do
  if CompareText(nID, PPTTunnelItem(FTunnels[nIdx]).FID) = 0 then
  begin
    Result := FTunnels[nIdx];
    Exit;
  end;
end;

//Date: 2014-06-11
//Parm: ͨ����;�����¼�
//Desc: ����nTunnelͨ����д�˿�
procedure TPoundTunnelManager.ActivePort(const nTunnel: string;
  nEvent: TOnTunnelDataEvent; const nOpenPort: Boolean);
var nPT: PPTTunnelItem;
begin
  FSyncLock.Enter;
  try
    nPT := GetTunnel(nTunnel);
    if not Assigned(nPT) then Exit;

    if not Assigned(nPT.FPort.FCOMPort) then
    begin
      nPT.FPort.FCOMPort := TComPort.Create(nil);
      with nPT.FPort.FCOMPort do
      begin
        Tag := FPorts.IndexOf(nPT.FPort);
        OnRxChar := OnComData;

        with Timeouts do
        begin
          ReadTotalConstant := 100;
          ReadTotalMultiplier := 10;
        end;

        with Parity do
        begin
          Bits := nPT.FPort.FParitybit;
          Check := nPT.FPort.FParityCheck;
        end;

        Port := nPT.FPort.FPort;
        BaudRate := nPT.FPort.FRate;
        DataBits := nPT.FPort.FDatabit;
        StopBits := nPT.FPort.FStopbit;
      end;
    end;
  
    nPT.FOnData := nEvent;
    nPT.FOldEventTunnel := nPT.FPort.FEventTunnel;
    nPT.FPort.FEventTunnel := nPT;

    try
      if nOpenPort then
        nPT.FPort.FCOMPort.Open;
      //�����˿�
    except
      on E: Exception do
      begin
        WriteLog(E.Message);
      end;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2014-06-11
//Parm: ͨ����
//Desc: �ر�nTunnelͨ����д�˿�
procedure TPoundTunnelManager.ClosePort(const nTunnel: string);
var nPT: PPTTunnelItem;
begin
  FSyncLock.Enter;
  try
    nPT := GetTunnel(nTunnel);
    if not Assigned(nPT) then Exit;
    nPT.FOnData := nil;

    if nPT.FPort.FEventTunnel = nPT then
    begin
      nPT.FPort.FEventTunnel := nPT.FOldEventTunnel;
      //��ԭ����ͨ��

      if Assigned(nPT.FPort.FCOMPort) then
        nPT.FPort.FCOMPort.Close;
      //ͨ��������ر�
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2014-06-11
//Desc: ��ȡ����
procedure TPoundTunnelManager.OnComData(Sender: TObject; Count: Integer);
var nVal: Double;
    nPort: PPTPortItem;
begin
  with TComPort(Sender) do
  begin
    nPort := FPorts[Tag];
    ReadStr(nPort.FCOMBuff, Count);
  end;

  FSyncLock.Enter;
  try
    if not (Assigned(nPort.FEventTunnel) and
            Assigned(nPort.FEventTunnel.FOnData)) then Exit;
    //�޽����¼�

    nPort.FCOMData := nPort.FCOMData + nPort.FCOMBuff;
    if Length(nPort.FCOMData) < nPort.FPackLen then Exit;
    //���ݲ�����������

    try
      if ParseWeight(nPort) then
      begin
        nVal := StrToFloat(nPort.FCOMData) * nPort.FDataEnlarge;
        nPort.FEventTunnel.FOnData(nVal);
        nPort.FCOMData := '';
      end;
    except
      on E: Exception do
      begin
        WriteLog(E.Message);
      end;
    end;
  finally
    FSyncLock.Leave;
  end;

  if Length(nPort.FCOMData) >= 5 * nPort.FPackLen then
  begin
    System.Delete(nPort.FCOMData, 1, 4 * nPort.FPackLen);
    WriteLog('��Ч���ݹ���,�Ѳü�.')
  end;
end;

//Date: 2014-06-12
//Parm: �˿�
//Desc: ����nPort�ϵĳ�������
function TPoundTunnelManager.ParseWeight(const nPort: PPTPortItem): Boolean;
var nIdx,nPos,nEnd: Integer;
begin
  Result := False;
  nEnd := -1;

  for nIdx:=Length(nPort.FCOMData) downto 1 do
  begin
    if nPort.FCOMData[nIdx] = nPort.FCharEnd then
    begin
      nEnd := nIdx;
      Continue;
    end;

    if (nEnd < 1) or (nPort.FCOMData[nIdx] <> nPort.FCharBegin) then Continue;
    //�����ݽ������,���ǿ�ʼ���

    nPort.FCOMData := Copy(nPort.FCOMData, nIdx + 1, nEnd - nIdx - 1);
    //�������ͷ������

    if nPort.FSplitPos > 0 then
    begin
      SplitStr(nPort.FCOMData, FStrList, 0, nPort.FSplitTag);
      //�������

      for nPos:=FStrList.Count - 1 downto 0 do
      begin
        FStrList[nPos] := Trim(FStrList[nPos]);
        if FStrList[nPos] = '' then FStrList.Delete(nPos);
      end; //��������

      if FStrList.Count < nPort.FSplitPos then
      begin
        nPort.FCOMData := '';
        Exit;
      end; //�ֶ�����Խ��

      nPort.FCOMData := FStrList[nPort.FSplitPos - 1];
      //��Ч����
    end;

    if nPort.FInvalidBegin > 0 then
      System.Delete(nPort.FCOMData, 1, nPort.FInvalidBegin);
    //�ײ���Ч����

    if nPort.FInvalidEnd > 0 then
      System.Delete(nPort.FCOMData, Length(nPort.FCOMData)-nPort.FInvalidEnd+1,
                    nPort.FInvalidEnd);
    //β����Ч����

    if nPort.FDataMirror then
      nPort.FCOMData := MirrorStr(nPort.FCOMData);
    //���ݷ�ת

    nPort.FCOMData := Trim(nPort.FCOMData);
    Result := IsNumber(nPort.FCOMData, False);
    Exit;
  end;
end;

//------------------------------------------------------------------------------
constructor TPoundTunnelConnector.Create(AOwner: TPoundTunnelManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := cPTWait_Short;

  FClient := TIdTCPClient.Create;
  FClient.ReadTimeout := 5 * 1000;
  FClient.ConnectTimeout := 5 * 1000;
end;

destructor TPoundTunnelConnector.Destroy;
begin
  FClient.Disconnect;
  FClient.Free;

  FWaiter.Free;
  inherited;
end;

procedure TPoundTunnelConnector.WakupMe;
begin
  FWaiter.Wakeup;
end;

procedure TPoundTunnelConnector.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure TPoundTunnelConnector.Execute;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    DoExecute;
    //����
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
      Sleep(500);
    end;
  end; 
end;

procedure TPoundTunnelConnector.DoExecute;
var nIdx: Integer;
    nTunnel: PPTTunnelItem;
begin
  FActiveTunnel := nil;
  //init

  with FOwner do
  try
    FSyncLock.Enter;
    try
      for nIdx:=FTunnels.Count - 1 downto 0 do
      begin
        nTunnel := FTunnels[nIdx];
        if nTunnel.FEnable and (not nTunnel.FLocked) and
           (GetTickCount - nTunnel.FLastActive < cPTWait_Long) then
        //�����ݵ����ȴ���
        begin
          FActiveTunnel := nTunnel;
          FActiveTunnel.FLocked := True;
          Break;
        end;
      end;

      if not Assigned(FActiveTunnel) then
      begin
        nIdx := 0;
        //init

        while True do
        begin
          if FTunnelIndex >= FTunnels.Count then
          begin
            FTunnelIndex := 0;
            Inc(nIdx);

            if nIdx > 1 then Break;
            //ɨ��һ��,��Ч�˳�
          end;

          nTunnel := FTunnels[FTunnelIndex];
          Inc(FTunnelIndex);
          if nTunnel.FLocked or (not nTunnel.FEnable) then Continue;

          FActiveTunnel := nTunnel;
          FActiveTunnel.FLocked := True;
          Break;
        end;
      end;
    finally
      FSyncLock.Leave;
    end;

    if Assigned(FActiveTunnel) and (not Terminated) then
    try
      if ReadPound(FActiveTunnel) then
      begin
        FWaiter.Interval := cPTWait_Short;
        FActiveTunnel.FLastActive := GetTickCount;
      end else
      begin
        if (FActiveTunnel.FLastActive > 0) and
           (GetTickCount - FActiveTunnel.FLastActive >= 3 * 1000) then
        begin
          FActiveTunnel.FLastActive := 0;
          FWaiter.Interval := cPTWait_Long;
        end;
      end;
    except
      FClient.Disconnect;      
      if Assigned(FClient.IOHandler) then
        FClient.IOHandler.InputBuffer.Clear;
      raise;
    end;
  finally
    if Assigned(FActiveTunnel) then
      FActiveTunnel.FLocked := False;
    //unlock
  end;
end;

function TPoundTunnelConnector.ReadPound(const nTunnel: PPTTunnelItem): Boolean;
begin

end;

initialization
  gPoundTunnelManager := nil;
finalization
  FreeAndNil(gPoundTunnelManager);
end.
