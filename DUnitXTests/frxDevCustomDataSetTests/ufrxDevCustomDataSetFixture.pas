unit ufrxDevCustomDataSetFixture;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Variants,
  DUnitX.TestFramework,
  cxTL,
  cxTLData,
  cxVirtualTreeListHelper,
  frxClass,
  frxDevCustomDataSet;

type
  { ========== TMockRecord ========== }
  { Конкретный наследник TVTBaseRecord с 5 колонками разных типов.
    Используется во всех тестах фикстуры как источник данных. }
  TMockRecord = class(TVTBaseRecord)
  public
    const
      COL_INTEGER = 0;  // → varInteger → fftNumeric
      COL_STRING  = 1;  // → varUString → fftString
      COL_DATE    = 2;  // → varDate   → fftDateTime
      COL_BOOLEAN = 3;  // → varBoolean → fftBoolean
      COL_NULL    = 4;  // → Null      → fftString (default)
  private
    FIntValue: Integer;
    FText: string;
    FDate: TDateTime;
    FBoolValue: Boolean;
    FNullValue: Variant;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;
  end;

  { ========== TTestFrxDevCustomDataSet ========== }
  { Тестовый наследник TfrxDevCustomDataSet.
    Реэкспортирует protected-свойства FieldIndexes и FieldTypes
    как public для возможности прямой проверки в тестах.
    Это устойчивее и производительнее, чем RTTI. }
  TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
  public
    property FieldIndexes;
    property FieldTypes;
    property CurrentIndex;
  end;

  { ========== TTestTVTRecordAdapter ========== }
  { Тестовый наследник TVTRecordAdapter.
    Реэкспортирует protected-свойства FieldIndexes, FieldTypes и FieldNames
    как public для проверки корректности копирования метаданных
    при создании адаптера в GetAdapterForRecord.
    Это устойчивее и производительнее, чем RTTI. }
  TTestTVTRecordAdapter = class(TVTRecordAdapter)
  public
    property FieldIndexes;
    property FieldTypes;
    property FieldNames;
  end;

  [TestFixture]
  TfrxDevCustomDataSetFixture = class
  private
    FDataSet: TTestFrxDevCustomDataSet;
    FTreeList: TcxVirtualTreeList;
    FDataSource: TVTLoadAllDataSource<TMockRecord>;

    /// <summary>
    /// Создаёт ACount видимых колонок в FTreeList с именами 'Col1', 'Col2', ...
    /// Если AWithHidden=True, добавляет ещё одну невидимую колонку 'Hidden'.
    /// </summary>
    procedure PrepareColumns(ACount: Integer; AWithHidden: Boolean = False);

    /// <summary>
    /// Заполняет FDataSource указанным количеством записей со стандартными значениями.
    /// </summary>
    procedure PopulateDataSource(ARecordsCount: Integer);

    /// <summary>
    /// Пересоздаёт FDataSource с привязкой к FTreeList.
    /// Необходимо для тестов навигации (4.1.2), где InsertRecordHandle
    /// должен создавать VCL-узлы для корректной работы InternalFirst/InternalNext.
    /// Если ARecordCount > 0, заполняет источник указанным количеством записей.
    /// </summary>
    procedure SetupForNavigation(ARecordCount: Integer = 0);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    { ============================================================ }
    { === 4.1.1 Привязка к источнику (AssignDataSource) === }
    { ============================================================ }

    /// <summary>
    /// 4.1.1.1 AssignDataSource(nil, TreeList) должен выбросить
    /// EArgumentNilException с текстом 'ADataSource must not be nil'.
    /// </summary>
    [Test]
    procedure AssignDataSource_NilDataSource_RaisesException;

    /// <summary>
    /// 4.1.1.2 AssignDataSource(DataSource, nil) должен выбросить
    /// EArgumentNilException с текстом 'ATreeList must not be nil'.
    /// </summary>
    [Test]
    procedure AssignDataSource_NilTreeList_RaisesException;

    /// <summary>
    /// 4.1.1.3 Привязка к TreeList с 3 видимыми колонками создаёт
    /// корректные списки Fields, FieldIndexes и FieldTypes.
    /// Проверяется основная логика BuildFieldListFromTreeList.
    /// </summary>
    [Test]
    procedure AssignDataSource_BuildsFieldListFromColumns;

    /// <summary>
    /// 4.1.1.4 Невидимые колонки (Visible=False) пропускаются
    /// и не попадают в списки полей.
    /// </summary>
    [Test]
    procedure AssignDataSource_HiddenColumn_Skipped;

    /// <summary>
    /// 4.1.1.5 Колонки с пустым Caption получают авто-имена 'Col0', 'Col1'.
    /// </summary>
    [Test]
    procedure AssignDataSource_EmptyColumnCaption_GeneratesColN;

    /// <summary>
    /// 4.1.1.6 Дублирующиеся имена колонок получают суффикс '_N'
    /// (где N - индекс колонки в TreeList).
    /// </summary>
    [Test]
    procedure AssignDataSource_DuplicateColumnNames_AddsSuffix;

    /// <summary>
    /// 4.1.1.7 Повторная привязка к новому источнику очищает предыдущее
    /// состояние: Fields, FieldIndexes, FieldTypes и кэш адаптеров.
    /// </summary>
    [Test]
    procedure AssignDataSource_ClearsPreviousState;

    { ============================================================ }
    { === 4.1.2 Навигация по записям (Navigation) === }
    { ============================================================ }

    /// <summary>
    /// 4.1.2.1 Open сбрасывает CurrentIndex в -1 и не устанавливает
    /// активный адаптер (FActiveAdapter = nil).
    /// </summary>
    [Test]
    procedure Open_SetsCurrentIndexToMinusOne;

    /// <summary>
    /// 4.1.2.2 First устанавливает CurrentIndex = 0 и создаёт активный адаптер
    /// для первой записи.
    /// </summary>
    [Test]
    procedure First_SetsCurrentIndexToZero;

    /// <summary>
    /// 4.1.2.3 Next инкрементирует CurrentIndex и обновляет CurrentNode
    /// на следующий узел дерева.
    /// </summary>
    [Test]
    procedure Next_IncrementsIndex;

    /// <summary>
    /// 4.1.2.4 Eof становится True, когда навигация прошла все записи.
    /// </summary>
    [Test]
    procedure Eof_TrueWhenNoMoreNodes;

    /// <summary>
    /// 4.1.2.5 Eof возвращает True, если не вызван AssignDataSource.
    /// </summary>
    [Test]
    procedure Eof_TrueWhenNoDataSource;

    /// <summary>
    /// 4.1.2.6 RecordCount возвращает количество записей в источнике
    /// (RootHandle.TotalCount).
    /// </summary>
    [Test]
    procedure RecordCount_ReturnsRootTotalCount;

    /// <summary>
    /// 4.1.2.7 Close полностью сбрасывает состояние навигации:
    /// CurrentIndex = -1, CurrentNode = nil, FActiveAdapter = nil.
    /// </summary>
    [Test]
    procedure Close_ResetsNavigationState;

    /// <summary>
    /// 4.1.2.8 First на пустом источнике устанавливает CurrentIndex = 0,
    /// CurrentNode = nil, Eof = True.
    /// </summary>
    [Test]
    procedure First_OnEmptyDataSource_SetsNilAdapter;

    /// <summary>
    /// 4.1.2.9 RecordCount без привязки возвращает 0.
    /// </summary>
    [Test]
    procedure RecordCount_NoDataSource_ReturnsZero;

    /// <summary>
    /// 4.1.2.10 Повторный вызов First после Next сбрасывает указатель в начало.
    /// </summary>
    [Test]
    procedure First_MultipleCalls_ResetToBeginning;

    /// <summary>
    /// 4.1.2.11 Вызов Next после достижения Eof = True не вызывает исключений.
    /// </summary>
    [Test]
    procedure Next_AfterEof_NoException;

    { ============================================================ }
    { === 4.1.3 GetValue / GetDisplayText === }
    { ============================================================ }

    /// <summary>
    /// 4.1.3.1 GetValue без активного адаптера (Open без First)
    /// возвращает Null для любого поля.
    /// </summary>
    [Test]
    procedure GetValue_ReturnsNull_WhenNoActiveAdapter;

    /// <summary>
    /// 4.1.3.2 GetDisplayText без активного адаптера возвращает
    /// пустую строку для любого поля.
    /// </summary>
    [Test]
    procedure GetDisplayText_ReturnsEmpty_WhenNoActiveAdapter;

    /// <summary>
    /// 4.1.3.3 GetValue делегирует вызов активному адаптеру для
    /// полей разных типов (Integer, String, Date, Boolean, Null).
    /// Проверяется сохранение VarType варианта.
    /// </summary>
    [Test]
    procedure GetValue_CallsAdapterGetValue;

    /// <summary>
    /// 4.1.3.4 GetDisplayText форматирует значения в WideString
    /// по правилам TVTRecordAdapter:
    /// Integer → '42', String → 'Test', Boolean → 'True', Null → ''.
    /// </summary>
    [Test]
    procedure GetDisplayText_CallsAdapterGetDisplayText;

    /// <summary>
    /// 4.1.3.5 GetValue для несуществующего поля возвращает Null.
    /// Поиск имён полей case-insensitive (TStringList.CaseSensitive=False
    /// по умолчанию), поэтому 'col1', 'COL1' и 'Col1' эквивалентны.
    /// </summary>
    [Test]
    procedure GetValue_UnknownField_ReturnsNull;

    /// <summary>
    /// 4.1.3.6 GetFieldType возвращает корректный FastReport-тип
    /// для каждого поля: fftNumeric, fftString, fftDateTime, fftBoolean.
    /// Неизвестное поле → fftString (default).
    /// </summary>
    [Test]
    procedure GetFieldType_ReturnsCorrectType;

    /// <summary>
    /// 4.1.3.7 (дополнительный) После Next GetValue возвращает
    /// значения следующей записи (адаптер сменяется).
    /// </summary>
    [Test]
    procedure GetValue_AfterNext_ReturnsNextRecordValues;

    /// <summary>
    /// 4.1.3.8 (дополнительный) На пустом источнике First не может
    /// установить FActiveAdapter, поэтому GetValue возвращает Null.
    /// </summary>
    [Test]
    procedure GetValue_EmptyDataSource_ReturnsNull;

    { ============================================================ }
    { === 4.1.4 Адаптер записи (Master-Detail) === }
    { ============================================================ }

    /// <summary>
    /// 4.1.4.1 GetAdapterForRecord создаёт новый адаптер при первом
    /// обращении к записи. Проверяется, что адаптер создан и привязан
    /// к правильной записи через SourceRecord.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_CreatesNew_IfNotExists;

    /// <summary>
    /// 4.1.4.2 Повторное обращение к одной записи возвращает тот же
    /// адаптер из кэша (AreSame). Кэш FAdapters работает корректно.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_ReturnsExisting_IfExists;

    /// <summary>
    /// 4.1.4.3 Разные записи получают разные адаптеры.
    /// В кэше FAdapters появляются два разных объекта.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_DifferentRecords_DifferentAdapters;

    /// <summary>
    /// 4.1.4.4 Адаптер получает копию метаданных полей (FieldNames,
    /// FieldIndexes, FieldTypes) из DataSet. Проверяется, что адаптер
    /// владеет своими коллекциями, а не ссылками на DataSet.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_PreservesFieldMetadata;

    /// <summary>
    /// 4.1.4.5 RecordCount адаптера всегда возвращает 1 (семантика
    /// "одна запись на адаптер"), независимо от RecordCount DataSet.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_RecordCount_AlwaysOne;

    /// <summary>
    /// 4.1.4.6 Полный жизненный цикл навигации адаптера:
    /// Open → First (Eof=False) → Next (Eof=True) → безопасный повторный Next.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_Navigation_OneRecordLifecycle;

    /// <summary>
    /// 4.1.4.7 (дополнительный) Adapter.GetValue делегирует вызов
    /// исходной записи и сохраняет типы вариантов. Поиск имён
    /// case-insensitive.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_GetValue_DelegatesToSource;

    /// <summary>
    /// 4.1.4.8 (дополнительный) Повторная AssignDataSource очищает
    /// кэш адаптеров (FAdapters.Clear). Новые адаптеры отличаются
    /// от старых.
    /// </summary>
    [Test]
    procedure GetAdapterForRecord_CacheClearedOnReassign;
  end;

  { ============================================================ }
  { TfrxDevCustomDataSetAdapterFixture — изолированные тесты      }
  { TVTRecordAdapter без VCL-зависимостей.                        }
  { Полностью автономная фикстура, проверяющая сам адаптер        }
  { без участия TfrxDevCustomDataSet и TcxVirtualTreeList.        }
  { ============================================================ }
  [TestFixture]
  TfrxDevCustomDataSetAdapterFixture = class
  private
    FSource: TMockRecord;
    FFieldNames: TStringList;
    FFieldIndexes: TList<Integer>;
    FFieldTypes: TList<TfrxFieldType>;

    /// <summary>
    /// Заполняет метаданные стандартными значениями (ID, Name, Date).
    /// </summary>
    procedure PrepareMetadata;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    { ============================================================ }
    { === 4.2.1 Конструктор и инициализация === }
    { ============================================================ }

    /// <summary>
    /// 4.2.1.1 Конструктор корректно инициализирует все поля:
    /// FSource = ASource, FFieldNames/FFieldIndexes/FFieldTypes
    /// скопированы (не по ссылке), FCurrentRecNo = 0, FEofFlag = False.
    /// </summary>
    [Test]
    procedure Create_InitializesFieldsCorrectly;

    /// <summary>
    /// 4.2.1.2 Конструктор с nil коллекциями не вызывает исключений.
    /// Проверяет устойчивость к некорректным параметрам.
    /// </summary>
    [Test]
    procedure Create_WithNilCollections_DoesNotRaise;

    { ============================================================ }
    { === 4.2.2 Навигация (всегда одна запись) === }
    { ============================================================ }

    /// <summary>
    /// 4.2.2.1 Open сбрасывает FCurrentRecNo в 0 и FEofFlag в False.
    /// </summary>
    [Test]
    procedure Open_ResetsRecNo;

    /// <summary>
    /// 4.2.2.2 First сбрасывает FCurrentRecNo в 0.
    /// </summary>
    [Test]
    procedure First_ResetsRecNo;

    /// <summary>
    /// 4.2.2.3 После First + Next FEofFlag становится True
    /// (семантика "одна запись на адаптер").
    /// </summary>
    [Test]
    procedure Next_SetsEofToTrue;

    /// <summary>
    /// 4.2.2.4 Eof возвращает True после Next (FCurrentRecNo >= 1).
    /// </summary>
    [Test]
    procedure Eof_TrueAfterNext;

    /// <summary>
    /// 4.2.2.5 RecordCount всегда возвращает 1
    /// (семантика "одна запись на адаптер").
    /// </summary>
    [Test]
    procedure RecordCount_AlwaysOne;

    /// <summary>
    /// 4.2.2.6 (дополнительный) Повторный First после Next
    /// сбрасывает состояние в начало.
    /// </summary>
    [Test]
    procedure First_AfterNext_ResetsState;

    /// <summary>
    /// 4.2.2.7 (дополнительный) Повторный Next после Eof
    /// не вызывает исключений.
    /// </summary>
    [Test]
    procedure Next_AfterEof_IsSafe;

    { ============================================================ }
    { === 4.2.3 GetValue === }
    { ============================================================ }

    /// <summary>
    /// 4.2.3.1 GetValue для известного поля возвращает значение
    /// из FSource по индексу FFieldIndexes[ColIdx].
    /// </summary>
    [Test]
    procedure GetValue_KnownField_ReturnsValue;

    /// <summary>
    /// 4.2.3.2 GetValue для неизвестного поля возвращает Null
    /// (FFieldNames.IndexOf вернул -1).
    /// </summary>
    [Test]
    procedure GetValue_UnknownField_ReturnsNull;

    /// <summary>
    /// 4.2.3.3 GetValue при FSource = nil возвращает Null
    /// (без Access Violation).
    /// </summary>
    [Test]
    procedure GetValue_NilSource_ReturnsNull;

    { ============================================================ }
    { === 4.2.4 GetFieldList === }
    { ============================================================ }

    /// <summary>
    /// 4.2.4.1 GetFieldList копирует FFieldNames в переданный список
    /// через List.Assign.
    /// </summary>
    [Test]
    procedure GetFieldList_ReturnsFieldNames;

    { ============================================================ }
    { === 4.2.5 FieldsCount === }
    { ============================================================ }

    /// <summary>
    /// 4.2.5.1 FieldsCount возвращает FFieldNames.Count.
    /// </summary>
    [Test]
    procedure FieldsCount_ReturnsFieldNamesCount;

    { ============================================================ }
    { === 4.2.6 Дополнительные тесты === }
    { ============================================================ }

    /// <summary>
    /// 4.2.6.1 (дополнительный) GetDisplayText форматирует значения:
    /// Integer -> '42', String -> 'Test', Boolean -> 'True', Null -> ''.
    /// </summary>
    [Test]
    procedure GetDisplayText_FormatsValues;

    /// <summary>
    /// 4.2.6.2 (дополнительный) GetFieldType возвращает тип из
    /// FFieldTypes[ColIdx] для известного поля.
    /// </summary>
    [Test]
    procedure GetFieldType_ReturnsMappedType;

    /// <summary>
    /// 4.2.6.3 (дополнительный) GetFieldType для неизвестного поля
    /// возвращает fftString (default).
    /// </summary>
    [Test]
    procedure GetFieldType_UnknownField_ReturnsString;

    /// <summary>
    /// 4.2.6.4 (дополнительный) Поиск имён полей в GetValue
    /// case-insensitive (TStringList.CaseSensitive=False по умолчанию).
    /// </summary>
    [Test]
    procedure GetValue_CaseInsensitive;
  end;

