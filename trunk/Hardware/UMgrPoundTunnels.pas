{*******************************************************************************
  作者: dmzn@163.com 2014-06-11
  描述: 磅站通道管理器
*******************************************************************************}
unit UMgrPoundTunnels;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, CPort, CPortTypes, IdComponent,
  IdTCPConnection, IdTCPClient, IdGlobal, IdSocketHandle, NativeXml, ULibFun,
  UWaitItem, USysLoger;

const
  cPTMaxCameraTunnel = 5;
  //支持的摄像机通道数

  cPTWait_Short = 50;
  cPTWait_Long  = 2 * 1000; //网络通讯时刷新频度

type
  TOnTunnelDataEvent = procedure (const nValue: Double) of object;
  //事件定义

  TPoundTunnelManager = class;
  TPoundTunnelConnector = class;

  PPTPortItem = ^TPTPortItem;
  PPTCameraItem = ^TPTCameraItem;
  PPTTunnelItem = ^TPTTunnelItem;
  
  TPTTunnelItem = record
    FID: string;                     //标识
    FName: string;                   //名称
    FPort: PPTPortItem;              //通讯端口
    FProber: string;                 //控制器
    FReader: string;                 //磁卡读头
    FUserInput: Boolean;             //手工输入

    FFactoryID: string;              //工厂标识
    FCardInterval: Integer;          //读卡间隔
    FSampleNum: Integer;             //采样个数
    FSampleFloat: Integer;           //采样浮动

    FCamera: PPTCameraItem;          //摄像机
    FCameraTunnels: array[0..cPTMaxCameraTunnel-1] of Byte;
                                     //摄像通道                                     
    FOnData: TOnTunnelDataEvent;     //接收事件
    FOldEventTunnel: PPTTunnelItem;  //原接收通道

    FEnable: Boolean;                //是否启用
    FLocked : Boolean;               //是否锁定
    FLastActive: Int64;              //上次活动
  end;

  TPTCameraItem = record
    FID: string;                     //标识
    FHost: string;                   //主机地址
    FPort: Integer;                  //端口
    FUser: string;                   //用户名
    FPwd: string;                    //密码
    FPicSize: Integer;               //图像大小
    FPicQuality: Integer;            //图像质量
  end;

  TPTConnType = (ctTCP, ctCOM);
  //链路类型: 网络,串口
         
  TPTPortItem = record
    FID: string;                     //标识
    FName: string;                   //名称
    FType: string;                   //类型
    FConn: TPTConnType;              //链路
    FPort: string;                   //端口
    FRate: TBaudRate;                //波特率
    FDatabit: TDataBits;             //数据位
    FStopbit: TStopBits;             //起停位
    FParitybit: TParityBits;         //校验位
    FParityCheck: Boolean;           //启用校验
    FCharBegin: Char;                //起始标记
    FCharEnd: Char;                  //结束标记
    FPackLen: Integer;               //数据包长
    FSplitTag: string;               //分段标识
    FSplitPos: Integer;              //有效段
    FInvalidBegin: Integer;          //截首长度
    FInvalidEnd: Integer;            //截尾长度
    FDataMirror: Boolean;            //镜像数据
    FDataEnlarge: Single;            //放大倍数

    FHostIP: string;
    FHostPort: Integer;              //网络链路

    FCOMPort: TComPort;              //读写对象
    FCOMBuff: string;                //通讯缓冲
    FCOMData: string;                //通讯数据
    FEventTunnel: PPTTunnelItem;     //接收通道
  end;

  TPoundTunnelConnector = class(TThread)
  private
    FOwner: TPoundTunnelManager;
    //拥有者
    FActiveTunnel: PPTTunnelItem;
    //当前通道
    FWaiter: TWaitObject;
    //等待对象
    FClient: TIdTCPClient;
    //网络对象
  protected
    procedure DoExecute;
    procedure Execute; override;
    //执行线程
    function ReadPound(const nTunnel: PPTTunnelItem): Boolean;
    //读取数据
  public
    constructor Create(AOwner: TPoundTunnelManager);
    destructor Destroy; override;
    //创建释放
    procedure WakupMe;
    //唤醒线程
    procedure StopMe;
    //停止线程
  end;

  TPoundTunnelManager = class(TObject)
  private
    FPorts: TList;
    //端口列表
    FCameras: TList;
    //摄像机
    FTunnelIndex: Integer;
    FTunnels: TList;
    //通道列表
    FStrList: TStrings;
    //字符列表
    FSyncLock: TCriticalSection;
    //同步锁定
  protected
    procedure ClearList(const nFree: Boolean);
    //清理资源
    function ParseWeight(const nPort: PPTPortItem): Boolean;
    procedure OnComData(Sender: TObject; Count: Integer);
    //读取数据
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    procedure LoadConfig(const nFile: string);
    //读取配置
    procedure ActivePort(const nTunnel: string; nEvent: TOnTunnelDataEvent;
      const nOpenPort: Boolean = False);
    procedure ClosePort(const nTunnel: string);
    //起停端口
    function GetPort(const nID: string): PPTPortItem;
    function GetCamera(const nID: string): PPTCameraItem;
    function GetTunnel(const nID: string): PPTTunnelItem;
    //检索数据
    property Tunnels: TList read FTunnels;
    //属性相关
  end;

