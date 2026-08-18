# frxDevCustomDataSetTests

DUnitX-тесты адаптера `TfrxDevCustomDataSet` и автономного адаптера одной записи `TVTRecordAdapter`.

## Текущее состояние

- Платформа проекта: **Win32**.
- Тип приложения: консольный DUnitX runner.
- Зарегистрировано **52 теста**.
- Фикстуры:
  - `TfrxDevCustomDataSetFixture` — 34 теста, интеграция с `TcxVirtualTreeList`;
  - `TfrxDevCustomDataSetAdapterFixture` — 18 тестов, автономная проверка `TVTRecordAdapter`.
- Последний сохранённый результат в `exe/dunitx-results.xml`: **52 теста, 0 ошибок, 0 падений** (2026-08-19).
- Проект не использует отдельный файл `frxDevCustomDataSetTests.dpr`; фактический runner — `frxDevCustomDataSetFixture.dpr`.

## Структура каталога

```text
frxDevCustomDataSetTests/
├── frxDevCustomDataSetFixture.dpr       # главный DUnitX runner
├── frxDevCustomDataSetFixture.dproj     # проект Delphi
├── ufrxDevCustomDataSetFixture.pas      # TMockRecord, фикстуры и тесты
├── frxDevCustomDataSetFixture.md        # подробная спецификация тестов
├── README.md                            # описание проекта
└── exe/
    ├── frxDevCustomDataSetFixture.exe   # сохранённый бинарный результат сборки
    └── dunitx-results.xml               # NUnit XML последнего запуска
```

Каталоги `Win32\Debug` и `Win32\Release` используются Delphi для DCU-файлов. Файлы IDE (`.dsk`, `.dsv`, `.identcache`, `.skincfg`, `.dproj.local`) не являются частью тестовой логики.

## Что тестируется

Тестируемый production-модуль:

```text
loader\frxDevDS\frxDevCustomDataSet.pas
```

Целевые классы:

- `TfrxDevCustomDataSet` — адаптер `TVTBaseDataSource<TVTBaseRecord>` к FastReport;
- `TVTRecordAdapter` — адаптер одной записи для Master-Detail.

## Разделы тестов

### 4.1 `TfrxDevCustomDataSetFixture` — 34 теста

| Раздел | Количество | Покрытие |
|---|---:|---|
| 4.1.1 Привязка к источнику | 7 | Проверка аргументов, построение полей, скрытые колонки, имена, повторная привязка |
| 4.1.2 Навигация | 11 | `Open`, `Close`, `First`, `Next`, `Eof`, `RecordCount`, пустой источник |
| 4.1.3 `GetValue` / `GetDisplayText` | 8 | Делегирование активному адаптеру, значения разных типов, неизвестные поля, типы полей |
| 4.1.4 Адаптер записи / Master-Detail | 8 | Создание и кэширование адаптеров, метаданные, навигация одной записи, очистка кэша |
| **Итого** | **34** | |

Для навигационных тестов источник создаётся с `FTreeList`, а после добавления записей вызывается `DataChanged`. Это связывает записи с VCL-узлами, используемыми `InternalFirst` и `InternalNext`.

### 4.2 `TfrxDevCustomDataSetAdapterFixture` — 18 тестов

Это автономная фикстура. Она не создаёт `TcxVirtualTreeList`, `TfrxDevCustomDataSet` или `TVTLoadAllDataSource` и не требует VCL-узлов.

| Раздел | Количество | Тесты |
|---|---:|---|
| 4.2.1 Конструктор и инициализация | 2 | `Create_InitializesFieldsCorrectly`, `Create_WithNilCollections_DoesNotRaise` |
| 4.2.2 Навигация одной записи | 7 | `Open_ResetsRecNo`, `First_ResetsRecNo`, `Next_SetsEofToTrue`, `Eof_TrueAfterNext`, `RecordCount_AlwaysOne`, `First_AfterNext_ResetsState`, `Next_AfterEof_IsSafe` |
| 4.2.3 `GetValue` | 3 | Известное поле, неизвестное поле, `nil`-источник |
| 4.2.4 `GetFieldList` | 1 | Копирование имён полей |
| 4.2.5 `FieldsCount` | 1 | Количество имён полей |
| 4.2.6 Дополнительное поведение | 4 | `GetDisplayText`, `GetFieldType`, неизвестный тип, поиск без учёта регистра |
| **Итого** | **18** | |