implementation

{ ================================================================ }
{ TMockRecord implementation }
{ ================================================================ }

constructor TMockRecord.Create(AParent: TVTBase);
begin
  inherited;
  FIntValue := 0;
  FText := '';
  FDate := 0;
  FBoolValue := False;
  FNullValue := Null;
end;

function TMockRecord.GetValue(ColIdx: Integer): Variant;
begin
  case ColIdx of
    COL_INTEGER: Result := FIntValue;
    COL_STRING:  Result := FText;
    COL_DATE:    Result := FDate;
    COL_BOOLEAN: Result := FBoolValue;
    COL_NULL:    Result := FNullValue;
  else
    Result := Unassigned;
  end;
end;

procedure TMockRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  case ColIdx of
    COL_INTEGER: FIntValue := AValue;
    COL_STRING:  FText := AValue;
    COL_DATE:    FDate := AValue;
    COL_BOOLEAN: FBoolValue := AValue;
    COL_NULL:    FNullValue := AValue;
  end;
end;

procedure TMockRecord.Assign(Source: TVTBaseRecord);
var
  Src: TMockRecord;
begin
  if Source is TMockRecord then
  begin
    Src := TMockRecord(Source);
    FIntValue := Src.FIntValue;
    FText := Src.FText;
    FDate := Src.FDate;
    FBoolValue := Src.FBoolValue;
    FNullValue := Src.FNullValue;
  end;
end;

{ ================================================================ }
{ TfrxDevCustomDataSetFixture implementation }
{ ================================================================ }

procedure TfrxDevCustomDataSetFixture.Setup;
begin
  { Создаём тестируемый DataSet и валидный TreeList.
    TcxVirtualTreeList доступен через глобальный Application singleton
    из Vcl.Forms (подключён в .dpr). В консольном раннере DUnitX
    Application создаётся автоматически при инициализации модуля
    Vcl.Forms, поэтому дополнительная инициализация не требуется.

    FDataSource создаём с nil вместо TreeList: нам нужна только
    CRUD-логика для хранения записей, а привязку к UI сделаем
    через AssignDataSource. }
  FDataSet := TTestFrxDevCustomDataSet.Create(nil);
  FTreeList := TcxVirtualTreeList.Create(nil);
  FDataSource := TVTLoadAllDataSource<TMockRecord>.Create(nil);
end;

procedure TfrxDevCustomDataSetFixture.TearDown;
begin
  FreeAndNil(FDataSource);
  FreeAndNil(FTreeList);
  FreeAndNil(FDataSet);
end;

procedure TfrxDevCustomDataSetFixture.PrepareColumns(ACount: Integer;
  AWithHidden: Boolean);
var
  I: Integer;
  Col: TcxTreeListColumn;
begin
  for I := 1 to ACount do
  begin
    Col := FTreeList.CreateColumn;
    Col.Caption.Text := 'Col' + IntToStr(I);
    Col.Visible := True;
  end;

  if AWithHidden then
  begin
    Col := FTreeList.CreateColumn;
    Col.Caption.Text := 'Hidden';
    Col.Visible := False;
  end;
end;

procedure TfrxDevCustomDataSetFixture.PopulateDataSource(ARecordsCount: Integer);
var
  I: Integer;
  Rec: TMockRecord;
begin
  for I := 1 to ARecordsCount do
  begin
    Rec := TMockRecord(FDataSource.InsertRecordHandle(FDataSource.RootHandle, True));
    Rec.SetValue(TMockRecord.COL_INTEGER, I);
    Rec.SetValue(TMockRecord.COL_STRING, 'Record_' + IntToStr(I));
    Rec.SetValue(TMockRecord.COL_DATE, EncodeDate(2026, 1, I));
    Rec.SetValue(TMockRecord.COL_BOOLEAN, Odd(I));
  end;
end;

procedure TfrxDevCustomDataSetFixture.SetupForNavigation(ARecordCount: Integer);
begin
  { Для навигации требуется, чтобы FDataSource был создан с FTreeList.
    Это обеспечивает автоматическую синхронизацию: InsertRecordHandle
    создаёт и запись TVTBaseRecord, и VCL-узел TcxTreeListNode.
    Без этого FTreeList.Root.getFirstChild возвращает nil, и InternalFirst
    не находит первую запись. }
  FreeAndNil(FDataSource);
  FDataSource := TVTLoadAllDataSource<TMockRecord>.Create(FTreeList);
  if ARecordCount > 0 then
  begin
    PopulateDataSource(ARecordCount);
    FDataSource.DataChanged;
  end;
end;

{ === 4.1.1.1 AssignDataSource_NilDataSource_RaisesException === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_NilDataSource_RaisesException;
begin
  { Спецификация:
    - Вызвать FDataSet.AssignDataSource(nil, FTreeList).
    - Ожидание: EArgumentNilException с сообщением 'ADataSource must not be nil'.

    В реализации frxDevCustomDataSet.pas:
      if not Assigned(ADataSource) then
        raise EArgumentNilException.Create('ADataSource must not be nil');
      if not Assigned(ATreeList) then
        raise EArgumentNilException.Create('ATreeList must not be nil');

    Проверка ADataSource происходит первой, поэтому исключение будет
    выброшено ДО того, как FTreeList будет использован. }
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FDataSet.AssignDataSource(nil, FTreeList);
    end,
    EArgumentNilException,
    'ADataSource must not be nil',
    'При передаче nil в ADataSource должно быть выброшено EArgumentNilException'
  );

  { Дополнительная проверка: состояние DataSet не должно измениться.
    После провала валидации AssignDataSource не должен привязывать
    источник, и внутренние коллекции должны остаться пустыми. }
  Assert.AreEqual(0, FDataSet.FieldIndexes.Count,
    'FieldIndexes должен остаться пустым после провала валидации');
  Assert.AreEqual(0, FDataSet.FieldTypes.Count,
    'FieldTypes должен остаться пустым после провала валидации');
  Assert.IsFalse(Assigned(FDataSet.DataSource),
    'DataSource не должен быть привязан после провала валидации');
end;

{ === 4.1.1.2 AssignDataSource_NilTreeList_RaisesException === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_NilTreeList_RaisesException;
begin
  { Спецификация:
    - Вызвать FDataSet.AssignDataSource(FDataSource, nil).
    - Ожидание: EArgumentNilException с сообщением 'ATreeList must not be nil'. }
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), nil);
    end,
    EArgumentNilException,
    'ATreeList must not be nil',
    'При передаче nil в ATreeList должно быть выброшено EArgumentNilException'
  );

  { Дополнительная проверка: состояние DataSet не должно измениться. }
  Assert.AreEqual(0, FDataSet.FieldIndexes.Count,
    'FieldIndexes должен остаться пустым после провала валидации');
  Assert.AreEqual(0, FDataSet.FieldTypes.Count,
    'FieldTypes должен остаться пустым после провала валидации');
  Assert.IsFalse(Assigned(FDataSet.DataSource),
    'DataSource не должен быть привязан после провала валидации');
end;

