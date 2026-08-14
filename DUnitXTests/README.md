# DUnitX Tests для DllManager

![Platform](https://img.shields.io/badge/platform-Win32-blue)
![Framework](https://img.shields.io/badge/framework-DUnitX-orange)
![Delphi](https://img.shields.io/badge/Delphi-10.4%2B-red)

## Обзор

Этот проект содержит набор модульных тестов DUnitX для компонента `TDllManager` из библиотеки `Common\DllManager.pas`. 

`TDllManager` — это потокобезопасный менеджер загрузки/выгрузки DLL-плагинов с поддержкой COM-интерфейсов (через `safecall`) и дженерик-обёрток. Тесты покрывают все сценарии из спецификации (раздел 2.1), включая edge cases, обработку ошибок и проверку потокобезопасности.

## Структура проекта

```
DUnitXTests/
├── pgDUnitXTests.groupproj    # Group-проект (сборка TestDLL + DllManagerFixture)
├── DllManagerFixture.dpr      # Исполняемый файл тестов (DUnitX-раннер)
├── DllManagerFixture.dproj    # Файл проекта тестов
├── uDllManagerFixture.pas     # Модуль с тестовыми фикстурами (14 тестов)
├── TestDLL.dpr                # Тестовая DLL-заглушка (5 экспортов)
├── TestDLL.dproj              # Файл проекта тестовой DLL
└── exe/                       # Каталог с собранными бинарниками
```

## Зависимости

Проект использует модули из каталога `Common`:

| Модуль | Назначение |
|--------|------------|
| `DllManager.pas` | Тестируемый компонент |
| `intf_dll.pas` | Базовый интерфейс `IDLLIntf`, GUID'ы |
| `intf_common.pas` | Общие интерфейсы (`IPartsCatalog`, `ILogData`, `IDllIntfRun`) |

Пути к модулям прописаны относительные: `..\..\Common\*`.

## Тестовая заглушка TestDLL

Для тестирования используется **реальная DLL-заглушка** (не мок WinAPI), что обеспечивает максимальную приближенность к продакшену.

`TestDLL.dll` экспортирует 5 функций инициализации:

| Экспорт | Возвращает | Назначение |
|---------|------------|------------|
| `InitProc` | `TStubDLL` (реализует `IDLLIntf`) | Стандартный успешный сценарий |
| `FakeInitProc` | `nil` | Тест: InitProc вернул nil (2.1.5) |
| `InitNoDllIntf` | `TNoDLLIntf` (только `IInterface`) | Тест: не поддерживает IDLLIntf (2.1.6) |
| `InitPCDLL` | `TPCDLL` (`IDLLIntf` + `IPartsCatalog`) | Тесты: дженерики, GetIntf по GUID |
| `InitLDDLL` | `TLDDLL` (`IDLLIntf` + `ILogData`) | Тест: UnloadAll |

> **Примечание**: Все функции используют модификатор `safecall`, что соответствует соглашению о вызовах, ожидаемому `TDllManager`.

## Покрытие тестами

### Фикстура `TTestDLLManager`

| № | Тест | Что проверяет |
|---|------|---------------|
| 2.1.1 | `Load_KnownDll_ReturnsTrue_AndIntfAvailable` | Успешная загрузка: Result=True, IsLoaded=True, GetIntf≠nil |
| 2.1.2 | `Load_MissingFile_ShowsErrorRaisesException` | Файл не найден: `EArgumentException` (InternalLoad) / `EOleException` (safecall Load) |
| 2.1.3 | `Load_AlreadyLoaded_ShowsErrorRaisesException` | Повторная загрузка: Exception "Interface already loaded" |
| 2.1.4 | `Load_MissingInitProc_RaisesException` | Пустой InitProc: Exception "Function ... not found" |
| 2.1.5 | `Load_InitProcReturnsNil_RaisesException` | InitProc вернул nil: Exception "... returned nil" |
| 2.1.6 | `Load_IntfNotSupported_RaisesException` | Интерфейс не поддерживает IDLLIntf |
| 2.1.7 | `UnLoad_LoadedDll_ReturnsTrue_AndIntfNotAvailable` | Успешная выгрузка |
| 2.1.8 | `UnLoad_NotLoaded_ReturnsFalse` | Выгрузка незагруженного интерфейса |
| 2.1.9 | `UnloadAll_ClearsAllProvidersAndModules` | Массовая выгрузка (3 разных интерфейса) |
| 2.1.10 | `GetIntf_ExistingGUID_ReturnsIntf` | Поиск по GUID через `GetIntfGeneric<T>` |
| 2.1.11 | `GetIntf_UnknownGUID_ReturnsNil` | Несуществующий GUID → nil |
| 2.1.12 | `ThreadSafety_MultipleLoadsAndUnloads_NoAV` | Потокобезопасность: 4 потока × 20 циклов |
| 2.1.13a | `LoadGeneric_SuccessAndGetIntfGeneric_ReturnsT` | Дженерик-загрузка `LoadGeneric<T>` |
| 2.1.13b | `GetIntfGeneric_NotLoaded_ReturnsNil` | Дженерик для незагруженного интерфейса |

## Ключевые особенности реализации

### 1. Обход `safecall` через `InternalLoad`

Методы `TDllManager.Load` и `UnLoad` объявлены как `safecall`, что приводит к автоматической трансляции всех исключений в `EOleException` с потерей оригинального типа и сообщения.

Для корректной проверки исключений используется метод `InternalLoad` (без `safecall`), содержащий бизнес-логику. Метод `Load` является тонкой обёрткой над ним.

```delphi
// Правильно: проверяем оригинальное EArgumentException
Assert.WillRaiseWithMessage(
  procedure begin FDLLManager.InternalLoad(badInfo, True) end,
  EArgumentException, 'File ... not found');

// Правильно: проверяем safecall-обёртку
Assert.WillRaise(
  procedure begin FDLLManager.Load(badInfo, True) end,
  EOleException);
```

### 2. Потокобезопасность (тест 2.1.12)

Тест создаёт 4 потока, каждый из которых выполняет 20 циклов:
```
InternalLoad → Sleep(20ms) → IsLoaded → InternalUnLoad
```

**Проверяется:**
- Отсутствие Access Violations
- Отсутствие deadlock'ов (WaitForMultipleObjects с таймаутом 60 сек)
- Отсутствие FatalException в потоках
- Корректная выгрузка всех модулей: `GetLoadedCount = 0`
- Состояние IsLoaded для каждого интерфейса

**Реализация `InternalLoad` защищает от race condition:**
- Двойное блокирование через `TCriticalSection`
- `FProviders.TryAdd` вместо `Add` (не падает при дубляже)
- Корректный ownership transfer: `FreeLibrary` вызывается в `finally` при неудачном `TryAdd`
- Освобождение интерфейса (`Pointer(intf) := nil`) **после** выхода из критической секции (защита от deadlock в `DllMain`)

### 3. TestDLL как stub (не мок WinAPI)

Вместо сложного перехвата WinAPI-функций (`LoadLibrary`, `GetProcAddress`) используется **реальная тестовая DLL**. Это даёт:
- Проверку реального взаимодействия с Windows
- Отсутствие хрупких хаков (DDetours/SynHook)
- Покрытие всех экспортов `TestDLL.dpr` в тестах

## Как собрать

### Предварительные требования
- Delphi 10.4+ (или совместимая версия с поддержкой DUnitX)
- DUnitX установлен в Library Path (или поставляется с IDE)
- Платформа: Win32

### Шаги сборки

1. Откройте `pgDUnitXTests.groupproj` в Delphi IDE
2. Убедитесь, что конфигурация установлена в `Debug | Win32`
3. Выполните **Build All** (Shift+F9)

В результате в каталоге `exe\` появятся:
- `DllManagerFixture.exe` — тестовый раннер
- `TestDLL.dll` — тестовая заглушка

> **Важно**: `TestDLL.dll` должна находиться в одной папке с `DllManagerFixture.exe`, либо в папке, указанной в системной переменной PATH.

## Как запустить

### Запуск из IDE
- Установите `DllManagerFixture` как активный проект
- Нажмите F9 (Run)
- Консольное окно покажет результаты тестов
- XML-отчёт будет сгенерирован в `exe\DllManagerFixture.xml`

### Запуск из командной строки
```cmd
cd exe
DllManagerFixture.exe
```

### Интеграция с CI/CD
Проект поддерживает стандартный NUnit-совместимый XML-отчёт:

```cmd
DllManagerFixture.exe --format=xml --output=test-results.xml
```

Параметры командной строки DUnitX:
| Параметр | Описание |
|----------|----------|
| `--help` | Показать справку |
| `--list` | Список всех тестов без запуска |
| `--run=<test_name>` | Запустить конкретный тест |
| `--format=xml` | Генерация XML-отчёта |
| `--exit:continue` | Не останавливаться после сбоев |

### Интеграция с TestInsight
Проект поддерживает [TestInsight](https://bitbucket.org/sglienke/testinsight) через директиву `TESTINSIGHT`. Для включения:
```delphi
{$DEFINE TESTINSIGHT}
```

## Структура теста

Каждый тест следует паттерну **AAA (Arrange-Act-Assert)**:

```delphi
procedure TTestDLLManager.Load_KnownDll_ReturnsTrue_AndIntfAvailable;
var
  res: boolean;
  intf: IInterface;
begin
  // Arrange
  Assert.IsTrue(FileExists(FValidDLLInfo.FileName), 'TestDLL.dll не найдена');

  // Act
  res := FDLLManager.InternalLoad(FValidDLLInfo, false);

  // Assert
  Assert.IsTrue(res, 'Load должен вернуть true');
  Assert.IsTrue(FDLLManager.IsLoaded(FValidDLLInfo.intfName));
  intf := FDLLManager.GetIntf(FValidDLLInfo.guid);
  Assert.IsTrue(Assigned(intf));
end;
```

## Известные ограничения

1. **Только Win32**: Тесты не кроссплатформенные из-за зависимостей от WinAPI (`LoadLibrary`, `HMODULE`).
2. **Физический файл TestDLL.dll**: Требуется реальное наличие DLL в каталоге. Без неё тест 2.1.1 упадёт на `Assert.IsTrue(FileExists(...))`.
3. **Тест 2.1.12** тестирует race condition на одном интерфейсе: благодаря `TryAdd` утечек не возникает, но при большом параллелизме возможны ложные `False` от `Load` (это не баг, а ожидаемое поведение).

## Траблшутинг

### "TestDLL.dll не найдена"
Проверьте настройки проекта `TestDLL.dproj`:
- Output directory должен быть `..\exe\`
- В Post-Build events можно добавить: `copy "$(OutputPath)TestDLL.dll" "..\exe\"`

### "EOleException вместо EArgumentException"
Убедитесь, что вызываете `InternalLoad`, а не `Load`. `safecall` "съедает" оригинальные типы исключений.

### Тест 2.1.12 зависает
Это указывает на deadlock в `DllManager.pas`. Проверьте, что освобождение интерфейса (`Pointer(intf) := nil`) происходит **вне** `FLock.Leave`.

### "Duplicate key" при потокобезопасности
Признак того, что `DllManager.pas` использует `Add` вместо `TryAdd`. Требуется рефакторинг метода `InternalLoad`.

## Лицензия

Проект является частью внутренней библиотеки и распространяется в соответствии с лицензией основного продукта.
