unit uCatalogServiceFixture;

interface

uses
  DUnitX.TestFramework, System.Generics.Collections, System.SysUtils, System.Classes,
  System.Variants,
  uMockCatalogRepository, uCatalogService, uCatalogRepositoryIntf, uEntities;

type
  [TestFixture]
  TCatalogServiceFixture = class
  private
    FMock: TMockCatalogRepository;
    FService: TCatalogService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    /// Хелпер для безопасного освобождения массива TPartRow, возвращаемого методом GetParts.
    /// Используйте в каждом тесте, который вызывает GetParts, чтобы избежать утечек памяти.
    /// Метод GetParts создает объекты TPartRow и возвращает их в динамическом массиве,
    /// поэтому ответственность за их освобождение лежит на вызывающем коде.
    /// </summary>
    procedure FreePartRows(var ARows: TArray<TPartRow>);

    // Тесты для метода GetCategories (пункт 5.2 спецификации)
    [Test]
    procedure GetCategories_DelegatesAndReturns;
    [Test]
    procedure GetCategories_EmptyTable_ReturnsEmptyArray;

    // Тесты для метода GetCategoryAttributes (пункт 5.3 спецификации)
    [Test]
    procedure GetAttributes_MapsTypeStrings;

    // Тесты для метода GetParts (пункт 5.4 спецификации)
    [Test]
    procedure GetParts_GroupsByPartIDAndFormatsValues;
    [Test]
    procedure GetParts_WithSearchTerm_DelegatesParameter;
    [Test]
    procedure GetParts_MultiplePartIDs_GroupsCorrectly;
    [Test]
    procedure GetParts_DateValue_FormatsCorrectly;
    [Test]
    procedure GetParts_NumberValue_FormatsCorrectly;
    [Test]
    procedure GetParts_EmptyResult_ReturnsEmptyArray;
    [Test]
    procedure GetParts_BooleanFalse_FormatsAsNet;

    // Тесты для метода SaveCategory (пункт 5.5 спецификации)
    [Test]
    procedure SaveCategory_New_Inserts;
    [Test]
    procedure SaveCategory_Existing_Updates;
    [Test]
    procedure SaveCategory_DBError_Rollbacks;

    // Тесты для метода SaveAttribute (пункт 5.6 спецификации)
    [Test]
    procedure SaveAttribute_New_Inserts;
    [Test]
    procedure SaveAttribute_Existing_Updates;
    [Test]
    procedure SaveAttribute_MapsEnumToStr_String;
    [Test]
    procedure SaveAttribute_MapsEnumToStr_Number;
    [Test]
    procedure SaveAttribute_MapsEnumToStr_Date;
    [Test]
    procedure SaveAttribute_MapsEnumToStr_Boolean;
    [Test]
    procedure SaveAttribute_DBError_Rollbacks;

    // Тесты для метода SavePart (пункт 5.7 спецификации)
    [Test]
    procedure SavePart_UpsertsPartAndValues;
    [Test]
    procedure SavePart_AttributeNotFound_Raises;
    [Test]
    procedure SavePart_DBErrorOnUpsertValue_Rollbacks;

    // Тесты для метода DeleteAttribute (пункт 5.8 спецификации)
    [Test]
    procedure DeleteAttribute_Success_ReturnsTrue;
    [Test]
    procedure DeleteAttribute_FKViolation_ReturnsFalseWithErrorMsg;
    [Test]
    procedure DeleteAttribute_OtherError_ReturnsFalseWithErrorMsg;

    // Тесты для метода DeletePart (пункт 5.9 спецификации)
    [Test]
    procedure DeletePart_Success_ReturnsTrue;
    [Test]
    procedure DeletePart_Error_Raises;

    // Тесты для метода DeleteCategory (пункт 5.10 спецификации)
    [Test]
    procedure DeleteCategory_Success_ReturnsTrue;
    [Test]
    procedure DeleteCategory_FKViolation_ReturnsFalseWithErrorMsg;
    [Test]
    procedure DeleteCategory_OtherError_ReturnsFalseWithErrorMsg;
  end;

implementation

{ TCatalogServiceFixture }

procedure TCatalogServiceFixture.Setup;
begin
  // Создаем мок. TMockCatalogRepository наследуется от TInterfacedObject.
  FMock := TMockCatalogRepository.Create;

  // Создаем сервис. Передаем мок как интерфейс ICatalogRepository.
  // При приведении к интерфейсу вызывается _AddRef, и счетчик ссылок на мок становится 1.
  // TCatalogService теперь владеет моком через интерфейс.
  FService := TCatalogService.Create(FMock as ICatalogRepository);
end;

procedure TCatalogServiceFixture.TearDown;
begin
  // Освобождение TCatalogService автоматически вызовет _Release на
  // ICatalogRepository (поле FRepo). Поскольку это была единственная сильная ссылка,
  // счетчик ссылок станет 0, и TMockCatalogRepository уничтожится автоматически.
  //
  // ВАЖНО: Не вызывайте FMock.Free вручную — это приведет к double-free и AV,
  // так как объект уже уничтожен через механизм reference counting.
  FreeAndNil(FService);

  // Обнуляем указатель на мок, чтобы избежать случайного использования
  // висячего указателя в других методах (хотя DUnitX гарантирует, что
  // TearDown вызывается после теста, и новый Setup создаст новый мок).
  FMock := nil;
end;