{ === 4.1.1.3 AssignDataSource_BuildsFieldListFromColumns === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_BuildsFieldListFromColumns;
begin
  { Спецификация:
    - Подготовить TreeList с 3 видимыми колонками (ID, Name, Date).
    - Добавить хотя бы одну запись для определения типов.
    - Вызвать AssignDataSource.
    - Ожидание:
        Fields.Count = 3
        FieldIndexes.Count = 3
        FieldTypes.Count = 3
        Fields = [ID, Name, Date]
        FieldIndexes = [0, 1, 2]
        FieldTypes = [fftNumeric, fftString, fftDateTime] }

  // === Arrange ===
  var Col0 := FTreeList.CreateColumn;
  Col0.Caption.Text := 'ID';
  Col0.Visible := True;

  var Col1 := FTreeList.CreateColumn;
  Col1.Caption.Text := 'Name';
  Col1.Visible := True;

  var Col2 := FTreeList.CreateColumn;
  Col2.Caption.Text := 'Date';
  Col2.Visible := True;

  // Добавляем запись для определения типов полей.
  // BuildFieldListFromTreeList использует первую запись (RootHandle[0])
  // для вызова GetFieldType(I) на каждой колонке.
  PopulateDataSource(1);

  // === Act ===
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert: основные требования спецификации ===

  // 1. Fields.Count = 3
  Assert.AreEqual(3, FDataSet.Fields.Count,
    'Fields.Count должен быть 3 (3 видимые колонки)');

  // 2. FieldIndexes.Count = 3
  Assert.AreEqual(3, FDataSet.FieldIndexes.Count,
    'FieldIndexes.Count должен быть 3');

  // 3. FieldTypes.Count = 3
  Assert.AreEqual(3, FDataSet.FieldTypes.Count,
    'FieldTypes.Count должен быть 3');

  // === Assert: корректность имён полей ===
  Assert.AreEqual('ID', FDataSet.Fields[0], 'Fields[0] = ID');
  Assert.AreEqual('Name', FDataSet.Fields[1], 'Fields[1] = Name');
  Assert.AreEqual('Date', FDataSet.Fields[2], 'Fields[2] = Date');

  // === Assert: корректность маппинга индексов ===
  // FieldIndexes хранит индексы колонок TreeList для каждого поля.
  // Колонки имеют индексы 0, 1, 2 → FieldIndexes = [0, 1, 2].
  Assert.AreEqual(0, FDataSet.FieldIndexes[0], 'FieldIndexes[0] = 0 (колонка ID)');
  Assert.AreEqual(1, FDataSet.FieldIndexes[1], 'FieldIndexes[1] = 1 (колонка Name)');
  Assert.AreEqual(2, FDataSet.FieldIndexes[2], 'FieldIndexes[2] = 2 (колонка Date)');

  // === Assert: корректность типов полей ===
  // BuildFieldListFromTreeList определяет тип по GetFieldType первой записи:
  //   - COL_INTEGER (0) → varInteger → fftNumeric
  //   - COL_STRING  (1) → varUString → fftString
  //   - COL_DATE    (2) → varDate   → fftDateTime
  Assert.AreEqual(fftNumeric, FDataSet.FieldTypes[0],
    'FieldTypes[0] = fftNumeric (Integer)');
  Assert.AreEqual(fftString, FDataSet.FieldTypes[1],
    'FieldTypes[1] = fftString (string)');
  Assert.AreEqual(fftDateTime, FDataSet.FieldTypes[2],
    'FieldTypes[2] = fftDateTime (TDateTime)');

  // === Assert: DataSource и TreeList привязаны корректно ===
  Assert.AreSame(FDataSource, FDataSet.DataSource,
    'DataSource должен быть привязан к FDataSource');
  Assert.AreSame(FTreeList, FDataSet.TreeList,
    'TreeList должен быть привязан к FTreeList');
end;

{ === 4.1.1.4 AssignDataSource_HiddenColumn_Skipped === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_HiddenColumn_Skipped;
begin
  { Спецификация:
    - 4 колонки (3 видимые + 1 скрытая Visible=False).
    - Ожидание: Fields.Count = 3 (только видимые).
    - Имя скрытой колонки отсутствует в Fields. }

  // === Arrange ===
  PrepareColumns(3, True);  // 3 видимые + 1 скрытая 'Hidden'
  PopulateDataSource(1);

  Assert.AreEqual(4, FTreeList.ColumnCount,
    'В TreeList должно быть 4 колонки (3 видимые + 1 скрытая)');

  // === Act ===
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert ===
  Assert.AreEqual(3, FDataSet.Fields.Count,
    'Скрытая колонка не должна попасть в Fields (только 3 видимые)');
  Assert.AreEqual(3, FDataSet.FieldIndexes.Count,
    'FieldIndexes должен содержать только 3 индекса видимых колонок');
  Assert.AreEqual(3, FDataSet.FieldTypes.Count,
    'FieldTypes должен содержать только 3 типа видимых колонок');

  // Проверяем, что имени 'Hidden' нет в Fields
  var FoundHidden := False;
  for var I := 0 to FDataSet.Fields.Count - 1 do
    if FDataSet.Fields[I] = 'Hidden' then
      FoundHidden := True;
  Assert.IsFalse(FoundHidden,
    'Имя "Hidden" должно отсутствовать в Fields');

  // Проверяем, что видимые колонки на месте
  Assert.AreEqual('Col1', FDataSet.Fields[0], 'Fields[0] = Col1');
  Assert.AreEqual('Col2', FDataSet.Fields[1], 'Fields[1] = Col2');
  Assert.AreEqual('Col3', FDataSet.Fields[2], 'Fields[2] = Col3');

  // Проверяем, что индексы в FieldIndexes соответствуют видимым колонкам
  Assert.AreEqual(0, FDataSet.FieldIndexes[0], 'FieldIndexes[0] = 0 (Col1)');
  Assert.AreEqual(1, FDataSet.FieldIndexes[1], 'FieldIndexes[1] = 1 (Col2)');
  Assert.AreEqual(2, FDataSet.FieldIndexes[2], 'FieldIndexes[2] = 2 (Col3)');
  // Индекс 3 (Hidden) НЕ должен быть в FieldIndexes
end;

{ === 4.1.1.5 AssignDataSource_EmptyColumnCaption_GeneratesColN === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_EmptyColumnCaption_GeneratesColN;
begin
  { Спецификация:
    - 2 колонки с Caption.Text = ''.
    - Ожидание: Fields[0] = 'Col0', Fields[1] = 'Col1'.

    Источник логики в BuildFieldListFromTreeList:
      if FieldName = '' then
        FieldName := Format('Col%d', [I]);
    где I — индекс колонки в TreeList. }

  // === Arrange ===
  var Col0 := FTreeList.CreateColumn;
  Col0.Caption.Text := '';   // Пустой заголовок → авто-имя 'Col0'
  Col0.Visible := True;

  var Col1 := FTreeList.CreateColumn;
  Col1.Caption.Text := '';   // Пустой заголовок → авто-имя 'Col1'
  Col1.Visible := True;

  // Смешанный сценарий: добавим колонку с обычным именем посередине,
  // чтобы проверить, что авто-имена генерируются по индексу TreeList,
  // а не по порядковому номеру видимой колонки.
  var Col2 := FTreeList.CreateColumn;
  Col2.Caption.Text := 'ValidName';
  Col2.Visible := True;

  var Col3 := FTreeList.CreateColumn;
  Col3.Caption.Text := '';   // Пустой заголовок → авто-имя 'Col3'
  Col3.Visible := True;

  PopulateDataSource(1);

  // === Act ===
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert ===
  Assert.AreEqual(4, FDataSet.Fields.Count,
    'Все 4 видимые колонки должны быть в Fields');

  Assert.AreEqual('Col0', FDataSet.Fields[0],
    'Колонка 0 с пустым Caption получает авто-имя Col0');
  Assert.AreEqual('Col1', FDataSet.Fields[1],
    'Колонка 1 с пустым Caption получает авто-имя Col1');
  Assert.AreEqual('ValidName', FDataSet.Fields[2],
    'Колонка 2 с валидным Caption сохраняет имя ValidName');
  Assert.AreEqual('Col3', FDataSet.Fields[3],
    'Колонка 3 с пустым Caption получает авто-имя Col3');

  Assert.AreEqual(4, FDataSet.FieldIndexes.Count,
    'FieldIndexes должен содержать 4 индекса');
  Assert.AreEqual(4, FDataSet.FieldTypes.Count,
    'FieldTypes должен содержать 4 типа');
end;

{ === 4.1.1.6 AssignDataSource_DuplicateColumnNames_AddsSuffix === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_DuplicateColumnNames_AddsSuffix;
begin
  { Спецификация:
    - 2 колонки с одинаковым Caption.Text = 'Name'.
    - Ожидание: Fields[0] = 'Name', Fields[1] = 'Name_1'.

    Источник логики в BuildFieldListFromTreeList:
      if UsedNames.IndexOf(FieldName) >= 0 then
        FieldName := Format('%s_%d', [FieldName, I]);
    где I — индекс колонки в TreeList. }

  // === Arrange ===
  var Col0 := FTreeList.CreateColumn;
  Col0.Caption.Text := 'Name';
  Col0.Visible := True;

  var Col1 := FTreeList.CreateColumn;
  Col1.Caption.Text := 'Name';   // Дубликат → суффикс '_1'
  Col1.Visible := True;

  // Добавим третью колонку с тем же именем, чтобы проверить множественные дубликаты
  var Col2 := FTreeList.CreateColumn;
  Col2.Caption.Text := 'Name';   // Второй дубликат → суффикс '_2'
  Col2.Visible := True;

  PopulateDataSource(1);

  // === Act ===
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert ===
  Assert.AreEqual(3, FDataSet.Fields.Count,
    'Все 3 колонки должны быть в Fields');

  Assert.AreEqual('Name', FDataSet.Fields[0],
    'Первое вхождение "Name" сохраняет оригинальное имя');
  Assert.AreEqual('Name_1', FDataSet.Fields[1],
    'Второе вхождение "Name" получает суффикс "_1" (индекс колонки = 1)');
  Assert.AreEqual('Name_2', FDataSet.Fields[2],
    'Третье вхождение "Name" получает суффикс "_2" (индекс колонки = 2)');

  Assert.AreEqual(3, FDataSet.FieldIndexes.Count,
    'FieldIndexes должен содержать 3 индекса');
  Assert.AreEqual(0, FDataSet.FieldIndexes[0], 'FieldIndexes[0] = 0');
  Assert.AreEqual(1, FDataSet.FieldIndexes[1], 'FieldIndexes[1] = 1');
  Assert.AreEqual(2, FDataSet.FieldIndexes[2], 'FieldIndexes[2] = 2');

  Assert.AreEqual(3, FDataSet.FieldTypes.Count,
    'FieldTypes должен содержать 3 типа');
end;

{ === 4.1.1.7 AssignDataSource_ClearsPreviousState === }
procedure TfrxDevCustomDataSetFixture.AssignDataSource_ClearsPreviousState;
begin
  { Спецификация:
    - Привязать к источнику с 3 колонками.
    - Привязать повторно к другому TreeList с 2 колонками.
    - Ожидание:
        Fields.Count = 2 (не 3+2=5)
        FieldIndexes.Count = 2
        FieldTypes.Count = 2
    - FAdapters (кэш адаптеров) должен быть очищен.

    Источник логики в AssignDataSource:
      Close;
      FAdapters.Clear;
      FDataSource := ADataSource;
      FTreeList := ATreeList;
      BuildFieldListFromTreeList;

    BuildFieldListFromTreeList вызывает:
      Fields.Clear;
      FFieldIndexes.Clear;
      FFieldTypes.Clear; }

  // === Arrange: первая привязка с 3 колонками ===
  PrepareColumns(3, False);  // Col1, Col2, Col3
  PopulateDataSource(1);

  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  Assert.AreEqual(3, FDataSet.Fields.Count,
    'После первой привязки Fields.Count = 3');
  Assert.AreEqual(3, FDataSet.FieldIndexes.Count,
    'После первой привязки FieldIndexes.Count = 3');
  Assert.AreEqual(3, FDataSet.FieldTypes.Count,
    'После первой привязки FieldTypes.Count = 3');

  // === Arrange: подготовка второй привязки ===
  // Создаём второй TreeList с 2 колонками
  var TreeList2 := TcxVirtualTreeList.Create(nil);
  try
    var Col0 := TreeList2.CreateColumn;
    Col0.Caption.Text := 'NewCol1';
    Col0.Visible := True;

    var Col1 := TreeList2.CreateColumn;
    Col1.Caption.Text := 'NewCol2';
    Col1.Visible := True;

    // === Act: повторная привязка ===
    FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), TreeList2);

    // === Assert: старое состояние полностью очищено ===

    // 1. Fields.Count = 2 (не 3+2=5)
    Assert.AreEqual(2, FDataSet.Fields.Count,
      'После повторной привязки Fields.Count = 2 (старые 3 колонки очищены)');

    // 2. FieldIndexes.Count = 2
    Assert.AreEqual(2, FDataSet.FieldIndexes.Count,
      'После повторной привязки FieldIndexes.Count = 2');

    // 3. FieldTypes.Count = 2
    Assert.AreEqual(2, FDataSet.FieldTypes.Count,
      'После повторной привязки FieldTypes.Count = 2');

    // 4. Имена полей обновлены
    Assert.AreEqual('NewCol1', FDataSet.Fields[0],
      'Fields[0] = NewCol1 (из нового TreeList)');
    Assert.AreEqual('NewCol2', FDataSet.Fields[1],
      'Fields[1] = NewCol2 (из нового TreeList)');

    // 5. DataSource и TreeList привязаны к новым объектам
    Assert.AreSame(FDataSource, FDataSet.DataSource,
      'DataSource привязан к FDataSource');
    Assert.AreSame(TreeList2, FDataSet.TreeList,
      'TreeList привязан к новому TreeList2');

    // 6. Старых имён полей нет
    var FoundOld := False;
    for var I := 0 to FDataSet.Fields.Count - 1 do
      if (FDataSet.Fields[I] = 'Col1') or
         (FDataSet.Fields[I] = 'Col2') or
         (FDataSet.Fields[I] = 'Col3') then
        FoundOld := True;
    Assert.IsFalse(FoundOld,
      'Старые имена полей (Col1, Col2, Col3) должны отсутствовать после повторной привязки');
  finally
    FreeAndNil(TreeList2);
  end;
end;

{ ================================================================ }
{ 4.1.2 Навигация по записям (Navigation)                           }
{ ================================================================ }

{ === 4.1.2.1 Open_SetsCurrentIndexToMinusOne === }
procedure TfrxDevCustomDataSetFixture.Open_SetsCurrentIndexToMinusOne;
begin
  { Спецификация:
    - Вызвать Open на привязанном DataSet.
    - Ожидание: CurrentIndex = -1, CurrentNode = nil, FActiveAdapter = nil.

    Источник логики в frxDevCustomDataSet.pas:
      procedure TfrxDevCustomDataSet.Open;
      begin
        FCurrentIndex := -1;
        inherited;
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Act ===
  FDataSet.Open;

  // === Assert ===
  Assert.AreEqual(-1, FDataSet.CurrentIndex,
    'Open должен установить CurrentIndex = -1');
  Assert.IsNull(FDataSet.CurrentNode,
    'Open не должен устанавливать CurrentNode');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col1')),
    'Без First GetValue должен вернуть Null (FActiveAdapter = nil)');
end;

{ === 4.1.2.2 First_SetsCurrentIndexToZero === }
procedure TfrxDevCustomDataSetFixture.First_SetsCurrentIndexToZero;
begin
  { Спецификация:
    - Вызвать Open, First.
    - Ожидание: CurrentIndex = 0, CurrentNode = первый узел, FActiveAdapter не nil.

    Источник логики:
      procedure TfrxDevCustomDataSet.InternalFirst;
      begin
        FCurrentIndex := 0;
        if ... TotalCount > 0 then
        begin
          FCurrentNode := FTreeList.Root.getFirstChild;
          FDataSource.CalcNode := FCurrentNode;
          FActiveAdapter := GetAdapterForRecord(...);
        end;
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Act ===
  FDataSet.First;

  // === Assert ===
  Assert.AreEqual(0, FDataSet.CurrentIndex,
    'First должен установить CurrentIndex = 0');
  Assert.IsNotNull(FDataSet.CurrentNode,
    'First должен установить CurrentNode на первый узел');
  Assert.AreSame(FTreeList.Root.getFirstChild, FDataSet.CurrentNode,
    'CurrentNode должен быть первым дочерним узлом FTreeList.Root');
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('Col1')),
    'После First GetValue должен вернуть значение (FActiveAdapter не nil)');
end;

{ === 4.1.2.3 Next_IncrementsIndex === }
procedure TfrxDevCustomDataSetFixture.Next_IncrementsIndex;
var
  PrevNode, CurrNode: TcxTreeListNode;
begin
  { Спецификация:
    - После First: CurrentIndex = 0.
    - После 1-го Next: CurrentIndex = 1, CurrentNode ≠ предыдущий.
    - После 2-го Next: CurrentIndex = 2, CurrentNode ≠ предыдущий.

    Источник логики:
      procedure TfrxDevCustomDataSet.InternalNext;
      begin
        Inc(FCurrentIndex);
        if Assigned(FCurrentNode) then
          FCurrentNode := FCurrentNode.GetNext;
        ...
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  // === Assert: состояние после First ===
  Assert.AreEqual(0, FDataSet.CurrentIndex,
    'После First: CurrentIndex = 0');
  PrevNode := FDataSet.CurrentNode;
  Assert.IsNotNull(PrevNode, 'После First: CurrentNode не nil');

  // === Act: первый Next ===
  FDataSet.Next;

  // === Assert: состояние после первого Next ===
  Assert.AreEqual(1, FDataSet.CurrentIndex,
    'После первого Next: CurrentIndex = 1');
  CurrNode := FDataSet.CurrentNode;
  Assert.IsNotNull(CurrNode, 'После первого Next: CurrentNode не nil');
  Assert.AreNotSame(PrevNode, CurrNode,
    'Next должен перейти к следующему узлу');

  // === Act: второй Next ===
  PrevNode := CurrNode;
  FDataSet.Next;

  // === Assert: состояние после второго Next ===
  Assert.AreEqual(2, FDataSet.CurrentIndex,
    'После второго Next: CurrentIndex = 2');
  CurrNode := FDataSet.CurrentNode;
  Assert.IsNotNull(CurrNode, 'После второго Next: CurrentNode не nil (ещё есть узлы)');
  Assert.AreNotSame(PrevNode, CurrNode,
    'Второй Next должен перейти к следующему узлу');
end;

{ === 4.1.2.4 Eof_TrueWhenNoMoreNodes === }
procedure TfrxDevCustomDataSetFixture.Eof_TrueWhenNoMoreNodes;
begin
  { Спецификация:
    - Источник с 2 записями.
    - First → Eof = False.
    - Next (1) → Eof = False (вторая запись).
    - Next (2) → Eof = True (вышли за пределы).

    Источник логики:
      function TfrxDevCustomDataSet.InternalEof: Boolean;
      begin
        if not Assigned(FDataSource) or not Assigned(FDataSource.RootHandle) then
          Result := True
        else
          Result := not Assigned(FCurrentNode);
      end; }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Act + Assert: First ===
  FDataSet.First;
  Assert.IsFalse(FDataSet.Eof,
    'После First: Eof = False (на первой записи)');
  Assert.IsNotNull(FDataSet.CurrentNode,
    'После First: CurrentNode не nil');

  // === Act + Assert: первый Next ===
  FDataSet.Next;
  Assert.IsFalse(FDataSet.Eof,
    'После первого Next: Eof = False (на второй записи)');
  Assert.IsNotNull(FDataSet.CurrentNode,
    'После первого Next: CurrentNode не nil');

  // === Act + Assert: второй Next ===
  FDataSet.Next;
  Assert.IsTrue(FDataSet.Eof,
    'После второго Next: Eof = True (FCurrentNode = nil, вышли за пределы)');
  Assert.IsNull(FDataSet.CurrentNode,
    'После достижения конца: CurrentNode = nil');
end;

{ === 4.1.2.5 Eof_TrueWhenNoDataSource === }
procedure TfrxDevCustomDataSetFixture.Eof_TrueWhenNoDataSource;
begin
  { Спецификация:
    - Не вызывать AssignDataSource.
    - Ожидание: Eof = True.

    Источник логики:
      function TfrxDevCustomDataSet.InternalEof: Boolean;
      begin
        if not Assigned(FDataSource) ... then
          Result := True
        ...
      end; }
  Assert.IsTrue(FDataSet.Eof,
    'Без DataSource Eof должен вернуть True');
end;

{ === 4.1.2.6 RecordCount_ReturnsRootTotalCount === }
procedure TfrxDevCustomDataSetFixture.RecordCount_ReturnsRootTotalCount;
begin
  { Спецификация:
    - Привязать источник с 5 записями.
    - Ожидание: RecordCount = 5 = RootHandle.TotalCount.

    Источник логики:
      function TfrxDevCustomDataSet.RecordCount: Integer;
      begin
        if Assigned(FDataSource) and Assigned(FDataSource.RootHandle) then
          Result := FDataSource.RootHandle.TotalCount
        else
          Result := 0;
      end; }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(5);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert ===
  Assert.AreEqual(5, FDataSet.RecordCount,
    'RecordCount должен быть 5 (количество записей в FDataSource)');
  Assert.AreEqual(FDataSource.RootHandle.TotalCount, FDataSet.RecordCount,
    'RecordCount должен равняться RootHandle.TotalCount');
end;

{ === 4.1.2.7 Close_ResetsNavigationState === }
procedure TfrxDevCustomDataSetFixture.Close_ResetsNavigationState;
begin
  { Спецификация:
    - После Open + First вызвать Close.
    - Ожидание: CurrentIndex = -1, CurrentNode = nil, FActiveAdapter = nil.

    Источник логики:
      procedure TfrxDevCustomDataSet.Close;
      begin
        FCurrentIndex := -1;
        FActiveAdapter := nil;
        inherited;
      end; }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  // === Act ===
  FDataSet.Close;

  // === Assert ===
  Assert.AreEqual(-1, FDataSet.CurrentIndex,
    'Close должен установить CurrentIndex = -1');
  Assert.IsNull(FDataSet.CurrentNode,
    'Close должен сбросить CurrentNode');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col1')),
    'После Close GetValue должен вернуть Null (FActiveAdapter = nil)');
end;

{ === 4.1.2.8 First_OnEmptyDataSource_SetsNilAdapter === }
procedure TfrxDevCustomDataSetFixture.First_OnEmptyDataSource_SetsNilAdapter;
begin
  { Спецификация:
    - Источник без записей (только колонки в TreeList).
    - Ожидание: CurrentIndex = 0, CurrentNode = nil, Eof = True.

    Источник логики в InternalFirst:
      if ... TotalCount > 0 then
      begin
        FCurrentNode := ...;  // не выполняется
      end
      else
        FActiveAdapter := nil; }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(0);  // 0 записей
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Act ===
  FDataSet.First;

  // === Assert ===
  Assert.AreEqual(0, FDataSet.CurrentIndex,
    'First на пустом источнике устанавливает CurrentIndex = 0');
  Assert.IsNull(FDataSet.CurrentNode,
    'First на пустом источнике оставляет CurrentNode = nil');
  Assert.IsTrue(FDataSet.Eof,
    'First на пустом источнике: Eof = True (CurrentNode = nil)');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col1')),
    'First на пустом источнике: GetValue = Null (FActiveAdapter = nil)');
