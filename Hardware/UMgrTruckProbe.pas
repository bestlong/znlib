{*******************************************************************************
  作者：dmzn@163.com 2014-5-28
  描述：车辆检测控制器通讯单元
*******************************************************************************}
unit UMgrTruckProbe;

{.$DEFINE DEBUG}
interface

uses
  Windows, Classes, SysUtils, SyncObjs, IdTCPConnection, IdTCPClient, IdGlobal,
  NativeXml, UWaitItem, USysLoger, ULibFun;

const
  cProber_NullASCII           = $30;       //ASCII空字节
  cProber_Flag_Begin          = $F0;       //开始标识
  
  cProber_Frame_QueryIO       = $10;       //状态查询(in out)
  cProber_Frame_RelaysOC      = $20;       //通道开合(open close)
  cProber_Frame_DataForward   = $30;       //485数据转发
  cProber_Frame_IP            = $50;       //设置IP
  cProber_Frame_MAC           = $60;       //设置MAC

  cProber_Query_All           = $00;       //查询全部
  cProber_Query_In            = $01;       //查询输入
  cProber_Query_Out           = $02;       //查询输出
  cProber_Query_Interval      = 2000;      //查询间隔

  cProber_Len_Frame           = $14;       //普通帧长
  cProber_Len_FrameData       = 16;        //普通定长数据
  cProber_Len_485Data         = 100;       //485转发数据
    
type
  TProberIOAddress = array[0..7] of Byte;
  //in-out address

  TProberFrameData = array [0..cProber_Len_FrameData - 1] of Byte;
  TProber485Data   = array [0..cProber_Len_485Data - 1] of Byte;

  PProberFrameHeader = ^TProberFrameHeader;
  TProberFrameHeader = record
    FBegin  : Byte;                //起始帧
    FLength : Byte;                //帧长度
    FType   : Byte;                //帧类型
    FExtend : Byte;                //帧扩展
  end;

  PProberFrameControl = ^TProberFrameControl;
  TProberFrameControl = record
    FHeader : TProberFrameHeader;   //帧头
    FData   : TProberFrameData;     //数据
    FVerify : Byte;                //校验位
  end;

  PProberFrameDataForward = ^TProberFrameDataForward;
  TProberFrameDataForward = record
    FHeader : TProberFrameHeader;   //帧头
    FData   : TProber485Data;       //数据
    FVerify : Byte;                //校验位
  end;  

  PProberHost = ^TProberHost;
  TProberHost = record
    FID      : string;               //标识
    FName    : string;               //名称
    FHost    : string;               //IP
    FPort    : Integer;              //端口
    FStatusI : TProberIOAddress;     //输入状态
    FStatusO : TProberIOAddress;     //输出状态
    FStatusL : Int64;                //状态时间
    FEnable  : Boolean;              //是否启用
  end;  

  PProberTunnel = ^TProberTunnel;
  TProberTunnel = record
    FID      : string;               //标识
    FName    : string;               //名称
    FHost    : PProberHost;          //所在主机
    FIn      : TProberIOAddress;     //输入地址
    FOut     : TProberIOAddress;     //输出地址
    FEnable  : Boolean;              //是否启用
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
    //拥有者
    FBuffer: TList;
    //待发送数据
    FWaiter: TWaitObject;
    //等待对象
    FClient: TIdTCPClient;
    //客户端
    FQueryFrame: TProberFrameControl;
    //状态查询
  protected
    procedure DoExecute(const nHost: PProberHost);
    procedure Execute; override;
    //执行线程
    procedure DisconnectClient;
    function SendData(const nHost: PProberHost; var nData: TIdBytes;
      const nRecvLen: Integer): string;
    //发送数据
  public
    constructor Create(AOwner: TProberManager);
    destructor Destroy; override;
    //创建释放
    procedure Wakeup;
    procedure StopMe;
    //启停通道
  end;

  TProberManager = class(TObject)
  private
    FRetry: Byte;
    //重试次数
    FInSignalOn: Byte;
    FInSignalOff: Byte;
    FOutSignalOn: Byte;
    FOutSignalOff: Byte;
    //输入输出信号
    FCommand: TList;
    //命令列表
    FHosts: TProberHosts;
    FTunnels: TProberTunnels;
    //通道列表
    FReader: TProberThread;
    //连接对象
    FSyncLock: TCriticalSection;
    //同步锁定
  protected
    procedure ClearList(const nList: TList);
    //清理数据
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure StartProber;
    procedure StopProber;
    //启停检测器
    procedure LoadConfig(const nFile: string);
    //读取配置
    function OpenTunnel(const nTunnel: string): Boolean;
    function CloseTunnel(const nTunnel: string): Boolean;
    function TunnelOC(const nTunnel: string; nOC: Boolean): string;
    //开合通道
    function GetTunnel(const nTunnel: string): PProberTunnel;
    procedure EnableTunnel(const nTunnel: string; const nEnabled: Boolean);
    function QueryStatus(const nHost: PProberHost;
      var nIn,nOut: TProberIOAddress): string;
    function IsTunnelOK(const nTunnel: string): Boolean;
    //查询状态
    property Hosts: TProberHosts read FHosts;
    property RetryOnError: Byte read FRetry write FRetry;
    //属性相关
  end;

