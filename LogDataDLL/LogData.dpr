library LogData;
{$R 'MSSQL.res' '..\SQL\mssql.rc'}
{$R 'Oracle.res' '..\SQL\Oracle.rc'}
{$R 'Postgre.res' '..\SQL\Postgre.rc'}

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Winapi.Windows,
  Vcl.Forms,
  dxCore,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\Common\intf_common.pas',
  intf_dll_manager in '..\..\Common\intf_dll_manager.pas',
  uConnectionParams in 'uConnectionParams.pas' {frmConnections},
  uDMConn in 'uDMConn.pas' {dmConn: TDataModule},
  uLogData in 'uLogData.pas' {frmLogData};

{$R *.res}

type
  TLogDataImpl = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, ILogData)
  private
    FDM: TdmConn;
    FDllManager: IDllManager;
  public
    constructor Create;
    destructor Destroy; override;

    // IDLLIntf
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;

    // IDllIntfRun
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;

    // IUsesDllManager
    procedure SetDllManager(AMgr: IDllManager); safecall;
  end;

{ TLogDataImpl }

constructor TLogDataImpl.Create;
begin
  inherited Create;
  dxInitialize;
  FDM := TdmConn.Create(nil);
end;

destructor TLogDataImpl.Destroy;
begin
  FreeAndNil(FDM);
  dxFinalize;
  inherited;
end;

function TLogDataImpl.GetDescription: WideString;
begin
  Result := 'Логгирование БД';
end;

procedure TLogDataImpl.Init;
begin
//
end;

procedure TLogDataImpl.Fin;
begin
  //
end;

procedure TLogDataImpl.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

procedure TLogDataImpl.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
var
  AMsg: WideString;
  OldHandle: HWnd;
begin
  AMsg := '';
  OldHandle := Application.Handle;
  try
    Application.Handle := MainAppHandle;

    if TfrmConnections.RunForm(FDM, AMsg) then
    begin
      ACallbackProc('Соединение успешно установлено');
      TfrmLogData.RunForm(FDM, ACallbackProc, AMsg);
    end
    else
    begin
      if AMsg <> '' then
        ACallbackProc('Ошибка подключения: ' + AMsg);
    end;
  finally
    Application.Handle := OldHandle;
  end;
end;

function InitLogData: IDllIntfRun;
begin
  Result := TLogDataImpl.Create;
end;

exports
  InitLogData;

begin
end.
