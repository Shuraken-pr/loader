library AnalyticDashboard;

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Winapi.Windows,
  Vcl.Forms,
  dxCore,
  intf_dll in '..\..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\..\Common\intf_dll_manager.pas',
  intf_common in '..\..\..\Common\intf_common.pas',
  frxDevDSIntf in '..\..\..\Common\frxDevDSIntf.pas',
  cxVirtualTreeListHelper in '..\..\..\Common\cxVirtualTreeListHelper.pas',
  dmSkins in '..\..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  intf_skin in '..\..\..\Common\intf_skin.pas',
  uSkinHelper in '..\..\..\Common\uSkinHelper.pas',
  FireDAC.Moni.Custom.Logger in '..\..\..\Common\FireDAC.Moni.Custom.Logger.pas',
  FDMoniCustomLoggerHelper in '..\..\..\Common\FDMoniCustomLoggerHelper.pas',
  uDBConnectionSettings in '..\..\..\Common\uDBConnectionSettings.pas',
  uMultiDBSettingsForm in '..\..\..\Common\uMultiDBSettingsForm.pas' {frmMultiDBSettings},
  main in 'main.pas' {frmMain},
  RealTimePoller in 'RealTimePoller.pas',
  uConnectionSemaphore in 'uConnectionSemaphore.pas',
  VirtualDataCache in 'VirtualDataCache.pas';

{$R *.res}

type
  TAnalyticDashboard = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, ISkinAware, IAnalyticDashboard)
  private
    FDllManager: IDllManager;
    FSkin: TdmSkin;
    FSkinName: WideString;
    FNativeStyle: boolean;
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


{ TAnalyticDashboard }

procedure TAnalyticDashboard.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

constructor TAnalyticDashboard.Create;
begin
  inherited Create;
  FSkin := TdmSkin.Create(nil);
  dxInitialize;
end;

destructor TAnalyticDashboard.Destroy;
begin
  FreeAndNil(FSkin);
  inherited;
  dxFinalize;
end;

procedure TAnalyticDashboard.Fin;
begin

end;

function TAnalyticDashboard.GetDescription: WideString;
begin
  Result := 'Analytics Dashboard';
end;

procedure TAnalyticDashboard.Init;
begin

end;

procedure TAnalyticDashboard.Run(ACallbackProc: TProc<WideString>;
  MainAppHandle: HWnd);
var
  AMsg: WideString;
  OldHandle: HWnd;
begin
  AMsg := '';
  OldHandle := Application.Handle;
  try
    if Assigned(FDllManager) then
      FDllManager.Load(DIFrxDevDS, False);
    TfrmMain.RunForm(ACallbackProc, AMsg, FSkinName, FNativeStyle, FDllManager);
  finally
    Application.Handle := OldHandle;
  end;
end;

procedure TAnalyticDashboard.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

function InitAnalyticDashboard: IDLLIntf;
begin
  Result := TAnalyticDashboard.Create;
end;

exports InitAnalyticDashboard;

begin
end.
