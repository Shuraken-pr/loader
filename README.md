# Проект `loader` — Описание архитектуры и функциональности

## Общая архитектура

Проект `loader` — это **модульное Delphi-приложение с архитектурой плагинов**, реализованное на основе COM-интерфейсов (через `safecall`). Проект состоит из трёх основных частей:

1. **`Common`** — разделяемая библиотека (ядро), содержащая интерфейсы, менеджер плагинов, пул потоков, хелперы для виртуальных деревьев и мониторинг FireDAC.
2. **`CommonModules`** — общие модули данных (в частности, `dmSkins` для централизованного управления скинами DevExpress).
3. **`Loader`** — основное приложение (`loader.exe`) и набор плагинов в виде DLL (7 зарегистрированных плагинов + вспомогательные библиотеки).

---

## Часть 1: `Common` (ядро системы)

### Интерфейсы

Определяется иерархия интерфейсов:

- **`IDLLIntf`** — базовый интерфейс любого плагина: `GetDescription`, `Init`, `Fin`.
- **`IDllIntfRun`** (наследник `IDLLIntf`) — плагин с методом `Run(Callback, Handle)` — основной контракт для запускаемых плагинов.
- **`IUsesDllManager`** — плагин, который умеет получать ссылку на `IDllManager` для подгрузки зависимостей.
- **`IDllIntfRunWithDeps`** — объединяет `IDllIntfRun` + `IUsesDllManager`. Плагины этого типа могут самостоятельно подгружать свои зависимости через `IDllManager`.
- **`IDllManager`** — менеджер DLL: `Load`, `UnLoad`, `UnloadAll`, `GetIntf`, `IsLoaded`. Централизованно загружает DLL, кэширует их и раздаёт интерфейсы по GUID.
- **`IRunTask`** — интерфейс асинхронной задачи: `Start(Command, Params) → Handle`, `Stop(Handle)`, `Info`.
- **`IRunTaskFindInDir`** — поиск файлов по маске в каталоге (наследник `IRunTask`).
- **`IRunTaskFindInExeFile`** — поиск байтовых последовательностей внутри exe-файла (наследник `IRunTask`).
- **`IRunTaskShellExecute`** — асинхронный запуск shell-команд (наследник `IRunTask`).
- **`ISimpleNumbers`**, **`ICalcPrice`**, **`IExplorer`**, **`IRunTasks`**, **`ILogData`**, **`IPartsCatalog`**, **`IAnalyticDashboard`** — доменные интерфейсы конкретных плагинов.

Тип `TDLLInfo` — структура-дескриптор DLL (имя файла, имя init-функции, имя интерфейса, GUID), используется для регистрации/загрузки. В `intf_common.pas` определены функции-фабрики: `DISimpleNumbers`, `DICalcPrice`, `DIExplorer`, `DIRunTaskFindInDir`, `DIRunTaskFindInExeFile`, `DIRunTaskShellExecute`, `DIRunTasks`, `DILogData`, `DICatalogParts`, `DIAnalyticDashboard`.

### `DllManager.pas`

Класс `TDllManager` реализует `IDllManager`. Ключевые особенности:
- Потокобезопасность через `TCriticalSection`.
- Хранит два словаря: `FProviders` (имя интерфейса → `IInterface`) и `FModules` (имя файла → `THandle` модуля).
- При загрузке DLL (`Load`) вызывает `GetProcAddress` по имени init-процедуры, получая фабричную функцию, создаёт интерфейс и, если плагин поддерживает `IUsesDllManager`, внедряет в него сам `IDllManager`.
- При выгрузке (`UnLoad`) корректно обнуляет интерфейсные ссылки **после** снятия блокировки, чтобы избежать дедлоков при удалении объектов из DLL.
- Имеет generic-обёртки `LoadGeneric<T>` и `GetIntfGeneric<T>` для удобства.

### `cxVirtualTreeListHelper.pas`