var
  gPoundTunnelManager: TPoundTunnelManager = nil;
  //全局使用

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TPoundTunnelManager, '磅站通道管理', nEvent);
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
//Parm: 是否释放
//Desc: 清理列表资源
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

//Date：2014-6-18
//Parm：通道;地址字符串,类似: 1,2,3
//Desc：将nStr拆开,放入nTunnel.FCameraTunnels结构中
procedure SplitCameraTunnel(const nTunnel: PPTTunnelItem; const nStr: string);
var nIdx: Integer;
    nList: TStrings;
begin
  nList := TStringList.Create;
  try
    for nIdx:=Low(nTunnel.FCameraTunnels) to High(nTunnel.FCameraTunnels) do
      nTunnel.FCameraTunnels[nIdx] := MAXBYTE;
    //默认值

    SplitStr(nStr, nList, 0 , ',');
    if nList.Count < 1 then Exit;

    nIdx := nList.Count - 1;
    if nIdx > High(nTunnel.FCameraTunnels) then
      nIdx := High(nTunnel.FCameraTunnels);
    //检查边界

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
//Parm: 配置文件
//Desc: 载入nFile配置
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
      if Assigned(nTmp) then //直接指定截取长度
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
      //默认不启用
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
        raise Exception.Create(Format('通道[ %s.Port ]无效.', [nTunnel.FName]));
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
//Desc: 检索标识为nID的端口
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

//Desc: 检索标识为nID的摄像机
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

//Desc: 检索标识为nID的通道
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
//Parm: 通道号;接收事件
//Desc: 开启nTunnel通道读写端口
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
      //开启端口
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
//Parm: 通道号
//Desc: 关闭nTunnel通道读写端口
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
      //还原接收通道

      if Assigned(nPT.FPort.FCOMPort) then
        nPT.FPort.FCOMPort.Close;
      //通道空闲则关闭
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2014-06-11
//Desc: 读取数据
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
    //无接收事件

    nPort.FCOMData := nPort.FCOMData + nPort.FCOMBuff;
    if Length(nPort.FCOMData) < nPort.FPackLen then Exit;
    //数据不够整包长度

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
    WriteLog('无效数据过多,已裁剪.')
  end;
end;

//Date: 2014-06-12
//Parm: 端口
//Desc: 解析nPort上的称重数据
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
    //无数据结束标记,或不是开始标记

    nPort.FCOMData := Copy(nPort.FCOMData, nIdx + 1, nEnd - nIdx - 1);
    //待处理表头包数据

    if nPort.FSplitPos > 0 then
    begin
      SplitStr(nPort.FCOMData, FStrList, 0, nPort.FSplitTag);
      //拆分数据

      for nPos:=FStrList.Count - 1 downto 0 do
      begin
        FStrList[nPos] := Trim(FStrList[nPos]);
        if FStrList[nPos] = '' then FStrList.Delete(nPos);
      end; //整理数据

      if FStrList.Count < nPort.FSplitPos then
      begin
        nPort.FCOMData := '';
        Exit;
      end; //分段索引越界

      nPort.FCOMData := FStrList[nPort.FSplitPos - 1];
      //有效数据
    end;

    if nPort.FInvalidBegin > 0 then
      System.Delete(nPort.FCOMData, 1, nPort.FInvalidBegin);
    //首部无效数据

    if nPort.FInvalidEnd > 0 then
      System.Delete(nPort.FCOMData, Length(nPort.FCOMData)-nPort.FInvalidEnd+1,
                    nPort.FInvalidEnd);
    //尾部无效数据

    if nPort.FDataMirror then
      nPort.FCOMData := MirrorStr(nPort.FCOMData);
    //数据反转

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
    //读磅
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
        //有数据的优先处理
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
            //扫描一轮,无效退出
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