end;

{ === 4.1.2.9 RecordCount_NoDataSource_ReturnsZero === }
procedure TfrxDevCustomDataSetFixture.RecordCount_NoDataSource_ReturnsZero;
begin
  { Спецификация:
    - Не вызывать AssignDataSource.
    - Ожидание: RecordCount = 0. }
  Assert.AreEqual(0, FDataSet.RecordCount,
    'Без привязки RecordCount должен вернуть 0');
end;

{ === 4.1.2.10 First_MultipleCalls_ResetToBeginning === }
procedure TfrxDevCustomDataSetFixture.First_MultipleCalls_ResetToBeginning;
begin
  { Спецификация:
    - Open + First + Next + Next → CurrentIndex = 2.
    - Повторный First → CurrentIndex = 0, CurrentNode = первый узел. }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // Пройти вперёд по записям
  FDataSet.First;
  FDataSet.Next;
  FDataSet.Next;
  Assert.AreEqual(2, FDataSet.CurrentIndex,
    'После First + 2 Next: CurrentIndex = 2');

  // === Act ===
  FDataSet.First;

  // === Assert ===
  Assert.AreEqual(0, FDataSet.CurrentIndex,
    'Повторный First сбрасывает CurrentIndex в 0');
  Assert.AreSame(FTreeList.Root.getFirstChild, FDataSet.CurrentNode,
    'Повторный First устанавливает CurrentNode на первый узел');
end;

{ === 4.1.2.11 Next_AfterEof_NoException === }
procedure TfrxDevCustomDataSetFixture.Next_AfterEof_NoException;
begin
  { Спецификация:
    - Источник с 1 записью.
    - First → Next → Eof = True.
    - Повторный Next не должен вызывать исключений.
    - Eof остаётся True, CurrentNode остаётся nil. }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(1);  // 1 запись
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  FDataSet.First;
  Assert.IsFalse(FDataSet.Eof, 'После First: Eof = False (одна запись есть)');

  FDataSet.Next;
  Assert.IsTrue(FDataSet.Eof, 'После Next: Eof = True (запись кончилась)');
  Assert.IsNull(FDataSet.CurrentNode, 'После достижения Eof: CurrentNode = nil');

  // === Act: повторный Next ===
  Assert.WillNotRaise(
    procedure
    begin
      FDataSet.Next;
    end,
    Exception,
    'Next после Eof не должен вызывать исключений');

  // === Assert: состояние не ухудшилось ===
  Assert.IsTrue(FDataSet.Eof,
    'После повторного Next: Eof остаётся True');
  Assert.IsNull(FDataSet.CurrentNode,
    'После повторного Next: CurrentNode остаётся nil');
end;

{ ================================================================ }
{ 4.1.3 GetValue / GetDisplayText                                   }
{ ================================================================ }

{ === 4.1.3.1 GetValue_ReturnsNull_WhenNoActiveAdapter === }
procedure TfrxDevCustomDataSetFixture.GetValue_ReturnsNull_WhenNoActiveAdapter;
begin
  { Спецификация:
    - Open без First: FActiveAdapter остаётся nil.
    - Ожидание: GetValue для любого поля возвращает Null.

    Источник логики:
      function TfrxDevCustomDataSet.GetValue(Index: string): Variant;
      begin
        if Assigned(FActiveAdapter) then
          Result := FActiveAdapter.GetValue(Index)
        else
          Result := Null;  // ← этот путь
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Act: Open без First ===
  FDataSet.Open;

  // === Assert: состояние после Open ===
  Assert.AreEqual(-1, FDataSet.CurrentIndex,
    'После Open CurrentIndex = -1');
  Assert.IsNull(FDataSet.CurrentNode,
    'После Open CurrentNode = nil (First не вызван)');

  // === Assert: GetValue возвращает Null для всех полей ===
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col1')),
    'GetValue(Col1) без активного адаптера должен вернуть Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col2')),
    'GetValue(Col2) без активного адаптера должен вернуть Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col3')),
    'GetValue(Col3) без активного адаптера должен вернуть Null');
end;

{ === 4.1.3.2 GetDisplayText_ReturnsEmpty_WhenNoActiveAdapter === }
procedure TfrxDevCustomDataSetFixture.GetDisplayText_ReturnsEmpty_WhenNoActiveAdapter;
begin
  { Спецификация:
    - Open без First: FActiveAdapter остаётся nil.
    - Ожидание: GetDisplayText для любого поля возвращает '' (пустую строку).

    Источник логики:
      function TfrxDevCustomDataSet.GetDisplayText(Index: string): WideString;
      begin
        if Assigned(FActiveAdapter) then
          Result := FActiveAdapter.GetDisplayText(Index)
        else
          Result := '';  // ← пустая строка, не Null
      end;

    ВАЖНО: В отличие от GetValue (который возвращает Null),
    GetDisplayText всегда возвращает WideString, поэтому
    при отсутствии адаптера возвращается пустая строка. }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(3);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Assert: GetDisplayText возвращает '' для всех полей ===
  Assert.AreEqual('', string(FDataSet.GetDisplayText('Col1')),
    'GetDisplayText(Col1) без активного адаптера должен вернуть пустую строку');
  Assert.AreEqual('', string(FDataSet.GetDisplayText('Col2')),
    'GetDisplayText(Col2) без активного адаптера должен вернуть пустую строку');
  Assert.AreEqual('', string(FDataSet.GetDisplayText('Col3')),
    'GetDisplayText(Col3) без активного адаптера должен вернуть пустую строку');
end;

{ === 4.1.3.3 GetValue_CallsAdapterGetValue === }
procedure TfrxDevCustomDataSetFixture.GetValue_CallsAdapterGetValue;
var
  Rec: TMockRecord;
  V: Variant;
begin
  { Спецификация:
    - Создать 1 запись с конкретными значениями для 5 типов:
      Integer=42, String='Test', Date=2026-01-15, Boolean=True, Null=Null.
    - После Open + First проверить, что GetValue возвращает корректные
      значения и типы для каждого поля.

    Делегирование:
      TfrxDevCustomDataSet.GetValue(Index)
        → TVTRecordAdapter.GetValue(Index)
          → FFieldNames.IndexOf(Index) → ColIdx
          → FSource.GetValue(FFieldIndexes[ColIdx])
            → TMockRecord.GetValue(ColIdx) }

  // === Arrange: 5 колонок + 1 запись с конкретными значениями ===
  PrepareColumns(5);
  SetupForNavigation(0);  // создаём пустой DataSource с FTreeList

  // Вручную создаём запись с конкретными значениями
  Rec := TMockRecord(FDataSource.InsertRecordHandle(FDataSource.RootHandle, True));
  Rec.SetValue(TMockRecord.COL_INTEGER, 42);
  Rec.SetValue(TMockRecord.COL_STRING, 'Test');
  Rec.SetValue(TMockRecord.COL_DATE, EncodeDate(2026, 1, 15));
  Rec.SetValue(TMockRecord.COL_BOOLEAN, True);
  Rec.SetValue(TMockRecord.COL_NULL, Null);
  FDataSource.DataChanged;  // КРИТИЧНО: связывает запись с VCL-узлом

  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  // === Assert: Integer поле (Col1) ===
  V := FDataSet.GetValue('Col1');
  Assert.IsFalse(VarIsNull(V), 'GetValue(Col1) не должен быть Null');
  Assert.AreEqual(42, Integer(V), 'Integer значение = 42');
  Assert.AreEqual(varInteger, VarType(V), 'Тип Integer = varInteger');

  // === Assert: String поле (Col2) ===
  V := FDataSet.GetValue('Col2');
  Assert.IsFalse(VarIsNull(V), 'GetValue(Col2) не должен быть Null');
  Assert.AreEqual('Test', string(V), 'String значение = "Test"');
  Assert.IsTrue((VarType(V) = varString) or (VarType(V) = varUString),
    'Тип String = varString или varUString');

  // === Assert: Date поле (Col3) ===
  V := FDataSet.GetValue('Col3');
  Assert.IsFalse(VarIsNull(V), 'GetValue(Col3) не должен быть Null');
  Assert.AreEqual(EncodeDate(2026, 1, 15), TDateTime(V), 'Date значение = 2026-01-15');
  Assert.AreEqual(varDate, VarType(V), 'Тип Date = varDate');

  // === Assert: Boolean поле (Col4) ===
  V := FDataSet.GetValue('Col4');
  Assert.IsFalse(VarIsNull(V), 'GetValue(Col4) не должен быть Null');
  Assert.AreEqual(True, Boolean(V), 'Boolean значение = True');
  Assert.AreEqual(varBoolean, VarType(V), 'Тип Boolean = varBoolean');

  // === Assert: Null поле (Col5) ===
  V := FDataSet.GetValue('Col5');
  Assert.IsTrue(VarIsNull(V), 'GetValue(Col5) должен быть Null');
end;

{ === 4.1.3.4 GetDisplayText_CallsAdapterGetDisplayText === }
procedure TfrxDevCustomDataSetFixture.GetDisplayText_CallsAdapterGetDisplayText;
var
  Rec: TMockRecord;
  DateText: string;
