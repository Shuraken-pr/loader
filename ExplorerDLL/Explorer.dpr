library Explorer;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uExplorer in 'uExplorer.pas' {frmScanLocalDisks};

type
  TExplorerDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IExplorer)
  private
    FE: TfrmScanLocalDisks;
    FFindIntf: IRunTaskFindInDir;
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure initFindIntf(AIntf: IRunTaskFindInDir); safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
  end;

{$R *.res}

{ TExplorerDLL }

constructor TExplorerDLL.Create;
begin
  dxCore.dxInitialize;
  FFindIntf := nil;
  FE := TfrmScanLocalDisks.Create(nil);
end;

destructor TExplorerDLL.Destroy;
begin
  if Assigned(FE) then
    FreeAndNil(FE);
  if Assigned(FFindIntf) then
    FFindIntf := nil;
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
  Application.MainFormOnTaskBar := (GetWindowLong(MainAppHandle, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0;
  if Assigned(FFindIntf) then
  begin
    FE.FindIntf := FFindIntf;
    FE.CallbackProc := ACallbackProc;
    FE.Show;
  end
    else
    ACallbackProc('Не задан IRunTaskFind');
end;

function InitExplorer: IExplorer;
begin
  Result := TExplorerDLL.Create;
end;

exports
  InitExplorer;

begin
end.
