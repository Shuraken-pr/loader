unit uCalcPricesProc;

interface

procedure CalcPricesProc(InputPriceWithNDS: double; ProcNDS: Integer;
    out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);

function CheckNum(ANum: double): boolean;

implementation

uses Math;

function CheckNum(ANum: double): boolean;
begin
  Result := int(ANum*100)/100 = ANum;
end;

procedure CalcPricesProc(InputPriceWithNDS: double; ProcNDS: Integer;
  out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
var
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

  if IsZero(ProcNDS) then
  begin
    CorrectedPriceWithNDS := UpPriceWithNDS;
    CorrectedPriceWithoutNDS := UpPriceWithoutNDS;
  end
    else
  begin
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
  end;
end;

end.
