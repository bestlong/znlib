{*******************************************************************************
  ����: dmzn@163.com 2011-11-14
  ����: �м������ͨ��������
*******************************************************************************}
unit UMgrChannel;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, uROClient, uROWinInetHttpChannel,
  uROBinMessage;

type
  PChannelItem = ^TChannelItem;
  TChannelItem = record
    FUsed: Boolean;                //�Ƿ�ռ��
    FType: Integer;                //ͨ������
    FChannel: IUnknown;            //ͨ������

    FMsg: TROBinMessage;           //��Ϣ����
    FHttp: TROWinInetHTTPChannel;  //ͨ������
  end;

  TChannelArray = array of TChannelItem;
  //ͨ����

  TChannelManager = class(TObject)
  private
    FChannels: TChannelArray;
    //ͨ���б�
    FMaxCount: Integer;
    //ͨ����ֵ
    FLock: TCriticalSection;
    //ͬ����
    FClearing: Boolean;
    //��������
  protected
    function GetCount: Integer;
    procedure SetChannelMax(const nValue: Integer);
    //���Դ���
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    function LockChannel(const nType: Integer = -1): PChannelItem;
    procedure ReleaseChannel(const nChannel: PChannelItem);
    //ͨ������
    procedure ClearChannel;
    //����ͨ��
    property ChannelCount: Integer read GetCount;
    property ChannelMax: Integer read FMaxCount write SetChannelMax;
    //�������
  end;

var
  gChannelManager: TChannelManager = nil;
  //ȫ��ʹ��

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

//Desc: ����ͨ������
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

//Desc: ͨ������
function TChannelManager.GetCount: Integer;
begin
  FLock.Enter;
  Result := Length(FChannels);
  FLock.Leave;
end;

//Desc: ���ͨ����
procedure TChannelManager.SetChannelMax(const nValue: Integer);
begin
  FLock.Enter;
  FMaxCount := nValue;
  FLock.Leave;
end;

//Desc: ����ͨ��
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
      //��һ������ͨ��

      if nType < 0 then
        Break;
      //�����ͨ������
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

//Desc: �ͷ�ͨ��
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