begin
  { Спецификация:
    - Проверить форматирование значений в WideString:
      Integer 42 → '42'
      String 'Test' → 'Test' (прямая передача)
      Date 2026-01-15 → строковое представление (зависит от локали)
      Boolean True → 'True' (через BoolToStr)
      Null → '' (пустая строка)

    Источник логики:
      function TVTRecordAdapter.GetDisplayText(Index: string): WideString;
      var V: Variant;
      begin
        V := GetValue(Index);
        if VarIsNull(V) then
          Result := ''
        else if VarIsStr(V) then
          Result := V  // прямая передача строк
        else if VarType(V) = varBoolean then
          Result := BoolToStr(Boolean(V), True)  // 'True' / 'False'
        else
          Result := VarToWideStr(V);  // Integer, Date и т.д.
      end; }

  // === Arrange: 5 колонок + 1 запись с конкретными значениями ===
  PrepareColumns(5);
  SetupForNavigation(0);

  Rec := TMockRecord(FDataSource.InsertRecordHandle(FDataSource.RootHandle, True));
  Rec.SetValue(TMockRecord.COL_INTEGER, 42);
  Rec.SetValue(TMockRecord.COL_STRING, 'Test');
  Rec.SetValue(TMockRecord.COL_DATE, EncodeDate(2026, 1, 15));
  Rec.SetValue(TMockRecord.COL_BOOLEAN, True);
  Rec.SetValue(TMockRecord.COL_NULL, Null);
  FDataSource.DataChanged;

  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  // === Assert: Integer → '42' (через VarToWideStr) ===
  Assert.AreEqual('42', string(FDataSet.GetDisplayText('Col1')),
    'Integer 42 → "42"');

  // === Assert: String → 'Test' (прямая передача через VarIsStr) ===
  Assert.AreEqual('Test', string(FDataSet.GetDisplayText('Col2')),
    'String "Test" → "Test" (без изменений)');

  // === Assert: Date → непустая строка (формат зависит от локали) ===
  DateText := string(FDataSet.GetDisplayText('Col3'));
  Assert.IsTrue(Length(DateText) > 0,
    'Date должен быть преобразован в непустую строку');

  // === Assert: Boolean True → 'True' (через BoolToStr(V, True)) ===
  Assert.AreEqual('True', string(FDataSet.GetDisplayText('Col4')),
    'Boolean True → "True" (через BoolToStr)');

  // === Assert: Null → '' (пустая строка через VarIsNull) ===
  Assert.AreEqual('', string(FDataSet.GetDisplayText('Col5')),
    'Null → "" (пустая строка)');
end;

{ === 4.1.3.5 GetValue_UnknownField_ReturnsNull === }
procedure TfrxDevCustomDataSetFixture.GetValue_UnknownField_ReturnsNull;
begin
  { Спецификация:
    - Вызвать GetValue для несуществующего поля.
    - Ожидание: Null.

    Источник логики в TVTRecordAdapter.GetValue:
      Result := Null;  // начальное значение
      ColIdx := FFieldNames.IndexOf(Index);
      if (ColIdx >= 0) and (ColIdx < FFieldIndexes.Count) then
        Result := FSource.GetValue(FFieldIndexes[ColIdx]);
      // Если IndexOf вернул -1, условие не выполняется,
      // и Result остаётся Null.

    ВАЖНО: TStringList.IndexOf по умолчанию case-INSENSITIVE
    (CaseSensitive=False), поэтому поиск имён полей не зависит
    от регистра. Только действительно несуществующее имя
    возвращает Null. }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(1);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  // === Assert: существующие поля возвращают значения ===
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('Col1')),
    'Существующее поле Col1 должно вернуть значение');
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('Col2')),
    'Существующее поле Col2 должно вернуть значение');
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('Col3')),
    'Существующее поле Col3 должно вернуть значение');

  // === Assert: поиск case-insensitive (разный регистр = одно поле) ===
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('col1')),
    'Поиск case-insensitive: "col1" находит поле "Col1"');
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('COL1')),
    'Поиск case-insensitive: "COL1" находит поле "Col1"');
  Assert.IsFalse(VarIsNull(FDataSet.GetValue('cOl2')),
    'Поиск case-insensitive: "cOl2" находит поле "Col2"');

  // === Assert: несуществующие поля возвращают Null ===
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('NonExistentField')),
    'Несуществующее поле должно вернуть Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col99')),
    'Несуществующее поле Col99 должно вернуть Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('')),
    'Пустое имя поля должно вернуть Null');
end;

{ === 4.1.3.6 GetFieldType_ReturnsCorrectType === }
procedure TfrxDevCustomDataSetFixture.GetFieldType_ReturnsCorrectType;
begin
  { Спецификация:
    - Проверить маппинг VarType → TfrxFieldType:
      varInteger → fftNumeric
      varString/varUString → fftString
      varDate → fftDateTime
      varBoolean → fftBoolean
      0 (Null) → fftString (default)
    - Неизвестное поле → fftString (default).

    Источник логики в BuildFieldListFromTreeList:
      case SourceType of
        varInteger, varSmallInt, varInt64, varCurrency: FFieldTypes.Add(fftNumeric);
        varSingle, varDouble: FFieldTypes.Add(fftNumeric);
        varDate: FFieldTypes.Add(fftDateTime);
        varBoolean: FFieldTypes.Add(fftBoolean);
      else
        FFieldTypes.Add(fftString);
      end;

    И в FieldType:
      Result := fftString;  // default
      I := FieldIndex(FieldName);
      if (I >= 0) and (I < FFieldTypes.Count) then
        Result := FFieldTypes[I];
    Для неизвестного поля FieldIndex возвращает -1, и Result остаётся fftString. }

  // === Arrange: 5 колонок + 1 запись ===
  PrepareColumns(5);
  SetupForNavigation(1);  // создаёт запись со всеми 5 типами
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  // === Assert: типы полей ===
  Assert.AreEqual(fftNumeric, FDataSet.GetFieldType('Col1'),
    'Integer → fftNumeric');
  Assert.AreEqual(fftString, FDataSet.GetFieldType('Col2'),
    'string → fftString');
  Assert.AreEqual(fftDateTime, FDataSet.GetFieldType('Col3'),
    'TDateTime → fftDateTime');
  Assert.AreEqual(fftBoolean, FDataSet.GetFieldType('Col4'),
    'Boolean → fftBoolean');
  Assert.AreEqual(fftString, FDataSet.GetFieldType('Col5'),
    'Null → fftString (default)');

  // === Assert: неизвестное поле → fftString (default) ===
  Assert.AreEqual(fftString, FDataSet.GetFieldType('NonExistent'),
    'Неизвестное поле → fftString (default)');
end;

{ === 4.1.3.7 GetValue_AfterNext_ReturnsNextRecordValues === }
procedure TfrxDevCustomDataSetFixture.GetValue_AfterNext_ReturnsNextRecordValues;
begin
  { Спецификация:
    - Источник с 2 записями: ID=1 и ID=2.
    - First → GetValue(Col1) = 1.
    - Next → GetValue(Col1) = 2 (значения изменились).
    - Активный адаптер сменяется на адаптер второй записи.

    Это проверяет, что InternalNext корректно вызывает
    GetAdapterForRecord для новой записи. }

  // === Arrange ===
  PrepareColumns(2);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Act + Assert: First → запись 1 ===
  FDataSet.First;
  Assert.AreEqual(1, Integer(FDataSet.GetValue('Col1')),
    'После First: первая запись, Col1 = 1');
  Assert.AreEqual('Record_1', string(FDataSet.GetValue('Col2')),
    'После First: первая запись, Col2 = "Record_1"');

  // === Act + Assert: Next → запись 2 ===
  FDataSet.Next;
  Assert.AreEqual(2, Integer(FDataSet.GetValue('Col1')),
    'После Next: вторая запись, Col1 = 2');
  Assert.AreEqual('Record_2', string(FDataSet.GetValue('Col2')),
    'После Next: вторая запись, Col2 = "Record_2"');
end;

{ === 4.1.3.8 GetValue_EmptyDataSource_ReturnsNull === }
procedure TfrxDevCustomDataSetFixture.GetValue_EmptyDataSource_ReturnsNull;
begin
  { Спецификация:
    - Источник без записей (только колонки в TreeList).
    - First не может установить FActiveAdapter, т.к. в InternalFirst
      условие TotalCount > 0 не выполнено.
    - Ожидание: GetValue возвращает Null.

    Источник логики:
      procedure TfrxDevCustomDataSet.InternalFirst;
      begin
        FCurrentIndex := 0;
        if ... and (FDataSource.RootHandle.TotalCount > 0) then
        begin
          FCurrentNode := FTreeList.Root.getFirstChild;
          FActiveAdapter := GetAdapterForRecord(...);  // не выполняется
        end
        else
          FActiveAdapter := nil;  // ← этот путь
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(0);  // 0 записей
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;

  // === Act ===
  FDataSet.First;

  // === Assert ===
  Assert.AreEqual(0, FDataSet.CurrentIndex,
    'First на пустом источнике: CurrentIndex = 0');
  Assert.IsNull(FDataSet.CurrentNode,
    'First на пустом источнике: CurrentNode = nil (нет дочерних узлов)');
  Assert.IsTrue(FDataSet.Eof,
    'First на пустом источнике: Eof = True');

  // === Assert: GetValue возвращает Null (FActiveAdapter = nil) ===
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col1')),
    'First на пустом источнике: GetValue(Col1) = Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col2')),
    'First на пустом источнике: GetValue(Col2) = Null');
  Assert.IsTrue(VarIsNull(FDataSet.GetValue('Col3')),
    'First на пустом источнике: GetValue(Col3) = Null');

  // === Assert: GetDisplayText возвращает '' (пустую строку) ===
  Assert.AreEqual('', string(FDataSet.GetDisplayText('Col1')),
    'First на пустом источнике: GetDisplayText(Col1) = ""');
end;

{ ================================================================ }
{ 4.1.4 Адаптер записи (Master-Detail)                             }
{ ================================================================ }

{ === 4.1.4.1 GetAdapterForRecord_CreatesNew_IfNotExists === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_CreatesNew_IfNotExists;
var
  Rec1: TVTBaseRecord;
  Adapter: TVTRecordAdapter;
begin
  { Спецификация:
    - Первый вызов GetAdapterForRecord для новой записи должен создать
      новый адаптер и привязать его к исходной записи через SourceRecord.
    - Адаптер помещается в кэш FAdapters.

    Источник логики в frxDevCustomDataSet.pas:
      function TfrxDevCustomDataSet.GetAdapterForRecord(ARecord): TVTRecordAdapter;
      begin
        for Adapter in FAdapters do
          if Adapter.SourceRecord = ARecord then
            Exit(Adapter);   // <- кэш
        // Создание нового адаптера
        ...
        Result := TVTRecordAdapter.Create(Self, ARecord, FieldNames,
          FieldIndexes, FFieldTypes);
        FAdapters.Add(Result);  // <- добавление в кэш
      end; }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  Rec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  Assert.IsNotNull(Rec1, 'Текущая запись должна существовать');

  // === Act ===
  Adapter := FDataSet.GetAdapterForRecord(Rec1);

  // === Assert ===
  Assert.IsNotNull(Adapter,
    'GetAdapterForRecord должен создать адаптер');
  Assert.AreSame(Rec1, Adapter.SourceRecord,
    'Адаптер должен быть привязан к исходной записи через SourceRecord');
end;

{ === 4.1.4.2 GetAdapterForRecord_ReturnsExisting_IfExists === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_ReturnsExisting_IfExists;
var
  Rec1: TVTBaseRecord;
  Adapter1, Adapter2: TVTRecordAdapter;
begin
  { Спецификация:
    - Повторное обращение к той же записи должно вернуть ТОТ ЖЕ объект
      адаптера (из кэша FAdapters), а не создать новый.
    - Это критично для Master-Detail: при повторном обращении к
      детальным данным не должно создаваться дубликатов адаптеров.

    Источник логики (поиск в кэше):
      for Adapter in FAdapters do
        if Adapter.SourceRecord = ARecord then
          Exit(Adapter);  // <- возврат существующего, без создания нового }

  // === Arrange ===
  PrepareColumns(3);
  SetupForNavigation(1);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  Rec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));

  // === Act: два обращения к одной записи ===
  Adapter1 := FDataSet.GetAdapterForRecord(Rec1);
  Adapter2 := FDataSet.GetAdapterForRecord(Rec1);

  // === Assert: кэш работает ===
  Assert.IsNotNull(Adapter1, 'Первый адаптер создан');
  Assert.IsNotNull(Adapter2, 'Второй адаптер получен');
  Assert.AreSame(Adapter1, Adapter2,
    'Повторное обращение должно вернуть ТОТ ЖЕ адаптер (кэш работает)');
end;

{ === 4.1.4.3 GetAdapterForRecord_DifferentRecords_DifferentAdapters === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_DifferentRecords_DifferentAdapters;
var
  Rec1, Rec2: TVTBaseRecord;
  Adapter1, Adapter2: TVTRecordAdapter;
begin
  { Спецификация:
    - Разные записи должны получить разные адаптеры (AreNotSame).
    - Каждый адаптер привязан к своей записи через SourceRecord.
    - В кэше FAdapters появляются два разных объекта.

    Это основа семантики Master-Detail: главная запись и детальная
    запись имеют свои собственные адаптеры с одинаковыми полями,
    но работающие с разными данными. }

  // === Arrange: 2 записи в источнике ===
  PrepareColumns(2);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  Rec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  FDataSet.Next;
  Rec2 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));

  Assert.AreNotSame(Rec1, Rec2,
    'Записи должны быть разными объектами');

  // === Act: адаптеры для каждой записи ===
  Adapter1 := FDataSet.GetAdapterForRecord(Rec1);
  Adapter2 := FDataSet.GetAdapterForRecord(Rec2);

  // === Assert: разные адаптеры для разных записей ===
  Assert.IsNotNull(Adapter1, 'Adapter1 создан для первой записи');
  Assert.IsNotNull(Adapter2, 'Adapter2 создан для второй записи');
  Assert.AreNotSame(Adapter1, Adapter2,
    'Разные записи должны иметь РАЗНЫЕ адаптеры');
  Assert.AreSame(Rec1, Adapter1.SourceRecord,
    'Adapter1 привязан к Rec1');
  Assert.AreSame(Rec2, Adapter2.SourceRecord,
    'Adapter2 привязан к Rec2');
end;