Мощный дженерик-фреймворк для `TcxVirtualTreeList` (DevExpress):
- **`TVTBase`** / **`TVTBaseRecord`**: Базовые классы для узлов дерева с поддержкой иерархии, безопасного удаления и метода `NodeMoveTo`.
- **`TVTBaseDataSource<T>`**: Абстрактный источник данных, связывающий объекты Pascal с `TcxVirtualTreeList`.
- **`TVTSmartDataSource<T>`**: Стратегия **SmartLoad** (ленивая загрузка). Дети создаются только при раскрытии узла (через метод `InitChildren` и анонимный метод). Используется в `PartsCatalogDLL` и `AnalyticDashboardDLL` для экономии памяти.
- **`TVTLoadAllDataSource<T>`**: Стратегия **LoadAll** (жадная загрузка). Всё дерево строится заранее, доступ осуществляется по индексу через внутренний `TObjectList`. Используется для логов и статистики.

### `vstHelper.pas`

Хелпер для `TBaseVirtualTree` (библиотека VirtualTree). Позволяет хранить произвольные объекты в узлах дерева через паттерн `TBase → TBaseRecord` с generic-методами `Add<T>`, `Obj<T>`, `CurrentObj<T>`.

### Пул потоков

Абстракция над выполнением фоновых задач с возможностью выбора реализации через условную компиляцию:
- **`pool_config.inc`**: Файл конфигурации. Содержит директиву `{$define use_otl}` для переключения между реализациями.
- **`uAutonomiusThreadPool.pas`**: `TThreadPoolManager` — пул потоков на базе обычных `TThread`. Создаёт анонимные потоки, отслеживает их в `TThreadList`, при завершении потока автоматически удаляет его из списка. Поддерживает `Terminate` и `FreeOnTerminate`.
- **`uOmniThreadPoolManager.pas`**: `TOmniThreadPoolManager` — аналогичный пул, но на базе библиотеки **OmniThreadLibrary (OTL)** (`IOmniTaskControl`). Используется, если определён `use_otl`.

### Мониторинг и логирование FireDAC

Обеспечивает перехват, форматирование и отправку SQL-запросов и их параметров во внешнее окно отладки (SQL Logger) в реальном времени:
- **`FireDAC.Moni.Custom.Logger.pas`**: Базовая реализация кастомного клиента мониторинга FireDAC (`TFDMoniCustomClientLink` и `TFDMoniCustomClient`). Позволяет перехватывать события FireDAC (выполнение команд, SQL) и передавать их через кастомный обработчик вывода (`IFDMoniCustomClient`), поддерживая синхронизацию с главным потоком.
- **`FDMoniCustomLoggerHelper.pas`**: Хелпер для удобного использования кастомного логгера. Класс `TFDMoniCustomLogger` настраивает соединение (`TFDConnection`) на использование кастомного мониторинга (`mbCustom`) и фильтрует события (только `ekCmdExecute`, `ekSQL`). Функция `GetFDParamsStr` форматирует параметры запроса в читаемый вид SQL-переменных. Процедура `SendMonitorMessage` отправляет отформатированный SQL-запрос через механизм `WM_COPYDATA` в окно "SQL Logger" для отображения.

### Управление скинами (`intf_skin.pas`, `uSkinManager.pas`, `uSkinHelper.pas`)

- **`intf_skin.pas`**: Определяет контракты `ISkinAware` (плагин, получающий уведомления о смене темы) и `ISkinProvider` (получение списка доступных скинов).
- **`uSkinManager.pas`**: Центральный класс `TSkinManager`. Читает и сохраняет настройки (`skin_name`, `native_style`) в файл `settings.json` рядом с EXE. Ведёт список подписчиков (`FSubscribers: TInterfaceList`) и рассылает им команду `ApplySkin` при изменении темы (Live Update). Метод `PopulateSkinList` заполняет `TcxComboBox` доступными скинами DevExpress.
- **`uSkinHelper.pas`**: Утилиты `ApplySkinToForm` и `ApplySkinToDataModule` для быстрого применения скина к `TForm`, `TdxRibbon` и `TdxLayoutControl`.

