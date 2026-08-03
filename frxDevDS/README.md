# frxDevDS — FastReport DataSource Plugin

## Описание

`frxDevDS.dll` — плагин для интеграции **FastReport 2023** в архитектуру `loader` с поддержкой:
- **Иерархических данных** из `TVTBaseDataSource` (DevExpress virtual tree list)
- **Баз данных** через FireDAC с SQL-запросами
- **Скриптов FastScript** с расширенным набором функций
- **Множества форматов экспорта** (PDF, Excel, Word, изображения и др.)

Плагин предоставляет адаптер `TfrxDevCustomDataSet`, который преобразует структурированные данные из `TVTBaseRecord` в формат, понятный дизайнеру и рендеру отчётов FastReport.

## Возможности

### Работа с данными
✅ Создание отчётов с данными из `TVTBaseDataSource`  
✅ Создание отчётов с SQL-запросами через FireDAC  
✅ Открытие дизайнера FastReport (RunTime)  
✅ Просмотр отчётов (Preview)  
✅ Поддержка Master-Detail связей  
✅ Динамическое создание отчётов в коде  

### Скрипты и функции
✅ **FastScript (PascalScript)** — встроенный скриптовый движок  
✅ **Расширенные функции даты/времени** — 20+ функций в скриптах отчётов  
✅ **Пользовательские функции** — регистрация своих функций через `SetCustomFunction`  
✅ **RTTI для Classes, Graphics, FireDAC** — доступ к объектам Delphi из скриптов  

### Экспорт
✅ 📄 PDF (TfrxPDFExport)  
✅ 📊 Excel XLS/XLSX (TfrxXLSExport, TfrxXLSXExport)  
✅ 📃 Word DOCX/RTF (TfrxDOCXExport, TfrxRTFExport)  
✅ 🖼️ Изображения BMP/JPEG (TfrxBMPExport, TfrxJPEGExport)  
✅ 📧 Email (TfrxMailExport)  
✅ 🌐 HTML (TfrxHTMLExport — через диалог экспорта)  

### Интеграция
✅ Синхронизация с DllManager (IUsesDllManager)  
✅ Автоматическое управление памятью через TObjectList  
✅ Безопасная работа через интерфейсы (safecall)  
✅ Поддержка скинов DevExpress (uSkinHelper)  

## ⚠️ Важные ограничения

> **Внимание!** Обязательно прочитайте перед использованием:

### 1. PreviewReport требует обязательного указания шаблона

Метод `PreviewReport` работает **ТОЛЬКО** если указан `AReportFile` и файл существует:
```pascal
// НЕ РАБОТАЕТ — превью не откроется!
FrxDevDS.PreviewReport([FDataSource], [cxTL1], '');

// РАБОТАЕТ — шаблон обязателен
FrxDevDS.PreviewReport([FDataSource], [cxTL1], 'Templates\MyReport.fr3');
```
Если файл не существует или строка пустая — метод просто выходит без каких-либо действий.

### 2. PreviewDBReport требует обязательного указания шаблона

Аналогично PreviewReport — метод `PreviewDBReport` работает только с указанным шаблоном:
```pascal
// НЕ РАБОТАЕТ
FrxDevDS.PreviewDBReport('DriverID=PG;...', '');

// РАБОТАЕТ
FrxDevDS.PreviewDBReport('DriverID=PG;...', 'Templates\Orders.fr3');
```
**Примечание:** Метод `PreviewDBReport` принимает только 2 параметра (`ConnectionString`, `ReportFile`). SQL-запросы **не передаются** — они должны быть сохранены в самом шаблоне отчёта.

### 3. DesignDBReport: шаблон отчёта имеет приоритет

Если указан `AReportFile`, SQL-запросы из параметров `ASQLs` **игнорируются**:
```pascal
// Если Orders.fr3 существует, SQL из параметров игнорируются!
FrxDevDS.DesignDBReport(SQLs, Names, ConnStr, 'Templates\Orders.fr3');
```
Чтобы SQL-запросы были добавлены автоматически, укажите пустую строку вместо шаблона:
```pascal
// SQL из параметров будут добавлены как TfrxFDQuery
FrxDevDS.DesignDBReport(SQLs, Names, ConnStr, '');
```

