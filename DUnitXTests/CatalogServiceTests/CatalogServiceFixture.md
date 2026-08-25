# Спецификация тестов для TCatalogService (CatalogServiceFixture)
## Архитектурная стратегия: Interface Extraction & Repository Pattern

### 1. Обзор и цель рефакторинга
Текущая реализация `TCatalogService` жестко связана с VCL DataModule `TdmDB` и компонентами `TFDQuery`. Это нарушает принцип инверсии зависимостей (DIP) и делает написание чистых Unit-тестов невозможным без поднятия реальной базы данных или сложного мокинга UI-компонентов.

**Архитектурная стратегия** предполагает извлечение интерфейса `ICatalogRepository`, который инкапсулирует работу с БД. `TCatalogService` должен зависеть только от этого интерфейса. Это позволит использовать легковесные in-memory моки для тестирования бизнес-логики сервиса.

---

### 2. Проектирование интерфейса ICatalogRepository

Для корректного разделения ответственности интерфейс должен работать с "сырыми" записями БД (DTO), оставляя бизнес-маппинг в сервисе.

```pascal
type
  // Сырые записи, возвращаемые из БД
  TDBCategory = record
    ID: Integer;
    ParentID: Integer; // 0, если в БД был NULL
    Name: string;
    ChildCount: Integer;
  end;

  TDBAttribute = record
    ID: Integer;
    Name: string;
    TypeStr: string; // 'string', 'number', 'date', 'boolean'
  end;

  TDBPartValue = record
    PartID: Integer;
    Code: string;
    AttrName: string;
    // Используем Variant для поддержки SQL NULL
    ValStr: Variant;
    ValNum: Variant;
    ValDate: Variant;
    ValBool: Variant;
  end;

  ICatalogRepository = interface
    ['{B5E3D2A1-1234-5678-9ABC-DEF012345678}']
    // Транзакции
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;

    // Чтение
    function SelectCategories: TArray<TDBCategory>;
    function SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
    function SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;
    
    // Поиск атрибута по имени (необходимо для SavePart)
    function FindAttribute(ACategoryID: Integer; const AName: string; out AAttrID: Integer; out ATypeStr: string): Boolean;
    
    // Запись (CRUD)
    function InsertCategory(const AName: string; AParentID: Integer): Integer;
    function UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;
    
    function InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
    function UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;
    
    function UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer; // Возвращает PartID
    procedure UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);
    
    // Удаление. При ошибке БД (в т.ч. FK violation) пробрасывает Exception
    procedure DeleteAttribute(AAttributeID: Integer);
    procedure DeletePart(APartID: Integer);
    procedure DeleteCategory(ACategoryID: Integer);
  end;
```

---

### 3. Разделение ответственности (Service vs Repository)

В результате рефакторинга логика разделяется следующим образом:

| Логика | Где находится | Как тестируется |
| :--- | :--- | :--- |
| **Маппинг типов** (`TAttrType` ↔ `'string'`) | `TCatalogService` | Unit-тесты с моками (проверка маппинга). |
| **Группировка EAV** (строки БД → `TPartRow`) | `TCatalogService` | Unit-тесты (мок возвращает массив `TDBPartValue`). |
| **Форматирование UI** (`True` → `'Да'`) | `TCatalogService` | Unit-тесты (проверка строк в словаре `Values`). |
| **Управление транзакциями** | `TCatalogService` | Unit-тесты (проверка вызовов `Begin/Commit/Rollback`). |
| **Обработка ошибок FK** (парсинг `'23503'`) | `TCatalogService` | Unit-тесты (мок бросает Exception с нужным текстом). |
| **Парсинг чисел/дат** (`TryStrToInt`, `StrToDate`) | **Реализация репозитория** | *Интеграционные тесты репозитория (с реальной БД).* |
| **Работа с параметрами FireDAC** (`Clear`, `AsInteger`) | **Реализация репозитория** | *Интеграционные тесты репозитория.* |