---

## Часть 2: `Loader` (приложение и плагины)

### Главное приложение (`loader.exe`)

**`uMain.pas` + `uMain.dfm`** — основная форма с ленточным интерфейсом (DevExpress `dxRibbon`).

Реализует **паттерн Registry + Plugin Loader**:

1. В `FormCreate` создаётся `TDllManager`, список `FButtons: TButtonEntryList`, экземпляр `TdmSkin` и `TSkinManager`.
2. Каждая запись `TButtonEntry` связывает кнопку на ленте с определённым плагином (`TDLLInfo`). Зарегистрированы **7 кнопок**:
   - **SimpleNumbers** — вычисление простых чисел
   - **CalcPrice** — пересчёт цен с НДС
   - **Explorer** — сканирование дисков
   - **RunTasks** — запуск заданий
   - **LogData** — логирование БД
   - **CatalogParts** — каталог деталей (EAV)
   - **AnalyticDashboard** — аналитическая панель событий PostgreSQL
3. `LoadAllDlls` загружает все DLL через `FDllManager.Load(...)`, получает `GetDescription` и устанавливает единый обработчик `OnButtonClick`. При загрузке каждого плагина проверяется поддержка `ISkinAware`, и если он реализован, плагин регистрируется в `TSkinManager` для live-обновления скинов.
4. При нажатии кнопки вызывается `IDllIntfRun.Run(callback, AppHandle)`, где callback — это лямбда, добавляющая сообщения в `cxVirtualTreeList` (лог).
5. Дополнительно инициализируется FastReport (`InitializeFastReport`) — загружается `frxDevDS.dll` и настраивается выпадающая кнопка с действиями `DesignReport` и `PreviewReport`.

**Визуально**: лента с 7 кнопками, комбобокс выбора скина, область логов внизу в виде `cxVirtualTreeList` с колонками «Дата» и «Сообщение», группа FastReport с выпадающей кнопкой.

---

### Плагины (DLL)

#### 1. SimpleNumbers (`SimpleNumbersDLL`)
- **Интерфейс**: `ISimpleNumbers : IDllIntfRun` (+ метод `SilentRun`).
- **Функциональность**: вычисление простых чисел в диапазоне до N с использованием двух потоков.
- **Два режима**:
  - GUI (`Run`): показывает форму с двумя `VirtualStringTree` (по одному на поток), кнопкой запуска и спиннером для задания предела.
  - Silent (`SilentRun`): без UI, чисто вычисление с callback-уведомлениями.
- Потоки используют `TInterlocked.Increment` для атомарного раздачи чисел на проверку. Каждый поток сохраняет результаты в свой файл (`thread1.txt`, `thread2.txt`).
- Проверка простоты: перебор делителей до `sqrt(N)`.

#### 2. CalcPrice (`CalcPriceDLL`)
- **Интерфейс**: `ICalcPrice : IDllIntfRun` (+ метод `CalcPrices`).
- **Функциональность**: пересчёт цен с учётом НДС. Алгоритм:
  - Находит такие значения цены с НДС, чтобы цена без НДС была «красивым» числом (без дробной части после деления на `(1 + procNDS/100)`).
  - Перебирает значения вверх и вниз с шагом 0.01, пока не найдёт подходящее.
- Форма с полями: исходная цена с НДС, процент НДС, скорректированная цена с НДС, скорректированная цена без НДС. Вычисление запускается при любом изменении значения.
- Чистая бизнес-логика вынесена в `uCalcPricesProc.pas` и покрыта модульными тестами DUnitX (33 теста).

