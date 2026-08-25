unit uCalcPrice;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxLayoutcxEditAdapters, cxContainer, cxEdit,
  dxLayoutContainer, cxTextEdit, cxMaskEdit, cxSpinEdit, cxClasses,
  dxLayoutControl, dmSkins, uCalcPricesProc, dxSkinsCore,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle, dxSkinOffice2007Blue,
  dxSkinOffice2010Silver, dxSkinOffice2013LightGray, dxSkinVS2010;

type
  TfrmCalcPrice = class(TForm)
    lcCalcPriceGroup_Root: TdxLayoutGroup;
    lcCalcPrice: TdxLayoutControl;
    seInputPriceWithNDS: TcxSpinEdit;
    liInputPriceWithNDS: TdxLayoutItem;
    seProcNDS: TcxSpinEdit;
    liProcNDS: TdxLayoutItem;
    seCorrectedPriceWithNDS: TcxSpinEdit;
    liCorrectedPriceWithNDS: TdxLayoutItem;
    seCorrectedPriceWithoutNDS: TcxSpinEdit;
    liCorrectedPriceWithoutNDS: TdxLayoutItem;
    liDescription: TdxLayoutItem;
    procedure FormCreate(Sender: TObject);
    procedure seInputPriceWithNDSKeyPress(Sender: TObject; var Key: Char);
    procedure seInputPriceWithNDSPropertiesEditValueChanged(Sender: TObject);
  private
    FCallbackProc: TProc<WideString>;
    procedure DoCallbackProc(AMsg: WideString);
    { Private declarations }
  public
    { Public declarations }
    procedure CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
    out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
  end;

var
  frmCalcPrice: TfrmCalcPrice;

implementation

uses Math;

{$R *.dfm}

{ TfrmCalcPrice }

procedure TfrmCalcPrice.CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
  out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
const
  ACallbackMSG =
  'Рекомендованная цена с НДС: %s; Процент НДС: %s; Корректная цена с НДС: %s; Корректная цена без НДС: %s';
var
  Msg: WideString;
begin
  CalcPricesProc(InputPriceWithNDS, ProcNDS, CorrectedPriceWithNDS, CorrectedPriceWithoutNDS);
  //выводим результат.
  Msg := 'Вычисление цены завершено: ' +
         Format(ACallbackMSG, [FloatToStr(InputPriceWithNDS),
         IntToStr(ProcNDS), FloatToStr(CorrectedPriceWithNDS),
         FloatToStr(CorrectedPriceWithoutNDS)]);
  DoCallbackProc(Msg)
end;

procedure TfrmCalcPrice.DoCallbackProc(AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
    FCallbackProc(AMsg);
end;

procedure TfrmCalcPrice.FormCreate(Sender: TObject);
begin
  FCallbackProc := nil;
end;

procedure TfrmCalcPrice.seInputPriceWithNDSKeyPress(Sender: TObject;
  var Key: Char);
var
  pos_delim: integer;
begin
  //ограничение в 20 знаков после разделителя
  pos_delim := pos(FormatSettings.DecimalSeparator, seInputPriceWithNDS.Text);
  if (pos_delim > 0) and ((length(seInputPriceWithNDS.Text) - pos_delim) = 20)  then
    key := #0;
end;

//запускаем процедуру при любом изменении значения
procedure TfrmCalcPrice.seInputPriceWithNDSPropertiesEditValueChanged(
  Sender: TObject);
var
  InputPriceWithNDS: double; ProcNDS: Integer;
  CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double;
begin
  InputPriceWithNDS := seInputPriceWithNDS.Value;
  ProcNDS := seProcNDS.Value;
  CorrectedPriceWithNDS := 0;
  CorrectedPriceWithoutNDS := 0;
  CalcPrices(InputPriceWithNDS, ProcNDS, CorrectedPriceWithNDS, CorrectedPriceWithoutNDS);
  seCorrectedPriceWithNDS.Value := CorrectedPriceWithNDS;
  seCorrectedPriceWithoutNDS.Value := CorrectedPriceWithoutNDS;
end;

end.
