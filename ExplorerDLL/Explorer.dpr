library Explorer;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uExplorer in 'uExplorer.pas' {frmScanLocalDisks};

type
  // TExplorerDLL реализует: IDLLIntf + IDllIntfRun + IUsesDllManager + IExplorer
  // Наследование: IExplorer -> IDllIntfRunWithDeps -> (IDllIntfRun + IUsesDllManager)
  TExplorerDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, IExplorer)
  private
    FE: TfrmScanLocalDisks;
    FFindIntf: IRunTaskFindInDir;
    FDllManager: IDllManager;
    procedure TryLoadDependencies;
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
    // IExplorer
    procedure initFindIntf(AIntf: IRunTaskFindInDir); safecall;
  end;

{$R *.res}

{ TExplorerDLL }

constructor TExplorerDLL.Create;
begin
  dxCore.dxInitialize;
  FFindIntf := nil;
  FDllManager := nil;
  FE := TfrmScanLocalDisks.Create(nil);
end;

destructor TExplorerDLL.Destroy;
begin
  if Assigned(FE) then
    FreeAndNil(FE);
  FFindIntf := nil;
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
end;

function InitExplorer: IExplorer;
begin
  Result := TExplorerDLL.Create;
end;

exports
  InitExplorer;

begin
end.