#### 3. Explorer (`ExplorerDLL`)
- **Интерфейс**: `IExplorer : IDllIntfRunWithDeps` (+ метод `initFindIntf`).
- **Функциональность**: сканирование локальных дисков / конкретного каталога с фильтрацией по расширениям файлов.
- Реализует **ленивую загрузку зависимости**: хранит ссылку на `IRunTaskFindInDir`, которое подгружает через `IDllManager` в `TryLoadDependencies`.
- Форма: чекбоксы для выбора дисков (A–Z), поле фильтра расширений, кнопка «Сканировать». Результаты отображаются в `VirtualStringTree` с иерархией папок/файлов. При клике на файл — показ превью (текст или картинка).
- Сканирование работает асинхронно через `IRunTaskFindInDir.Start(dir, extensions)`.

#### 4. RunTasks (`RunTasksDLL`)
- **Интерфейс**: `IRunTasks : IDllIntfRunWithDeps`.
- **Функциональность**: оркестратор заданий. Объединяет три типа задач в единый интерфейс:
  - `IRunTaskFindInDir` — поиск файлов
  - `IRunTaskFindInExeFile` — поиск в exe
  - `IRunTaskShellExecute` — shell-выполнение
- Поддерживает два режима инициализации зависимостей: вручную (через `initRunTasks`) или автоматически через `InitViaDllManager`.
- Форма: комбобокс выбора типа задачи, поля для команды/параметров, кнопки Start/Stop/Show Results. Таблица заданий со статусами (выполняется, прервано, завершено, ошибка). Результаты отображаются во всплывающей панели.

#### 5. RunTaskFind (`RunTaskFindDLL`)
- **Интерфейсы**: `IRunTaskFindInDir` + `IRunTaskFindInExeFile` (два класса в одной DLL).
- **`TRunTaskFindInDir`** — рекурсивный асинхронный поиск файлов:
  - Используется `TScanContext` — изолированный контекст на каждый запуск (защита от гонок данных).
  - Поддержка нескольких каталогов через `;`.
  - Фильтрация по расширениям.
  - Вызовы callback'ов с ограничением частоты (не чаще 1 раза в 2 секунды для RunCallback).
- **`TRunTaskFindInExeFile`** — поиск байтовых последовательностей в exe-файле:
  - Реализован алгоритм **Boyer-Moore** для быстрого поиска подстрок.
  - Чтение файла блоками по 4 МБ с перекрытием для поиска на границах чанков.
  - Поддержка поиска нескольких шаблонов через запятую.

#### 6. RunTaskShellExecute (`RunTaskShellExecuteDLL`)
- **Интерфейс**: `IRunTaskShellExecute`.
- **Функциональность**: асинхронный запуск shell-команд через `CreateProcess`.
- Отслеживает хэндлы процессов, поддерживает принудительное завершение (`TerminateProcess`).

#### 7. LogData (`LogDataDLL`)
- **Интерфейс**: `ILogData : IDllIntfRun` (+ `IUsesDllManager`).
- **Функциональность**: система логирования изменений в базах данных (PostgreSQL, MS SQL Server, Oracle).
- Три этапа работы:
  1. **Подключение**: через `TfrmConnections` задаётся тип БД, сервер, логин/пароль (FireDAC).
  2. **Анализ**: выполняется SQL-запрос (из ресурсов `.rc`), который находит все таблицы с колонками и показывает, у каких уже есть лог-таблица (`_log`) и триггер.
  3. **Генерация и создание**: пользователь выбирает таблицы и колонки → плагин генерирует `CREATE TABLE` для лог-таблицы и `CREATE TRIGGER` для отслеживания INSERT/UPDATE/DELETE, подставляя специфичный синтаксис для каждой СУБД.
- SQL-шаблоны хранятся в ресурсах (`CreateTableMSSQLTemplate.sql`, `logTriggerMSSQLTemplate.sql` и т.д. для PostgreSQL и Oracle). Поддерживаются типы данных, специфичные для каждой СУБД.

