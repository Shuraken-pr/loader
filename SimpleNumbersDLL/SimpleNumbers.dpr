library SimpleNumbers;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  frxDevDSIntf in '..\..\Common\frxDevDSIntf.pas',
  main in 'main.pas' {frmSimpleNumbers},
  intf_tasks in '..\..\common\intf_tasks.pas',
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  intf_skin in '..\..\Common\intf_skin.pas',
  dmSkins in '..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  uSkinHelper in '..\..\Common\uSkinHelper.pas';

type
  TDllSimpleNumbers = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IUsesDllManager, ISimpleNumbers, ISkinAware)
  private
    FDllManager: IDllManager;
    FFrmSM: TfrmSimpleNumbers;
    FSkin: TdmSkin;
  public
    procedure Init; safecall;
    procedure Fin; safecall;
    function GetDescription: WideString; safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    procedure SilentRun(AMaxNum: integer; ACallbackProc: TProc<WideString>); safecall;
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean = False); safecall;
    // IUsesDllManager
    procedure SetDllManager(AMgr: IDllManager); safecall;
    constructor Create;
    destructor Destroy; override;
  end;

{$R *.res}

{ TDllSimpleNumbers }

procedure TDllSimpleNumbers.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  TfrmSimpleNumbers.RunForm(0, ACallbackProc, FDllManager, false);
end;

procedure TDllSimpleNumbers.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

procedure TDllSimpleNumbers.SilentRun(AMaxNum: integer;
  ACallbackProc: TProc<WideString>);
begin
  TfrmSimpleNumbers.RunForm(AMaxNum, ACallbackProc, FDllManager, true);
end;

procedure TDllSimpleNumbers.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

constructor TDllSimpleNumbers.Create;
begin
  dxCore.dxInitialize;
  FSkin := TdmSkin.Create(nil);
  FFrmSM := TfrmSimpleNumbers.Create(nil);
end;

destructor TDllSimpleNumbers.Destroy;
begin
  if Assigned(FFrmSM) then
    FreeAndNil(FFrmSM);
  if Assigned(FSkin) then
    FreeAndNil(FSkin);
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