### 4. PreviewReport не требует создания TfrxReport

Метод `PreviewReport` **не принимает** `TfrxReport` как параметр. Внутренний экземпляр `TfrxReport` уже создан в `TdmFR` и доступен через `dmFR.Report`.

### 5. DesignReport не требует создания TfrxReport

Аналогично PreviewReport — метод `DesignReport` работает с внутренним отчётом плагина.

## Архитектура

```
IFrxDevDS (интерфейс плагина) — наследует IDLLIntf
  ├─ DesignReport()           → открыть дизайнер с TVTBaseDataSource
  ├─ PreviewReport()          → открыть превью с TVTBaseDataSource
  ├─ DesignDBReport()         → открыть дизайнер с SQL-запросами (FireDAC)
  ├─ PreviewDBReport()        → открыть превью с SQL-запросами (FireDAC)
  └─ SetCustomFunction()      → регистрация пользовательской функции для FastScript

TDLLFrxDevDS (реализация, наследует IDLLIntf, IFrxDevDS, IUsesDllManager)
  ├─ GetDescription()         → описание плагина
  ├─ Init() / Fin()           → регистрация/удаление DataSet в FastReport
  ├─ SetDllManager()          → установка IDllManager
  ├─ RegisterDataSet()        → приватный метод регистрации TfrxDevCustomDataSet
  ├─ UnregisterDataSet()     → приватный метод удаления регистрации
  ├─ FillReportByTVT()        → заполнение отчёта данными из TVTBaseDataSource
  └─ CreateReportPage()       → создание страницы отчёта при необходимости

TfrxDevCustomDataSet (наследник TfrxUserDataSet)
  ├─ AssignDataSource()       → привязка TVTBaseDataSource
  ├─ Open/First/Next/Eof      → навигация по записям
  ├─ GetValue()               → получение значения поля
  ├─ GetAdapterForRecord()    → адаптер для Master-Detail
  └─ IsBlobField()            → всегда False (TVTBaseRecord не поддерживает BLOB)

TVTRecordAdapter (внутренний класс, наследник TfrxDataSet)
  └─ Оборачивает одну TVTBaseRecord в интерфейс TfrxDataSet

TdmFR (DataModule)
  ├─ TfrxReport               → основной компонент отчёта (v2023.2, PascalScript)
  ├─ TfrxDesigner             → дизайнер отчётов
  ├─ Экспортные компоненты    → PDF, XLS, XLSX, DOCX, RTF, BMP, JPEG, Mail
  ├─ FastScript               → скриптовый движок (PascalScript)
  ├─ RTTI аддоны              → Classes, Graphics, FireDAC
  ├─ TFDConnection            → подключение к БД (DriverID=PG по умолчанию)
  ├─ TfrxFDComponents         → FireDAC компоненты для FastReport
  └─ CustomFunc               → свойство для пользовательской функции

TFSAddFunctions (RTTI модуль)
  └─ Расширяет FastScript функциями даты/времени и CustomFunction
```

## Использование

> **Важно:** Все примеры ниже учитывают реальные сигнатуры методов интерфейса `IFrxDevDS`.
> Методы плагина **не принимают** `TfrxReport` — плагин работает с собственным экземпляром
> `TfrxReport`, который находится в `TdmFR`.

### Сигнатуры методов IFrxDevDS (для справки)

```pascal
procedure DesignReport(
  ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList;
  const AReportFile: WideString = ''); safecall;

procedure PreviewReport(
  ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList;
  const AReportFile: WideString = ''); safecall;

procedure SetCustomFunction(AFunc: TFunc<WideString, WideString, variant>); safecall;

procedure DesignDBReport(
  ASQLs: array of WideString;
  ADataSetNames: array of WideString;
  const AConnectionString: WideString;
  const AReportFile: WideString = ''); safecall;

procedure PreviewDBReport(
  const AConnectionString: WideString;
  const AReportFile: WideString = ''); safecall;
```