procedure TCatalogServiceFixture.FreePartRows(var ARows: TArray<TPartRow>);
var
  i: Integer;
begin
  for i := 0 to High(ARows) do
    ARows[i].Free;
  ARows := nil;
end;

procedure TCatalogServiceFixture.GetCategories_DelegatesAndReturns;
var
  Categories: TArray<TCategory>;
  Cat1, Cat2: TDBCategory;
begin
  // Arrange
  Cat1.ID := 10;
  Cat1.ParentID := 0; // Корневая категория (в БД был NULL)
  Cat1.Name := 'Engine Parts';
  Cat1.ChildCount := 5;
  FMock.AddCategory(Cat1);

  Cat2.ID := 11;
  Cat2.ParentID := 10; // Дочерняя категория
  Cat2.Name := 'Pistons';
  Cat2.ChildCount := 2;
  FMock.AddCategory(Cat2);

  // Act
  Categories := FService.GetCategories;

  // Assert
  Assert.AreEqual(2, Length(Categories), 'Должно вернуться ровно 2 категории');

  // Проверка первой категории
  Assert.AreEqual(10, Categories[0].ID, 'ID первой категории');
  Assert.AreEqual(0, Categories[0].ParentID, 'ParentID первой категории (NULL -> 0)');
  Assert.AreEqual('Engine Parts', Categories[0].Name, 'Name первой категории');
  Assert.AreEqual(5, Categories[0].ChildCount, 'ChildCount первой категории');

  // Проверка второй категории
  Assert.AreEqual(11, Categories[1].ID, 'ID второй категории');
  Assert.AreEqual(10, Categories[1].ParentID, 'ParentID второй категории');
  Assert.AreEqual('Pistons', Categories[1].Name, 'Name второй категории');
  Assert.AreEqual(2, Categories[1].ChildCount, 'ChildCount второй категории');
end;

procedure TCatalogServiceFixture.GetCategories_EmptyTable_ReturnsEmptyArray;
var
  Categories: TArray<TCategory>;
begin
  // Act: мок создан, но в него не добавлено ни одной категории.
  // Мок вернет пустой массив TDBCategory, сервис должен также вернуть пустой массив.
  Categories := FService.GetCategories;

  // Assert
  Assert.AreEqual(0, Length(Categories), 'Для пустой таблицы должен вернуться пустой массив');
end;

procedure TCatalogServiceFixture.GetAttributes_MapsTypeStrings;
var
  Attrs: TArray<TAttributeDef>;
  Attr1, Attr2, Attr3, Attr4: TDBAttribute;
begin
  // Arrange: настраиваем мок на возврат 4 атрибутов с разными строковыми типами
  Attr1.ID := 1; Attr1.Name := 'Material';     Attr1.TypeStr := 'string';
  Attr2.ID := 2; Attr2.Name := 'Weight';       Attr2.TypeStr := 'number';
  Attr3.ID := 3; Attr3.Name := 'Manufactured'; Attr3.TypeStr := 'date';
  Attr4.ID := 4; Attr4.Name := 'IsFragile';    Attr4.TypeStr := 'boolean';

  FMock.AddAttribute(Attr1);
  FMock.AddAttribute(Attr2);
  FMock.AddAttribute(Attr3);
  FMock.AddAttribute(Attr4);

  // Act: запрашиваем атрибуты для произвольной категории (ID не важен, так как мок вернет всё)
  Attrs := FService.GetCategoryAttributes(10);

  // Assert
  Assert.AreEqual(4, Length(Attrs), 'Должно вернуться ровно 4 атрибута');

  // Проверка маппинга 'string' -> atString
  Assert.AreEqual(1, Attrs[0].ID, 'ID первого атрибута');
  Assert.AreEqual('Material', Attrs[0].Name, 'Name первого атрибута');
  Assert.AreEqual(atString, Attrs[0].AttrType, 'TypeStr "string" должен маппиться в atString');

  // Проверка маппинга 'number' -> atNumber
  Assert.AreEqual(2, Attrs[1].ID, 'ID второго атрибута');
  Assert.AreEqual('Weight', Attrs[1].Name, 'Name второго атрибута');
  Assert.AreEqual(atNumber, Attrs[1].AttrType, 'TypeStr "number" должен маппиться в atNumber');

  // Проверка маппинга 'date' -> atDate
  Assert.AreEqual(3, Attrs[2].ID, 'ID третьего атрибута');
  Assert.AreEqual('Manufactured', Attrs[2].Name, 'Name третьего атрибута');
  Assert.AreEqual(atDate, Attrs[2].AttrType, 'TypeStr "date" должен маппиться в atDate');

  // Проверка маппинга 'boolean' -> atBoolean
  Assert.AreEqual(4, Attrs[3].ID, 'ID четвертого атрибута');
  Assert.AreEqual('IsFragile', Attrs[3].Name, 'Name четвертого атрибута');
  Assert.AreEqual(atBoolean, Attrs[3].AttrType, 'TypeStr "boolean" должен маппиться в atBoolean');
end;

procedure TCatalogServiceFixture.GetParts_GroupsByPartIDAndFormatsValues;
var
  Parts: TArray<TPartRow>;
  Part1, Part2: TDBPartValue;
  ActualValue: string;
