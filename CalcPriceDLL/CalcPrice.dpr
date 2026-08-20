library CalcPrice;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas',
  uCalcPrice in 'uCalcPrice.pas' {frmCalcPrice},
  dmSkins in '..\CommonModules\dmSkins.pas' {dmSkin: TDataModule},
  intf_skin in '..\..\Common\intf_skin.pas',
  uSkinHelper in '..\..\Common\uSkinHelper.pas',
  uCalcPricesProc in 'uCalcPricesProc.pas';

type
  TDLLCalcPrice = class(TInterfacedObject, IDLLIntf, IDllIntfRun, ICalcPrice, ISkinAware)
  private
    FCalcPrice: TfrmCalcPrice;
    FSkin: TdmSkin;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    function GetDescription: WideString; safecall;
    procedure CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
    out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double); safecall;
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean = False); safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
  end;


{$R *.res}

  function InitCalcPrice: ICalcPrice;
  begin
    Result := TDLLCalcPrice.Create;
  end;

  exports InitCalcPrice;
{ TDLLCalcPrice }

procedure TDLLCalcPrice.ApplySkin(const ASkinName: WideString;
  ANativeStyle: Boolean);
begin
   ApplySkinToDataModule(FSkin,
     FSkin.dxSkinController,
     FSkin.dxLayoutSkinLookAndFeel,
     ASkinName, ANativeStyle);
end;

procedure TDLLCalcPrice.CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
  out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
begin
  if Assigned(FCalcPrice) then
    FCalcPrice.CalcPrices(InputPriceWithNDS, ProcNDS, CorrectedPriceWithNDS, CorrectedPriceWithoutNDS);
end;

constructor TDLLCalcPrice.Create;
begin
  dxCore.dxInitialize;
  FCalcPrice := TfrmCalcPrice.Create(nil);
  FSkin := TdmSkin.Create(nil);
end;

destructor TDLLCalcPrice.Destroy;
begin
  if Assigned(FCalcPrice) then
    FreeAndNil(FCalcPrice);
  if Assigned(FSkin) then
    FreeAndNil(FSkin);
  inherited;
  dxCore.dxFinalize;
end;

procedure TDLLCalcPrice.Fin;
begin

end;

function TDLLCalcPrice.GetDescription: WideString;
begin
  Result := 'Вычисление цены';
end;

procedure TDLLCalcPrice.Init;
begin

end;

procedure TDLLCalcPrice.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  FCalcPrice.CallbackProc := ACallbackProc;
  FCalcPrice.Show;
end;

begin
end.