### Пример 1: Простой превью с данными из TreeList

```pascal
uses
  intf_dll_manager, frxDevDSIntf, cxVirtualTreeListHelper, cxTL;

procedure TMyPlugin.ShowLogsReport;
var
  FrxDevDS: IFrxDevDS;
  TemplatePath: string;
begin
  { Получить интерфейс плагина frxDevDS }
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then
  begin
    ShowMessage('FastReport plugin is not loaded');
    Exit;
  end;

  { ВАЖНО: PreviewReport требует шаблон! Без него превью не откроется }
  TemplatePath := ExtractFilePath(ParamStr(0)) + 'Templates\Logs.fr3';
  if not FileExists(TemplatePath) then
  begin
    ShowMessage('Шаблон отчёта не найден: ' + TemplatePath);
    Exit;
  end;

  { Открыть превью с привязкой данных }
  FrxDevDS.PreviewReport(
    [FLogDataSource],         { TVTBaseDataSource массив }
    [cxVirtualTreeList1],     { Соответствующие TreeList }
    TemplatePath);            { Шаблон отчёта ОБЯЗАТЕЛЕН }
end;
```

### Пример 2: Открытие дизайнера отчёта

```pascal
procedure TMyPlugin.DesignReport;
var
  FrxDevDS: IFrxDevDS;
  TemplatePath: string;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  { Опционально: загрузить существующий шаблон }
  TemplatePath := ExtractFilePath(ParamStr(0)) + 'Templates\MyReport.fr3';

  { Открыть дизайнер с привязкой Master-Detail }
  FrxDevDS.DesignReport(
    [FCategoryDataSource, FPartsDataSource],  { Master, Detail }
    [cxVirtualTreeList1, cxVirtualTreeList2],
    TemplatePath);  { Пустая строка = создать новый отчёт с нуля }
end;
```

### Пример 3: Отчёт с SQL-запросами (FireDAC) — без шаблона

```pascal
procedure TMyPlugin.ShowDatabaseReport;
var
  FrxDevDS: IFrxDevDS;
  SQLs: array of WideString;
  Names: array of WideString;
  ConnStr: WideString;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  { Настройка SQL-запросов }
  SetLength(SQLs, 2);
  SetLength(Names, 2);

  SQLs[0] := 'SELECT * FROM customers WHERE active = 1';
  Names[0] := 'Customers';

  SQLs[1] := 'SELECT * FROM orders WHERE customer_id = :cust_id';
  Names[1] := 'Orders';

  { Строка подключения PostgreSQL }
  ConnStr := 'DriverID=PG;Server=localhost;Database=mydb;User_name=postgres;Password=secret;';

  { Открыть дизайнер с SQL-запросами }
  { ВАЖНО: пустая строка как AReportFile — SQL-запросы будут добавлены автоматически! }
  FrxDevDS.DesignDBReport(
    SQLs,                    { Массив SQL-запросов }
    Names,                   { Имена наборов данных }
    ConnStr,                 { Строка подключения }
    ''                       { Пустая строка = SQL будут созданы автоматически }
  );
end;
```

### Пример 4: Превью отчёта с БД (с шаблоном)

```pascal
procedure TMyPlugin.PreviewDatabaseReport;
var
  FrxDevDS: IFrxDevDS;
  ConnStr: WideString;
  TemplatePath: string;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  { ВАЖНО: PreviewDBReport принимает только 2 параметра! }
  { SQL-запросы должны быть сохранены в самом шаблоне отчёта (.fr3) }
  TemplatePath := ExtractFilePath(ParamStr(0)) + 'Templates\Products.fr3';
  if not FileExists(TemplatePath) then
  begin
    ShowMessage('Шаблон не найден: ' + TemplatePath);
    Exit;
  end;

  ConnStr := 'DriverID=PG;Server=localhost;Database=shop;User_name=user;Password=pass;';

  { Открыть превью с данными из БД }
  { Шаблон отчёта уже содержит TfrxFDQuery с SQL-запросами }
  FrxDevDS.PreviewDBReport(ConnStr, TemplatePath);
end;
```