> **Важное изменение:** Логика записи `0` при невалидном числе и генерация `EConvertError` для невалидных дат в `SavePart` **переносится в реализацию `ICatalogRepository`**. `TCatalogService` просто передает строковое значение в `UpsertValue`. Это делает сервис чище, а тестирование парсинга строк переносится на уровень репозитория.

---

### 4. Проектирование мока (TMockCatalogRepository)

Для тестов создается класс `TMockCatalogRepository`, реализующий `ICatalogRepository`.

**Возможности мока:**
1. **Хранилище:** Внутренние `TList<TDBCategory>`, `TList<TDBAttribute>` и т.д. для возврата данных в `Select...` методах.
2. **Счетчики вызовов:** Поля `InsertCategory_CallCount`, `UpsertValue_CallCount` и списки переданных параметров для проверки (Assertions).
3. **Инъекция ошибок:** Свойства `RaiseExceptionOnDeleteAttribute: string` или `RaiseExceptionOnUpsert: Exception`. Если строка задана, метод бросает `Exception.Create(FErrorMessage)`. Это необходимо для тестирования перехвата кода `23503`.

---

### 5. Детализация тест-кейсов (TCatalogServiceFixture)

#### 5.1. Setup и TearDown
- **[Setup]**: Создание `TMockCatalogRepository` и `TCatalogService`.
- **[TearDown]**: Освобождение `TCatalogService` и мока.
- **Важно:** Метод `GetParts` создает объекты `TPartRow`. В каждом тесте, который вызывает `GetParts`, необходимо вручную освобождать элементы возвращаемого массива в конце теста, иначе произойдет утечка памяти (Memory Leak).

#### 5.2. GetCategories
- **GetCategories_DelegatesAndReturns**
  - *Arrange:* Мок настраивается на возврат 2 записей `TDBCategory`.
  - *Assert:* `Length(Result) = 2`. Поля скопированы корректно.
- **GetCategories_EmptyTable_ReturnsEmptyArray**
  - *Assert:* `Length(Result) = 0`.

#### 5.3. GetCategoryAttributes
- **GetAttributes_MapsTypeStrings**
  - *Arrange:* Мок возвращает атрибуты с `TypeStr` = `'string'`, `'number'`, `'date'`, `'boolean'`.
  - *Assert:* Сервис корректно маппит их в `atString`, `atNumber`, `atDate`, `atBoolean`.

#### 5.4. GetParts (Самый сложный тест на маппинг)
- **GetParts_GroupsByPartIDAndFormatsValues**
  - *Arrange:* Мок возвращает 2 строки `TDBPartValue` для **одного** `PartID`:
    1. `AttrName`='Color', `ValStr`='Red'
    2. `AttrName`='IsFragile', `ValBool`=True
  - *Assert:*
    - `Length(Result) = 1`.
    - `Result[0].Values['Color'] = 'Red'`.
    - `Result[0].Values['IsFragile'] = 'Да'` (проверка UI-форматирования).
  - *Cleanup:* `Result[0].Free`.
- **GetParts_WithSearchTerm_DelegatesParameter**
  - *Assert:* Переданный `ASearchTerm` проброшен в `Mock.SelectParts`.

#### 5.5. SaveCategory
- **SaveCategory_New_Inserts**
  - *Arrange:* `ACategoryID = 0`.
  - *Assert:* Вызван `Mock.InsertCategory`, `CommitTransaction` вызван.
- **SaveCategory_Existing_Updates**
  - *Arrange:* `ACategoryID = 5`.
  - *Assert:* Вызван `Mock.UpdateCategory`.
- **SaveCategory_DBError_Rollbacks**
  - *Arrange:* Мок настроен бросать `Exception` при `InsertCategory`.
  - *Assert:* Вызван `RollbackTransaction`, исключение проброшено дальше (`raise`).

#### 5.6. SaveAttribute
- **SaveAttribute_MapsEnumToStr**
  - *Arrange:* `AType = atBoolean`.
  - *Assert:* В `Mock.InsertAttribute` передан `TypeStr = 'boolean'`.
