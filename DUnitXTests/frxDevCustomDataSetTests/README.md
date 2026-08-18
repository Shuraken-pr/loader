# frxDevCustomDataSetTests — DUnitX тесты адаптера FastReport

![Platform](https://img.shields.io/badge/platform-Win32-blue)
![Framework](https://img.shields.io/badge/framework-DUnitX-green)
![Delphi](https://img.shields.io/badge/Delphi-XE%2B-red)
![Coverage](https://img.shields.io/badge/coverage_4.1.1-7%2F7_tests-brightgreen)

Модульные тесты DUnitX для компонента `TfrxDevCustomDataSet` — адаптера между `TVTBaseDataSource<TVTBaseRecord>` (DevExpress cxVirtualTreeList) и FastReport.

---

## 📋 Обзор

**Тестируемый модуль:** `loader\frxDevDS\frxDevCustomDataSet.pas`  
**Тестируемые классы:**
- `TfrxDevCustomDataSet` — главный адаптер FastReport
- `TVTRecordAdapter` — адаптер одной записи (для Master-Detail)

**Текущий статус:** Реализован раздел **4.1.1 (Привязка к источнику)** — 7 тестов, все проходят.

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
Тестовый наследник, реэкспортирующий `protected`-свойства как `public`:

```delphi
TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
public
  property FieldIndexes;  // TList<Integer>
  property FieldTypes;    // TList<TfrxFieldType>
end;
```

**Зачем:** Устойчивее и производительнее, чем RTTI. Работает в любой конфигурации (Debug/Release).

### VCL-инициализация
`TcxVirtualTreeList` требует глобальный `Application` singleton из `Vcl.Forms`. В консольном DUnitX-раннере `Vcl.Forms` подключён в `.dpr`, поэтому `Application` создаётся автоматически.

---

## ✅ Реализованные тесты (4.1.1 — Привязка к источнику)

| № | Тест | Что проверяет |
|---|------|---------------|
| **4.1.1.1** | `AssignDataSource_NilDataSource_RaisesException` | `nil` в `ADataSource` → `EArgumentNilException` с текстом `'ADataSource must not be nil'` |
| **4.1.1.2** | `AssignDataSource_NilTreeList_RaisesException` | `nil` в `ATreeList` → `EArgumentNilException` с текстом `'ATreeList must not be nil'` |
| **4.1.1.3** | `AssignDataSource_BuildsFieldListFromColumns` | 3 видимые колонки → `Fields.Count=3`, `FieldIndexes.Count=3`, `FieldTypes.Count=3`, корректные имена и типы |
| **4.1.1.4** | `AssignDataSource_HiddenColumn_Skipped` | Колонка с `Visible=False` пропускается |
| **4.1.1.5** | `AssignDataSource_EmptyColumnCaption_GeneratesColN` | Пустые `Caption.Text` → авто-имена `Col0`, `Col1`, ... |
| **4.1.1.6** | `AssignDataSource_DuplicateColumnNames_AddsSuffix` | Дублирующиеся имена → суффикс `_N` (`Name`, `Name_1`, `Name_2`) |
| **4.1.1.7** | `AssignDataSource_ClearsPreviousState` | Повторная привязка очищает предыдущие `Fields`, `FieldIndexes`, `FieldTypes`, `FAdapters` |

### Покрытие спецификации: 7/7 ✅

---

## 🔑 Ключевые архитектурные решения

### 1. `nil` вместо `TcxVirtualTreeList` в `TVTLoadAllDataSource.Create`

```delphi
FDataSource := TVTLoadAllDataSource<TMockRecord>.Create(nil);
```

**Зачем:** CRUD-логика не требует UI. Реальный `TcxVirtualTreeList` создаётся только в тестах, где нужна проверка `BuildFieldListFromTreeList`.

### 2. Тестовый наследник вместо RTTI

```delphi
TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
public
  property FieldIndexes;
  property FieldTypes;
end;
```

**Преимущества:**
- ✅ Устойчивость к оптимизациям компилятора в Release
- ✅ Быстрее (нет накладных расходов на рефлексию)
- ✅ Не требует `{$RTTI EXPLICIT FIELDS([vcPrivate])}`

### 3. `BuildFieldListFromTreeList` требует хотя бы одну запись

Метод определяет типы полей по **первой записи** `RootHandle[0]`:
```delphi
SourceType := TVTBaseRecord(FDataSource.RootHandle[0]).GetFieldType(I);
```

Если `FDataSource` пуст, `SourceType = 0` (varEmpty) → все типы становятся `fftString` (default). Тесты заполняют DataSource перед привязкой.

### 4. Обработка скрытых колонок

```delphi
if not Col.Visible then Continue;
```

`FieldIndexes` содержит **индексы в TreeList** (с учётом скрытых), но только для видимых колонок. Например, если TreeList имеет колонки `[Visible, Hidden, Visible]`, то `FieldIndexes = [0, 2]`.

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

### Проблема 2: `EAccessViolation` в `BuildFieldListFromTreeList`
**Причина:** `FDataSource` пуст, и обращение к `RootHandle[0]` возвращает `nil`.  
**Решение:** Вызовите `PopulateDataSource(1)` **перед** `AssignDataSource`.

### Проблема 3: Тесты 4.1.1.1/4.1.1.2 падают с `EOleException`
**Причина:** Метод `AssignDataSource` не должен быть `safecall`.  
**Решение:** Убедитесь, что `AssignDataSource` объявлен как `register` (по умолчанию).

### Проблема 4: `Duplicate key` в тестах дубликатов
**Причина:** `TfrxUserDataSet.Fields` — это `TStringList` без дубликатов по умолчанию.  
**Решение:** В реализации `BuildFieldListFromTreeList` добавляются суффиксы `_N`, поэтому дубликатов нет.

---

## 📊 Матрица покрытия раздела 4.1.1

| Метод | Прямое тестирование | Косвенное тестирование |
|-------|---------------------|------------------------|
| `AssignDataSource` | ✅ 4.1.1.1, 4.1.1.2, 4.1.1.3, 4.1.1.7 | 4.1.1.4–4.1.1.6 |
| `BuildFieldListFromTreeList` | ✅ через 4.1.1.3 | 4.1.1.4, 4.1.1.5, 4.1.1.6 |
| Валидация `nil` параметров | ✅ 4.1.1.1, 4.1.1.2 | — |
| Генерация авто-имён | ✅ 4.1.1.5 | — |
| Разрешение дубликатов | ✅ 4.1.1.6 | — |
| Очистка состояния | ✅ 4.1.1.7 | — |

**Итог:** 100% покрытие раздела 4.1.1 спецификации.

---

## 📝 Следующие шаги

Согласно спецификации, следующие разделы для реализации:

| Раздел | Тестов | Описание | Приоритет |
|--------|--------|----------|-----------|
| **4.1.2** Навигация | 6 | `Open`, `First`, `Next`, `Eof`, `RecordCount` | P0 |
| **4.1.3** GetValue / GetDisplayText | 6 | Делегирование активному адаптеру | P1 |
| **4.1.4** Master-Detail (адаптеры) | 6 | `GetAdapterForRecord`, кэширование | P1 |
| **4.2** TVTRecordAdapterFixture | 12 | Тесты самого адаптера | P1 |

---

## 📄 Лицензия и авторство

Тесты созданы в рамках проекта `loader` для автоматизации контроля качества адаптера FastReport.

**Дата последней актуализации:** Август 2026  
**Версия спецификации:** 1.0