{ === 4.1.4.4 GetAdapterForRecord_PreservesFieldMetadata === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_PreservesFieldMetadata;
var
  Col: TcxTreeListColumn;
  Rec1: TVTBaseRecord;
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Адаптер должен получить КОПИЮ метаданных полей из DataSet:
      FieldNames, FieldIndexes, FieldTypes.
    - Важно, что это именно копии (адаптер владеет своими коллекциями),
      а не ссылки на коллекции DataSet. Это обеспечивает изоляцию
      Master-Detail: изменение DataSet после создания адаптера не
      должно влиять на адаптер.

    Источник логики (TVTRecordAdapter.Create):
      FFieldNames := TStringList.Create;
      FFieldIndexes := TList<Integer>.Create;
      FFieldTypes := TList<TfrxFieldType>.Create;
      if Assigned(AFieldNames) then
        FFieldNames.Assign(AFieldNames);        // <- КОПИЯ имён
      if Assigned(AFieldIndexes) then
        FFieldIndexes.AddRange(AFieldIndexes);  // <- КОПИЯ индексов
      if Assigned(AFieldTypes) then
        FFieldTypes.AddRange(AFieldTypes);      // <- КОПИЯ типов

    Для проверки коллекций используем TTestTVTRecordAdapter
    (реэкспорт protected-свойств). }

  // === Arrange: 3 колонки разных типов ===
  Col := FTreeList.CreateColumn;
  Col.Caption.Text := 'ID';
  Col.Visible := True;

  Col := FTreeList.CreateColumn;
  Col.Caption.Text := 'Name';
  Col.Visible := True;

  Col := FTreeList.CreateColumn;
  Col.Caption.Text := 'Date';
  Col.Visible := True;

  SetupForNavigation(1);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  Rec1 := TVTBaseRecord(FDataSource.Obj(FTreeList.Root.getFirstChild));
  Assert.IsNotNull(Rec1, 'Запись должна существовать');

  // === Act ===
  Adapter := TTestTVTRecordAdapter(FDataSet.GetAdapterForRecord(Rec1));

  // === Assert: FieldNames скопирован из FDataSet.Fields ===
  Assert.AreEqual(3, Adapter.FieldNames.Count,
    'Adapter.FieldNames.Count = 3 (скопировано из DataSet)');
  Assert.AreEqual('ID', Adapter.FieldNames[0],
    'FieldNames[0] = ID');
  Assert.AreEqual('Name', Adapter.FieldNames[1],
    'FieldNames[1] = Name');
  Assert.AreEqual('Date', Adapter.FieldNames[2],
    'FieldNames[2] = Date');

  // === Assert: FieldIndexes скопирован из FDataSet.FieldIndexes ===
  Assert.AreEqual(3, Adapter.FieldIndexes.Count,
    'Adapter.FieldIndexes.Count = 3');
  Assert.AreEqual(0, Adapter.FieldIndexes[0],
    'FieldIndexes[0] = 0 (колонка ID)');
  Assert.AreEqual(1, Adapter.FieldIndexes[1],
    'FieldIndexes[1] = 1 (колонка Name)');
  Assert.AreEqual(2, Adapter.FieldIndexes[2],
    'FieldIndexes[2] = 2 (колонка Date)');

  // === Assert: FieldTypes скопирован из FDataSet.FieldTypes ===
  Assert.AreEqual(3, Adapter.FieldTypes.Count,
    'Adapter.FieldTypes.Count = 3');
  Assert.AreEqual(fftNumeric, Adapter.FieldTypes[0],
    'FieldTypes[0] = fftNumeric (Integer)');
  Assert.AreEqual(fftString, Adapter.FieldTypes[1],
    'FieldTypes[1] = fftString (string)');
  Assert.AreEqual(fftDateTime, Adapter.FieldTypes[2],
    'FieldTypes[2] = fftDateTime (TDateTime)');

  // === Assert: адаптер владеет СВОИМИ коллекциями (не ссылками на DataSet) ===
  Assert.AreNotSame(FDataSet.FieldIndexes, Adapter.FieldIndexes,
    'Adapter должен владеть СВОЕЙ копией FieldIndexes, не ссылкой на DataSet');
  Assert.AreNotSame(FDataSet.FieldTypes, Adapter.FieldTypes,
    'Adapter должен владеть СВОЕЙ копией FieldTypes, не ссылкой на DataSet');
end;

{ === 4.1.4.5 GetAdapterForRecord_RecordCount_AlwaysOne === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_RecordCount_AlwaysOne;
var
  Rec1, Rec2: TVTBaseRecord;
  Adapter1, Adapter2: TVTRecordAdapter;
begin
  { Спецификация:
    - RecordCount адаптера ВСЕГДА возвращает 1 (семантика
      "одна запись на адаптер").
    - Это не зависит от количества записей в DataSet.
    - Adapter.RecordCount (1) не равно DataSet.RecordCount (N).

    Источник логики (TVTRecordAdapter.RecordCount):
      function TVTRecordAdapter.RecordCount: Integer;
      begin
        Result := 1;  // Адаптер всегда представляет одну запись
      end; }

    {Это важно для Master-Detail: FastReport ожидает, что детальный
    DataSet (адаптер одной записи) имеет RecordCount = 1. }

  // === Arrange: источник с 5 записями ===
  PrepareColumns(2);
  SetupForNavigation(5);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  Rec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  Adapter1 := FDataSet.GetAdapterForRecord(Rec1);

  // === Assert: RecordCount = 1 для первого адаптера ===
  Assert.AreEqual(1, Adapter1.RecordCount,
    'Adapter1.RecordCount всегда = 1 (одна запись на адаптер)');

  // === Assert: RecordCount = 1 для второго адаптера ===
  FDataSet.Next;
  Rec2 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  Adapter2 := FDataSet.GetAdapterForRecord(Rec2);
  Assert.AreEqual(1, Adapter2.RecordCount,
    'Adapter2.RecordCount тоже = 1 (не зависит от RecordCount в DataSet)');

  // === Assert: DataSet.RecordCount отличается (5 записей) ===
  Assert.AreEqual(5, FDataSet.RecordCount,
    'DataSet.RecordCount = 5 (количество записей в источнике)');
  Assert.AreNotEqual(FDataSet.RecordCount, Adapter1.RecordCount,
    'RecordCount адаптера (1) отличается от RecordCount DataSet (5)');
end;

{ === 4.1.4.6 GetAdapterForRecord_Navigation_OneRecordLifecycle === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_Navigation_OneRecordLifecycle;
var
  Rec1: TVTBaseRecord;
  Adapter: TVTRecordAdapter;
begin
  { Спецификация:
    - Проверить полный жизненный цикл навигации адаптера:
      Open -> First (Eof=False) -> Next (Eof=True) -> повторный Next.
    - Так как адаптер представляет одну запись, после First+Next
      уже достигается конец набора (Eof=True).
    - Повторный Next не должен вызывать исключений.

    Источник логики (TVTRecordAdapter.Next):
      procedure TVTRecordAdapter.Next;
      begin
        Inc(FCurrentRecNo);
        FEofFlag := FCurrentRecNo >= 1;  // Одна запись на адаптер
        ...
      end; }

  // === Arrange: 1 запись, адаптер для неё ===
  PrepareColumns(2);
  SetupForNavigation(1);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  Rec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  Adapter := FDataSet.GetAdapterForRecord(Rec1);

  // === Assert: исходное состояние (до навигации адаптера) ===
  Assert.IsFalse(Adapter.Eof,
    'До Open/First адаптера: Eof = False (сброс в конструкторе)');

  // === Act: Open адаптера ===
  Adapter.Open;
  Assert.IsFalse(Adapter.Eof,
    'После Open адаптера: Eof = False');

  // === Act: First адаптера ===
  Adapter.First;
  Assert.IsFalse(Adapter.Eof,
    'После First адаптера: Eof = False (на единственной записи)');

  // === Assert: GetValue работает на записи ===
  Assert.IsFalse(VarIsNull(Adapter.GetValue('Col1')),
    'После First адаптера: GetValue возвращает значение (на записи)');

  // === Act: Next (переход за пределы одной записи) ===
  Adapter.Next;

  // === Assert: Eof = True ===
  Assert.IsTrue(Adapter.Eof,
    'После Next: Eof = True (запись кончилась, FCurrentRecNo >= 1)');

  // === Act: повторный Next (должен быть безопасным) ===
  Assert.WillNotRaise(
    procedure
    begin
      Adapter.Next;
    end,
    Exception,
    'Повторный Next после Eof не должен вызывать исключений');

  // === Assert: Eof остаётся True ===
  Assert.IsTrue(Adapter.Eof,
    'После повторного Next: Eof остаётся True');
end;

{ === 4.1.4.7 GetAdapterForRecord_GetValue_DelegatesToSource === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_GetValue_DelegatesToSource;
var
  Col: TcxTreeListColumn;
  Rec: TMockRecord;
  Adapter: TVTRecordAdapter;
  V, V_lower: Variant;
begin
  { Спецификация:
    - Adapter.GetValue должен делегировать вызов исходной записи
      (через FFieldNames.IndexOf -> FFieldIndexes[ColIdx] -> FSource.GetValue).
    - Значения и типы вариантов сохраняются.
    - Поиск имён полей case-insensitive (TStringList.CaseSensitive=False
      по умолчанию): 'ID' и 'id' эквивалентны.

    Источник логики (TVTRecordAdapter.GetValue):
      ColIdx := FFieldNames.IndexOf(Index);
      if (ColIdx >= 0) and (ColIdx < FFieldIndexes.Count) then
        Result := FSource.GetValue(FFieldIndexes[ColIdx]); }

  // === Arrange: 2 колонки, 1 запись с конкретными значениями ===
  Col := FTreeList.CreateColumn;
  Col.Caption.Text := 'ID';
  Col.Visible := True;

  Col := FTreeList.CreateColumn;
  Col.Caption.Text := 'Name';
  Col.Visible := True;

  SetupForNavigation(0);  // создаём пустой источник
  Rec := TMockRecord(FDataSource.InsertRecordHandle(FDataSource.RootHandle, True));
  Rec.SetValue(TMockRecord.COL_INTEGER, 42);
  Rec.SetValue(TMockRecord.COL_STRING, 'Test');
  FDataSource.DataChanged;  // КРИТИЧНО: связывает запись с VCL-узлом

  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);

  Adapter := FDataSet.GetAdapterForRecord(Rec);
  Adapter.Open;
  Adapter.First;

  // === Assert: GetValue возвращает значения записи ===

  // Integer поле
  V := Adapter.GetValue('ID');
  Assert.IsFalse(VarIsNull(V), 'GetValue(ID) не Null');
  Assert.AreEqual(42, Integer(V), 'GetValue(ID) = 42');
  Assert.AreEqual(varInteger, VarType(V), 'Тип ID = varInteger');

  // String поле
  V := Adapter.GetValue('Name');
  Assert.IsFalse(VarIsNull(V), 'GetValue(Name) не Null');
  Assert.AreEqual('Test', string(V), 'GetValue(Name) = "Test"');
  Assert.IsTrue((VarType(V) = varString) or (VarType(V) = varUString),
    'Тип Name = varString/varUString');

  // === Assert: поиск case-insensitive ===
  V_lower := Adapter.GetValue('id');
  Assert.IsFalse(VarIsNull(V_lower),
    'GetValue(id) работает (case-insensitive)');
  Assert.AreEqual(42, Integer(V_lower),
    'GetValue(id) = 42 (как и GetValue(ID))');

  V_lower := Adapter.GetValue('NAME');
  Assert.IsFalse(VarIsNull(V_lower),
    'GetValue(NAME) работает (case-insensitive)');
  Assert.AreEqual('Test', string(V_lower),
    'GetValue(NAME) = "Test" (как и GetValue(Name))');

  // === Assert: несуществующее поле -> Null ===
  Assert.IsTrue(VarIsNull(Adapter.GetValue('NonExistent')),
    'Несуществующее поле возвращает Null');
end;

{ === 4.1.4.8 GetAdapterForRecord_CacheClearedOnReassign === }
procedure TfrxDevCustomDataSetFixture.GetAdapterForRecord_CacheClearedOnReassign;
var
  NewDataSource: TVTLoadAllDataSource<TMockRecord>;
  NewRec: TMockRecord;
  NewAdapter1, NewAdapter2: TVTRecordAdapter;
begin
  // === Arrange: первая привязка с 2 записями ===
  PrepareColumns(2);
  SetupForNavigation(2);
  FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
  FDataSet.Open;
  FDataSet.First;

  var OldRec1 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));
  FDataSet.Next;
  var OldRec2 := TVTBaseRecord(FDataSource.Obj(FDataSet.CurrentNode));

  // Создаём адаптеры для проверки кэша (не сохраняем ссылки на после Clear)
  FDataSet.GetAdapterForRecord(OldRec1);
  FDataSet.GetAdapterForRecord(OldRec2);

  // === Assert: кэш содержит 2 адаптера ===
  // Используем косвенную проверку: повторный запрос возвращает те же объекты
  var CheckAdapter := FDataSet.GetAdapterForRecord(OldRec1);
  Assert.IsNotNull(CheckAdapter, 'Кэш работает: адаптер возвращается из кэша');

  // === Act: повторная привязка к НОВОМУ источнику ===
  NewDataSource := TVTLoadAllDataSource<TMockRecord>.Create(FTreeList);
  try
    NewRec := TMockRecord(NewDataSource.InsertRecordHandle(
      NewDataSource.RootHandle, True));
    NewRec.SetValue(TMockRecord.COL_INTEGER, 999);
    NewDataSource.DataChanged;

    FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(NewDataSource), FTreeList);

    // === Assert: кэш полностью очищен ===
    // После AssignDataSource новые адаптеры для новых записей создаются заново
    NewAdapter1 := FDataSet.GetAdapterForRecord(NewRec);
    NewAdapter2 := FDataSet.GetAdapterForRecord(NewRec);

    Assert.IsNotNull(NewAdapter1, 'Новый адаптер создан');
    Assert.AreSame(NewAdapter1, NewAdapter2,
      'Кэш работает: повторный запрос возвращает тот же адаптер');
    Assert.AreSame(NewRec, NewAdapter1.SourceRecord,
      'Новый адаптер привязан к новой записи');

    // === Assert: новый адаптер содержит значения новой записи ===
    NewAdapter1.Open;
    NewAdapter1.First;
    Assert.AreEqual(999, Integer(NewAdapter1.GetValue('Col1')),
      'Новый адаптер работает с данными нового источника');
  finally
    FreeAndNil(NewDataSource);
  end;
end;

{ ================================================================ }
{ TfrxDevCustomDataSetAdapterFixture implementation                }
{ ================================================================ }

procedure TfrxDevCustomDataSetAdapterFixture.PrepareMetadata;
begin
  FFieldNames.AddStrings(['ID', 'Name', 'Date']);
  FFieldIndexes.AddRange([TMockRecord.COL_INTEGER,
                          TMockRecord.COL_STRING,
                          TMockRecord.COL_DATE]);
  FFieldTypes.AddRange([fftNumeric, fftString, fftDateTime]);
end;

procedure TfrxDevCustomDataSetAdapterFixture.Setup;
begin
  { Создаём минимальную инфраструктуру: одну запись и метаданные.
    VCL-инициализация НЕ требуется (тесты полностью автономны).
    TcxVirtualTreeList и TfrxDevCustomDataSet не используются. }
  FSource := TMockRecord.Create(nil);
  FFieldNames := TStringList.Create;
  FFieldIndexes := TList<Integer>.Create;
  FFieldTypes := TList<TfrxFieldType>.Create;

  { Заполняем стандартными метаданными для большинства тестов. }
  PrepareMetadata;

  { Инициализируем запись конкретными значениями. }
  FSource.SetValue(TMockRecord.COL_INTEGER, 42);
  FSource.SetValue(TMockRecord.COL_STRING, 'Test');
  FSource.SetValue(TMockRecord.COL_DATE, EncodeDate(2026, 1, 15));
  FSource.SetValue(TMockRecord.COL_BOOLEAN, True);
  FSource.SetValue(TMockRecord.COL_NULL, Null);