- **SaveAttribute_DBError_Rollbacks**
  - *Assert:* `RollbackTransaction` вызван, исключение проброшено.

#### 5.7. SavePart
- **SavePart_UpsertsPartAndValues**
  - *Arrange:* 
    - `Mock.UpsertPart` возвращает `PartID = 100`.
    - `Mock.FindAttribute` возвращает `AttrID = 10`, `TypeStr = 'number'`.
  - *Assert:* Вызван `Mock.UpsertValue(100, 10, 'number', '123')`.
- **SavePart_AttributeNotFound_Raises**
  - *Arrange:* `Mock.FindAttribute` возвращает `False`.
  - *Assert:* Брошено исключение `Атрибут "..." не найден в категории`. `RollbackTransaction` вызван.

#### 5.8. DeleteAttribute (Тестирование обработки FK)
- **DeleteAttribute_Success**
  - *Arrange:* Мок работает штатно.
  - *Assert:* `Result = True`.
- **DeleteAttribute_FKViolation_ReturnsFalseWithErrorMsg**
  - *Arrange:* Мок бросает `Exception.Create('...ERROR: 23503...')`.
  - *Assert:* `Result = False`. `AErrorMsg = 'Невозможно удалить атрибут: он используется в существующих деталях.'`.
- **DeleteAttribute_OtherError_ReturnsFalseWithErrorMsg**
  - *Arrange:* Мок бросает `Exception.Create('Connection lost')` (без `23503`).
  - *Assert:* `Result = False`. `AErrorMsg` начинается с `'Ошибка удаления: '`. *(Исключение НЕ пробрасывается)*.

#### 5.9. DeletePart
- **DeletePart_Success**
  - *Assert:* `Result = True`.
- **DeletePart_Error_Raises**
  - *Arrange:* Мок бросает `Exception`.
  - *Assert:* Сервис пробрасывает новое исключение с текстом `'Ошибка при удалении детали: ' + E.Message`.

#### 5.10. DeleteCategory
- **DeleteCategory_FKViolation_ReturnsFalseWithErrorMsg**
  - *Arrange:* Мок бросает `Exception` с `23503`.
  - *Assert:* `Result = False`. `AErrorMsg` начинается с `'Невозможно удалить категорию: в ней есть дочерние...'`.
- **DeleteCategory_OtherError_ReturnsFalseWithErrorMsg**
  - *Arrange:* Мок бросает `Exception` без `23503`.
  - *Assert:* `Result = False`. `AErrorMsg` = `'Ошибка удаления категории: ' + Message`. *(Исключение НЕ пробрасывается)*.

---

### 6. Чек-лист внедрения для разработчика

1. [ ] **Создать юнит `uCatalogRepositoryIntf.pas`** с определением `ICatalogRepository` и DTO-записей (`TDBCategory`, `TDBAttribute`, `TDBPartValue`).
2. [ ] **Рефакторинг `TCatalogService`:** 
    - Заменить поле `FDM: TdmDB` на `FRepo: ICatalogRepository`.
    - Переписать методы чтения, чтобы они использовали `FRepo.Select...` и маппили DTO в доменные объекты (`TCategory`, `TAttributeDef`, `TPartRow`).
    - Переписать методы записи (`SavePart`, `SaveCategory`), чтобы они вызывали методы репозитория, а не `FDM.qry...ExecSQL`.
    - Оставить блоки `try...except` с парсингом `'23503'` для методов `Delete...`.
3. [ ] **Реализовать `TdmDBCatalogRepository`:** 
    - Создать класс, реализующий `ICatalogRepository` и использующий `TdmDB`.
    - Перенести сюда логику `TryStrToInt`, `StrToDate` и работу с параметрами `TFDQuery` из старого `SavePart`.
4. [ ] **Создать `TMockCatalogRepository`** в папке тестов.
5. [ ] **Написать тесты** в `uCatalogServiceFixture.pas` согласно разделу 5.
6. [ ] **Внедрить зависимость:** Обновить места создания `TCatalogService` в UI-коде (например, `Create(TdmDBCatalogRepository.Create(dmDB))`).
