library RunTasks;

uses
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  system.StrUtils,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uAutonomiusThreadPool in '..\..\common\uAutonomiusThreadPool.pas',
  uRunTasks in 'uRunTasks.pas' {frmRunTasks};

type
  TRunTasks = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IRunTasks)
  private
    FRunTasks: TfrmRunTasks;
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure initRunTasks(AFindInDir: IRunTaskFindInDir;
                           AFindInExeFile: IRunTaskFindInExeFile;
                           AShellExecute: IRunTaskShellExecute);
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
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
end;

destructor TRunTasks.Destroy;
begin
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
  FRunTasks.initRunTasks(AFindInDir, AFindInExeFile, AShellExecute)
end;

procedure TRunTasks.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  Application.MainFormOnTaskBar := (GetWindowLong(MainAppHandle, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0;
  if FRunTasks.IntfList.Count > 0 then
  begin
    FRunTasks.CallbackProc := ACallbackProc;
    FRunTasks.Show;
  end
    else
    ACallbackProc('Не задан ни один из требуемых модулей');
end;

begin
end.