#### 8. PartsCatalog (`PartsCatalogDLL`)
- **Интерфейс**: `IPartsCatalog : IDllIntfRun`.
- **Функциональность**: десктопное приложение для управления иерархическим каталогом деталей с динамическими атрибутами. Реализует паттерн **Entity-Attribute-Value (EAV)** для гибкого хранения характеристик деталей различных категорий.
- **Технологический стек**: Delphi + VCL + DevExpress (`TcxVirtualTreeList`, `TdxLayoutControl`), PostgreSQL 12+, FireDAC.
- **Архитектурные особенности**:
  - Используется кастомный дженерик-хелпер `cxVirtualTreeListHelper.pas` для типобезопасной работы с `TcxVirtualTreeList`.
  - Реализована **ленивая загрузка (SmartLoad)** дерева категорий: дочерние узлы загружаются из БД только при раскрытии родительского узла, что экономит память и ускоряет отклик.
  - Динамическое создание полей ввода на форме редактирования детали (`fPartEdit.pas`) на основе атрибутов выбранной категории (`TcxTextEdit` для строк/чисел, `TcxDateEdit` для дат, `TcxCheckBox` для булевых значений).
  - Целостность данных на уровне СУБД: CHECK-ограничение `chk_single_value`, триггеры `trgfn_check_required_attributes` и `trgfn_check_value_type`.
  - Разделение ответственности: UI Forms, `TCatalogService` (бизнес-логика), `uEntities` (модели).
  - Импорт и Экспорт XML с upsert-логикой.
  - Поддержка скинов DevExpress через `ISkinAware`.
- **Структура**: `Source/` (исходный код), `SQL/` (скрипты БД), `docs/` (документация), `Exe/` (исполняемые файлы).

#### 9. AnalyticDashboard (`AnalyticDashboardDLL`)
- **Интерфейс**: `IAnalyticDashboard : IDllIntfRun`.
- **Функциональность**: DLL-модуль аналитической панели для основного приложения. Отображает события из PostgreSQL, предоставляет агрегированную статистику и обновляет список событий в режиме, близком к реальному времени.
- **Ключевые возможности**:
  - **Список событий**: `TcxGridTableView` работает в unbound-режиме. Сначала выполняется `COUNT(*)`, затем `TVirtualDataCache<TEventRecord>` асинхронно загружает страницы по 1000 записей. Пока страница не загружена, отображается плейсхолдер `⌛ ...`. Кэш хранит не более 50 страниц и вытесняет давно использовавшиеся по LRU.
  - **Статистика**: `TcxVirtualTreeList` с `TVTLoadAllDataSource<TEventStatsRecord>`. Показывает час, источник, количество событий, среднюю задержку, скользящий тренд, процентный рост и общее количество событий.
  - **Real-time обновления**: `TRealTimePoller` — отдельный поток, который раз в 1000 мс проверяет новый `MAX(id)` таблицы `events`, загружает дельту и добавляет новые записи в начало кэша через `PrependRecord`.
  - **Защита пула соединений**: `TConnectionSemaphore` и RAII-обёртка `TSemaphoreGuard` ограничивают одновременные операции с пулом FireDAC. Количество слотов = `PoolMaxItems - 1`.
- **PostgreSQL**: схема содержит таблицы `users` и `events` с `JSONB`-полем `metadata`, вычисляемым `TSVECTOR`, индексами. Функции `get_events` (постраничная выборка) и `get_hourly_agg` (почасовая агрегация с оконными функциями).
- **Архитектура**: `main.pas` (форма, гриды, загрузка), `VirtualDataCache.pas` (потокобезопасный кэш), `RealTimePoller.pas` (polling), `uConnectionSemaphore.pas` (семафор).

---

## Схема взаимодействия

