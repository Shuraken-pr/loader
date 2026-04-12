library RunTasks;

uses
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  system.StrUtils,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uAutonomiusThreadPool in '..\..\common\uAutonomiusThreadPool.pas',
  uRunTasks in 'uRunTasks.pas' {frmRunTasks};

type
  // TRunTasks реализует: IDLLIntf + IDllIntfRun + IUsesDllManager + IRunTasks
  // Наследование: IRunTasks -> IDllIntfRunWithDeps -> (IDllIntfRun + IUsesDllManager)
  TRunTasks = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, IRunTasks)
  private
    FRunTasks: TfrmRunTasks;
    FDllManager: IDllManager;
    FFindInDir: IRunTaskFindInDir;
    FFindInExeFile: IRunTaskFindInExeFile;
    FShellExecute: IRunTaskShellExecute;
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
    // IRunTasks
    procedure initRunTasks(AFindInDir: IRunTaskFindInDir;
                           AFindInExeFile: IRunTaskFindInExeFile;
                           AShellExecute: IRunTaskShellExecute); safecall;
    procedure InitViaDllManager; safecall;
  end;

{$R *.res}

function InitRunTasks: IRunTasks;
begin
  Result := TRunTasks.Create;
end;

exports
  InitRunTasks;

{ TRunTasks }

constructor TRunTasks.Create;
begin
  dxCore.dxInitialize;
  FRunTasks := TfrmRunTasks.Create(nil);
  FDllManager := nil;
  FFindInDir := nil;
  FFindInExeFile := nil;
  FShellExecute := nil;
end;

destructor TRunTasks.Destroy;
begin
  FShellExecute := nil;
  FFindInExeFile := nil;
  FFindInDir := nil;
  FDllManager := nil;
  FreeAndNil(FRunTasks);
  inherited;
  dxCore.dxFinalize;
end;

procedure TRunTasks.Fin;
begin
end;

function TRunTasks.GetDescription: WideString;
begin
  Result := 'Запуск заданий';
end;

procedure TRunTasks.Init;
begin
end;

procedure TRunTasks.initRunTasks(AFindInDir: IRunTaskFindInDir;
  AFindInExeFile: IRunTaskFindInExeFile; AShellExecute: IRunTaskShellExecute);
begin
  FFindInDir := AFindInDir;
  FFindInExeFile := AFindInExeFile;
  FShellExecute := AShellExecute;
  FRunTasks.initRunTasks(AFindInDir, AFindInExeFile, AShellExecute);
end;

procedure TRunTasks.InitViaDllManager;
begin
  TryLoadDependencies;
  // Передаём загруженные интерфейсы форме
  FRunTasks.initRunTasks(FFindInDir, FFindInExeFile, FShellExecute);
end;

procedure TRunTasks.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;

  // Если интерфейсы не заданы вручную — пробуем загрузить через IDllManager
  if FRunTasks.IntfList.Count = 0 then
    InitViaDllManager;

  if FRunTasks.IntfList.Count > 0 then
  begin
    FRunTasks.CallbackProc := ACallbackProc;
    FRunTasks.Show;
  end
    else
    ACallbackProc('Не задан ни один из требуемых модулей');
end;

procedure TRunTasks.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

procedure TRunTasks.TryLoadDependencies;
var
  intf: IInterface;
begin
  if not Assigned(FDllManager) then
    Exit;

  // Загружаем IRunTaskFindInDir
  if not Assigned(FFindInDir) then
  begin
    if not FDllManager.IsLoaded('IRunTaskFindInDir') then
      FDllManager.Load(DIRunTaskFindInDir, False);
    if FDllManager.IsLoaded('IRunTaskFindInDir') then
    begin
      intf := FDllManager.GetIntf(IRunTaskFindInDir);
      if Assigned(intf) and Supports(intf, IRunTaskFindInDir, FFindInDir) then
      begin
        FFindInDir.Init;
        FRunTasks.IntfList.Add(FFindInDir);
      end;
    end;
  end;

  // Загружаем IRunTaskFindInExeFile
  if not Assigned(FFindInExeFile) then
  begin
    if not FDllManager.IsLoaded('IRunTaskFindInExeFile') then
      FDllManager.Load(DIRunTaskFindInExeFile, False);
    if FDllManager.IsLoaded('IRunTaskFindInExeFile') then
    begin
      intf := FDllManager.GetIntf(IRunTaskFindInExeFile);
      if Assigned(intf) and Supports(intf, IRunTaskFindInExeFile, FFindInExeFile) then
      begin
        FFindInExeFile.Init;
        FRunTasks.IntfList.Add(FFindInExeFile);
      end;
    end;
  end;

  // Загружаем IRunTaskShellExecute
  if not Assigned(FShellExecute) then
  begin
    if not FDllManager.IsLoaded('IRunTaskShellExecute') then
      FDllManager.Load(DIRunTaskShellExecute, False);
    if FDllManager.IsLoaded('IRunTaskShellExecute') then
    begin
      intf := FDllManager.GetIntf(IRunTaskShellExecute);
      if Assigned(intf) and Supports(intf, IRunTaskShellExecute, FShellExecute) then
      begin
        FShellExecute.Init;
        FRunTasks.IntfList.Add(FShellExecute);
      end;
    end;
  end;
end;

begin
end.
