library LogData;
{$R 'mssql.res' '..\SQL\mssql.rc'}
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
  frxDevDSIntf in '..\..\Common\frxDevDSIntf.pas',
  uDMConn in 'uDMConn.pas' {dmConn: TDataModule},
  uLogData in 'uLogData.pas' {frmLogData},
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  dmSkins in '..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  intf_skin in '..\..\Common\intf_skin.pas',
  FireDAC.Moni.Custom.Logger in '..\..\..\Common\FireDAC.Moni.Custom.Logger.pas',
  FDMoniCustomLoggerHelper in '..\..\..\Common\FDMoniCustomLoggerHelper.pas',
  uSkinHelper in '..\..\Common\uSkinHelper.pas',
  uDBConnectionSettings in '..\..\..\Common\uDBConnectionSettings.pas',
  uMultiDBSettingsForm in '..\..\..\Common\uMultiDBSettingsForm.pas' {frmMultiDBSettings};

{$R *.res}

type
  TLogDataImpl = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, ILogData, ISkinAware)
  private
    FDM: TdmConn;
    FSkin: TdmSkin;
    FSkinName: WideString;
    FNativeStyle: boolean;
    FIntfFR: IFrxDevDS;
    FDllManager: IDllManager;
  public
    constructor Create;
    destructor Destroy; override;

    // IDLLIntf
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean = False); safecall;

    // IDllIntfRun
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;

    // IUsesDllManager
    procedure SetDllManager(AMgr: IDllManager); safecall;
  end;

{ TLogDataImpl }

procedure TLogDataImpl.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

constructor TLogDataImpl.Create;
begin
  inherited Create;
  dxInitialize;
  FSkin := TdmSkin.Create(nil);
  FDM := TdmConn.Create(nil);
  FIntfFR := nil;
end;

destructor TLogDataImpl.Destroy;
begin
  if Assigned(FSkin) then
    FreeAndNil(FSkin);
  FIntfFR := nil;
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
  intf: IInterface;
begin
  // Загружаем IFrxDevDS
  if Assigned(FDllManager) and not Assigned(FIntfFR) then
  begin
    if not FDllManager.IsLoaded('IFrxDevDS') then
      FDllManager.Load(DIFrxDevDS, False);
    if FDllManager.IsLoaded('IFrxDevDS') then
    begin
      intf := FDllManager.GetIntf(IFrxDevDS);
      if Assigned(intf) and Supports(intf, IFrxDevDS, FIntfFR) then
      begin
        FIntfFR.Init;
      end;
    end;
  end;

  AMsg := '';
  OldHandle := Application.Handle;
  try
    Application.Handle := MainAppHandle;

    if FDM.Connect(AMsg) then
    begin
      ACallbackProc('Соединение успешно установлено');
      TfrmLogData.RunForm(FDM, ACallbackProc, AMsg, FSkinName, FNativeStyle, FIntfFR);
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