begin
  // Arrange: настраиваем мок на возврат 2 строк EAV для одного и того же PartID.
  // Это проверяет, что сервис корректно группирует строки по PartID в один TPartRow.
  Part1.PartID := 100;
  Part1.Code := 'PART-001';
  Part1.AttrName := 'Color';
  Part1.ValStr := 'Red';
  Part1.ValNum := Null;
  Part1.ValDate := Null;
  Part1.ValBool := Null;
  FMock.AddPartValue(Part1);

  Part2.PartID := 100; // Тот же PartID, что и у первой строки
  Part2.Code := 'PART-001';
  Part2.AttrName := 'IsFragile';
  Part2.ValStr := Null;
  Part2.ValNum := Null;
  Part2.ValDate := Null;
  Part2.ValBool := True; // Проверяем UI-форматирование: True -> 'Да'
  FMock.AddPartValue(Part2);

  // Act
  Parts := FService.GetParts(10, '');

  try
    // Assert: должен вернуться ровно 1 объект TPartRow
    Assert.AreEqual(1, Length(Parts), 'Должен вернуться ровно 1 сгруппированный TPartRow');

    // Проверка основных полей TPartRow
    Assert.AreEqual(100, Parts[0].PartID, 'PartID должен быть 100');
    Assert.AreEqual('PART-001', Parts[0].Code, 'Code должен быть PART-001');

    // Проверка словаря Values: строковое значение
    Assert.IsTrue(Parts[0].Values.TryGetValue('Color', ActualValue), 'Ключ "Color" должен существовать');
    Assert.AreEqual('Red', ActualValue, 'Значение Color должно быть "Red"');

    // Проверка словаря Values: булево значение с UI-форматированием (True -> 'Да')
    Assert.IsTrue(Parts[0].Values.TryGetValue('IsFragile', ActualValue), 'Ключ "IsFragile" должен существовать');
    Assert.AreEqual('Да', ActualValue, 'Булево True должно форматироваться как "Да"');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_WithSearchTerm_DelegatesParameter;
var
  Parts: TArray<TPartRow>;
begin
  // Act: вызываем GetParts с конкретным SearchTerm
  Parts := FService.GetParts(42, 'bearing');

  try
    // Assert: мок должен зафиксировать, что параметры были проброшены корректно
    Assert.AreEqual(1, FMock.SelectParts_CallCount, 'SelectParts должен быть вызван ровно 1 раз');
    Assert.AreEqual(42, FMock.LastSelectParts_CategoryID, 'CategoryID должен быть проброшен в репозиторий');
    Assert.AreEqual('bearing', FMock.LastSelectParts_SearchTerm, 'SearchTerm должен быть проброшен в репозиторий');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_MultiplePartIDs_GroupsCorrectly;
var
  Parts: TArray<TPartRow>;
  Part1A, Part1B, Part2A: TDBPartValue;
  Part100, Part200: TPartRow;
  i: Integer;
  ActualValue: string;
begin
  // Arrange: 2 строки для PartID=100 и 1 строка для PartID=200
  Part1A.PartID := 100; Part1A.Code := 'PART-A'; Part1A.AttrName := 'Color';
  Part1A.ValStr := 'Red'; Part1A.ValNum := Null; Part1A.ValDate := Null; Part1A.ValBool := Null;
  FMock.AddPartValue(Part1A);

  Part1B.PartID := 100; Part1B.Code := 'PART-A'; Part1B.AttrName := 'Weight';
  Part1B.ValStr := Null; Part1B.ValNum := 10.5; Part1B.ValDate := Null; Part1B.ValBool := Null;
  FMock.AddPartValue(Part1B);

  Part2A.PartID := 200; Part2A.Code := 'PART-B'; Part2A.AttrName := 'Material';
  Part2A.ValStr := 'Steel'; Part2A.ValNum := Null; Part2A.ValDate := Null; Part2A.ValBool := Null;
  FMock.AddPartValue(Part2A);

  // Act
  Parts := FService.GetParts(1, '');

  try
    // Assert: должно вернуться 2 объекта TPartRow
    Assert.AreEqual(2, Length(Parts), 'Должно вернуться ровно 2 сгруппированных TPartRow');

    // Находим нужный PartRow по PartID (словарь не гарантирует порядок)
    Part100 := nil;
    Part200 := nil;
    for i := 0 to High(Parts) do
    begin
      if Parts[i].PartID = 100 then Part100 := Parts[i]
      else if Parts[i].PartID = 200 then Part200 := Parts[i];
    end;

    Assert.IsNotNull(Part100, 'PartID=100 должен быть в результате');
    Assert.IsNotNull(Part200, 'PartID=200 должен быть в результате');

    // Проверка Part100: 2 атрибута
    Assert.AreEqual('PART-A', Part100.Code, 'Code для PartID=100');
    Assert.AreEqual(2, Part100.Values.Count, 'PartID=100 должен иметь 2 значения');
    Assert.IsTrue(Part100.Values.TryGetValue('Color', ActualValue), 'Color должен существовать');
    Assert.AreEqual('Red', ActualValue, 'Color = Red');
    Assert.IsTrue(Part100.Values.TryGetValue('Weight', ActualValue), 'Weight должен существовать');
    // VarToStr зависит от локали, поэтому принимаем как точку, так и запятую
    Assert.IsTrue((ActualValue = '10.5') or (ActualValue = '10,5'), 
      'Weight должен быть "10.5" или "10,5" (в зависимости от локали), получено: ' + ActualValue);

    // Проверка Part200: 1 атрибут
    Assert.AreEqual('PART-B', Part200.Code, 'Code для PartID=200');
    Assert.AreEqual(1, Part200.Values.Count, 'PartID=200 должен иметь 1 значение');
    Assert.IsTrue(Part200.Values.TryGetValue('Material', ActualValue), 'Material должен существовать');
    Assert.AreEqual('Steel', ActualValue, 'Material = Steel');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_DateValue_FormatsCorrectly;