### Пример 5: Программный экспорт в PDF (после превью)

```pascal
uses
  dmFastReport, frxExportPDF;

procedure TMyPlugin.ExportToPdf;
var
  FrxDevDS: IFrxDevDS;
  TemplatePath: string;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  TemplatePath := ExtractFilePath(ParamStr(0)) + 'Templates\MyReport.fr3';
  if not FileExists(TemplatePath) then Exit;

  { Сначала открываем превью — это заполняет внутренний dmFR.Report данными }
  FrxDevDS.PreviewReport([FDataSource], [cxVirtualTreeList1], TemplatePath);

  { Теперь можно экспортировать напрямую через dmFR.Report }
  { Примечание: dmFR — глобальный экземпляр DataModule из dmFastReport.pas }
  if Assigned(dmFR) and Assigned(dmFR.Report) then
  begin
    dmFR.PDFExport.FileName := 'export.pdf';
    dmFR.PDFExport.ShowDialog := False;
    dmFR.Report.PrepareReport(True);
    dmFR.Report.Export(dmFR.PDFExport);
  end;
end;
```

### Пример 6: Динамическое создание отчёта через DesignReport

```pascal
procedure TMyPlugin.GenerateDynamicReport;
var
  FrxDevDS: IFrxDevDS;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  { Передаём пустую строку как шаблон — плагин сам создаст страницу отчёта
    и привяжет TfrxDevCustomDataSet к указанным DataSource }
  FrxDevDS.DesignReport(
    [FDataSource],             { массив TVTBaseDataSource }
    [cxVirtualTreeList1],     { массив TcxVirtualTreeList }
    ''                        { Пустая строка = создать с нуля }
  );

  { В дизайнере FastReport:
    1. Автоматически создаётся TfrxReportPage
    2. Создаётся TfrxDevCustomDataSet с именем frxDS0
    3. Вкладка Data показывает DataSet: frxDS0
    4. Перетаскивайте поля из frxDS0 на банды отчёта
  }
end;
```

### Пример 7: Использование пользовательских функций

```pascal
procedure TMyPlugin.SetupCustomFunctions;
var
  FrxDevDS: IFrxDevDS;
  MyFunc: TFunc<WideString, WideString, variant>;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  { Регистрация пользовательской функции через анонимный метод }
  MyFunc := function(Name, Params: WideString): variant
    begin
      if Name = 'GetUserName' then
        Result := CurrentUser.Name
      else if Name = 'FormatCurrency' then
        Result := FormatFloat('###,##0.00 ₽', StrToFloatDef(Params, 0))
      else if Name = 'GetAppVersion' then
        Result := '1.0.0'
      else
        Result := Null;
    end;

  FrxDevDS.SetCustomFunction(MyFunc);
end;
```

**Использование в скрипте отчёта (FastScript):**
```pascal
// В выражении FastReport или в коде скрипта:
[CustomFunction('GetUserName', '')]
[CustomFunction('FormatCurrency', [TotalSum])]
[CustomFunction('GetAppVersion', '')]
```

### Пример 8: Полный цикл — подготовка отчёта с Master-Detail

```pascal
procedure TMyPlugin.ShowMasterDetailReport;
var
  FrxDevDS: IFrxDevDS;
  TemplatePath: string;
begin
  if not Supports(FDllManager.GetIntf(IID_IFrxDevDS), IFrxDevDS, FrxDevDS) then Exit;

  TemplatePath := ExtractFilePath(ParamStr(0)) + 'Templates\MasterDetail.fr3';
  if not FileExists(TemplatePath) then
  begin
    { Создаём отчёт с нуля }
    FrxDevDS.DesignReport(
      [FCategoriesDS, FProductsDS],
      [vtlCategories, vtlProducts],
      ''
    );
    { В дизайнере пользователю нужно:
      1. Master Band → DataSet: frxDS0
      2. Detail Band → DataSet: frxDS1, Master: frxDS0
      3. Сохранить как MasterDetail.fr3
    }
  end
  else
  begin
    { Открываем готовый шаблон с данными }
    FrxDevDS.PreviewReport(
      [FCategoriesDS, FProductsDS],
      [vtlCategories, vtlProducts],
      TemplatePath
    );
  end;
end;
```