end;

procedure TfrxDevCustomDataSetAdapterFixture.TearDown;
begin
  { Освобождаем в обратном порядке.
    ВАЖНО: TVTRecordAdapter при создании делает КОПИИ коллекций
    (через Assign/AddRange), поэтому он владеет своими копиями,
    а не нашими FFieldNames/FFieldIndexes/FFieldTypes.
    Наши коллекции освобождаем мы сами. }
  FreeAndNil(FFieldTypes);
  FreeAndNil(FFieldIndexes);
  FreeAndNil(FFieldNames);
  FreeAndNil(FSource);
end;

{ === 4.2.1.1 Create_InitializesFieldsCorrectly === }
procedure TfrxDevCustomDataSetAdapterFixture.Create_InitializesFieldsCorrectly;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Конструктор TVTRecordAdapter.Create(AOwner, ASource, AFieldNames,
      AFieldIndexes, AFieldTypes) должен:
      1. Сохранить FSource = ASource
      2. Скопировать FFieldNames из AFieldNames (через Assign)
      3. Скопировать FFieldIndexes из AFieldIndexes (через AddRange)
      4. Скопировать FFieldTypes из AFieldTypes (через AddRange)
      5. Инициализировать FCurrentRecNo = 0
      6. Инициализировать FEofFlag = False

    Для проверки используем TTestTVTRecordAdapter (реэкспорт
    protected-свойств FieldIndexes, FieldTypes, FieldNames). }

  // === Act ===
  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: FSource сохранён ===
    Assert.AreSame(FSource, Adapter.SourceRecord,
      'FSource должен быть сохранён в Adapter.SourceRecord');

    // === Assert: FFieldNames скопирован (копия, а не ссылка) ===
    Assert.AreEqual(3, Adapter.FieldNames.Count,
      'FieldNames.Count = 3 (скопировано из AFieldNames)');
    Assert.AreEqual('ID', Adapter.FieldNames[0], 'FieldNames[0] = ID');
    Assert.AreEqual('Name', Adapter.FieldNames[1], 'FieldNames[1] = Name');
    Assert.AreEqual('Date', Adapter.FieldNames[2], 'FieldNames[2] = Date');
    Assert.AreNotSame(FFieldNames, Adapter.FieldNames,
      'Adapter должен владеть СВОЕЙ копией FieldNames, а не ссылкой');

    FFieldNames[0] := 'ChangedName';
    FFieldNames.Add('AddedName');
    Assert.AreEqual('ID', Adapter.FieldNames[0],
      'Изменение исходных FieldNames не должно менять копию адаптера');
    Assert.AreEqual(3, Adapter.FieldNames.Count,
      'Добавление в исходные FieldNames не должно менять копию адаптера');

    // === Assert: FFieldIndexes скопирован (копия, а не ссылка) ===
    Assert.AreEqual(3, Adapter.FieldIndexes.Count,
      'FieldIndexes.Count = 3 (скопировано из AFieldIndexes)');
    Assert.AreEqual(TMockRecord.COL_INTEGER, Adapter.FieldIndexes[0],
      'FieldIndexes[0] = COL_INTEGER');
    Assert.AreEqual(TMockRecord.COL_STRING, Adapter.FieldIndexes[1],
      'FieldIndexes[1] = COL_STRING');
    Assert.AreEqual(TMockRecord.COL_DATE, Adapter.FieldIndexes[2],
      'FieldIndexes[2] = COL_DATE');
    Assert.AreNotSame(FFieldIndexes, Adapter.FieldIndexes,
      'Adapter должен владеть СВОЕЙ копией FieldIndexes, а не ссылкой');

    FFieldIndexes[0] := TMockRecord.COL_BOOLEAN;
    FFieldIndexes.Add(TMockRecord.COL_NULL);
    Assert.AreEqual(TMockRecord.COL_INTEGER, Adapter.FieldIndexes[0],
      'Изменение исходных FieldIndexes не должно менять копию адаптера');
    Assert.AreEqual(3, Adapter.FieldIndexes.Count,
      'Добавление в исходные FieldIndexes не должно менять копию адаптера');

    // === Assert: FFieldTypes скопирован (копия, а не ссылка) ===
    Assert.AreEqual(3, Adapter.FieldTypes.Count,
      'FieldTypes.Count = 3 (скопировано из AFieldTypes)');
    Assert.AreEqual(fftNumeric, Adapter.FieldTypes[0],
      'FieldTypes[0] = fftNumeric');
    Assert.AreEqual(fftString, Adapter.FieldTypes[1],
      'FieldTypes[1] = fftString');
    Assert.AreEqual(fftDateTime, Adapter.FieldTypes[2],
      'FieldTypes[2] = fftDateTime');
    Assert.AreNotSame(FFieldTypes, Adapter.FieldTypes,
      'Adapter должен владеть СВОЕЙ копией FieldTypes, а не ссылкой');

    FFieldTypes[0] := fftBoolean;
    FFieldTypes.Add(fftString);
    Assert.AreEqual(fftNumeric, Adapter.FieldTypes[0],
      'Изменение исходных FieldTypes не должно менять копию адаптера');
    Assert.AreEqual(3, Adapter.FieldTypes.Count,
      'Добавление в исходные FieldTypes не должно менять копию адаптера');

    // === Assert: FCurrentRecNo = 0, FEofFlag = False (проверяем через поведение) ===
    Assert.IsFalse(Adapter.Eof,
      'После создания: Eof = False (FEofFlag = False)');
    Assert.AreEqual(1, Adapter.RecordCount,
      'RecordCount = 1 (семантика "одна запись")');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.1.2 Create_WithNilCollections_DoesNotRaise === }
procedure TfrxDevCustomDataSetAdapterFixture.Create_WithNilCollections_DoesNotRaise;
var
  Adapter: TVTRecordAdapter;
begin
  { Спецификация:
    - Конструктор с nil коллекциями не должен вызывать исключений.
    - Это защита от некорректных параметров (багоустойчивость).

    Источник логики (TVTRecordAdapter.Create):
      if Assigned(AFieldNames) then
        FFieldNames.Assign(AFieldNames);
      if Assigned(AFieldIndexes) then
        FFieldIndexes.AddRange(AFieldIndexes);
      if Assigned(AFieldTypes) then
        FFieldTypes.AddRange(AFieldTypes);
    Все операции обёрнуты в Assigned-проверки. }

  // === Act + Assert: все три коллекции nil ===
  Assert.WillNotRaise(
    procedure
    begin
      Adapter := TTestTVTRecordAdapter.Create(nil, nil, nil, nil, nil);
      try
        Assert.IsNotNull(Adapter, 'Adapter должен быть создан даже с nil параметрами');
      finally
        FreeAndNil(Adapter);
      end;
    end,
    Exception,
    'Создание с nil коллекциями не должно вызывать исключений');

  // === Act + Assert: только FSource nil ===
  Assert.WillNotRaise(
    procedure
    begin
      Adapter := TTestTVTRecordAdapter.Create(
        nil, nil, FFieldNames, FFieldIndexes, FFieldTypes);
      try
        Assert.IsNotNull(Adapter, 'Adapter с nil Source должен быть создан');
      finally
        FreeAndNil(Adapter);
      end;
    end,
    Exception,
    'Создание с nil Source не должно вызывать исключений');
end;

{ === 4.2.2.1 Open_ResetsRecNo === }
procedure TfrxDevCustomDataSetAdapterFixture.Open_ResetsRecNo;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Open сбрасывает FCurrentRecNo в 0 и FEofFlag в False.
    - Это подготовка к навигации.

    Источник логики (TVTRecordAdapter.Open):
      procedure TVTRecordAdapter.Open;
      begin
        FCurrentRecNo := 0;
        FEofFlag := False;
        ...
      end; }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // Имитируем состояние после Next (Eof = True)
    Adapter.Next;
    Assert.IsTrue(Adapter.Eof,
      'После Next: Eof = True (FCurrentRecNo >= 1)');

    // === Act ===
    Adapter.Open;

    // === Assert: состояние сброшено ===
    Assert.IsFalse(Adapter.Eof,
      'После Open: Eof = False (FEofFlag сброшен)');

    // Косвенная проверка FCurrentRecNo = 0: First должен работать
    Adapter.First;
    Assert.IsFalse(Adapter.Eof,
      'После Open + First: на записи (FCurrentRecNo = 0)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.2 First_ResetsRecNo === }
procedure TfrxDevCustomDataSetAdapterFixture.First_ResetsRecNo;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - First сбрасывает FCurrentRecNo в 0.
    - Это возвращение к началу набора данных.

    Источник логики (TVTRecordAdapter.First):
      procedure TVTRecordAdapter.First;
      begin
        FCurrentRecNo := 0;
        FEofFlag := False;
        ...
      end; }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // Имитируем состояние в конце (Eof = True)
    Adapter.Next;
    Assert.IsTrue(Adapter.Eof, 'После Next: Eof = True');

    // === Act ===
    Adapter.First;

    // === Assert: указатель на первой записи ===
    Assert.IsFalse(Adapter.Eof,
      'После First: Eof = False (FCurrentRecNo = 0)');
    Assert.IsFalse(VarIsNull(Adapter.GetValue('ID')),
      'После First: GetValue работает (на записи)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.3 Next_SetsEofToTrue === }
procedure TfrxDevCustomDataSetAdapterFixture.Next_SetsEofToTrue;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - После First + Next FEofFlag становится True.
    - Это следствие семантики "одна запись на адаптер":
      после перехода на следующую запись мы вышли за пределы
      единственной записи.

    Источник логики (TVTRecordAdapter.Next):
      procedure TVTRecordAdapter.Next;
      begin
        Inc(FCurrentRecNo);
        FEofFlag := FCurrentRecNo >= 1;  // Одна запись на адаптер
        ...
      end; }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Adapter.First;
    Assert.IsFalse(Adapter.Eof,
      'После First: Eof = False (FCurrentRecNo = 0)');

    // === Act ===
    Adapter.Next;

    // === Assert: FCurrentRecNo = 1, FEofFlag = True ===
    Assert.IsTrue(Adapter.Eof,
      'После Next: Eof = True (FCurrentRecNo >= 1, вышли за пределы)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.4 Eof_TrueAfterNext === }
procedure TfrxDevCustomDataSetAdapterFixture.Eof_TrueAfterNext;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Eof возвращает True после Next.
    - Это свойство Eof, которое читает FEofFlag.

    Источник логики (TVTRecordAdapter.Eof):
      function TVTRecordAdapter.Eof: Boolean;
      begin
        Result := FEofFlag;
      end; }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: до First Eof = False (сброс в конструкторе) ===
    Assert.IsFalse(Adapter.Eof,
      'До First: Eof = False (FEofFlag = False в конструкторе)');

    Adapter.First;
    Assert.IsFalse(Adapter.Eof,
      'После First: Eof = False (на записи)');

    // === Act ===
    Adapter.Next;

    // === Assert ===
    Assert.IsTrue(Adapter.Eof,
      'После Next: Eof = True (FEofFlag = True, FCurrentRecNo = 1)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.5 RecordCount_AlwaysOne === }
procedure TfrxDevCustomDataSetAdapterFixture.RecordCount_AlwaysOne;
var
  Adapter: TTestTVTRecordAdapter;
  EmptyNames: TStringList;
  EmptyIndexes: TList<Integer>;
  EmptyTypes: TList<TfrxFieldType>;
begin
  { Спецификация:
    - RecordCount ВСЕГДА возвращает 1.
    - Это не зависит от метаданных или FSource.
    - Это следствие семантики "одна запись на адаптер".

    Источник логики (TVTRecordAdapter.RecordCount):
      function TVTRecordAdapter.RecordCount: Integer;
      begin
        Result := 1;
      end; }

  // === Test 1: полный набор метаданных ===
  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Assert.AreEqual(1, Adapter.RecordCount,
      'RecordCount = 1 (стандартные метаданные)');
  finally
    FreeAndNil(Adapter);
  end;

  // === Test 2: пустые метаданные ===
  EmptyNames := TStringList.Create;
  EmptyIndexes := TList<Integer>.Create;
  EmptyTypes := TList<TfrxFieldType>.Create;
  try
    Adapter := TTestTVTRecordAdapter.Create(
      nil, FSource, EmptyNames, EmptyIndexes, EmptyTypes);
    try
      Assert.AreEqual(1, Adapter.RecordCount,
        'RecordCount = 1 (пустые метаданные — не зависит от размера)');
    finally
      FreeAndNil(Adapter);
    end;
  finally
    FreeAndNil(EmptyNames);
    FreeAndNil(EmptyIndexes);
    FreeAndNil(EmptyTypes);
  end;

  // === Test 3: nil Source ===
  Adapter := TTestTVTRecordAdapter.Create(
    nil, nil, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Assert.AreEqual(1, Adapter.RecordCount,
      'RecordCount = 1 (nil Source — не зависит от FSource)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.6 First_AfterNext_ResetsState === }
procedure TfrxDevCustomDataSetAdapterFixture.First_AfterNext_ResetsState;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Повторный First после Next сбрасывает состояние.
    - Это свойство идемпотентности First. }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Adapter.First;
    Assert.IsFalse(Adapter.Eof, 'После первого First: Eof = False');

    Adapter.Next;
    Assert.IsTrue(Adapter.Eof, 'После Next: Eof = True');

    // === Act: повторный First ===
    Adapter.First;

    // === Assert: состояние сброшено ===
    Assert.IsFalse(Adapter.Eof,
      'Повторный First: Eof = False (FCurrentRecNo = 0)');
    Assert.IsFalse(VarIsNull(Adapter.GetValue('ID')),
      'Повторный First: GetValue работает');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.2.7 Next_AfterEof_IsSafe === }
procedure TfrxDevCustomDataSetAdapterFixture.Next_AfterEof_IsSafe;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Повторный Next после Eof не вызывает исключений.
    - Это свойство идемпотентности Next и защита от ошибок клиента. }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Adapter.First;
    Adapter.Next;
    Assert.IsTrue(Adapter.Eof, 'После First + Next: Eof = True');

    // === Act: повторные Next ===
    Assert.WillNotRaise(
      procedure
      begin
        Adapter.Next;
        Adapter.Next;
        Adapter.Next;
      end,
      Exception,
      'Повторные Next после Eof не должны вызывать исключений');

    // === Assert: Eof остаётся True ===
    Assert.IsTrue(Adapter.Eof,
      'После повторных Next: Eof остаётся True');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.3.1 GetValue_KnownField_ReturnsValue === }
