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

initialization
  TDUnitX.RegisterTestFixture(TfrxDevCustomDataSetFixture);

end.