```text
loader.exe (uMain)
├── TDllManager (загружает и кэширует все DLL)
├── TSkinManager (управление скинами, live-обновление)
├── btnSimpleNumbers → SimpleNumbers.dll (ISimpleNumbers)
├── btnCalcPrice → CalcPrice.dll (ICalcPrice)
├── btnExplorer → Explorer.dll (IExplorer)
│   └── зависит от → RunTaskFind.dll (IRunTaskFindInDir)
├── btnRunTasks → RunTasks.dll (IRunTasks)
│   └── зависит от → RunTaskFind.dll (IRunTaskFindInDir)
│                   RunTaskFind.dll (IRunTaskFindInExeFile)
│                   RunTaskShellExecute.dll (IRunTaskShellExecute)
├── btnLogData → LogData.dll (ILogData)
│   └── подключение к PostgreSQL / MS SQL / Oracle через FireDAC
├── btnCatalogParts → PartsCatalog.dll (IPartsCatalog)
│   └── PostgreSQL + EAV + SmartLoad через cxVirtualTreeListHelper
├── btnAnalyticDashboard → AnalyticDashboard.dll (IAnalyticDashboard)
│   └── PostgreSQL + VirtualDataCache + RealTimePoller + ConnectionSemaphore
└── bFastReport → frxDevDS.dll (IFrxDevDS)
    └── DesignReport / PreviewReport для TVTBaseDataSource и TDataSet
```

---

## Часть 3: Единый механизм управления скинами DevExpress

Для обеспечения согласованного внешнего вида всего приложения (главного окна и всех плагинов) реализован централизованный механизм управления скинами DevExpress, построенный на паттерне **Издатель-Подписчик (Publisher-Subscriber)**.

### Архитектура
Механизм включает следующие ключевые компоненты:

1. **`Common\intf_skin.pas`** — определяет контракты взаимодействия:
   - `ISkinAware` — интерфейс, который реализует любой плагин (DLL), желающий получать уведомления о смене скина и применять его к своим формам.
   - `ISkinProvider` — интерфейс для получения списка доступных скинов.

2. **`Common\uSkinManager.pas`** — центральный класс `TSkinManager`, выступающий в роли издателя:
   - **Хранение настроек**: читает и записывает текущий скин (`skin_name`) и флаг `native_style` в файл `settings.json` в папке с исполняемым файлом.
   - **Управление UI**: метод `PopulateSkinList` заполняет `TcxComboBox` списком всех доступных в системе скинов DevExpress.
   - **Применение к главной форме**: метод `ApplyToMainForm` мгновенно обновляет `TcxLookAndFeel` и цветовую схему `TdxRibbon` главного приложения.
   - **Live-обновление плагинов**: при смене скина менеджер автоматически рассылает вызов `ApplySkin` всем зарегистрированным подписчикам (`ISkinAware`), обеспечивая мгновенное изменение внешнего вида открытых окон DLL без их перезагрузки.

3. **`Common\uSkinHelper.pas`** — утилиты `ApplySkinToForm` и `ApplySkinToDataModule` для быстрого применения скина к формам и дата-модулям.

4. **`CommonModules\dmSkins.pas`** — общий DataModule `TdmSkin`, содержащий `TdxSkinController` и `TdxLayoutLookAndFeelList` для централизованного управления скинами на уровне приложения.

### Интеграция в главное приложение (`loader.exe`)
- При старте создается экземпляр `TSkinManager`, загружаются настройки из `settings.json`.
- На главной форме (`uMain.pas`) размещен `TcxComboBox` для выбора скина. При его изменении вызывается `TSkinManager.CurrentSkin := SelectedSkin`, что триггерит обновление главной формы и всех подключенных DLL.
- При загрузке каждого плагина главное приложение проверяет поддержку интерфейса `ISkinAware`. Если он реализован, плагин регистрируется в `TSkinManager`, и к нему сразу применяется текущий скин.
- `dmSkin` создается в `FormCreate` и владеет `TdxSkinController`, который применяется ко всем формам через `uSkinHelper`.