var
  Parts: TArray<TPartRow>;
  Part1: TDBPartValue;
  ActualValue: string;
  TestDate: TDateTime;
begin
  // Arrange: настраиваем мок на возврат даты
  TestDate := EncodeDate(2024, 12, 25);

  Part1.PartID := 300;
  Part1.Code := 'PART-D';
  Part1.AttrName := 'Manufactured';
  Part1.ValStr := Null;
  Part1.ValNum := Null;
  Part1.ValDate := TestDate; // Дата
  Part1.ValBool := Null;
  FMock.AddPartValue(Part1);

  // Act
  Parts := FService.GetParts(1, '');

  try
    Assert.AreEqual(1, Length(Parts), 'Должен вернуться 1 TPartRow');

    // Assert: дата должна быть отформатирована как dd.mm.yyyy
    Assert.IsTrue(Parts[0].Values.TryGetValue('Manufactured', ActualValue), 'Ключ "Manufactured" должен существовать');
    Assert.AreEqual('25.12.2024', ActualValue, 'Дата должна быть отформатирована как dd.mm.yyyy');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_NumberValue_FormatsCorrectly;
var
  Parts: TArray<TPartRow>;
  Part1: TDBPartValue;
  ActualValue: string;
begin
  // Arrange: настраиваем мок на возврат числа
  Part1.PartID := 400;
  Part1.Code := 'PART-N';
  Part1.AttrName := 'Weight';
  Part1.ValStr := Null;
  Part1.ValNum := 123.45; // Число
  Part1.ValDate := Null;
  Part1.ValBool := Null;
  FMock.AddPartValue(Part1);

  // Act
  Parts := FService.GetParts(1, '');

  try
    Assert.AreEqual(1, Length(Parts), 'Должен вернуться 1 TPartRow');

    // Assert: число должно быть преобразовано в строку
    Assert.IsTrue(Parts[0].Values.TryGetValue('Weight', ActualValue), 'Ключ "Weight" должен существовать');
    // VarToStr зависит от локали, поэтому принимаем как точку, так и запятую
    Assert.IsTrue((ActualValue = '123.45') or (ActualValue = '123,45'), 
      'Число должно быть "123.45" или "123,45" (в зависимости от локали), получено: ' + ActualValue);
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_EmptyResult_ReturnsEmptyArray;
var
  Parts: TArray<TPartRow>;
begin
  // Arrange: мок создан, но в него не добавлено ни одной строки TDBPartValue.
  // Мок вернет пустой массив, сервис должен также вернуть пустой массив.

  // Act
  Parts := FService.GetParts(1, '');

  try
    // Assert
    Assert.AreEqual(0, Length(Parts), 'Для пустого результата должен вернуться пустой массив');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.GetParts_BooleanFalse_FormatsAsNet;
var
  Parts: TArray<TPartRow>;
  Part1: TDBPartValue;
  ActualValue: string;
begin
  // Arrange: настраиваем мок на возврат Boolean = False
  Part1.PartID := 500;
  Part1.Code := 'PART-BF';
  Part1.AttrName := 'IsAvailable';
  Part1.ValStr := Null;
  Part1.ValNum := Null;
  Part1.ValDate := Null;
  Part1.ValBool := False; // Проверяем UI-форматирование: False -> 'Нет'
  FMock.AddPartValue(Part1);

  // Act
  Parts := FService.GetParts(1, '');

  try
    Assert.AreEqual(1, Length(Parts), 'Должен вернуться 1 TPartRow');

    // Assert: Boolean False должно форматироваться как 'Нет'
    Assert.IsTrue(Parts[0].Values.TryGetValue('IsAvailable', ActualValue), 'Ключ "IsAvailable" должен существовать');
    Assert.AreEqual('Нет', ActualValue, 'Булево False должно форматироваться как "Нет"');
  finally
    FreePartRows(Parts);
  end;
end;

procedure TCatalogServiceFixture.SaveCategory_New_Inserts;
var
  Result: Boolean;
begin
  // Arrange: ACategoryID = 0 означает создание новой категории
  FMock.InsertCategory_ReturnValue := 42; // Возвращаемый ID новой категории

  // Act
  Result := FService.SaveCategory(0, 'New Category', 10);

  // Assert
  Assert.IsTrue(Result, 'SaveCategory должен вернуть True при успешном сохранении');
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.InsertCategory_CallCount, 'InsertCategory должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.UpdateCategory_CallCount, 'UpdateCategory не должен вызываться для новой категории');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');

  // Проверка переданных параметров в InsertCategory
  Assert.AreEqual('New Category', FMock.LastInsertCategory_Name, 'Name должен быть проброшен в InsertCategory');
  Assert.AreEqual(10, FMock.LastInsertCategory_ParentID, 'ParentID должен быть проброшен в InsertCategory');
end;

procedure TCatalogServiceFixture.SaveCategory_Existing_Updates;
var
  Result: Boolean;