var
  gProberManager: TProberManager = nil;
  //全局使用

function ProberVerifyData(var nData: TIdBytes; const nDataLen: Integer;
  const nLast: Boolean): Byte;
procedure ProberStr2Data(const nStr: string; var nData: TProberFrameData);
//入口函数

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TProberManager, '车辆检测控制', nEvent);
end;

//Desc: 对nData做异或校验
function ProberVerifyData(var nData: TIdBytes; const nDataLen: Integer;
  const nLast: Boolean): Byte;
var nIdx,nLen: Integer;
begin
  Result := 0;
  if nDataLen < 1 then Exit;

  nLen := nDataLen - 2;
  //末位不参与计算
  Result := nData[0];

  for nIdx:=1 to nLen do
    Result := Result xor nData[nIdx];
  //xxxxx

  if nLast then
    nData[nDataLen - 1] := Result;
  //附加到末尾
end;

//Date: 2014-05-30
//Parm: 字符串;数据
//Desc: 将nStr填充到nData中
procedure ProberStr2Data(const nStr: string; var nData: TProberFrameData);
var nIdx,nLen: Integer;
begin
  nLen := Length(nStr);
  if nLen > cProber_Len_FrameData then
    nLen := cProber_Len_FrameData;
  //长度矫正

  for nIdx:=1 to nLen do
    nData[nIdx-1] := Ord(nStr[nIdx]);
  //xxxxx
end;

//Date: 2012-4-13
//Parm: 字符
//Desc: 获取nTxt的内码
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

//Date：2014-5-13
//Parm：地址结构;地址字符串,类似: 1,2,3
//Desc：将nStr拆开,放入nAddr结构中
procedure SplitAddr(var nAddr: TProberIOAddress; const nStr: string);
var nIdx: Integer;
    nList: TStrings;
begin
  nList := TStringList.Create;
  try
    SplitStr(nStr, nList, 0 , ',');
    //拆分
    
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

//Desc: 清理数据
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

//Desc: 启动
procedure TProberManager.StartProber;
begin
  if not Assigned(FReader) then
    FReader := TProberThread.Create(Self);
  FReader.Wakeup;
end;

//Desc: 停止
procedure TProberManager.StopProber;
begin
  if Assigned(FReader) then
    FReader.StopMe;
  FReader := nil;
end;

//Desc: 载入nFile配置文件
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
        //最后一次查询状态时间,超时系统会不认可当前状态
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
//Date：2014-5-14
//Parm：通道号
//Desc：获取nTunnel的通道数据
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

//Date：2014-5-13
//Parm：通道号;True=Open,False=Close
//Desc：对nTunnel执行开合操作,若有错误则返回
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
    Result := '通道[ %s ]编号无效.';
    Result := Format(Result, [nTunnel]); Exit;
  end;

  if not (nPTunnel.FEnable and nPTunnel.FHost.FEnable ) then Exit;
  //不启用,不发送

  i := 0;
  for nIdx:=Low(nPTunnel.FOut) to High(nPTunnel.FOut) do
    if nPTunnel.FOut[nIdx] <> cProber_NullASCII then Inc(i);
  //xxxxx

  if i < 1 then Exit;
  //无输出地址,表示不使用输出控制

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

