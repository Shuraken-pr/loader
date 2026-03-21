library SimpleNumbers;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  main in 'main.pas' {frmSimpleNumbers},
  intf_tasks in '..\..\common\intf_tasks.pas';

type
  TDllSimpleNumbers = class(TInterfacedObject, IDLLIntf, IDllIntfRun, ISimpleNumbers)
  private
    FFrmSM: TfrmSimpleNumbers;
  public
    procedure Init; safecall;
    procedure Fin; safecall;
    function GetDescription: WideString; safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    procedure SilentRun(AMaxNum: integer; ACallbackProc: TProc<WideString>); safecall;
    constructor Create;
    destructor Destroy; override;
  end;

{$R *.res}

{ TDllSimpleNumbers }

procedure TDllSimpleNumbers.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  Application.MainFormOnTaskBar := (GetWindowLong(MainAppHandle, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0;
  FFrmSM.CallbackProc := ACallbackProc;
  FFrmSM.show;
end;

procedure TDllSimpleNumbers.SilentRun(AMaxNum: integer;
  ACallbackProc: TProc<WideString>);
begin
  FFrmSM.CallbackProc := ACallbackProc;
  FFrmSM.Run(AMaxNum, true);
end;

constructor TDllSimpleNumbers.Create;
begin
  dxCore.dxInitialize;
  FFrmSM := TfrmSimpleNumbers.Create(nil);
end;

destructor TDllSimpleNumbers.Destroy;
begin
  if Assigned(FFrmSM) then
    FreeAndNil(FFrmSM);
  inherited;
  dxCore.dxFinalize;
end;

procedure TDllSimpleNumbers.Fin;
begin

end;

function TDllSimpleNumbers.GetDescription: WideString;
begin
  Result := 'Вычисление простых чисел';
end;

procedure TDllSimpleNumbers.Init;
begin

end;

function InitSimpleNumbers: ISimpleNumbers;
begin
  Result := TDllSimpleNumbers.Create;
end;

exports
  InitSimpleNumbers;

begin
end.
