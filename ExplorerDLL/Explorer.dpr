library Explorer;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  frxDevDSIntf in '..\..\Common\frxDevDSIntf.pas',
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uExplorer in 'uExplorer.pas' {frmScanLocalDisks},
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  dmSkins in '..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  intf_skin in '..\..\Common\intf_skin.pas',
  uSkinHelper in '..\..\Common\uSkinHelper.pas';

type
  // TExplorerDLL реализует: IDLLIntf + IDllIntfRun + IUsesDllManager + IExplorer
  // Наследование: IExplorer -> IDllIntfRunWithDeps -> (IDllIntfRun + IUsesDllManager)
  TExplorerDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, IExplorer, ISkinAware)
  private
    FE: TfrmScanLocalDisks;
    FSkin: TdmSkin;
    FFindIntf: IRunTaskFindInDir;
    FFRIntf: IFrxDevDS;
    FDllManager: IDllManager;
    procedure TryLoadDependencies;
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
    // IExplorer
    procedure initFindIntf(AIntf: IRunTaskFindInDir); safecall;
  end;

{$R *.res}

{ TExplorerDLL }

procedure TExplorerDLL.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

constructor TExplorerDLL.Create;
begin
  dxCore.dxInitialize;
  FFindIntf := nil;
  FDllManager := nil;
  FFRIntf := nil;
  FSkin := TdmSkin.Create(nil);
  FE := TfrmScanLocalDisks.Create(nil);
end;

destructor TExplorerDLL.Destroy;
begin
  if Assigned(FE) then
    FreeAndNil(FE);
  if Assigned(FSkin) then
    FreeAndNil(FSkin);
  FFindIntf := nil;
  FFRIntf := nil;
  FDllManager := nil;
  inherited;
  dxCore.dxFinalize;
end;

procedure TExplorerDLL.Fin;
begin
end;

function TExplorerDLL.GetDescription: WideString;
begin
  Result := 'Сканирование локальных дисков с фильтрацией файлов';
end;

procedure TExplorerDLL.Init;
begin
end;

procedure TExplorerDLL.initFindIntf(AIntf: IRunTaskFindInDir);
begin
  FFindIntf := AIntf;
end;

procedure TExplorerDLL.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;

  // Если FFindIntf не задан вручную — пробуем загрузить через IDllManager
  if not Assigned(FFindIntf) then
    TryLoadDependencies;

  if Assigned(FFindIntf) then
  begin
    FE.FindIntf := FFindIntf;
    if Assigned(FFRIntf) then
      FE.FRIntf := FFRIntf;
    FE.CallbackProc := ACallbackProc;
    FE.Show;
  end
    else
    ACallbackProc('Не задан IRunTaskFindInDir');
end;

procedure TExplorerDLL.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

procedure TExplorerDLL.TryLoadDependencies;
var
  intf: IInterface;
begin
  if not Assigned(FDllManager) then
    Exit;

  // Пробуем загрузить RunTaskFind.dll → IRunTaskFindInDir
  if not FDllManager.IsLoaded('IRunTaskFindInDir') then
    FDllManager.Load(DIRunTaskFindInDir, False);

  if FDllManager.IsLoaded('IRunTaskFindInDir') then
  begin
    intf := FDllManager.GetIntf(IRunTaskFindInDir);
    if Assigned(intf) and Supports(intf, IRunTaskFindInDir, FFindIntf) then
      FFindIntf.Init;
  end;

  if not FDllManager.IsLoaded('IFrxDevDS') then
    FDllManager.Load(DIFrxDevDS, False);

  if FDllManager.IsLoaded('IFrxDevDS') then
  begin
    intf := FDllManager.GetIntf(IFrxDevDS);
    if Assigned(intf) and Supports(intf, IFrxDevDS, FFRIntf) then
      FFRIntf.Init;
  end;
end;

function InitExplorer: IExplorer;
begin
  Result := TExplorerDLL.Create;
end;

exports
  InitExplorer;

begin
end.
