unit uCalcPricesProc;

interface

procedure CalcPricesProc(InputPriceWithNDS: double; ProcNDS: Integer;
    out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);

function CheckNum(ANum: double): boolean;

implementation

uses Math, SysUtils;

function CheckNum(ANum: double): boolean;
begin
  // Используем SameValue для корректного сравнения чисел с плавающей точкой
  // с допуском 1e-5, чтобы избежать проблем точности представления double
  Result := SameValue(ANum, Round(ANum * 100) / 100, 1e-5);
end;

procedure CalcPricesProc(InputPriceWithNDS: double; ProcNDS: Integer;
  out CorrectedPriceWithNDS, CorrectedPriceWithoutNDS: double);
var
  koefficient: double;
  BaseWithoutNDS: double;
  i: Integer;
  TestWithoutNDS, TestWithNDS: double;
  BestWithoutNDS, BestWithNDS: double;
  MinDiff: double;
  Diff: double;
begin
  if IsZero(ProcNDS) then
  begin
    CorrectedPriceWithNDS := InputPriceWithNDS;
    CorrectedPriceWithoutNDS := InputPriceWithNDS;
    Exit;
  end;

  koefficient := 1 + ProcNDS / 100.0;
  BaseWithoutNDS := Round(InputPriceWithNDS / koefficient * 100) / 100;
  
  MinDiff := 1e9;
  BestWithoutNDS := BaseWithoutNDS;
  BestWithNDS := BaseWithoutNDS * koefficient;

  // Ищем в диапазоне +/- 10 копеек от базового математического значения
  for i := -10 to 10 do
  begin
    TestWithoutNDS := BaseWithoutNDS + i * 0.01;
    if TestWithoutNDS < 0 then Continue;
    
    // Вычисляем цену с НДС и округляем до 2 знаков по правилам математики
    TestWithNDS := Round(TestWithoutNDS * koefficient * 100) / 100;
    
    // Проверяем, что обе цены корректны (имеют не более 2 знаков после запятой)
    // и разница с исходной ценой минимальна
    if CheckNum(TestWithoutNDS) and CheckNum(TestWithNDS) then
    begin
      Diff := Abs(TestWithNDS - InputPriceWithNDS);
      if Diff < MinDiff then
      begin
        MinDiff := Diff;
        BestWithoutNDS := TestWithoutNDS;
        BestWithNDS := TestWithNDS;
      end;
    end;
  end;

  CorrectedPriceWithoutNDS := BestWithoutNDS;
  CorrectedPriceWithNDS := BestWithNDS;
end;

end.