## Функции FastScript (uFrxRTTIAddons)

Модуль `uFrxRTTIAddons.pas` расширяет FastScript следующими функциями, доступными в скриптах отчётов:

### Функции начала периода

| Функция | Описание | Синтаксис |
|---------|----------|-----------|
| `StartOfTheYear` | Начало года | `StartOfTheYear(DateTime): TDateTime` |
| `StartOfTheMonth` | Начало месяца | `StartOfTheMonth(DateTime): TDateTime` |
| `StartOfTheWeek` | Начало недели | `StartOfTheWeek(DateTime): TDateTime` |
| `StartOfTheDay` | Начало дня | `StartOfTheDay(DateTime): TDateTime` |
| `StartOfAYear` | Начало указанного года | `StartOfAYear(Year: Word): TDateTime` |
| `StartOfAMonth` | Начало указанного месяца | `StartOfAMonth(Year, Month: Word): TDateTime` |
| `StartOfAWeek` | Начало указанной недели | `StartOfAWeek(Year, WeekOfYear, DayOfWeek=1): TDateTime` |
| `StartOfADay` | Начало указанного дня | `StartOfADay(Year, DayOfYear: Word): TDateTime` |

### Функции конца периода

| Функция | Описание | Синтаксис |
|---------|----------|-----------|
| `EndOfTheYear` | Конец года | `EndOfTheYear(DateTime): TDateTime` |
| `EndOfTheMonth` | Конец месяца | `EndOfTheMonth(DateTime): TDateTime` |
| `EndOfTheWeek` | Конец недели | `EndOfTheWeek(DateTime): TDateTime` |
| `EndOfTheDay` | Конец дня | `EndOfTheDay(DateTime): TDateTime` |
| `EndOfAYear` | Конец указанного года | `EndOfAYear(Year: Word): TDateTime` |
| `EndOfAMonth` | Конец указанного месяца | `EndOfAMonth(Year, Month: Word): TDateTime` |
| `EndOfAWeek` | Конец указанной недели | `EndOfAWeek(Year, WeekOfYear, DayOfWeek: Word): TDateTime` |
| `EndOfADay` | Конец указанного дня | `EndOfADay(Year, Month, Day: Word): TDateTime` |

### Функции смещения даты

| Функция | Описание | Синтаксис |
|---------|----------|-----------|
| `IncMonth` | Добавить/вычесть месяцы | `IncMonth(DateTime, NumberOfMonths: Integer): TDateTime` |
| `IncYear` | Добавить/вычесть годы | `IncYear(DateTime, NumberOfYear: Integer): TDateTime` |
| `IncWeek` | Добавить/вычесть недели | `IncWeek(DateTime, NumberOfWeek: Integer): TDateTime` |
| `IncDay` | Добавить/вычесть дни | `IncDay(DateTime, NumberOfDay: Integer): TDateTime` |

### Пользовательские функции

| Функция | Описание | Синтаксис |
|---------|----------|-----------|
| `CustomFunction` | Вызов пользовательской функции | `CustomFunction(Name, Params: String): Variant` |

**Пример использования в выражении FastReport:**
```pascal
// Получить первый день текущего месяца
[StartOfTheMonth(Now)]

// Получить последний день прошлого года
[EndOfTheYear(IncYear(Now, -1))]

// Дата через 30 дней
[IncDay(Now, 30)]

// Начало указанной даты
[StartOfAMonth(2026, 8)]  // 01.08.2026 00:00:00

// Вызов пользовательской функции
[CustomFunction('GetUserName', '')]
```

## 🐛 Известные проблемы в коде

> Следующие проблемы обнаружены при анализе текущей реализации и требуют исправления:

