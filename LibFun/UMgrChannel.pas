{*******************************************************************************
  作者: dmzn@163.com 2011-11-14
  描述: 中间件数据通道管理器
*******************************************************************************}
unit UMgrChannel;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, uROClient, uROWinInetHttpChannel,
  uROBinMessage;

type
  PChannelItem = ^TChannelItem;
  TChannelItem = record
    FUsed: Boolean;                //是否占用
    FType: Integer;                //通道类型
    FChannel: IUnknown;            //通道对象

    FMsg: TROBinMessage;           //消息对象
    FHttp: TROWinInetHTTPChannel;  //通道对象
  end;

  TChannelArray = array of TChannelItem;
  //通道组

  TChannelManager = class(TObject)
  private
    FChannels: TChannelArray;
    //通道列表
    FMaxCount: Integer;
    //通道峰值
    FLock: TCriticalSection;
    //同步锁
    FClearing: Boolean;
    //正在清理
  protected
    function GetCount: Integer;
    procedure SetChannelMax(const nValue: Integer);
    //属性处理
  public
    constructor Create;
    destructor Destroy; override;
    //创建释放
    function LockChannel(const nType: Integer = -1): PChannelItem;
    procedure ReleaseChannel(const nChannel: PChannelItem);
    //通道处理
    procedure ClearChannel;
    //清理通道
    property ChannelCount: Integer read GetCount;
    property ChannelMax: Integer read FMaxCount write SetChannelMax;
    //属性相关
  end;

var
  gChannelManager: TChannelManager = nil;
  //全局使用

implementation

constructor TChannelManager.Create;
begin
  FMaxCount := 5;
  FClearing := False;
  FLock := TCriticalSection.Create;
end;

destructor TChannelManager.Destroy;
begin
  ClearChannel;
  FLock.Free;
  inherited;
end;

//Desc: 清理通道对象
procedure TChannelManager.ClearChannel;
var nIdx: Integer;
begin
  FLock.Enter;
  try
    FClearing := True;

    for nIdx:=Low(FChannels) to High(FChannels) do
    with FChannels[nIdx] do
    begin
      if FUsed then
      try
        FLock.Leave;

        while FUsed do Sleep(1);
      finally
        FLock.Enter;
      end;  

      if Assigned(FHttp) then FreeAndNil(FHttp);
      if Assigned(FMsg) then FreeAndNil(FMsg);  
      if Assigned(FChannel) then FChannel := nil;
    end;

    SetLength(FChannels, 0);
  finally
    FClearing := False;
    FLock.Leave;
  end;
end;

//Desc: 通道数量
function TChannelManager.GetCount: Integer;
begin
  FLock.Enter;
  Result := Length(FChannels);
  FLock.Leave;
end;

//Desc: 最大通道数
procedure TChannelManager.SetChannelMax(const nValue: Integer);
begin
  FLock.Enter;
  FMaxCount := nValue;
  FLock.Leave;
end;

//Desc: 锁定通道
function TChannelManager.LockChannel(const nType: Integer): PChannelItem;
var nIdx,nFit: Integer;
begin
  Result := nil;
  FLock.Enter;
  try
    if FClearing then Exit;
    nFit := -1;

    for nIdx:=Low(FChannels) to High(FChannels) do
    with FChannels[nIdx] do
    begin
      if FUsed then Continue;

      if (nType > -1) and (FType = nType) then
      begin
        Result := @FChannels[nIdx];
        Exit;
      end;

      if nFit < 0 then
        nFit := nIdx;
      //第一个空闲通道

      if nType < 0 then
        Break;
      //不检查通道类型
    end;

    nIdx := Length(FChannels);
    if nIdx < FMaxCount then
    begin
      SetLength(FChannels, nIdx + 1);
      with FChannels[nIdx] do
      begin
        FType := nType;
        FChannel := nil;

        FMsg := TROBinMessage.Create;
        FHttp := TROWinInetHTTPChannel.Create(nil);
      end;

      Result := @FChannels[nIdx];
      Exit;
    end;

    if nFit > -1 then
    begin
      Result := @FChannels[nFit];
      Result.FType := nType;
      Result.FChannel := nil;
    end;
  finally
    if Assigned(Result) then
      Result.FUsed := True;
    FLock.Leave;
  end;
end;

//Desc: 释放通道
procedure TChannelManager.ReleaseChannel(const nChannel: PChannelItem);
begin
  if Assigned(nChannel) then
  begin
    FLock.Enter;
    try
      nChannel.FUsed := False;
    finally
      FLock.Leave;
    end;
  end;
end;

initialization
  gChannelManager := TChannelManager.Create;
finalization
  FreeAndNil(gChannelManager);
end.