begin
  // Arrange: ACategoryID > 0 означает обновление существующей категории
  // Act
  Result := FService.SaveCategory(5, 'Updated Category', 20);

  // Assert
  Assert.IsTrue(Result, 'SaveCategory должен вернуть True при успешном обновлении');
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.InsertCategory_CallCount, 'InsertCategory не должен вызываться для существующей категории');
  Assert.AreEqual(1, FMock.UpdateCategory_CallCount, 'UpdateCategory должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');

  // Проверка переданных параметров в UpdateCategory
  Assert.AreEqual(5, FMock.LastUpdateCategory_ID, 'CategoryID должен быть проброшен в UpdateCategory');
  Assert.AreEqual('Updated Category', FMock.LastUpdateCategory_Name, 'Name должен быть проброшен в UpdateCategory');
  Assert.AreEqual(20, FMock.LastUpdateCategory_ParentID, 'ParentID должен быть проброшен в UpdateCategory');
end;

procedure TCatalogServiceFixture.SaveCategory_DBError_Rollbacks;
var
  ExceptionRaised: Boolean;
begin
  // Arrange: настраиваем мок на выброс исключения при InsertCategory
  FMock.RaiseExceptionOnInsertCategory := 'Database connection lost';

  // Act: вызываем SaveCategory и перехватываем исключение вручную.
  // Assert.WillRaise в DUnitX может иметь проблемы с anonymous methods,
  // которые захватывают Self, поэтому используем явный try/except.
  ExceptionRaised := False;
  try
    FService.SaveCategory(0, 'Error Category', 10);
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      Assert.IsTrue(Pos('Database connection lost', E.Message) > 0, 
        'Текст исключения должен сохраниться при пробросе. Получено: ' + E.Message);
    end;
  end;

  // Assert: исключение должно быть проброшено
  Assert.IsTrue(ExceptionRaised, 'SaveCategory должен пробросить исключение дальше');
  
  // Assert: проверяем, что транзакция была откачена
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.InsertCategory_CallCount, 'InsertCategory должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

{ ===== Тесты для SaveAttribute (пункт 5.6 спецификации) ===== }

procedure TCatalogServiceFixture.SaveAttribute_New_Inserts;
var
  Result: Boolean;
begin
  // Arrange: AAttributeID = 0 означает создание нового атрибута
  FMock.InsertAttribute_ReturnValue := 99; // Возвращаемый ID нового атрибута

  // Act: создаем новый атрибут в категории 10 с типом atString
  Result := FService.SaveAttribute(10, 0, 'Color', atString);

  // Assert
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True при успешном сохранении');
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.InsertAttribute_CallCount, 'InsertAttribute должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.UpdateAttribute_CallCount, 'UpdateAttribute не должен вызываться для нового атрибута');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');

  // Проверка переданных параметров в InsertAttribute
  Assert.AreEqual('Color', FMock.LastInsertAttribute_Name, 'Name должен быть проброшен в InsertAttribute');
  Assert.AreEqual('string', FMock.LastInsertAttribute_TypeStr, 'atString должен маппиться в "string" и передаваться в InsertAttribute');
end;

procedure TCatalogServiceFixture.SaveAttribute_Existing_Updates;
var
  Result: Boolean;
begin
  // Arrange: AAttributeID > 0 означает обновление существующего атрибута
  
  // Act: обновляем атрибут с ID=77 в категории 10, меняя тип на atBoolean
  Result := FService.SaveAttribute(10, 77, 'IsFragile', atBoolean);

  // Assert
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True при успешном обновлении');
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.InsertAttribute_CallCount, 'InsertAttribute не должен вызываться для существующего атрибута');
  Assert.AreEqual(1, FMock.UpdateAttribute_CallCount, 'UpdateAttribute должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');

  // Проверка переданных параметров в UpdateAttribute
  Assert.AreEqual(77, FMock.LastUpdateAttribute_ID, 'AAttributeID должен быть проброшен в UpdateAttribute');
  Assert.AreEqual('IsFragile', FMock.LastUpdateAttribute_Name, 'Name должен быть проброшен в UpdateAttribute');
  Assert.AreEqual('boolean', FMock.LastUpdateAttribute_TypeStr, 'atBoolean должен маппиться в "boolean" и передаваться в UpdateAttribute');
end;

procedure TCatalogServiceFixture.SaveAttribute_MapsEnumToStr_String;
var
  Result: Boolean;
begin
  // Act: создаем атрибут с типом atString
  Result := FService.SaveAttribute(1, 0, 'Material', atString);

  // Assert: проверяем маппинг atString -> 'string'
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True');
  Assert.AreEqual('string', FMock.LastInsertAttribute_TypeStr, 'atString должен маппиться в "string"');
end;

procedure TCatalogServiceFixture.SaveAttribute_MapsEnumToStr_Number;
var
  Result: Boolean;
begin
  // Act: создаем атрибут с типом atNumber
  Result := FService.SaveAttribute(1, 0, 'Weight', atNumber);

  // Assert: проверяем маппинг atNumber -> 'number'
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True');
  Assert.AreEqual('number', FMock.LastInsertAttribute_TypeStr, 'atNumber должен маппиться в "number"');
end;

procedure TCatalogServiceFixture.SaveAttribute_MapsEnumToStr_Date;
var
  Result: Boolean;
begin
  // Act: создаем атрибут с типом atDate
  Result := FService.SaveAttribute(1, 0, 'Manufactured', atDate);

  // Assert: проверяем маппинг atDate -> 'date'
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True');
  Assert.AreEqual('date', FMock.LastInsertAttribute_TypeStr, 'atDate должен маппиться в "date"');
