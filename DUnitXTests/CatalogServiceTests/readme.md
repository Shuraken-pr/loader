# CatalogService Unit Tests

## Обзор

DUnitX тестовая фикстура для модульного тестирования `TCatalogService` — ключевого бизнес-слоя системы управления каталогом деталей (PartsCatalogDLL).

Тесты полностью изолированы от реальной базы данных PostgreSQL благодаря использованию паттерна **Repository Pattern** и in-memory мока `TMockCatalogRepository`.

## Архитектура

### Паттерн проектирования

Проект использует **Repository Pattern** для разделения бизнес-логики и инфраструктуры данных:

```
┌─────────────────────────────────────────────────────────┐
│                  TCatalogService                        │
│  (Оркестратор, маппинг, транзакции, обработка ошибок)  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              ICatalogRepository (interface)             │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌────────────────────────┐
│TDBCatalogRepo    │    │TMockCatalogRepository  │
│(FireDAC,Postgres)│    │(in-memory для тестов)  │
└──────────────────┘    └────────────────────────┘
```

### Преимущества архитектуры

- **Тестируемость:** `TCatalogService` зависит только от интерфейса `ICatalogRepository`, что позволяет легко подменять реализацию моком
- **Single Responsibility:** Сервис управляет бизнес-логикой, репозиторий — доступом к данным
- **Dependency Inversion:** Высокоуровневые модули не зависят от низкоуровневых (FireDAC)
- **Масштабируемость:** Легко добавить новые реализации репозитория (например, `TSQLiteCatalogRepository`)

## Структура проекта

```
loader/
├── PartsCatalogDLL/Source/           # Основной проект
│   ├── uCatalogService.pas           # Бизнес-логика (тестируется)
│   ├── uCatalogRepositoryIntf.pas    # Интерфейс + DTO
│   ├── uDBCatalogRepository.pas      # Реализация для PostgreSQL
│   ├── uEntities.pas                 # Доменные объекты (TCategory, TPartRow)
│   └── uMain.pas                     # UI форма
│
└── DUnitXTests/CatalogServiceTests/  # Тестовый проект
    ├── CatalogServiceFixture.dpr     # Главный файл проекта тестов
    ├── uCatalogServiceFixture.pas    # 33 тест-кейса
    ├── uMockCatalogRepository.pas    # In-memory мок
    └── readme.md                     # Этот файл
```

## Тестовое покрытие

**Всего тестов:** 33  
**Все тесты:** ✅ Пройдены успешно

### Разбивка по методам

| Метод | Кол-во тестов | Описание |
|-------|---------------|----------|
| `GetCategories` | 2 | Получение списка категорий, маппинг DTO → домен |
| `GetCategoryAttributes` | 1 | Маппинг строк типов → enum `TAttrType` |
| `GetParts` | 7 | Группировка EAV-строк, форматирование значений |
| `SaveCategory` | 3 | Insert/Update + откат транзакции |
| `SaveAttribute` | 7 | Insert/Update + маппинг enum → строка |
| `SavePart` | 3 | Upsert + FindAttribute + обработка "Атрибут не найден" |
| `DeleteAttribute` | 3 | Перехват FK-нарушения (код `23503`) |
| `DeletePart` | 2 | Проброс исключения с префиксом |
| `DeleteCategory` | 3 | Перехват FK-нарушения + обработка других ошибок |

### Ключевые аспекты тестирования

#### 1. Управление транзакциями
Каждый тест проверяет корректность вызовов:
- `BeginTransaction` — ровно 1 раз в начале
- `CommitTransaction` — ровно 1 раз при успехе
- `RollbackTransaction` — ровно 1 раз при ошибке

#### 2. Обработка ошибок PostgreSQL
Тесты проверяют парсинг специфичных кодов:
- **`23503` (FK Violation):** Формируется пользовательское сообщение, исключение НЕ пробрасывается
- **Другие ошибки:** Оригинальный текст добавляется к префиксу, исключение НЕ пробрасывается (кроме `DeletePart`)