### Интеграция в плагины (DLL)
Чтобы плагин поддерживал единую систему скинов, необходимо:
1. Добавить модуль `intf_skin` в секцию `uses`.
2. Реализовать интерфейс `ISkinAware` в главном классе плагина (например, в классе, реализующем `IDllIntfRun`).
3. В методе `ApplySkin` применить переданные параметры к `RootLookAndFeel` активной формы плагина с помощью `uSkinHelper.ApplySkinToForm`.

### Преимущества
- **Единая точка конфигурации**: пользователь выбирает тему только в главном окне, настройка надежно сохраняется в `settings.json`.
- **Отсутствие дублирования кода**: логика выбора, сохранения и применения скина вынесена в переиспользуемый модуль `uSkinManager`.
- **Мгновенное обновление (Live Update)**: смена скина применяется ко всем открытым окнам плагинов "на лету" без необходимости их закрывать и открывать заново.
- **Масштабируемость**: добавление поддержки скинов в новый плагин требует реализации всего одного короткого метода интерфейса `ISkinAware`.

---

## Часть 4: FastReport — фактическая интеграция

### `frxDevDS.dll`

Плагин загружается отдельно от списка запускаемых DLL: `Source\uMain.pas` вызывает `FDllManager.Load(DIFrxDevDS, False)`, получает `IFrxDevDS` и вызывает `Init`. Плагин не реализует `IDllIntfRun`, поэтому его кнопка не входит в `FButtons` и не обрабатывается общим `OnButtonClick`.

`frxDevDS.dll` предоставляет:
- `DesignReport` и `PreviewReport` для данных `TVTBaseDataSource` и `TcxVirtualTreeList`;
- `DesignDBReport` и `PreviewDBReport` для отчётов с FireDAC (поддержка `TDataSet`);
- `SetCustomFunction` для вызовов из FastScript;
- экспортные компоненты PDF, XLS/XLSX, DOCX, RTF, BMP, JPEG и Mail в `dmFastReport`.

### `loader.exe`

В `Source\uMain.dfm` создана группа `bFastReport` с выпадающей кнопкой `btnFastReport` и действиями:
- `btnFRDesigner` — открывает дизайнер;
- `btnFRPreview` — открывает предварительный просмотр.

Оба действия используют журнал `FSLog` и `vtlLog` как источник данных и шаблон `FastReportTemplates\loader.fr3` рядом с исполняемым файлом.

### `PartsCatalog.dll`

В `PartsCatalogDLL\Source\uMain.dfm` создана группа `brReport` с выпадающей кнопкой `btnFastReport`:
- `btnFRDesigner` вызывает `DesignDBReport`;
- `btnPreview` вызывает `PreviewDBReport`.

Перед вызовом формируется строка соединения из `dmDB.PGConn`, включая пароль, а запросы `qryReportCategories` и `qryReportParts` передаются в `DesignDBReport`. Используется шаблон `FastReportTemplates\PartsCatalog.fr3` рядом с `loader.exe`.

Шаблон `PartsCatalog.fr3` уже содержит внутренние `TfrxFDQuery` с именами `Categories` и `Parts`, master-detail-связь `Parts.Master = Categories`, а также SQL для построения дерева категорий и списка деталей. Поэтому при открытии дизайнера с существующим шаблоном SQL, переданный из `PartsCatalog`, фактически не применяется: текущая реализация `DesignDBReport` загружает шаблон вместо добавления переданных наборов.

### Ограничения текущей реализации

- `PreviewReport` и `PreviewDBReport` открывают отчёт только при непустом существующем шаблоне; иначе завершаются без уведомления вызывающего кода.
- `CreateReportPage` не создаёт страницу для полностью пустого `TfrxReport`, поскольку выполняется только при `PagesCount > 0`.

---