end;

procedure TCatalogServiceFixture.SaveAttribute_MapsEnumToStr_Boolean;
var
  Result: Boolean;
begin
  // Act: создаем атрибут с типом atBoolean
  Result := FService.SaveAttribute(1, 0, 'IsActive', atBoolean);

  // Assert: проверяем маппинг atBoolean -> 'boolean'
  Assert.IsTrue(Result, 'SaveAttribute должен вернуть True');
  Assert.AreEqual('boolean', FMock.LastInsertAttribute_TypeStr, 'atBoolean должен маппиться в "boolean"');
end;

procedure TCatalogServiceFixture.SaveAttribute_DBError_Rollbacks;
var
  ExceptionRaised: Boolean;
begin
  // Arrange: настраиваем мок на выброс исключения при InsertAttribute
  FMock.RaiseExceptionOnInsertAttribute := 'Unique constraint violation';

  // Act: вызываем SaveAttribute и перехватываем исключение вручную
  ExceptionRaised := False;
  try
    FService.SaveAttribute(1, 0, 'Duplicate', atString);
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      Assert.IsTrue(Pos('Unique constraint violation', E.Message) > 0, 
        'Текст исключения должен сохраниться при пробросе. Получено: ' + E.Message);
    end;
  end;

  // Assert: исключение должно быть проброшено
  Assert.IsTrue(ExceptionRaised, 'SaveAttribute должен пробросить исключение дальше');

  // Assert: проверяем, что транзакция была откачена
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.InsertAttribute_CallCount, 'InsertAttribute должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

{ ===== Тесты для SavePart (пункт 5.7 спецификации) ===== }

procedure TCatalogServiceFixture.SavePart_UpsertsPartAndValues;
var
  Result: Boolean;
  Values: TArray<TPair<string, string>>;
begin
  // Arrange
  FMock.UpsertPart_ReturnValue := 100; // Мок вернет PartID = 100
  
  FMock.FindAttribute_Result := True;
  FMock.FindAttribute_AttrID := 10;
  FMock.FindAttribute_TypeStr := 'number';
  
  // Создаем массив пар (AttributeName, ValueString)
  SetLength(Values, 2);
  Values[0] := TPair<string, string>.Create('Weight', '123');
  Values[1] := TPair<string, string>.Create('Material', 'Steel');

  // Act
  Result := FService.SavePart(5, 0, 'PART-001', Values);

  // Assert
  Assert.IsTrue(Result, 'SavePart должен вернуть True при успешном сохранении');
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');

  // Проверка вызова UpsertPart
  Assert.AreEqual(1, FMock.UpsertPart_CallCount, 'UpsertPart должен быть вызван ровно 1 раз');
  Assert.AreEqual(5, FMock.LastUpsertPart_CategoryID, 'ACategoryID должен быть проброшен в UpsertPart');
  Assert.AreEqual(0, FMock.LastUpsertPart_PartID, 'APartID должен быть проброшен в UpsertPart');
  Assert.AreEqual('PART-001', FMock.LastUpsertPart_Code, 'ACode должен быть проброшен в UpsertPart');

  // Проверка вызовов FindAttribute и UpsertValue для каждого значения
  Assert.AreEqual(2, FMock.FindAttribute_CallCount, 'FindAttribute должен быть вызван для каждого значения');
  Assert.AreEqual(2, FMock.UpsertValue_CallCount, 'UpsertValue должен быть вызван для каждого значения');
  
  // Проверка параметров последнего вызова UpsertValue (для 'Material')
  Assert.AreEqual(100, FMock.LastUpsertValue_PartID, 'PartID из UpsertPart должен быть проброшен в UpsertValue');
  Assert.AreEqual(10, FMock.LastUpsertValue_AttrID, 'AttrID из FindAttribute должен быть проброшен в UpsertValue');
  Assert.AreEqual('number', FMock.LastUpsertValue_AttrTypeStr, 'TypeStr из FindAttribute должен быть проброшен в UpsertValue');
  Assert.AreEqual('Steel', FMock.LastUpsertValue_ValStr, 'ValStr должен быть проброшен в UpsertValue');
end;

procedure TCatalogServiceFixture.SavePart_AttributeNotFound_Raises;
var
  ExceptionRaised: Boolean;
  Values: TArray<TPair<string, string>>;
begin
  // Arrange
  FMock.UpsertPart_ReturnValue := 100;
  
  // Настраиваем мок на то, что атрибут не будет найден
  FMock.FindAttribute_Result := False;
  
  SetLength(Values, 1);
  Values[0] := TPair<string, string>.Create('NonExistentAttr', 'SomeValue');

  // Act
  ExceptionRaised := False;
  try
    FService.SavePart(5, 0, 'PART-001', Values);
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      Assert.IsTrue(Pos('Атрибут "NonExistentAttr" не найден в категории', E.Message) > 0, 
        'Сообщение исключения должно содержать имя атрибута. Получено: ' + E.Message);
    end;
  end;

  // Assert
  Assert.IsTrue(ExceptionRaised, 'SavePart должен пробросить исключение, если атрибут не найден');
  
  // Проверка отката транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

procedure TCatalogServiceFixture.SavePart_DBErrorOnUpsertValue_Rollbacks;
var
  ExceptionRaised: Boolean;
  Values: TArray<TPair<string, string>>;
