# frxDevCustomDataSetTests — DUnitX тесты адаптера FastReport

![Platform](https://img.shields.io/badge/platform-Win32-blue)
![Framework](https://img.shields.io/badge/framework-DUnitX-green)
![Delphi](https://img.shields.io/badge/Delphi-XE%2B-red)
![Coverage](https://img.shields.io/badge/coverage-34_tests-brightgreen)
![Sections](https://img.shields.io/badge/sections-4.1.1_+_4.1.2_+_4.1.3_+_4.1.4-blue)

Модульные тесты DUnitX для компонента `TfrxDevCustomDataSet` — адаптера между `TVTBaseDataSource<TVTBaseRecord>` (DevExpress cxVirtualTreeList) и FastReport.

---

## 📋 Обзор

**Тестируемый модуль:** `loader\frxDevDS\frxDevCustomDataSet.pas`  
**Тестируемые классы:**
- `TfrxDevCustomDataSet` — главный адаптер FastReport
- `TVTRecordAdapter` — адаптер одной записи (для Master-Detail)

**Текущий статус:** Реализованы **все 4 раздела спецификации 4.1** — 34 теста (7 + 11 + 8 + 8), все проходят.

| Раздел | Тестов | Статус |
|--------|--------|--------|
| 4.1.1 Привязка к источнику | 7 | ✅ Реализовано |
| 4.1.2 Навигация по записям | 11 | ✅ Реализовано |
| 4.1.3 GetValue / GetDisplayText | 8 | ✅ Реализовано |
| 4.1.4 Адаптер записи (Master-Detail) | 8 | ✅ Реализовано |
| **Итого** | **34** | ✅ **100%** |

---

## 🏗 Структура проекта

```
frxDevCustomDataSetTests/
├── frxDevCustomDataSetFixture.dpr          ← DUnitX runner
├── frxDevCustomDataSetFixture.dproj        ← проект Delphi
├── ufrxDevCustomDataSetFixture.pas         ← фикстура + все тесты
├── frxDevCustomDataSetFixture.md           ← подробная спецификация
└── README.md                               ← этот файл
```

---

## 🔗 Зависимости

### Productive code
| Модуль | Путь | Назначение |
|--------|------|-----------|
| `cxVirtualTreeListHelper` | `Common\` | Дженерик-фреймворк TVT |
| `frxDevDSIntf` | `Common\` | Интерфейсы frxDev |
| `frxDevCustomDataSet` | `loader\frxDevDS\` | Тестируемый компонент |

### External
- **DevExpress VCL** — `cxTL`, `cxTLData`, `cxCustomData` (TcxVirtualTreeList, TcxTreeListColumn)
- **FastReport** — `frxClass`, `frxDsgnIntf` (TfrxUserDataSet, TfrxFieldType)
- **DUnitX** — фреймворк тестирования

---

## 🎭 Тестовая инфраструктура

### TMockRecord
Конкретный наследник `TVTBaseRecord` с 5 колонками разных типов для полного покрытия `GetFieldType`:

| ColIdx | Тип Delphi | VarType | FastReport тип |
|--------|------------|---------|----------------|
| 0 | `Integer` | `varInteger` (3) | `fftNumeric` |
| 1 | `string` | `varUString` (258) | `fftString` |
| 2 | `TDateTime` | `varDate` (7) | `fftDateTime` |
| 3 | `Boolean` | `varBoolean` (11) | `fftBoolean` |
| 4 | `Null` | `0` (особый случай) | `fftString` (default) |

### TTestFrxDevCustomDataSet
Тестовый наследник `TfrxDevCustomDataSet`, реэкспортирующий `protected`-свойства как `public`:

```delphi
TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
public
  property FieldIndexes;  // TList<Integer>
  property FieldTypes;    // TList<TfrxFieldType>
  property CurrentIndex;  // Integer
end;
```

### TTestTVTRecordAdapter
Тестовый наследник `TVTRecordAdapter`, реэкспортирующий `protected`-свойства как `public`:

```delphi
TTestTVTRecordAdapter = class(TVTRecordAdapter)
public
  property FieldIndexes;  // TList<Integer>
  property FieldTypes;    // TList<TfrxFieldType>
  property FieldNames;    // TStringList
end;
```

**Зачем:** Устойчивее и производительнее, чем RTTI. Работает в любой конфигурации (Debug/Release).

### VCL-инициализация
`TcxVirtualTreeList` требует глобальный `Application` singleton из `Vcl.Forms`. В консольном DUnitX-раннере `Vcl.Forms` подключён в `.dpr`, поэтому `Application` создаётся автоматически.

---

## ✅ Реализованные тесты

### 4.1.1 — Привязка к источнику (AssignDataSource) — 7 тестов

| № | Тест | Что проверяет |
|---|------|---------------|
| 4.1.1.1 | `AssignDataSource_NilDataSource_RaisesException` | `nil` в `ADataSource` → `EArgumentNilException` с текстом `'ADataSource must not be nil'` |
| 4.1.1.2 | `AssignDataSource_NilTreeList_RaisesException` | `nil` в `ATreeList` → `EArgumentNilException` с текстом `'ATreeList must not be nil'` |
| 4.1.1.3 | `AssignDataSource_BuildsFieldListFromColumns` | 3 видимые колонки → `Fields.Count=3`, `FieldIndexes.Count=3`, `FieldTypes.Count=3` |
| 4.1.1.4 | `AssignDataSource_HiddenColumn_Skipped` | Колонка с `Visible=False` пропускается |
| 4.1.1.5 | `AssignDataSource_EmptyColumnCaption_GeneratesColN` | Пустые `Caption.Text` → авто-имена `Col0`, `Col1`, ... |
| 4.1.1.6 | `AssignDataSource_DuplicateColumnNames_AddsSuffix` | Дублирующиеся имена → суффикс `_N` (`Name`, `Name_1`, `Name_2`) |
| 4.1.1.7 | `AssignDataSource_ClearsPreviousState` | Повторная привязка очищает предыдущее состояние |

### 4.1.2 — Навигация по записям — 11 тестов

| № | Тест | Что проверяет |
|---|------|---------------|
| 4.1.2.1 | `Open_SetsCurrentIndexToMinusOne` | `Open` сбрасывает `CurrentIndex = -1` |
| 4.1.2.2 | `First_SetsCurrentIndexToZero` | `First` устанавливает `CurrentIndex = 0`, создаёт активный адаптер |
| 4.1.2.3 | `Next_IncrementsIndex` | Последовательная навигация: `CurrentIndex` инкрементируется |
| 4.1.2.4 | `Eof_TrueWhenNoMoreNodes` | `Eof = True` после прохождения всех записей |
| 4.1.2.5 | `Eof_TrueWhenNoDataSource` | Без привязки `Eof = True` |
| 4.1.2.6 | `RecordCount_ReturnsRootTotalCount` | `RecordCount = RootHandle.TotalCount` |
| 4.1.2.7 | `Close_ResetsNavigationState` | `Close` полностью сбрасывает состояние |
| 4.1.2.8 | `First_OnEmptyDataSource_SetsNilAdapter` | `First` на пустом источнике |
| 4.1.2.9 | `RecordCount_NoDataSource_ReturnsZero` | `RecordCount = 0` без привязки |
| 4.1.2.10 | `First_MultipleCalls_ResetToBeginning` | Повторный `First` сбрасывает в начало |
| 4.1.2.11 | `Next_AfterEof_NoException` | `Next` после `Eof` не падает |

### 4.1.3 — GetValue / GetDisplayText — 8 тестов

| № | Тест | Что проверяет |
|---|------|---------------|
| 4.1.3.1 | `GetValue_ReturnsNull_WhenNoActiveAdapter` | Без активного адаптера `GetValue` → `Null` |
| 4.1.3.2 | `GetDisplayText_ReturnsEmpty_WhenNoActiveAdapter` | Без активного адаптера `GetDisplayText` → `''` |
| 4.1.3.3 | `GetValue_CallsAdapterGetValue` | Делегирование для 5 типов данных с сохранением VarType |
| 4.1.3.4 | `GetDisplayText_CallsAdapterGetDisplayText` | Форматирование в WideString |
| 4.1.3.5 | `GetValue_UnknownField_ReturnsNull` | Несуществующее поле → `Null`, поиск case-insensitive |
| 4.1.3.6 | `GetFieldType_ReturnsCorrectType` | Маппинг VarType → FastReport-тип |
| 4.1.3.7 | `GetValue_AfterNext_ReturnsNextRecordValues` | После `Next` значения меняются |
| 4.1.3.8 | `GetValue_EmptyDataSource_ReturnsNull` | На пустом источнике `GetValue` → `Null` |

### 4.1.4 — Адаптер записи (Master-Detail) — 8 тестов

| № | Тест | Что проверяет |
|---|------|---------------|
| 4.1.4.1 | `GetAdapterForRecord_CreatesNew_IfNotExists` | Создание нового адаптера с привязкой к записи через `SourceRecord` |
| 4.1.4.2 | `GetAdapterForRecord_ReturnsExisting_IfExists` | Кэш адаптеров (AreSame для одной записи) |
| 4.1.4.3 | `GetAdapterForRecord_DifferentRecords_DifferentAdapters` | Разные адаптеры для разных записей |
| 4.1.4.4 | `GetAdapterForRecord_PreservesFieldMetadata` | Копирование `FieldNames`, `FieldIndexes`, `FieldTypes` (адаптер владеет своими копиями) |
| 4.1.4.5 | `GetAdapterForRecord_RecordCount_AlwaysOne` | `RecordCount = 1` всегда (семантика "одна запись на адаптер") |
| 4.1.4.6 | `GetAdapterForRecord_Navigation_OneRecordLifecycle` | Полный цикл: `Open` → `First` → `Next` → `Eof=True` |
| 4.1.4.7 | `GetAdapterForRecord_GetValue_DelegatesToSource` | Делегирование `GetValue` исходной записи, case-insensitive поиск |
| 4.1.4.8 | `GetAdapterForRecord_CacheClearedOnReassign` | Повторная `AssignDataSource` очищает кэш адаптеров |

---

## 🔑 Ключевые архитектурные решения

### 1. Два варианта Setup для разных разделов

```delphi
// Для 4.1.1 (привязка): FDataSource с nil
FDataSource := TVTLoadAllDataSource<TMockRecord>.Create(nil);

// Для 4.1.2+ (навигация, GetValue, Master-Detail): FDataSource с FTreeList
FDataSource := TVTLoadAllDataSource<TMockRecord>.Create(FTreeList);
```

**Зачем:** Навигация и `GetValue` требуют VCL-узлов в `FTreeList`, которые создаются автоматически только при передаче `FTreeList` в конструктор.

### 2. Критическое правило: `DataChanged` после заполнения данных

```delphi
PopulateDataSource(N);
FDataSource.DataChanged;  // ← КРИТИЧНО
```

**Зачем:** `DataChanged` связывает записи `TVTBaseRecord` с VCL-узлами `TcxTreeListNode`. Без этого `FTreeList.Root.getFirstChild` возвращает `nil`, и `InternalFirst`/`InternalNext` не работают.

### 3. Обязательный explicit cast при привязке

```delphi
FDataSet.AssignDataSource(TVTBaseDataSource<TVTBaseRecord>(FDataSource), FTreeList);
```

**Зачем:** Delphi generics не поддерживают ковариантность — `TVTLoadAllDataSource<TMockRecord>` несовместим с `TVTBaseDataSource<TVTBaseRecord>` без явного cast.

### 4. Тестовый наследник вместо RTTI

```delphi
TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
public
  property FieldIndexes;
  property FieldTypes;
  property CurrentIndex;
end;

TTestTVTRecordAdapter = class(TVTRecordAdapter)
public
  property FieldIndexes;
  property FieldTypes;
  property FieldNames;
end;
```

**Преимущества:**
- ✅ Устойчивость к оптимизациям компилятора в Release
- ✅ Быстрее (нет накладных расходов на рефлексию)
- ✅ Не требует `{$RTTI EXPLICIT FIELDS([vcPrivate])}`
- ✅ Единственное поле без прямого доступа — `FActiveAdapter` (проверяется косвенно через `GetValue`)

### 5. Использование `CreateColumn` вместо `Columns.Add`

```delphi
Col := FTreeList.CreateColumn;  // ✅ ПРАВИЛЬНО
// Col := FTreeList.Columns.Add; // ❌ НЕПРАВИЛЬНО (метод не существует)
```

### 6. Поиск имён полей case-insensitive

`TStringList.CaseSensitive = False` по умолчанию, поэтому `GetValue('id')` и `GetValue('ID')` возвращают одно и то же. Это документировано в тестах 4.1.3.5 и 4.1.4.7.

---

## 🚀 Как собрать и запустить

### Требования
- Delphi XE или новее
- DevExpress VCL (установлен в IDE)
- FastReport VCL (установлен в IDE)
- DUnitX (встроен в Delphi или установлен отдельно)

### Из IDE
1. Открыть `frxDevCustomDataSetFixture.dproj` в Delphi
2. Выбрать конфигурацию **Debug | Win32**
3. Убедиться, что в **Search Path** указаны:
   ```
   ..\..\..\Common
   ..\..\frxDevDS
   ```
4. Запустить (F9)

### Из командной строки
```cmd
frxDevCustomDataSetFixture.exe
```

### С выводом в NUnit XML (для CI/CD)
```cmd
frxDevCustomDataSetFixture.exe --format=NUNIT --output=dunitx-results.xml
```

---

## 🐛 Типовые проблемы

### Проблема 1: `EInvalidOperation: Cannot create form`
**Причина:** `TcxVirtualTreeList.Create(nil)` требует VCL-контекст.  
**Решение:** Убедитесь, что `Vcl.Forms` подключён в `.dpr` **до** `ufrxDevCustomDataSetFixture`.

### Проблема 2: `GetValue` возвращает `Null` после `First`
**Причина:** Записи не связаны с VCL-узлами.  
**Решение:** Вызвать `FDataSource.DataChanged` после `PopulateDataSource`.

### Проблема 3: `EAccessViolation` в `InternalFirst`
**Причина:** `FDataSource` создан с `nil`, VCL-узлы не созданы.  
**Решение:** Использовать `SetupForNavigation`, который создаёт `FDataSource` с `FTreeList`.

### Проблема 4: `EInvalidCast` в `AssignDataSource`
**Причина:** Delphi generics не поддерживают ковариантность.  
**Решение:** Обязательный explicit cast `TVTBaseDataSource<TVTBaseRecord>(FDataSource)`.

### Проблема 5: `E2029` / `Columns.Add` не существует
**Причина:** `TcxVirtualTreeList` не имеет метода `Columns.Add`.  
**Решение:** Использовать только `FTreeList.CreateColumn`.

### Проблема 6: `FCurrentNode = nil` после `First`
**Причина:** `FTreeList.Root.getFirstChild` возвращает `nil`.  
**Решение:** Передать `FTreeList` в конструктор `TVTLoadAllDataSource`.

### Проблема 7: `Adapter.SourceRecord = nil`
**Причина:** Запись не привязана к VCL-узлу.  
**Решение:** Вызвать `FDataSource.DataChanged` после `InsertRecordHandle`.

---

## 📊 Матрица покрытия раздела 4.1

### TfrxDevCustomDataSet

| Метод | Тесты |
|-------|-------|
| `AssignDataSource` | 4.1.1.1–4.1.1.7, 4.1.4.8 |
| `Open` | 4.1.2.1 |
| `Close` | 4.1.2.7 |
| `First` | 4.1.2.2, 4.1.2.8, 4.1.2.10 |
| `Next` | 4.1.2.3, 4.1.2.11 |
| `Eof` | 4.1.2.4, 4.1.2.5 |
| `GetValue` | 4.1.3.1, 4.1.3.3, 4.1.3.5, 4.1.3.7, 4.1.3.8 |
| `GetDisplayText` | 4.1.3.2, 4.1.3.4 |
| `GetFieldType` | 4.1.3.6 |
| `RecordCount` | 4.1.2.6, 4.1.2.9 |
| `GetAdapterForRecord` | 4.1.4.1–4.1.4.8 |
| `BuildFieldListFromTreeList` | через 4.1.1.3–4.1.1.6 |

### TVTRecordAdapter

| Метод | Тесты |
|-------|-------|
| `Create` | 4.1.4.1, 4.1.4.4 |
| `Open` / `Close` / `First` / `Next` / `Eof` | 4.1.4.6 |
| `GetValue` | 4.1.4.7 (через 4.1.3.3, 4.1.3.5) |
| `GetDisplayText` | через 4.1.3.4 |
| `GetFieldList` / `FieldsCount` | 4.1.4.4 |
| `RecordCount` | 4.1.4.5 |
| `SourceRecord` (property) | 4.1.4.1, 4.1.4.3 |

---

## 📝 Следующие шаги

Согласно спецификации `DUnitXLoader.md`, следующие модули для реализации:

| Модуль | Раздел | Приоритет | Описание |
|--------|--------|-----------|----------|
| **frxDevCustomDataSet** | 4.2 TVTRecordAdapterFixture | P1 | Изолированные тесты самого адаптера (12 тестов) |
| **VirtualDataCache** | 5.1 | P2 | Кэш с LRU-eviction и семафором (12 тестов) |
| **uCatalogService** | 6.1 | P2 | Сервис каталога с мок-БД (24 теста) |
| **uCalcPrice** | 7.1 | P1 | Расчёт цен с НДС (12 тестов) |

---

## 📄 Лицензия и авторство

Тесты созданы в рамках проекта `loader` для автоматизации контроля качества адаптера FastReport.

**Дата последней актуализации:** Август 2026  
**Версия спецификации:** 1.6  
**Статус:** Раздел 4.1 реализован полностью (34 теста)
