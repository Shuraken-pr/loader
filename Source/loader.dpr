program loader;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  vstHelper in '..\..\common\vstHelper.pas',
  intf_dll in '..\..\common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  DllManager in '..\..\common\DllManager.pas',
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  dxSkinsCore,
  dxSkinBasic,
  dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle,
  dxSkinOffice2007Blue,
  dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark,
  dxSkinVS2010;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