begin
  // Arrange
  FMock.UpsertPart_ReturnValue := 100;
  FMock.FindAttribute_Result := True;
  FMock.FindAttribute_AttrID := 10;
  FMock.FindAttribute_TypeStr := 'number';
  
  // Настраиваем мок на выброс исключения при UpsertValue
  FMock.RaiseExceptionOnUpsertValue := 'Database constraint violation';
  
  SetLength(Values, 1);
  Values[0] := TPair<string, string>.Create('Weight', '999');

  // Act
  ExceptionRaised := False;
  try
    FService.SavePart(5, 0, 'PART-001', Values);
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      Assert.IsTrue(Pos('Database constraint violation', E.Message) > 0, 
        'Текст исключения должен сохраниться при пробросе. Получено: ' + E.Message);
    end;
  end;

  // Assert
  Assert.IsTrue(ExceptionRaised, 'SavePart должен пробросить исключение дальше');
  
  // Проверка отката транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван');
  Assert.AreEqual(1, FMock.UpsertPart_CallCount, 'UpsertPart должен быть вызван до ошибки');
  Assert.AreEqual(1, FMock.FindAttribute_CallCount, 'FindAttribute должен быть вызван');
  Assert.AreEqual(1, FMock.UpsertValue_CallCount, 'UpsertValue должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

{ ===== Тесты для DeleteAttribute (пункт 5.8 спецификации) ===== }

procedure TCatalogServiceFixture.DeleteAttribute_Success_ReturnsTrue;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: Мок работает штатно (исключения не бросаются)
  
  // Act: удаляем атрибут с ID=77
  Result := FService.DeleteAttribute(77, ErrorMsg);

  // Assert
  Assert.IsTrue(Result, 'DeleteAttribute должен вернуть True при успешном удалении');
  Assert.AreEqual('', ErrorMsg, 'ErrorMsg должен быть пустой при успехе');
  
  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteAttribute_CallCount, 'DeleteAttribute должен быть вызван ровно 1 раз');
  Assert.AreEqual(77, FMock.LastDeleteAttribute_ID, 'AAttributeID должен быть проброшен в репозиторий');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');
end;

procedure TCatalogServiceFixture.DeleteAttribute_FKViolation_ReturnsFalseWithErrorMsg;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: настраиваем мок на выброс исключения с кодом FK violation (23503)
  // PostgreSQL при нарушении ограничения внешнего ключа возвращает ошибку с кодом 23503
  FMock.RaiseExceptionOnDeleteAttribute := 'ERROR: 23503: update or delete on table "attributes" violates foreign key constraint "fk_part_values_attribute"';

  // Act: пытаемся удалить атрибут с ID=50
  Result := FService.DeleteAttribute(50, ErrorMsg);

  // Assert
  Assert.IsFalse(Result, 'DeleteAttribute должен вернуть False при FK violation');
  Assert.AreEqual('Невозможно удалить атрибут: он используется в существующих деталях.', 
    ErrorMsg, 'ErrorMsg должен содержать понятное пользователю сообщение об FK violation');
  
  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteAttribute_CallCount, 'DeleteAttribute должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(50, FMock.LastDeleteAttribute_ID, 'AAttributeID должен быть проброшен в репозиторий');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

procedure TCatalogServiceFixture.DeleteAttribute_OtherError_ReturnsFalseWithErrorMsg;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: настраиваем мок на выброс исключения БЕЗ кода 23503
  // Это может быть сетевая ошибка, потеря соединения и т.д.
  FMock.RaiseExceptionOnDeleteAttribute := 'Connection lost';

  // Act: пытаемся удалить атрибут с ID=30
  Result := FService.DeleteAttribute(30, ErrorMsg);

  // Assert
  Assert.IsFalse(Result, 'DeleteAttribute должен вернуть False при любой ошибке БД');
  
  // ВАЖНО: Исключение НЕ пробрасывается дальше, а перехватывается в сервисе.
  // ErrorMsg должен начинаться с 'Ошибка удаления: ' и содержать текст оригинальной ошибки
  Assert.IsTrue(Pos('Ошибка удаления: ', ErrorMsg) = 1, 
    'ErrorMsg должен начинаться с "Ошибка удаления: ". Получено: ' + ErrorMsg);
  Assert.IsTrue(Pos('Connection lost', ErrorMsg) > 0, 
    'ErrorMsg должен содержать текст оригинальной ошибки. Получено: ' + ErrorMsg);
  
  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteAttribute_CallCount, 'DeleteAttribute должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(30, FMock.LastDeleteAttribute_ID, 'AAttributeID должен быть проброшен в репозиторий');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

{ ===== Тесты для DeletePart (пункт 5.9 спецификации) ===== }

procedure TCatalogServiceFixture.DeletePart_Success_ReturnsTrue;
var
  Result: Boolean;
begin
  // Arrange: Мок работает штатно (исключения не бросаются)
  
  // Act: удаляем деталь с ID=150
  Result := FService.DeletePart(150);

  // Assert
  Assert.IsTrue(Result, 'DeletePart должен вернуть True при успешном удалении');
  
  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeletePart_CallCount, 'DeletePart должен быть вызван ровно 1 раз');
  Assert.AreEqual(150, FMock.LastDeletePart_ID, 'APartID должен быть проброшен в репозиторий');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');
end;

procedure TCatalogServiceFixture.DeletePart_Error_Raises;
var
  ExceptionRaised: Boolean;