## Тестовые классы и данные

### `TMockRecord`

`TMockRecord` — наследник `TVTBaseRecord` с пятью колонками:

| Константа | Индекс | Значение по умолчанию в тестах | `VarType` |
|---|---:|---|---|
| `COL_INTEGER` | 0 | `42` | `varInteger` |
| `COL_STRING` | 1 | `'Test'` | `varString` / `varUString` |
| `COL_DATE` | 2 | `EncodeDate(2026, 1, 15)` | `varDate` |
| `COL_BOOLEAN` | 3 | `True` | `varBoolean` |
| `COL_NULL` | 4 | `Null` | `varNull` |

### `TTestFrxDevCustomDataSet`

Тестовый наследник `TfrxDevCustomDataSet`, открывающий protected-свойства:

```delphi
TTestFrxDevCustomDataSet = class(TfrxDevCustomDataSet)
public
  property FieldIndexes;
  property FieldTypes;
  property CurrentIndex;
end;
```

### `TTestTVTRecordAdapter`

Для тестов адаптера используется именно `TTestTVTRecordAdapter`, а не `TVTRecordAdapter` напрямую. Наследник открывает protected-свойства и protected-методы:

```delphi
TTestTVTRecordAdapter = class(TVTRecordAdapter)
public
  property FieldIndexes;
  property FieldTypes;
  property FieldNames;
end;
```

Все локальные переменные адаптера в тестах раздела 4.2 должны иметь тип `TTestTVTRecordAdapter`, а экземпляры создаются через `TTestTVTRecordAdapter.Create(...)`. Это позволяет обращаться к protected API без RTTI.

## Ключевые правила тестовой инфраструктуры

### 1. `DataChanged` для тестов с TreeList

```delphi
PopulateDataSource(Count);
FDataSource.DataChanged;
```

Без этого `FTreeList.Root.getFirstChild` может не содержать корректно связанную запись, и навигация вернёт `nil`.

### 2. Явное приведение generic-типа

При передаче источника в `AssignDataSource` используется:

```delphi
FDataSet.AssignDataSource(
  TVTBaseDataSource<TVTBaseRecord>(FDataSource),
  FTreeList
);
```

### 3. Создание колонок

Для `TcxVirtualTreeList` используется:

```delphi
Col := FTreeList.CreateColumn;
```

`FTreeList.Columns.Add` в используемом API не применяется.

### 4. Изоляция коллекций адаптера

`TVTRecordAdapter.Create` копирует `TStringList` и оба `TList`. Адаптер владеет своими копиями. Тест 4.2.1 проверяет не только `AreNotSame`, но и то, что последующие изменения исходных списков не изменяют данные адаптера.

### 5. Семантика одной записи

`TVTRecordAdapter` всегда сообщает `RecordCount = 1`. Начальное состояние и состояние после `First` имеют `Eof = False`; после `Next` устанавливается `Eof = True`. Повторный `Next` не должен выбрасывать исключение.

### 6. Регистронезависимый поиск

Имена полей хранятся в `TStringList`, у которой `CaseSensitive = False` по умолчанию. Поэтому `GetValue('ID')` и `GetValue('id')` должны находить одно поле.

## Зависимости

### Production units

Указаны непосредственно в `frxDevCustomDataSetFixture.dpr`:

```text
Common\cxVirtualTreeListHelper.pas
Common\frxDevDSIntf.pas
loader\frxDevDS\frxDevCustomDataSet.pas
```

