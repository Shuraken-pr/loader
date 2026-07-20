program loader;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  vstHelper in '..\..\common\vstHelper.pas',
  intf_dll in '..\..\common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  dxSkinsCore,
  dxSkinBasic,
  dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle,
  dxSkinOffice2007Blue,
  dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark,
  dxSkinVS2010,
  dmSkins in '..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  uSkinManager in '..\..\Common\uSkinManager.pas',
  uSkinHelper in '..\..\Common\uSkinHelper.pas',
  intf_skin in '..\..\Common\intf_skin.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
