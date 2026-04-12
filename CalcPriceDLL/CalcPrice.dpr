library CalcPrice;

uses
  System.SysUtils,
  System.Classes,
  dxCore,
  VCL.Forms,
  Winapi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas' ,
  uCalcPrice in 'uCalcPrice.pas' {frmCalcPrice};

type
  TDLLCalcPrice = class(TInterfacedObject, IDLLIntf, IDllIntfRun, ICalcPrice)
  private
    FCalcPrice: TfrmCalcPrice;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    function GetDescription: WideString; safecall;
    procedure CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
    out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double); safecall;
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
end;

destructor TDLLCalcPrice.Destroy;
begin
  if Assigned(FCalcPrice) then
    FreeAndNil(FCalcPrice);
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