procedure TfrxDevCustomDataSetAdapterFixture.GetValue_KnownField_ReturnsValue;
var
  Adapter: TVTRecordAdapter;
  V: Variant;
begin
  { Спецификация:
    - GetValue для известного поля возвращает значение из FSource
      по индексу FFieldIndexes[ColIdx].

    Источник логики (TVTRecordAdapter.GetValue):
      ColIdx := FFieldNames.IndexOf(Index);
      if (ColIdx >= 0) and (ColIdx < FFieldIndexes.Count) then
        Result := FSource.GetValue(FFieldIndexes[ColIdx]);

    Цепочка делегирования:
      Adapter.GetValue('ID')
        -> FFieldNames.IndexOf('ID') = 0
        -> FFieldIndexes[0] = TMockRecord.COL_INTEGER (0)
        -> FSource.GetValue(0) = 42 }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: Integer поле (ID) ===
    V := Adapter.GetValue('ID');
    Assert.IsFalse(VarIsNull(V), 'GetValue(ID) не Null');
    Assert.AreEqual(42, Integer(V), 'GetValue(ID) = 42');
    Assert.AreEqual(varInteger, VarType(V), 'Тип ID = varInteger');

    // === Assert: String поле (Name) ===
    V := Adapter.GetValue('Name');
    Assert.IsFalse(VarIsNull(V), 'GetValue(Name) не Null');
    Assert.AreEqual('Test', string(V), 'GetValue(Name) = "Test"');
    Assert.IsTrue((VarType(V) = varString) or (VarType(V) = varUString),
      'Тип Name = varString/varUString');

    // === Assert: Date поле (Date) ===
    V := Adapter.GetValue('Date');
    Assert.IsFalse(VarIsNull(V), 'GetValue(Date) не Null');
    Assert.AreEqual(EncodeDate(2026, 1, 15), TDateTime(V),
      'GetValue(Date) = 2026-01-15');
    Assert.AreEqual(varDate, VarType(V), 'Тип Date = varDate');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.3.2 GetValue_UnknownField_ReturnsNull === }
procedure TfrxDevCustomDataSetAdapterFixture.GetValue_UnknownField_ReturnsNull;
var
  Adapter: TVTRecordAdapter;
begin
  { Спецификация:
    - GetValue для неизвестного поля возвращает Null.
    - Это следствие FFieldNames.IndexOf('X') = -1.

    Источник логики (TVTRecordAdapter.GetValue):
      Result := Null;  // начальное значение
      ColIdx := FFieldNames.IndexOf(Index);
      if (ColIdx >= 0) and (ColIdx < FFieldIndexes.Count) then
        Result := FSource.GetValue(FFieldIndexes[ColIdx]);
      // Если IndexOf вернул -1, условие ложно, Result остаётся Null. }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: существующие поля работают ===
    Assert.IsFalse(VarIsNull(Adapter.GetValue('ID')),
      'Существующее поле ID возвращает значение');
    Assert.IsFalse(VarIsNull(Adapter.GetValue('Name')),
      'Существующее поле Name возвращает значение');

    // === Assert: несуществующие поля возвращают Null ===
    Assert.IsTrue(VarIsNull(Adapter.GetValue('NonExistent')),
      'Несуществующее поле -> Null');
    Assert.IsTrue(VarIsNull(Adapter.GetValue('Foo')),
      'Несуществующее поле Foo -> Null');
    Assert.IsTrue(VarIsNull(Adapter.GetValue('')),
      'Пустое имя поля -> Null');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.3.3 GetValue_NilSource_ReturnsNull === }
procedure TfrxDevCustomDataSetAdapterFixture.GetValue_NilSource_ReturnsNull;
var
  Adapter: TVTRecordAdapter;
begin
  { Спецификация:
    - GetValue при FSource = nil возвращает Null (без AV).
    - Это защита от некорректного состояния адаптера.

    Источник логики (TVTRecordAdapter.GetValue):
      if not Assigned(FSource) then
        Exit;  // Result остаётся Null (начальное значение)
      ColIdx := FFieldNames.IndexOf(Index);
      ... }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, nil, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: GetValue не падает и возвращает Null ===
    Assert.WillNotRaise(
      procedure
      begin
        Assert.IsTrue(VarIsNull(Adapter.GetValue('ID')),
          'GetValue(ID) с nil Source должен вернуть Null');
      end,
      Exception,
      'GetValue с nil Source не должен вызывать Access Violation');

    Assert.IsTrue(VarIsNull(Adapter.GetValue('Name')),
      'GetValue(Name) с nil Source = Null');
    Assert.IsTrue(VarIsNull(Adapter.GetValue('Date')),
      'GetValue(Date) с nil Source = Null');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.4.1 GetFieldList_ReturnsFieldNames === }
procedure TfrxDevCustomDataSetAdapterFixture.GetFieldList_ReturnsFieldNames;
var
  Adapter: TVTRecordAdapter;
  List: TStringList;
begin
  { Спецификация:
    - GetFieldList(List) копирует FFieldNames в List через List.Assign.
    - После вызова List содержит те же имена, что и FFieldNames.

    Источник логики (TVTRecordAdapter.GetFieldList):
      procedure TVTRecordAdapter.GetFieldList(List: TStrings);
      begin
        List.Assign(FFieldNames);
      end; }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    List := TStringList.Create;
    try
      // === Act ===
      Adapter.GetFieldList(List);

      // === Assert: List содержит те же имена, что и FFieldNames ===
      Assert.AreEqual(3, List.Count,
        'List.Count = 3 (скопировано из FFieldNames)');
      Assert.AreEqual('ID', List[0], 'List[0] = ID');
      Assert.AreEqual('Name', List[1], 'List[1] = Name');
      Assert.AreEqual('Date', List[2], 'List[2] = Date');

      // Assert: List содержит копию, а не ссылку
      Assert.AreNotSame(FFieldNames, List,
        'List должен быть отдельным объектом (не ссылкой на FFieldNames)');
    finally
      FreeAndNil(List);
    end;
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.5.1 FieldsCount_ReturnsFieldNamesCount === }
procedure TfrxDevCustomDataSetAdapterFixture.FieldsCount_ReturnsFieldNamesCount;
var
  Adapter: TVTRecordAdapter;
  EmptyNames: TStringList;
  EmptyIndexes: TList<Integer>;
  EmptyTypes: TList<TfrxFieldType>;
begin
  { Спецификация:
    - FieldsCount возвращает FFieldNames.Count.
    - Это свойство, зависящее только от размера FFieldNames.

    Источник логики (TVTRecordAdapter.FieldsCount):
      function TVTRecordAdapter.FieldsCount: Integer;
      begin
        Result := FFieldNames.Count;
      end; }

  // === Test 1: стандартные метаданные (3 поля) ===
  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    Assert.AreEqual(3, Adapter.FieldsCount,
      'FieldsCount = 3 (3 поля в метаданных)');
  finally
    FreeAndNil(Adapter);
  end;

  // === Test 2: пустые метаданные (0 полей) ===
  EmptyNames := TStringList.Create;
  EmptyIndexes := TList<Integer>.Create;
  EmptyTypes := TList<TfrxFieldType>.Create;
  try
    Adapter := TTestTVTRecordAdapter.Create(
      nil, FSource, EmptyNames, EmptyIndexes, EmptyTypes);
    try
      Assert.AreEqual(0, Adapter.FieldsCount,
        'FieldsCount = 0 (пустые метаданные)');
    finally
      FreeAndNil(Adapter);
    end;
  finally
    FreeAndNil(EmptyNames);
    FreeAndNil(EmptyIndexes);
    FreeAndNil(EmptyTypes);
  end;
end;

{ === 4.2.6.1 GetDisplayText_FormatsValues === }
procedure TfrxDevCustomDataSetAdapterFixture.GetDisplayText_FormatsValues;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - GetDisplayText форматирует значения в WideString:
      Integer 42 -> '42' (через VarToWideStr)
      String 'Test' -> 'Test' (прямая передача через VarIsStr)
      Boolean True -> 'True' (через BoolToStr(V, True))
      Null -> '' (через VarIsNull)

    Источник логики (TVTRecordAdapter.GetDisplayText):
      V := GetValue(Index);
      if VarIsNull(V) then Result := ''
      else if VarIsStr(V) then Result := V
      else if VarType(V) = varBoolean then
        Result := BoolToStr(Boolean(V), True)
      else
        Result := VarToWideStr(V); }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: Integer -> '42' ===
    Assert.AreEqual('42', string(Adapter.GetDisplayText('ID')),
      'Integer 42 -> "42"');

    // === Assert: String -> 'Test' (прямая передача) ===
    Assert.AreEqual('Test', string(Adapter.GetDisplayText('Name')),
      'String "Test" -> "Test"');

    // === Assert: Date -> непустая строка (формат зависит от локали) ===
    var DateText := string(Adapter.GetDisplayText('Date'));
    Assert.IsTrue(Length(DateText) > 0,
      'Date должен быть преобразован в непустую строку');

    // === Assert: Boolean -> 'True' ===
    // Для этого теста нужны метаданные с Boolean полем.
    // Создаём отдельный адаптер с 5 колонками.
    var BoolNames := TStringList.Create;
    var BoolIndexes := TList<Integer>.Create;
    var BoolTypes := TList<TfrxFieldType>.Create;
    try
      BoolNames.AddStrings(['IntCol', 'StrCol', 'DateCol', 'BoolCol', 'NullCol']);
      BoolIndexes.AddRange([TMockRecord.COL_INTEGER, TMockRecord.COL_STRING,
                            TMockRecord.COL_DATE, TMockRecord.COL_BOOLEAN,
                            TMockRecord.COL_NULL]);
      BoolTypes.AddRange([fftNumeric, fftString, fftDateTime, fftBoolean, fftString]);

      var BoolAdapter := TTestTVTRecordAdapter.Create(
        nil, FSource, BoolNames, BoolIndexes, BoolTypes);
      try
        Assert.AreEqual('True', string(BoolAdapter.GetDisplayText('BoolCol')),
          'Boolean True -> "True"');

        // === Assert: Null -> '' ===
        Assert.AreEqual('', string(BoolAdapter.GetDisplayText('NullCol')),
          'Null -> "" (пустая строка)');
      finally
        FreeAndNil(BoolAdapter);
      end;
    finally
      FreeAndNil(BoolNames);
      FreeAndNil(BoolIndexes);
      FreeAndNil(BoolTypes);
    end;
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.6.2 GetFieldType_ReturnsMappedType === }
procedure TfrxDevCustomDataSetAdapterFixture.GetFieldType_ReturnsMappedType;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - GetFieldType возвращает тип из FFieldTypes[ColIdx] для известного поля.

    Источник логики (TVTRecordAdapter.FieldType):
      Result := fftString;  // default
      I := FieldIndex(FieldName);
      if (I >= 0) and (I < FFieldTypes.Count) then
        Result := FFieldTypes[I];

    FieldIndex использует FFieldNames.IndexOf (case-insensitive). }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: типы полей соответствуют метаданным ===
    Assert.AreEqual(fftNumeric, Adapter.GetFieldType('ID'),
      'ID -> fftNumeric');
    Assert.AreEqual(fftString, Adapter.GetFieldType('Name'),
      'Name -> fftString');
    Assert.AreEqual(fftDateTime, Adapter.GetFieldType('Date'),
      'Date -> fftDateTime');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.6.3 GetFieldType_UnknownField_ReturnsString === }
procedure TfrxDevCustomDataSetAdapterFixture.GetFieldType_UnknownField_ReturnsString;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - GetFieldType для неизвестного поля возвращает fftString (default).

    Источник логики:
      Result := fftString;  // default
      I := FieldIndex(FieldName);
      if (I >= 0) and (I < FFieldTypes.Count) then
        Result := FFieldTypes[I];
      // Для неизвестного поля I = -1, условие ложно,
      // Result остаётся fftString. }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: неизвестные поля возвращают fftString ===
    Assert.AreEqual(fftString, Adapter.GetFieldType('NonExistent'),
      'Несуществующее поле -> fftString (default)');
    Assert.AreEqual(fftString, Adapter.GetFieldType('Foo'),
      'Несуществующее поле Foo -> fftString (default)');
    Assert.AreEqual(fftString, Adapter.GetFieldType(''),
      'Пустое имя поля -> fftString (default)');
  finally
    FreeAndNil(Adapter);
  end;
end;

{ === 4.2.6.4 GetValue_CaseInsensitive === }
procedure TfrxDevCustomDataSetAdapterFixture.GetValue_CaseInsensitive;
var
  Adapter: TTestTVTRecordAdapter;
begin
  { Спецификация:
    - Поиск имён полей в GetValue case-insensitive.
    - TStringList.CaseSensitive = False по умолчанию.
    - 'ID', 'id', 'Id', 'ID' эквивалентны.

    Источник логики:
      FFieldNames := TStringList.Create;
      // CaseSensitive = False (по умолчанию)
      ColIdx := FFieldNames.IndexOf(Index);
      // IndexOf case-insensitive по умолчанию }

  Adapter := TTestTVTRecordAdapter.Create(
    nil, FSource, FFieldNames, FFieldIndexes, FFieldTypes);
  try
    // === Assert: разный регистр = одно поле ===
    Assert.AreEqual(42, Integer(Adapter.GetValue('ID')),
      'GetValue(ID) = 42');
    Assert.AreEqual(42, Integer(Adapter.GetValue('id')),
      'GetValue(id) = 42 (case-insensitive)');
    Assert.AreEqual(42, Integer(Adapter.GetValue('Id')),
      'GetValue(Id) = 42 (case-insensitive)');
    Assert.AreEqual(42, Integer(Adapter.GetValue('iD')),
      'GetValue(iD) = 42 (case-insensitive)');

    Assert.AreEqual('Test', string(Adapter.GetValue('NAME')),
      'GetValue(NAME) = "Test" (case-insensitive)');
    Assert.AreEqual('Test', string(Adapter.GetValue('name')),
      'GetValue(name) = "Test" (case-insensitive)');

    Assert.AreEqual(EncodeDate(2026, 1, 15), TDateTime(Adapter.GetValue('DATE')),
      'GetValue(DATE) = 2026-01-15 (case-insensitive)');
  finally
    FreeAndNil(Adapter);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TfrxDevCustomDataSetFixture);
  TDUnitX.RegisterTestFixture(TfrxDevCustomDataSetAdapterFixture);

end.