begin
  // Arrange: настраиваем мок на выброс исключения при DeletePart
  FMock.RaiseExceptionOnDeletePart := 'Database connection timeout';

  // Act: вызываем DeletePart и перехватываем исключение вручную.
  // Согласно архитектуре, DeletePart пробрасывает новое исключение с префиксом
  // 'Ошибка при удалении детали: ' + оригинальное сообщение
  ExceptionRaised := False;
  try
    FService.DeletePart(200);
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      // Проверяем, что исключение содержит префикс сервиса
      Assert.IsTrue(Pos('Ошибка при удалении детали: ', E.Message) = 1, 
        'Сообщение исключения должно начинаться с префикса сервиса. Получено: ' + E.Message);
      // Проверяем, что оригинальный текст ошибки сохранен
      Assert.IsTrue(Pos('Database connection timeout', E.Message) > 0, 
        'Сообщение исключения должно содержать оригинальный текст ошибки. Получено: ' + E.Message);
    end;
  end;

  // Assert: исключение должно быть проброшено
  Assert.IsTrue(ExceptionRaised, 'DeletePart должен пробросить исключение дальше');
  
  // Assert: проверяем, что транзакция была откачена
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeletePart_CallCount, 'DeletePart должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(200, FMock.LastDeletePart_ID, 'APartID должен быть проброшен в репозиторий');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

{ ===== Тесты для DeleteCategory (пункт 5.10 спецификации) ===== }

procedure TCatalogServiceFixture.DeleteCategory_Success_ReturnsTrue;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: Мок работает штатно (исключения не бросаются)

  // Act: удаляем категорию с ID=500
  Result := FService.DeleteCategory(500, ErrorMsg);

  // Assert
  Assert.IsTrue(Result, 'DeleteCategory должен вернуть True при успешном удалении');
  Assert.AreEqual('', ErrorMsg, 'ErrorMsg должен быть пустой при успехе');

  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteCategory_CallCount, 'DeleteCategory должен быть вызван ровно 1 раз');
  Assert.AreEqual(500, FMock.LastDeleteCategory_ID, 'ACategoryID должен быть проброшен в репозиторий');
  Assert.AreEqual(1, FMock.CommitTransaction_CallCount, 'CommitTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(0, FMock.RollbackTransaction_CallCount, 'RollbackTransaction не должен вызываться при успехе');
end;

procedure TCatalogServiceFixture.DeleteCategory_FKViolation_ReturnsFalseWithErrorMsg;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: настраиваем мок на выброс исключения с кодом FK violation (23503).
  // Это срабатывает, если у категории есть дочерние категории, атрибуты или детали.
  FMock.RaiseExceptionOnDeleteCategory := 'ERROR: 23503: update or delete on table "categories" violates foreign key constraint "fk_attributes_category"';

  // Act: пытаемся удалить категорию с ID=100
  Result := FService.DeleteCategory(100, ErrorMsg);

  // Assert
  Assert.IsFalse(Result, 'DeleteCategory должен вернуть False при FK violation');
  Assert.AreEqual(
    'Невозможно удалить категорию: в ней есть дочерние категории, атрибуты или детали. Сначала удалите их.',
    ErrorMsg,
    'ErrorMsg должен содержать понятное пользователю сообщение об FK violation');

  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteCategory_CallCount, 'DeleteCategory должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(100, FMock.LastDeleteCategory_ID, 'ACategoryID должен быть проброшен в репозиторий');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

procedure TCatalogServiceFixture.DeleteCategory_OtherError_ReturnsFalseWithErrorMsg;
var
  Result: Boolean;
  ErrorMsg: string;
begin
  // Arrange: настраиваем мок на выброс исключения БЕЗ кода 23503.
  // Это может быть сетевая ошибка, потеря соединения, deadlock и т.д.
  FMock.RaiseExceptionOnDeleteCategory := 'Deadlock detected';

  // Act: пытаемся удалить категорию с ID=200
  Result := FService.DeleteCategory(200, ErrorMsg);

  // Assert
  Assert.IsFalse(Result, 'DeleteCategory должен вернуть False при любой ошибке БД');

  // ВАЖНО: Исключение НЕ пробрасывается дальше, а перехватывается в сервисе.
  // ErrorMsg должен начинаться строго с 'Ошибка удаления категории: '
  Assert.IsTrue(Pos('Ошибка удаления категории: ', ErrorMsg) = 1,
    'ErrorMsg должен начинаться с "Ошибка удаления категории: ". Получено: ' + ErrorMsg);
  Assert.IsTrue(Pos('Deadlock detected', ErrorMsg) > 0,
    'ErrorMsg должен содержать текст оригинальной ошибки. Получено: ' + ErrorMsg);

  // Проверка транзакции
  Assert.AreEqual(1, FMock.BeginTransaction_CallCount, 'BeginTransaction должен быть вызван ровно 1 раз');
  Assert.AreEqual(1, FMock.DeleteCategory_CallCount, 'DeleteCategory должен быть вызван (и выбросить исключение)');
  Assert.AreEqual(200, FMock.LastDeleteCategory_ID, 'ACategoryID должен быть проброшен в репозиторий');
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount, 'CommitTransaction не должен вызываться при ошибке');
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount, 'RollbackTransaction должен быть вызван ровно 1 раз при ошибке');
end;

initialization
  TDUnitX.RegisterTestFixture(TCatalogServiceFixture);

end.