### 1. Дублирование обработчиков `StartOfADay` и `EndOfADay` в `uFrxRTTIAddons.pas`

В функции `CallMethod` присутствуют дублирующие блоки `if`, из-за чего перегрузка с 3 параметрами никогда не вызывается:

```pascal
// ❌ Баг: второй if никогда не выполнится
if MethodName = 'STARTOFADAY' then
    Result := StartOfADay(Caller.Params[0], Caller.Params[1])
else if MethodName = 'STARTOFADAY' then  // ← ДУБЛИКАТ! Это мёртвый код
    Result := StartOfADay(Caller.Params[0], Caller.Params[1], Caller.Params[2])
```

**Влияние:** Функция `StartOfADay(Year, Month, Day)` с тремя параметрами недоступна в скриптах отчётов.

**Исправление:** Переименовать вторую перегрузку или удалить дубликат.

### 2. PreviewReport и PreviewDBReport — тихое игнорирование при отсутствии шаблона

```pascal
// В PreviewReport:
if (AReportFile <> '') and FileExists(AReportFile) then
  ...
  // else — НИЧЕГО НЕ ДЕЛАЕТ!
```

**Влияние:** Вызывающий код не получает никаких уведомлений об ошибке. Метод просто не выполняет никаких действий.

**Рекомендация:** Добавить выброс исключения или возврат результата.

### 3. DesignDBReport игнорирует SQL при наличии шаблона

```pascal
if (AReportFile <> '') and FileExists(AReportFile) then
    FDM.Report.LoadFromFile(AReportFile)
else begin
    // SQL-запросы добавляются только здесь
    ...
end;
```

**Влияние:** Если передать одновременно и SQL-запросы, и шаблон — SQL будут проигнорированы без предупреждения.

### 4. `PreviewReport` не вызывает `FillReportByTVT` при отсутствии шаблона

```pascal
if (AReportFile <> '') and FileExists(AReportFile) then
begin
  if not FillReportByTVT(ADataSources, ATreeLists) then
    exit;
  FDM.Report.LoadFromFile(AReportFile);
  FDM.Report.ShowReport(True);
end;
```

**Влияние:** `TfrxDevCustomDataSet` создаётся **только** когда указан валидный шаблон. В остальных случаях DataSource не привязываются.

### 5. Отсутствие обработки ошибок в `SetCustomFunction`

Метод `SetCustomFunction` не проверяет результат присваивания и не вызывает `fsScript.AddMethod` для `CustomFunction` — функция регистрируется только в `uFrxRTTIAddons`, и `dmFR.CustomFunc` должен быть установлен **до** открытия отчёта.

## Интеграция в главное приложение (loader.exe)

### 1. Добавить кнопку в uMain.dfm

В ленте dxRibbon добавить `dxBarLargeButton`:
```
dxBar1
  └── dxBarLargeButton
      ├── Name: btnFastReport
      ├── Caption: 'FastReport'
      └── LargeImageIndex: [индекс в ImageList]
```

### 2. Обновить uMain.pas

```pascal
unit uMain;

interface

uses
  {...},
  frxDevDSIntf;  { Новое подключение }

type
  TfrmMain = class(TForm)
    {...}
    btnFastReport: TdxBarLargeButton;
  private
    procedure SetupFastReportButton;
  end;

implementation

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  {...}
  SetupFastReportButton;
  LoadAllDlls;  { Загрузит frxDevDS.dll }
end;

procedure TfrmMain.SetupFastReportButton;
begin
  FButtons.AddEntry(btnFastReport, DIFrxDevDS, nil);
end;

end.
```

## Требования

- **Delphi**: 10.3 Rio или выше
- **FastReport VCL**: 2023 версия
- **DevExpress VCL**: любая версия с cxVirtualTreeList
- **FireDAC**: для работы с базами данных (включён в Delphi)
- **Common модули**: `intf_dll.pas`, `intf_dll_manager.pas`, `cxVirtualTreeListHelper.pas`

## Компиляция

