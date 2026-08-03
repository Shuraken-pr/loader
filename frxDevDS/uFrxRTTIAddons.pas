unit uFrxRTTIAddons;

interface

uses System.SysUtils, System.Classes, System.Types, frxClass, fs_iinterpreter, System.Variants;

type
  TFSAddFunctions = class(TfsRTTIModule)
  private
    function CallMethod(Instance: TObject; ClassType: TClass; const MethodName: String; Caller: TfsMethodHelper): Variant;
  public
    constructor Create(AScript: TfsScript); override;
  end;

implementation

uses System.DateUtils, System.StrUtils, dmFastReport;

{ TFSAddFunctions }

function TFSAddFunctions.CallMethod(Instance: TObject; ClassType: TClass;
  const MethodName: String; Caller: TfsMethodHelper): Variant;
begin
  Result := 0;
  if MethodName = 'STARTOFTHEYEAR' then
    Result := StartOfTheYear(Caller.Params[0]) else
  if MethodName = 'STARTOFTHEMONTH' then
    Result := StartOfTheMonth(Caller.Params[0]) else
  if MethodName = 'STARTOFTHEWEEK' then
    Result := StartOfTheWeek(Caller.Params[0]) else
  if MethodName = 'STARTOFTHEDAY' then
    Result := StartOfTheDay(Caller.Params[0]) else
  if MethodName = 'ENDOFTHEYEAR' then
    Result := EndOfTheYear(Caller.Params[0]) else
  if MethodName = 'ENDOFTHEMONTH' then
    Result := EndOfTheMonth(Caller.Params[0]) else
  if MethodName = 'ENDOFTHEWEEK' then
    Result := EndOfTheWeek(Caller.Params[0]) else
  if MethodName = 'ENDOFTHEDAY' then
    Result := EndOfTheDay(Caller.Params[0]) else

  if MethodName = 'STARTOFAYEAR' then
    Result := StartOfAYear(Caller.Params[0]) else
  if MethodName = 'STARTOFAMONTH' then
    Result := StartOfAMonth(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'STARTOFAWEEK' then
    Result := StartOfAWeek(Caller.Params[0], Caller.Params[1], Caller.Params[2]) else
  if MethodName = 'STARTOFADAY' then
    Result := StartOfADay(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'STARTOFADAY' then
    Result := StartOfADay(Caller.Params[0], Caller.Params[1], Caller.Params[2]) else
  if MethodName = 'ENDOFAYEAR' then
    Result := EndOfAYear(Caller.Params[0]) else
  if MethodName = 'ENDOFAMONTH' then
    Result := EndOfAMonth(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'ENDOFAWEEK' then
    Result := EndOfAWeek(Caller.Params[0], Caller.Params[1], Caller.Params[2]) else
  if MethodName = 'ENDOFADAY' then
    Result := EndOfADay(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'ENDOFADAY' then
    Result := EndOfADay(Caller.Params[0], Caller.Params[1], Caller.Params[2]) else
  if MethodName = 'INCMONTH' then
    Result := IncMonth(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'INCYEAR' then
    Result := IncYear(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'INCWEEK' then
    Result := IncWeek(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'INCDAY' then
    Result := IncDay(Caller.Params[0], Caller.Params[1]) else
  if MethodName = 'CUSTOMFUNCTION' then
  begin
    if Assigned(dmFR) and Assigned(dmFR.CustomFunc) then
      Result := dmFR.CustomFunc(VarToStr(caller.Params[0]), VarToStr(Caller.Params[1]));
  end;
end;

constructor TFSAddFunctions.Create(AScript: TfsScript);
begin
  inherited Create(AScript);
  with AScript do
  begin
    AddMethod('function StartOfTheYear(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало года');
    AddMethod('function StartOfTheMonth(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало месяца');
    AddMethod('function StartOfTheWeek(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало недели');
    AddMethod('function StartOfTheDay(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало дня');
    AddMethod('function EndOfTheYear(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец года');
    AddMethod('function EndOfTheMonth(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец месяца');
    AddMethod('function EndOfTheWeek(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец недели');
    AddMethod('function EndOfTheDay(const AValue: TDateTime): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец дня');
    AddMethod('function StartOfAYear(const AYear: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало года');
    AddMethod('function StartOfAMonth(const AYear, AMonth: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало месяца');
    AddMethod('function StartOfAWeek(const AYear, AWeekOfYear, ADayOfWeek: Word = 1): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало недели');
    AddMethod('function StartOfADay(const AYear, ADayOfYear: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало дня');
    AddMethod('function StartOfADay(const AYear, AMonth, ADay: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает начало дня');
    AddMethod('function EndOfAYear(const AYear: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец года');
    AddMethod('function EndOfAMonth(const AYear, AMonth: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец месяца');
    AddMethod('function EndOfAWeek(const AYear, AWeekOfYear, ADayOfWeek: Word = 7): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец недели');
    AddMethod('function EndOfADay(const AYear, ADayOfYear: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец дня');
    AddMethod('function EndOfADay(const AYear, AMonth, ADay: Word): TDateTime;', CallMethod,
              'ctDate', 'Возвращает конец дня');
    AddMethod('function IncMonth(const DateTime: TDateTime; NumberOfMonths: Integer = 1): TDateTime;', CallMethod,
              'ctDate', 'Увеличивает(уменьшает) кол-во месяцев');
    AddMethod('function IncYear(const DateTime: TDateTime; NumberOfYear: Integer = 1): TDateTime;', CallMethod,
              'ctDate', 'Увеличивает(уменьшает) кол-во лет');
    AddMethod('function IncWeek(const DateTime: TDateTime; NumberOfWeek: Integer = 1): TDateTime;', CallMethod,
              'ctDate', 'Увеличивает(уменьшает) кол-во недель');
    AddMethod('function IncDay(const DateTime: TDateTime; NumberOfDay: Integer = 1): TDateTime;', CallMethod,
              'ctDate', 'Увеличивает(уменьшает) кол-во дней');
    AddMethod('function CustomFunction(AName: string; AParams: string): Variant', CallMethod,
    'Common', 'Пользовательская функция, которая вызывается в запускаемой задаче');
  end;
end;

initialization
  fsRTTIModules.Add(TFSAddFunctions);
finalization
  fsRTTIModules.Remove(TFSAddFunctions);
end.
