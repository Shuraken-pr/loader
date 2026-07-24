library PartsCatalog;

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
  cxVirtualTreeListHelper in '..\..\..\Common\cxVirtualTreeListHelper.pas',
  dmDatabase in 'dmDatabase.pas' {dmDB: TDataModule},
  fAttributeDelete in 'fAttributeDelete.pas' {fAttributeDelete},
  fAttributeEdit in 'fAttributeEdit.pas' {frmAttributeEdit},
  fAttributeSelect in 'fAttributeSelect.pas' {fAttributeSelect},
  fCategoryEdit in 'fCategoryEdit.pas' {frmCategoryEdit},
  fPartEdit in 'fPartEdit.pas' {fPartEdit},
  uCatalogService in 'uCatalogService.pas',
  uEntities in 'uEntities.pas',
  uMain in 'uMain.pas' {frmMain},
  uXmlExporter in 'uXmlExporter.pas',
  uXmlImporter in 'uXmlImporter.pas',
  dmSkins in '..\..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  intf_skin in '..\..\..\Common\intf_skin.pas',
  uSkinHelper in '..\..\..\Common\uSkinHelper.pas',
  FireDAC.Moni.Custom.Logger in '..\..\..\Common\FireDAC.Moni.Custom.Logger.pas';

{$R *.res}

type
  TDLLPartsCatalog = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, IPartsCatalog, ISkinAware)
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


{ TDLLPartsCatalog }

procedure TDLLPartsCatalog.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

constructor TDLLPartsCatalog.Create;
begin
  inherited Create;
  FSkin := TdmSkin.Create(nil);
  dxInitialize;
end;

destructor TDLLPartsCatalog.Destroy;
begin
  if Assigned(FSkin) then
    FreeAndNil(FSkin);
  inherited;
  dxFinalize;
end;

procedure TDLLPartsCatalog.Init;
begin
//
end;

procedure TDLLPartsCatalog.Fin;
begin
//
end;

function TDLLPartsCatalog.GetDescription: WideString;
begin
  Result := '”правление иерархическим каталогом деталей';
end;

procedure TDLLPartsCatalog.Run(ACallbackProc: TProc<WideString>;
  MainAppHandle: HWnd);
var
  AMsg: WideString;
  OldHandle: HWnd;
begin
  AMsg := '';
  OldHandle := Application.Handle;
  try
    TfrmMain.RunForm(ACallbackProc, AMsg, FSkinName, FNativeStyle);
  finally
    Application.Handle := OldHandle;
  end;
end;

procedure TDLLPartsCatalog.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

function InitPartsCatalog: IDllIntfRun;
begin
  Result := TDLLPartsCatalog.Create;
end;

exports
  InitPartsCatalog;

begin

end.