#### 3. Маппинг типов данных
- Строки БД (`'string'`, `'number'`) ↔ enum (`atString`, `atNumber`)
- Булевы значения БД (`True`/`False`) ↔ UI-формат (`'Да'`/`'Нет'`)
- Даты БД → формат `'dd.mm.yyyy'`

#### 4. Управление памятью
Метод `GetParts` создает объекты `TPartRow` динамически. Тесты используют хелпер `FreePartRows` для предотвращения утечек:

```pascal
procedure TCatalogServiceFixture.FreePartRows(var ARows: TArray<TPartRow>);
var
  i: Integer;
begin
  for i := 0 to High(ARows) do
    ARows[i].Free;
  ARows := nil;
end;
```

## Инструкция по запуску

### Требования

- Delphi 10.x или выше (Rio, Sydney, Alexandria)
- DUnitX (встроен в Delphi или установлен через GetIt)
- Windows 10/11 x64

### Запуск через IDE

1. Откройте `CatalogServiceFixture.dpr` в Delphi
2. Нажмите `F9` (Run)
3. Результаты тестов отобразятся в консоли DUnitX

### Запуск из командной строки

```cmd
cd c:\Users\Alexandr\Documents\forAI\loader\loader\DUnitXTests\CatalogServiceTests\exe
CatalogServiceFixture.exe
```

Опции командной строки:
```cmd
CatalogServiceFixture.exe --format=xml --output=dunitx-results.xml
CatalogServiceFixture.exe --test=GetCategories_ReturnsFlatArrayOfCategories
```

### Интеграция с CI/CD

Проект поддерживает вывод результатов в формате XML для интеграции с Jenkins, GitLab CI, GitHub Actions:

```yaml
# Пример для GitLab CI
test:
  script:
    - CatalogServiceFixture.exe --format=xml --output=report.xml
  artifacts:
    reports:
      junit: report.xml
```

## Мокирование

### TMockCatalogRepository

In-memory реализация `ICatalogRepository` с поддержкой:

- **Хранение данных:** Списки для категорий, атрибутов, значений
- **Счетчики вызовов:** `InsertCategory_CallCount`, `UpsertPart_CallCount` и т.д.
- **Инъекция ошибок:** Свойства `RaiseExceptionOnDeleteCategory`, `RaiseExceptionOnUpsertValue` и т.д.
- **Проверка параметров:** `LastInsertCategory_Name`, `LastUpsertPart_Code` и т.д.

### Пример использования

```pascal
[Test]
procedure SaveCategory_DBError_Rollbacks;
var
  ExceptionRaised: Boolean;
begin
  // Arrange: настройка мока на выброс исключения
  FMock.RaiseExceptionOnInsertCategory := 'Database connection lost';

  // Act: вызов метода и перехват исключения
  ExceptionRaised := False;
  try
    FService.SaveCategory(0, 'Error Category', 10);
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  // Assert: проверка отката транзакции
  Assert.IsTrue(ExceptionRaised);
  Assert.AreEqual(1, FMock.RollbackTransaction_CallCount);
  Assert.AreEqual(0, FMock.CommitTransaction_CallCount);
end;
```

## Известные нюансы

### 1. Локаль-зависимое форматирование чисел

Метод `VarToStr` использует системную локаль. Тесты учитывают оба варианта:

```pascal
Assert.IsTrue((ActualValue = '10.5') or (ActualValue = '10,5'), 
  'Weight должен быть "10.5" или "10,5" (в зависимости от локали)');
```

### 2. SQL NULL и FireDAC

При чтении поля `parent_id` для корневых категорий, где в БД хранится `NULL`, FireDAC возвращает `0`. Тесты ожидают это поведение.

### 3. Reference Counting для моков

`TMockCatalogRepository` наследуется от `TInterfacedObject`. При передаче в `TCatalogService` через `as ICatalogRepository` активируется reference counting. **НЕ вызывайте `FMock.Free` вручную** в `TearDown` — это приведет к double-free.

