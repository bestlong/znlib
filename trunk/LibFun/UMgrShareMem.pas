{*******************************************************************************
  ����: dmzn@163.com 2012-2-20
  ����: ϵͳ�����ڴ�,���ڿ����ͨѶ

  ��ע:
  *.�����ڴ������ʹ����ͬMemNameӳ����ͬ�ڴ�ռ�.
  *.Ϊ��ͬ����д,ʹ����ͬLockNameͬ������.
  *.LockData,UnLockData����ɶ�ʹ��,��������.
  *.ͬ���ڴ�ֵ�ԪƬ,ÿƬ��Сһ��.������������,������1��ʼ.
*******************************************************************************}
unit UMgrShareMem;

interface

uses
  Windows, Classes, SysUtils;

type
  TShareMemoryManager = class(TObject)
  private
    FMapFile: THandle;
    //ӳ���ļ�
    FFilePtr: Pointer;
    //�ļ�ָ��
    FMemName: string;
    //�ڴ��ʶ
    FPerNum: Cardinal;
    //��Ԫ����
    FPerSize: Cardinal;
    //��Ԫ��С
    FPerIndex: Cardinal;
    //��Ԫ����
    FSyncLock: THandle;
    //ͬ������
  protected
    procedure ClearAllHandle;
    //������
    procedure MemoryLock(const nLock: Boolean; nHandle: THandle = 0);
    //ͬ������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    function InitMem(const nMemName,nLockName: string; const nPerNum,
      nPerSize,nPerIndex: Cardinal; const nHost: Boolean = True): Boolean;
    //��ʼ��
    function LockData(var nBuf: Pointer; nPerIndex: Cardinal = 0): Boolean;
    procedure UnLockData;
    //��д�ڴ�
    property MemName: string read FMemName;
    property PerNum: Cardinal read FPerNum;
    property PerSize: Cardinal read FPerSize;
    property PerIndex: Cardinal read FPerIndex;
    //�������
  end;

var
  gShareMemoryManager: TShareMemoryManager = nil;
  //ȫ��ʹ��

implementation

constructor TShareMemoryManager.Create;
begin
  FMapFile := INVALID_HANDLE_VALUE;
  FFilePtr := nil;
  FSyncLock := INVALID_HANDLE_VALUE;
end;

destructor TShareMemoryManager.Destroy;
begin
  ClearAllHandle;
  inherited;
end;

//Desc: ����ϵͳ���
procedure TShareMemoryManager.ClearAllHandle;
var nLock: THandle;
begin
  try
    if FSyncLock <> INVALID_HANDLE_VALUE then
      MemoryLock(True);
    //lock memory

    if Assigned(FFilePtr) then
    begin
      UnmapViewOfFile(FFilePtr);
      FFilePtr := nil;
    end; //unmap file

    if FMapFile <> INVALID_HANDLE_VALUE then
    begin
      CloseHandle(FMapFile);
      FMapFile := INVALID_HANDLE_VALUE;
    end; //close map file

    if FSyncLock <> INVALID_HANDLE_VALUE then
    begin
      nLock := FSyncLock;
      FSyncLock := INVALID_HANDLE_VALUE;

      MemoryLock(False, nLock);
      CloseHandle(nLock);
    end; //lock free
  finally
    if FSyncLock <> INVALID_HANDLE_VALUE then
      MemoryLock(False);
    //unlock memory
  end;
end;

//Date: 2012-2-20
//Parm: �ڴ�����;ͬ������;��Ԫ��;��Ԫ��С;��Ԫ����;�Ƿ�����
//Desc: ����nMemName�Ĺ����ڴ�.���������ڴ�ռ�,������ӳ��ռ��ַ
function TShareMemoryManager.InitMem(const nMemName,nLockName: string;
  const nPerNum,nPerSize,nPerIndex: Cardinal; const nHost: Boolean): Boolean;
begin
  Result := False;
  try
    ClearAllHandle;
    FSyncLock := CreateEvent(nil, False, True, PChar(nLockName));
    if FSyncLock = 0 then Exit;

    FMemName := nMemName;
    FPerNum := nPerNum;
    FPerSize := nPerSize;
    FPerIndex := nPerIndex;

    if nHost then
    begin
      FMapFile := CreateFileMapping(
                   $FFFFFFFF,                      //�����ڴ�ӳ����
                   nil,                            //��ȫ����
                   PAGE_READWRITE or SEC_COMMIT,   //����ģʽ
                   0,                              //�ڴ��С(��λ)
                   FPerNum * FPerSize,             //�ڴ��С(��λ)
                   PChar(FMemName));               //�ڴ����Ʊ�ʶ
    end else
    begin
      FMapFile := OpenFileMapping(
                   FILE_MAP_WRITE,                 //����ģʽ
                   True,                           //
                   PChar(FMemName));               //�ڴ����Ʊ�ʶ
    end;

    if FMapFile = 0 then Exit;
    FFilePtr := MapViewOfFile(
                 FMapFile,                         //�ڴ�ӳ����
                 FILE_MAP_WRITE,                   //����ģʽ
                 0, 0,                             //ӳ����ʼλ��
                 FPerNum * FPerSize);              //ӳ���ڴ��С
    //xxxxx

    if not Assigned(FFilePtr) then Exit;
    Result := True;
  finally
    if FSyncLock = 0 then
      FSyncLock := INVALID_HANDLE_VALUE;
    //lock invalid

    if FMapFile = 0 then
      FMapFile := INVALID_HANDLE_VALUE;
    //map invalid

    if (not Result) and (FMapFile <> INVALID_HANDLE_VALUE) then
    begin
      CloseHandle(FMapFile);
      FMapFile := INVALID_HANDLE_VALUE;
    end;
  end;
end;

//Desc: �����ڴ�
procedure TShareMemoryManager.MemoryLock(const nLock: Boolean; nHandle: THandle);
begin
  if nHandle < 1 then
    nHandle := FSyncLock;
  //fix handle

  if (nHandle <> INVALID_HANDLE_VALUE) and (nHandle > 0) then
  begin
    if nLock then
         WaitForSingleObject(nHandle, INFINITE)
    else SetEvent(nHandle);
  end;
end;

//Date: 2012-2-20
//Parm: ����ָ��;��Ԫ����
//Desc: ��������ΪnPerIndex�ĵ�Ԫ��ʼλ��ָ��
function TShareMemoryManager.LockData(var nBuf: Pointer;
  nPerIndex: Cardinal): Boolean;
begin
  MemoryLock(True);
  if nPerIndex < 1 then nPerIndex := FPerIndex;
  Result := Assigned(FFilePtr) and (nPerIndex > 0) and (nPerIndex <= FPerNum);

  if Result then
    nBuf := Pointer(Cardinal(FFilePtr) + FPerSize * (nPerIndex - 1));
  //fix buffer position
end;

//Desc: �ͷ��ڴ���
procedure TShareMemoryManager.UnLockData;
begin
  MemoryLock(False);
end;

initialization
  gShareMemoryManager := TShareMemoryManager.Create;
finalization
  FreeAndNil(gShareMemoryManager);
end.
