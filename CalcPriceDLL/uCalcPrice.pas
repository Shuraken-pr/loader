unit uCalcPrice;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxLayoutcxEditAdapters, cxContainer, cxEdit,
  dxLayoutContainer, cxTextEdit, cxMaskEdit, cxSpinEdit, cxClasses,
  dxLayoutControl;

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

{$R *.dfm}

{ TfrmCalcPrice }

procedure TfrmCalcPrice.CalcPrices(InputPriceWithNDS: double; ProcNDS: Integer;
  out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
const
  ACallbackMSG =
  'Рекомендованная цена с НДС: %s; Процент НДС: %s; Корректная цена с НДС: %s; Корректная цена без НДС: %s';

  function CheckNum(ANum: double): boolean;
  begin
    Result := int(ANum*100)/100 = ANum;
  end;

var
  Msg: WideString;
  koefficient: double;
  UpPriceWithNDS, DownPriceWithNDS: double;
  UpPriceWithoutNDS, DownPriceWithoutNDS: double;
begin
  //для расчёта цены без НДС
  koefficient := 1 + ProcNDS/100;
  //изначальная цена с НДС
  UpPriceWithNDS := InputPriceWithNDS;
  DownPriceWithNDS := UpPriceWithNDS;
  //изначальная цена без НДС
  UpPriceWithoutNDS := UpPriceWithNDS/koefficient;
  DownPriceWithoutNDS := UpPriceWithoutNDS;

  //цикл проверки цены без НДС, пока не получим нужный результат
  while not CheckNum(UpPriceWithoutNDS) and not CheckNum(DownPriceWithoutNDS) do
  begin
    if DownPriceWithNDS > 0.01 then
    begin
      //уменьшаем цену с НДС на 0.01
      DownPriceWithNDS := Round(DownPriceWithNDS*100 - 1)/100;
      DownPriceWithoutNDS := DownPriceWithNDS/koefficient;
    end;
    //повышаем цену с НДС на 0.01
    UpPriceWithNDS := Round(UpPriceWithNDS*100 + 1)/100;
    UpPriceWithoutNDS := UpPriceWithNDS/koefficient;
  end;

  //проверяем, какая цена корректная: которую увеличивали или уменьшали.
  if CheckNum(UpPriceWithoutNDS) then
  begin
    CorrectedPriceWithNDS := UpPriceWithNDS;
    CorrectedPriceWithoutNDS := UpPriceWithoutNDS;
  end
    else
  begin
    CorrectedPriceWithNDS := DownPriceWithNDS;
    CorrectedPriceWithoutNDS := DownPriceWithoutNDS;
  end;
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