//Date：2014-5-13
//Parm：通道号
//Desc：对nTunnel执行吸合操作
function TProberManager.OpenTunnel(const nTunnel: string): Boolean;
var nStr: string;
begin
  nStr := TunnelOC(nTunnel, False);
  Result := nStr = '';

  if not Result then
    WriteLog(nStr);
  //xxxxxx
end;

//Date：2014-5-13
//Parm：通道号
//Desc：对nTunnel执行断开操作
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
//Parm: 通道号;启用
//Desc: 是否启用nTunnel通道
procedure TProberManager.EnableTunnel(const nTunnel: string;
  const nEnabled: Boolean);
var nPT: PProberTunnel;
begin
  nPT := GetTunnel(nTunnel);
  if Assigned(nPT) then
    nPT.FEnable := nEnabled;
  //xxxxx
end;

//Date：2014-5-14
//Parm：主机;查询类型;输入输出结果
//Desc：查询nHost的输入输出状态,存入nIn nOut.
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
      Result := Format('车辆检测器[ %s ]状态查询超时.', [nHost.FName]);
      Exit;
    end;

    nIn := FHosts[nIdx].FStatusI;
    nOut := FHosts[nIdx].FStatusO;
    Result := ''; Exit;
  end;

  Result := Format('车辆检测器[ %s ]已无效.', [nHost.FID]);
end;

//Date：2014-5-14
//Parm：通道号
//Desc：查询nTunnel的输入是否全部为无信号
function TProberManager.IsTunnelOK(const nTunnel: string): Boolean;
var nIdx,nNum: Integer;
    nPT: PProberTunnel;
begin
  Result := False;
  nPT := GetTunnel(nTunnel);

  if not Assigned(nPT) then
  begin
    WriteLog(Format('通道[ %s ]无效.',  [nTunnel]));
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

  if nNum < 1 then //无输入地址,标识不使用输入监测
  begin
    Result := True;
    Exit;
  end;

  if GetTickCount - nPT.FHost.FStatusL >= 2 * cProber_Query_Interval then
  begin
    WriteLog(Format('车辆检测器[ %s ]状态查询超时.', [nPT.FHost.FName]));
    Exit;
  end;

  for nIdx:=Low(nPT.FIn) to High(nPT.FIn) do
  begin
    if nPT.FIn[nIdx] = cProber_NullASCII then Continue;
    //invalid addr

    if nPT.FHost.FStatusI[nPT.FIn[nIdx] - 1] = FInSignalOn then Exit;
    //某路输入有信号,认为车辆未停妥
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
    WriteLog(Format('连接[ %s.%d ]失败.', [FClient.Host, FClient.Port]));
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
  //查询状态

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
    //更新时间
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

//Desc: 断开客户端套接字
procedure TProberThread.DisconnectClient;
begin
  FClient.Disconnect;
  if Assigned(FClient.IOHandler) then
    FClient.IOHandler.InputBuffer.Clear;
  //try to swtich connection
end;

//Date：2014-5-13
//Parm：主机;发送数据[in],应答数据[out];待接收长度
//Desc：向nHost发送nData数据,并接收应答
function TProberThread.SendData(const nHost: PProberHost; var nData: TIdBytes;
  const nRecvLen: Integer): string;
var nBuf: TIdBytes;
    nIdx,nLen: Integer;
begin
  Result := '';
  try
    nLen := Length(nData);
    ProberVerifyData(nData, nLen, True);
    //添加异或校验

    SetLength(nBuf, nLen);
    CopyTIdBytes(nData, 0, nBuf, 0, nLen);
    //备份待发送内容

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
      //校验通过

      if nIdx = FOwner.FRetry then
      begin
        Result := '未从[ %s:%s.%d ]收到能通过校验的应答数据.';
        Result := Format(Result, [nHost.FName, nHost.FHost, nHost.FPort]);
      end;
    except
      on E: Exception do
      begin
        DisconnectClient;
        //断开重连

        Inc(nIdx);
        if nIdx < FOwner.FRetry then
             Sleep(100)
        else raise;
      end;
    end;
  except
    on E: Exception do
    begin
      Result := '向[ %s:%s:%d ]发送数据失败,描述: %s';
      Result := Format(Result, [nHost.FName, nHost.FHost, nHost.FPort, E.Message]);
    end;
  end;
end;

initialization
  gProberManager := nil;
finalization
  FreeAndNil(gProberManager);
end.