## Часть 5: Модульное тестирование (DUnitX)

Проект включает набор модульных тестов на базе **DUnitX** для ключевых компонентов. Тесты расположены в `loader\loader\DUnitXTests\` и организованы по подкаталогам:

### Структура тестов

| Подкаталог | Тестируемый компонент | Приоритет |
|------------|----------------------|-----------|
| `DLLManagerTests` | `Common\DllManager.pas` — загрузка/выгрузка DLL, потокобезопасность | P0 |
| `cxVirtualTreeListHelperTests` | `Common\cxVirtualTreeListHelper.pas` — дженерик-фреймворк TVT | P0 |
| `frxDevCustomDataSetTests` | `loader\frxDevDS\frxDevCustomDataSet.pas` — адаптер для FastReport | P1 |
| `CalcPriceTests` | `loader\CalcPriceDLL\uCalcPricesProc.pas` — расчёт цен с НДС | P1 |
| `VirtualDataCacheTests` | `loader\AnalyticDashboardDLL\Source\VirtualDataCache.pas` — виртуальный кэш | P2 |
| `CatalogServiceTests` | `loader\PartsCatalogDLL\Source\uCatalogService.pas` — сервис каталога | P2 |

### Примеры тестов

- **DllManager**: успешная загрузка/выгрузка, обработка ошибок (файл не найден, функция не найдена, InitProc вернул nil), потокобезопасность (4 потока × 20 циклов Load/Unload), generic-обёртки.
- **cxVirtualTreeListHelper**: создание иерархии (`TVTBase`), `DeleteChildren`, `NodeMoveTo`, `InsertRecordHandle`, `DeleteRecord`, `Clear`, LRU-переупорядочивание.
- **VirtualDataCache**: попадание/промах кэша, LRU eviction, `PrependRecord`, защита от дубликатов загрузки страниц.
- **CatalogService**: CRUD операции, транзакции, обработка FK-нарушений, валидация типов атрибутов.
- **CalcPrice**: функция `CheckNum` (проверка денежного представления), `CalcPricesProc` для различных ставок НДС (0%, 10%, 20%), граничные случаи (0.00, 0.01, 1_200_000.00).

### Организация

Каждый подкаталог содержит:
- `*Fixture.dpr` — главный файл проекта DUnitX (консольное приложение)
- `*Fixture.dproj` — файл проекта Delphi
- `u*Fixture.pas` — исходный код тестовых кейсов
- `*Fixture.md` — подробная спецификация и дизайн-документ тестов
- `exe\` — каталог выходных файлов (содержит `*Fixture.exe` и `dunitx-results.xml`)

**Текущий статус**: Все тесты проходят успешно.

---

## Итого

Проект представляет собой **фреймворк плагинной архитектуры** на Delphi с демонстрационными и продуктовыми плагинами. Ядром фреймворка является `Common` с определениями интерфейсов, менеджером загрузки DLL, пулом потоков, фреймворком для виртуальных деревьев и мониторингом FireDAC.

Приложение-лоадер динамически подгружает **7 DLL-плагинов**, каждый из которых предоставляет свою функциональность:
- **SimpleNumbers** — вычисление простых чисел
- **CalcPrice** — расчёт цен с НДС
- **Explorer** — файловый менеджер
- **RunTasks** — оркестратор задач
- **LogData** — генерация SQL-триггеров для аудита БД
- **PartsCatalog** — управление каталогом деталей (EAV) с PostgreSQL
- **AnalyticDashboard** — аналитическая панель событий с real-time polling и виртуальным кэшем

Дополнительно интегрирована библиотека **FastReport** (`frxDevDS.dll`) для построения отчётов, а также реализован **единый механизм управления скинами DevExpress** с live-обновлением всех плагинов.

Проект покрыт **модульными тестами DUnitX** для ключевых компонентов, что обеспечивает надёжность и возможность рефакторинга.