### Внешние библиотеки

- Delphi RTL/VCL, включая `Vcl.Forms`;
- DevExpress VCL: `cxTL`, `cxTLData`, `cxCustomData`;
- FastReport VCL: `frxClass`, `frxDsgnIntf`;
- DUnitX: test framework, console logger и NUnit XML logger.

`Vcl.Forms` подключён в `.dpr` до тестовой fixture, потому что `TcxVirtualTreeList` требует VCL-контекст.

## Сборка и запуск

### Из Delphi IDE

1. Открыть `frxDevCustomDataSetFixture.dproj`.
2. Выбрать `Debug | Win32` или `Release | Win32`.
3. Проверить доступность DevExpress, FastReport и DUnitX в конфигурации Delphi.
4. Запустить проект.

Настройки проекта:

- `MainSource`: `frxDevCustomDataSetFixture.dpr`;
- `AppType`: `Console`;
- DCU по умолчанию: `Win32\Debug` или `Win32\Release`;
- executable для Release-настройки: `exe`.

### Командная строка

После сборки запуск выполняется из каталога с executable:

```cmd
frxDevCustomDataSetFixture.exe
```

NUnit XML создаётся logger’ом DUnitX. Путь и имя зависят от `TDUnitX.Options.XMLOutputFile`; сохранённый в репозитории пример находится в:

```text
exe\dunitx-results.xml
```

В `.dpr` runner:

- вызывает `TDUnitX.CheckCommandLine`;
- использует RTTI для обнаружения `[TestFixture]`;
- подключает console logger;
- подключает NUnit XML logger;
- устанавливает ненулевой exit code при неуспешных тестах;
- в обычном локальном запуске ожидает Enter перед завершением, если не определён `CI`.

## Типовые проблемы

| Симптом | Причина | Решение |
|---|---|---|
| `FCurrentNode = nil` после `First` | Источник создан без `FTreeList` или не вызван `DataChanged` | Использовать `SetupForNavigation` и вызвать `DataChanged` |
| `GetValue` возвращает `Null` после `First` | Нет активного адаптера или запись не связана с узлом | Проверить `Open`, `First`, `DataChanged` и `Obj(CurrentNode)` |
| `EInvalidCast` при `AssignDataSource` | Несовместимые generic-инстанцирования | Использовать явный cast к `TVTBaseDataSource<TVTBaseRecord>` |
| Ошибка при создании `TcxVirtualTreeList` | Нет VCL-контекста | Оставить `Vcl.Forms` в `.dpr` до fixture |
| Недоступен protected метод адаптера | Используется `TVTRecordAdapter` вместо тестового наследника | Использовать `TTestTVTRecordAdapter` |
| Ошибочное ожидание сброса состояния после `Close` адаптера | `TVTRecordAdapter.Close` не переопределяет внутренние флаги, а вызывает `inherited` | Проверять сброс через `Open` или `First`, не объявлять иное поведение контрактом |

## Дополнительная документация

- `frxDevCustomDataSetFixture.md` — детальная спецификация разделов 4.1 и 4.2, сценарии, ожидаемые результаты и матрица покрытия.
- `DUnitXLoader.md` — общая спецификация тестов проекта `loader`.
- `loader\frxDevDS\frxDevCustomDataSet.pas` — production-реализация адаптеров.

## Ограничения

- Тесты `TfrxDevCustomDataSetFixture` зависят от DevExpress VCL и VCL-узлов.
- Тесты не используют реальную БД, DLL или внешние сервисы.
- Автоматическая проверка утечек памяти не является отдельным тестом.
- README отражает 52 теста, зарегистрированных в текущем `ufrxDevCustomDataSetFixture.pas`; запуск/компиляция не выполнялись в рамках обновления этого документа.

## Лицензия и авторство

Тесты созданы в рамках проекта `loader` для автоматизации проверки интеграции FastReport с виртуальным деревом.

Дата актуализации: **2026-08-19**.