### Подготовка:
1. Убедитесь, что переменная окружения `FR_2023_VCL` указывает на корректный путь
2. Установлена последняя версия FastReport 2023
3. В Delphi IDE установлены пакеты DevExpress

### Сборка в IDE:
```
Project → Compile 'frxDevDS'
```

### Или через командную строку:
```bash
cd C:\Users\Alexandr\Documents\forAI\loader\frxDevDS
rsvars.bat  # Установить переменные окружения
dcc32 frxDevDS.dpr -B
```

### Копирование:
```bash
copy frxDevDS.dll C:\Users\Alexandr\Documents\forAI\loader\Exe\
```

## Дизайнер FastReport (RunTime)

После загрузки плагина:
1. В дизайнере FastReport → вкладка "Data"
2. Появляется новая категория: "DevExpress DataSource"
3. Перетаскивайте поля на банды отчёта
4. В свойствах полей настраивайте форматирование

### Цикл навигации FastReport:
```
Open()
First()
repeat
  GetValue('Field1'), GetValue('Field2'), ...
  Next()
until Eof()
Close()
```

## Master-Detail

Для создания связанных наборов данных:

```pascal
FrxDevDS.DesignReport(Report,
  [FMasterDataSource, FDetailDataSource],
  [vtlMaster, vtlDetail]);

{ В дизайнере:
  1. Master-банд → Dataset: frxDS0
  2. Detail-банд → Dataset: frxDS1, Master: frxDS0
}
```

## Работа с базами данных (FireDAC)

Плагин поддерживает работу с любыми базами данных через FireDAC:

### Поддерживаемые СУБД:
- PostgreSQL (DriverID=PG)
- MySQL (DriverID=MySQL)
- SQLite (DriverID=SQLite)
- InterBase/Firebird (DriverID=IB/FB)
- Oracle (DriverID=Ora)
- MS SQL Server (DriverID=MSSQL)
- И другие через FireDAC драйверы

### Архитектура работы с БД:
```
Вызывающий код (loader.exe / плагин)
  │
  ├─ Передаёт: SQL-запросы + Строка подключения
  │
  └─ frxDevDS.dll
      │
      ├─ TFDConnection (устанавливает соединение)
      ├─ TfrxFDComponents (глобальный менеджер FireDAC)
      ├─ TfrxFDQuery (выполняет SQL)
      └─ FastReport (отображает данные)
```

### Преимущества FireDAC интеграции:
1. **Изоляция границ модулей** — TFDConnection живёт внутри DLL
2. **Чистота архитектуры** — строка подключения передаётся как WideString
3. **Штатный механизм FastReport** — использование GFDComponents.DefaultDatabase
4. **Отсутствие накладных расходов** — нет копирования данных в TClientDataSet

## Экспорт

FastReport поддерживает экспорт в:
- 📄 **PDF** (TfrxPDFExport) — с поддержкой PDF/A, шрифтов, защиты
- 📊 **Excel XLS** (TfrxXLSExport) — старый формат Excel
- 📊 **Excel XLSX** (TfrxXLSXExport) — современный формат
- 📃 **Word DOCX** (TfrxDOCXExport) — формат Microsoft Word
- 📃 **RTF** (TfrxRTFExport) — Rich Text Format
- 🖼️ **BMP** (TfrxBMPExport) — растровые изображения
- 🖼️ **JPEG** (TfrxJPEGExport) — сжатые изображения
- 📧 **Email** (TfrxMailExport) — отправка по SMTP
- 🌐 **HTML** (через диалог экспорта) — веб-страницы
- 📝 **Текст** (через диалог экспорта) — простой текст

## Решение проблем

