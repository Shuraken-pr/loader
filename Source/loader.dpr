program loader;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  vstHelper in '..\..\common\vstHelper.pas',
  intf_dll in '..\..\common\intf_dll.pas',
  DllManager in '..\..\common\DllManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