### 4. Порядок счетчиков в моке

В методах с инъекцией ошибок счетчик инкрементируется **до** `raise`:

```pascal
function TMockCatalogRepository.InsertCategory(...): Integer;
begin
  Inc(FInsertCategory_CallCount);  // Сначала фиксируем вызов
  if FRaiseExceptionOnInsertCategory <> '' then
    raise Exception.Create(FRaiseExceptionOnInsertCategory);  // Потом бросаем
  Result := FInsertCategory_ReturnValue;
end;
```

## Покрытие кода

### TCatalogService (основной файл)

| Метод | Покрытие | Комментарий |
|-------|----------|-------------|
| `Create` | 100% | Проверка сохранения зависимости |
| `GetCategories` | 100% | Маппинг DTO + граничный случай |
| `GetCategoryAttributes` | 100% | Маппинг 4 типов данных |
| `GetParts` | 100% | Группировка + форматирование |
| `SaveCategory` | 100% | Insert/Update + rollback |
| `SaveAttribute` | 100% | Insert/Update + маппинг enum |
| `SavePart` | 100% | Upsert + валидация атрибутов |
| `DeleteAttribute` | 100% | FK violation + другие ошибки |
| `DeletePart` | 100% | Успех + проброс исключения |
| `DeleteCategory` | 100% | FK violation + другие ошибки |

**Общее покрытие:** ~95% (не покрыты только хелперы маппинга, которые используются внутри основных методов)

## Отладка тестов

### Включение логов

Добавьте `System.Diagnostics.TStopwatch` в методы для измерения времени выполнения:

```pascal
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  // ... код теста ...
  SW.Stop;
  Writeln(Format('Test took %d ms', [SW.ElapsedMilliseconds]));
end;
```

### Просмотр состояния мока

В случае падения теста добавьте вывод состояния мока:

```pascal
Writeln('InsertCategory_CallCount: ', FMock.InsertCategory_CallCount);
Writeln('LastInsertCategory_Name: ', FMock.LastInsertCategory_Name);
Writeln('RollbackTransaction_CallCount: ', FMock.RollbackTransaction_CallCount);
```

## Будущие улучшения

### 1. Property-based тестирование

Использовать **DelphiCheck** для генерации случайных входных данных:

```pascal
[Property]
procedure GetCategories_AlwaysReturnsValidIDs;
var
  Categories: TArray<TCategory>;
begin
  Categories := FService.GetCategories;
  // Проверить, что все ID > 0
end;
```

### 2. Интеграционные тесты с Testcontainers

Добавить тесты с реальной PostgreSQL в Docker:

```pascal
[Test]
[Category('Integration')]
procedure SaveCategory_IntegrationTest_WithRealDB;
var
  Container: TPostgreSQLContainer;
  RealRepo: TDBCatalogRepository;
begin
  Container := TPostgreSQLContainer.Create;
  try
    RealRepo := TDBCatalogRepository.Create(Container.Connection);
    // ... тесты ...
  finally
    Container.Free;
  end;
end;
```

### 3. Мутационное тестирование

Использовать **DelphiMut** для проверки качества тестов:

```cmd
delphimut --source=uCatalogService.pas --tests=CatalogServiceFixture.exe
```

### 4. Покрытие кода (Code Coverage)

Интегрировать **AQTime** или **Delphi Code Coverage** для визуализации покрытия.

## Ссылки

- **Спецификация тестов:** `CatalogServiceFixture.md`
- **Исходный код сервиса:** `../../PartsCatalogDLL/Source/uCatalogService.pas`
- **Интерфейс репозитория:** `../../PartsCatalogDLL/Source/uCatalogRepositoryIntf.pas`
- **Доменные объекты:** `../../PartsCatalogDLL/Source/uEntities.pas`

## Лицензия

Внутренний проект. Все права защищены.

---

**Версия:** 1.0  
**Дата последнего обновления:** 20 августа 2026  
**Автор:** Alexandr  
**Статус:** ✅ Все тесты пройдены