| Проблема | Решение |
|----------|---------|
| DLL не загружается | Убедитесь, что `frxDevDS.dll` рядом с `loader.exe` |
| "Интерфейс не найден" | Проверьте, что GUID в `frxDevDSIntf.pas` совпадает с `DIFrxDevDS` |
| Данные не отображаются | Убедитесь, что `AssignDataSource()` вызван с непустым `RootHandle` |
| Ошибка в дизайнере | Проверьте версию FastReport в `FR_2023_VCL\Sources` |
| FireDAC: "Connection is not defined" | Передайте корректную строку подключения в `DesignDBReport` |
| FireDAC: SQL ошибка | Проверьте синтаксис SQL-запроса и права доступа к БД |
| Функции даты не работают | Убедитесь, что `uFrxRTTIAddons.pas` подключён в `frxDevDS.dpr` |
| CustomFunction возвращает Null | Проверьте, что `SetCustomFunction()` был вызван до открытия отчёта |
| Утечка памяти при повторных вызовах | Используется `TObjectList<TfrxDataset>` — утечек быть не должно |

## Файлы проекта

```
frxDevDS/
├── frxDevDS.dpr              (main library, exports InitFrxDevDS)
├── frxDevDS.dproj            (Delphi project configuration)
├── frxDevDS.rc               (version resource)
├── frxDevDS.res              (compiled resource)
├── dmFastReport.pas          (DataModule с TfrxReport, экспортами, FastScript, FireDAC)
├── dmFastReport.dfm          (конфигурация DataModule в design-time)
├── frxDevCustomDataSet.pas   (TfrxDevCustomDataSet, TVTRecordAdapter)
├── uFrxRTTIAddons.pas        (расширение FastScript: функции даты/времени)
├── README.md                 (this file)
├── INTEGRATION_CHECKLIST.md  (пошаговая интеграция)
├── PLUGIN_INTEGRATION_EXAMPLES.md (примеры кода)
├── FILES_CREATED.md          (описание файлов)
└── 00_START_HERE.md          (быстрый старт)
```

### Описание модулей:

#### dmFastReport.pas (DataModule)
Содержит все компоненты FastReport и FireDAC:
- `Report: TfrxReport` — основной компонент отчёта
- `designer: TfrxDesigner` — дизайнер отчётов
- `PDFExport, XLSXExport, DOCXExport, ...` — экспортные компоненты
- `fsScript, fsPascal` — FastScript (PascalScript)
- `fsClassesRTTI, fsGraphicsRTTI, fsFDRTTI` — RTTI для скриптов
- `FDConn: TFDConnection` — подключение к БД
- `frxFDComponents1` — FireDAC компоненты для FastReport
- `CustomFunc` — свойство для пользовательской функции

#### uFrxRTTIAddons.pas (FastScript Addons)
Расширяет FastScript дополнительными функциями:
- Класс `TFSAddFunctions` (наследник `TfsRTTIModule`)
- Регистрация 20+ функций даты/времени
- Регистрация `CustomFunction` для пользовательских функций
- Автоматическая регистрация в `initialization` секции

#### frxDevCustomDataSet.pas (Адаптер)
Основные классы для работы с TVTBaseDataSource:
- `TVTRecordAdapter` — обёртка одной записи
- `TfrxDevCustomDataSet` — адаптер всего DataSource
- Функции регистрации в FastReport

## История версий

### v1.1 (2026-08-03)
- ✅ Добавлена поддержка FireDAC (DesignDBReport, PreviewDBReport)
- ✅ Интеграция FastScript (PascalScript)
- ✅ Модуль uFrxRTTIAddons с функциями даты/времени
- ✅ Поддержка пользовательских функций (SetCustomFunction)
- ✅ DataModule dmFastReport со всеми компонентами
- ✅ Расширенные экспортные возможности (DOCX, XLSX, BMP, JPEG, Mail)
- ✅ Автоматическое управление памятью через TObjectList

### v1.0 (2026-07-29)
- ✅ Первая версия
- ✅ Базовая поддержка TfrxDevCustomDataSet
- ✅ Методы дизайна и превью отчётов
- ✅ Поддержка Master-Detail

## Лицензия

Часть экосистемы `loader`. Следует существующим соглашениям проекта.

## Контакты

Для вопросов и предложений обратитесь к разработчику `loader`.

---

**Версия**: 1.1  
**Дата**: 3 августа 2026  
**Статус**: Production-ready
