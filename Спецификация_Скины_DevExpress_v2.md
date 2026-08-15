# Спецификация: Единый механизм скинов DevExpress для проекта Loader (v2)

> **Версия 2** учитывает реальное состояние репозитория: существующее имя `cmbSkins` в `loader.exe`, расположение общего кода в отдельном репозитории `Common/`, и — главное — проблему скининга `TdxLayoutControl`, решение которой уже существует в `PartsCatalogDLL` и должно быть распространено на все проекты.

---

## 1. Анализ текущего состояния

### 1.1. Архитектура приложения

```
repo/
├── common/                                  ← отдельный репозиторий (общее ядро)
│   ├── intf_dll.pas            TDLLInfo, IDLLIntf, IDllIntfRun
│   ├── intf_common.pas         доменные интерфейсы + DISimpleNumbers..DICatalogParts
│   ├── intf_dll_manager.pas    IDllManager, IUsesDllManager, IDllIntfRunWithDeps
│   ├── intf_tasks.pas          IRunTask и наследники
│   ├── DllManager.pas          TDllManager
│   ├── pool_config.inc         {$define use_otl}
│   ├── vstHelper.pas
│   ├── cxVirtualTreeListHelper.pas
│   ├── uAutonomiusThreadPool.pas
│   └── uOmniThreadPoolManager.pas
└── loader/
    ├── loader.exe (основное приложение)
    │   └── Главная форма TfrmMain (dxRibbon + dxBarManager + dxLayoutControl)
    └── DLL-плагины (8 штук):
        ├── SimpleNumbers.dll     (TdxLayoutControl)
        ├── CalcPrice.dll         (TdxLayoutControl)
        ├── Explorer.dll          (TdxLayoutControl)
        ├── RunTasks.dll          (TdxLayoutControl + TdxRibbon)
        ├── LogData.dll           (TdxLayoutControl в диалоге + TdxRibbon)
        ├── RunTaskFind.dll       (невизуальная)
        ├── RunTaskShellExecute.dll (невизуальная)
        └── PartsCatalog.dll      (TdxLayoutControl × 6 форм + TdxRibbon) ← единственный с корректным скином
```

### 1.2. Как сейчас работают скины

**PartsCatalogDLL** (`loader\PartsCatalogDLL\Source\uMain.pas`):

```pascal
// Список скинов заполняется локально в форме
procedure TfrmMain.InitializeSkinList;
var
  SkinNames: TStringList;
begin
  SkinNames := TStringList.Create;
  try
    cxLookAndFeelPaintersManager.PopulateSkinNames(SkinNames);
    cmbSkins.Properties.Items.Clear;
    for i := 0 to SkinNames.Count - 1 do
      cmbSkins.Properties.Items.Add(SkinNames[i]);
    CurrentSkin := RootLookAndFeel.SkinName;
    if CurrentSkin = '' then
      CurrentSkin := 'DevExpressStyle';
    cmbSkins.EditValue := CurrentSkin;
  finally
    SkinNames.Free;
  end;
end;

// Скин меняется локально в форме DLL
procedure TfrmMain.cmbSkinsPropertiesChange(Sender: TObject);
var
  SelectedSkin: string;
begin
  SelectedSkin := VarToStr(cmbSkins.EditValue);
  if SelectedSkin <> '' then
  begin
    RootLookAndFeel.BeginUpdate;
    try
      RootLookAndFeel.SkinName := SelectedSkin;
      RootLookAndFeel.NativeStyle := False;
      rbMain.ColorSchemeName := SelectedSkin;  // Синхронизация Ribbon
    finally
      RootLookAndFeel.EndUpdate;
    end;
  end;
end;
```

### 1.3. Проблема `TdxLayoutControl`

`TdxLayoutControl` — это контейнер DevExpress с **собственным механизмом LookAndFeel**, отдельным от `Root.LookAndFeel` и `RootLookAndFeel` формы. По умолчанию он использует «стандартный» отрисовщик (`StandardLookAndFeel`), который **игнорирует** все глобальные скин-настройки. В результате: форма перекрашивается в выбранный скин, а группа `TdxLayoutGroup` и её caption'ы остаются с серой «классической» заливкой — визуальный рассинхрон.

**Решение в PartsCatalogDLL** — центральный DataModule с общим `TdxLayoutSkinLookAndFeel`:

```pascal
// dmDatabase.pas (строки 48-50)
TdmDB = class(TDataModule)
  ...
  dxSkinController: TdxSkinController;
  dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
  dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
end;
```

```dfm
// dmDatabase.dfm
object dxSkinController: TdxSkinController
  SkinName = 'DevExpressStyle'
end
object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
  object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
    LookAndFeel.Kind = lfUltraFlat
    LookAndFeel.NativeStyle = False    // ← критично
  end
end
```

Все 6 форм PartsCatalog (`uMain`, `fPartEdit`, `fCategoryEdit`, `fAttributeEdit`, `fAttributeSelect`, `fAttributeDelete`) в своих DFM ссылаются на один и тот же общий объект:

```dfm
object lcMain: TdxLayoutControl
  LayoutLookAndFeel = dmDB.dxLayoutSkinLookAndFeel1
end
```

### 1.4. Состояние `TdxLayoutControl` в остальных проектах

| Проект | Форма / Файл | `LayoutLookAndFeel` назначен? | `dxSkinController`? | DataModule с общим LookAndFeel? |
|---|---|---|---|---|
| **loader.exe** | `Source/uMain.dfm` (`lcMain`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **ExplorerDLL** | `uExplorer.dfm` (`lcExplorer`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **CalcPriceDLL** | `uCalcPrice.dfm` (`lcCalcPrice`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **RunTasksDLL** | `uRunTasks.dfm` (`lcRunTasks`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **SimpleNumbersDLL** | `main.dfm` (`lcMain`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **LogDataDLL** | `uConnectionParams.dfm` (`lcConnectionParams`) | ❌ НЕТ | ❌ НЕТ | ❌ НЕТ |
| **PartsCatalogDLL** | 6 форм | ✅ `dmDB.dxLayoutSkinLookAndFeel1` | ✅ `dmDB.dxSkinController` | ✅ `dmDatabase.pas` |

PartsCatalogDLL — **единственный** проект, где layout-контролы корректно настроены под скин. В 6 остальных формах (5 DLL + главная форма `loader.exe`) layout-контролы сейчас рендерятся «стандартным» отрисовщиком и **не будут** менять скин даже после реализации остальной спецификации.

### 1.5. Проблемы текущего подхода

| Проблема | Описание |
|----------|----------|
| **Фрагментация** | Скины выбираются только в PartsCatalogDLL; остальные 7 DLL живут со скином по умолчанию |
| **Отсутствие единообразия** | Каждая DLL имеет свой `RootLookAndFeel` — переключение в одной не влияет на другие |
| **Дублирование кода** | Если добавить выбор скина в каждую DLL — код `InitializeSkinList` и `cmbSkinsPropertiesChange` дублируется 8 раз |
| **Нет централизации** | Главное приложение не знает о скинах и не управляет ими |
| **Сохранение настроек** | Выбранный скин не сохраняется между запусками; при перезапуске PartsCatalogDLL сбрасывается на `'DevExpressStyle'` |
| **Синхронизация Ribbon** | `rbMain.ColorSchemeName` синхронизируется вручную — легко забыть при добавлении новых форм |
| **`TdxLayoutControl` не скинится** | В 6 формах из 7 layout-контролы используют стандартный отрисовщик и не реагируют на смену скина |
| **Отсутствие `TdxSkinController`** | В 6 формах из 7 нет `TdxSkinController` — глобального применения скина ко всем DevExpress-контролам не происходит |

---

## 2. Целевая архитектура

### 2.1. Принцип: «Один скин — все DLL + все LayoutControl»

Главная форма `loader.exe` становится **единственным источником истины** для скина. При запуске любой DLL выбранный скин передаётся внутрь. Паттерн DataModule с `TdxSkinController` + `TdxLayoutLookAndFeelList` + `TdxLayoutSkinLookAndFeel` гарантирует, что **и обычные контролы, и `TdxLayoutControl`, и `TdxRibbon`** будут в одном скине.

```
┌──────────────────────────────────────────────────────────┐
│  loader.exe (TfrmMain)                                   │
│  ├─ dmSkin: TdmSkin (DataModule)                         │
│  │   ├─ dxSkinController: TdxSkinController              │
│  │   ├─ dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList│
│  │   └─ dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel│
│  ├─ cmbSkins: TcxComboBox (уже существует в DFM)         │
│  ├─ FSkinManager: TSkinManager                           │
│  └─ Настройки в settings.json рядом с .exe               │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼ при Run() → ISkinAware.ApplySkin(skin, native)
    ┌───────────────┼───────────────┬───────────────┐
    ▼               ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌────────────┐    ┌────────────┐
│Explorer│    │LogData   │    │PartsCatalog│    │CalcPrice   │
│  .dll  │    │  .dll    │    │   .dll     │    │  .dll      │
│ локал. │    │ dmSkin   │    │ dmDB       │    │ локал.     │
│ LFLAF  │    │ (новый)  │    │ (существ.) │    │ LFLAF      │
└────────┘    └──────────┘    └────────────┘    └────────────┘
```

Где `LFLAF` = `TdxLayoutLookAndFeelList` + `TdxLayoutSkinLookAndFeel` (локально на форме).

### 2.2. Новый интерфейс `ISkinAware`

Добавить в `Common/intf_skin.pas`:

```pascal
unit intf_skin;

interface

type
  /// <summary>
  /// Интерфейс для плагинов, которые поддерживают внешнее управление скином.
  /// Вызывается главным приложением перед Show/ShowModal.
  /// </summary>
  ISkinAware = interface(IInterface)
    ['{8A3E7B12-C4D5-4F6A-9E8B-2D1C5F7A3B90}']
    /// <summary>
    /// Установить скин DevExpress для всех форм плагина.
    /// </summary>
    /// <param name="ASkinName">Имя скина (например, 'DevExpressStyle', 'Office2016Dark')</param>
    /// <param name="ANativeStyle">True — нативный стиль Windows, False — скин</param>
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean = False); safecall;
  end;

  /// <summary>
  /// Интерфейс для получения списка доступных скинов от плагина.
  /// Необязательный — главное приложение может само собрать список.
  /// </summary>
  ISkinProvider = interface(IInterface)
    ['{9B4F8C23-D5E6-5A7B-BF9C-3E2D6G8B4CA1}']
    procedure GetAvailableSkins(out ASkinNames: TArray<WideString>); safecall;
  end;

implementation

end.
```

`ISkinProvider` пока нигде не реализуется — оставлен на будущее.

**Почему отдельный `intf_skin.pas`, а не расширение `intf_dll.pas`:** `intf_dll.pas` используется невизуальными DLL (`RunTaskFind`, `RunTaskShellExecute`), и его зависимости не должны утяжеляться визуальными типами. `intf_skin.pas` подключают только визуальные DLL.

### 2.3. Паттерн DataModule с `TdxSkinController` + `TdxLayoutLookAndFeelList`

Для каждого проекта, где используется `TdxLayoutControl`, создаётся **центральный DataModule** (или компоненты размещаются на форме — для простых случаев) со следующим содержимым:

```pascal
type
  TdmSkin = class(TDataModule)
    dxSkinController: TdxSkinController;
    dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
  end;
```

Соответствующая DFM:

```dfm
object dmSkin: TdmSkin
  object dxSkinController: TdxSkinController
    SkinName = 'DevExpressStyle'
    Left = 48
    Top = 12
  end
  object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
    Left = 48
    Top = 68
    object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
      GroupOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      GroupOptions.CaptionOptions.Font.Color = clWindowText
      GroupOptions.CaptionOptions.Font.Height = -12
      GroupOptions.CaptionOptions.Font.Name = 'Segoe UI'
      GroupOptions.CaptionOptions.Font.Style = []
      GroupOptions.CaptionOptions.UseDefaultFont = False
      ItemOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      ItemOptions.CaptionOptions.Font.Color = clWindowText
      ItemOptions.CaptionOptions.Font.Height = -12
      ItemOptions.CaptionOptions.Font.Name = 'Segoe UI'
      ItemOptions.CaptionOptions.Font.Style = []
      ItemOptions.CaptionOptions.UseDefaultFont = False
      LookAndFeel.Kind = lfUltraFlat
      LookAndFeel.NativeStyle = False       // ← критично: иначе скин игнорируется
      PixelsPerInch = 96
    end
  end
end
```

Все `TdxLayoutControl` в проекте ссылаются на этот общий `dxLayoutSkinLookAndFeel1` через свойство `LayoutLookAndFeel` в DFM:

```dfm
object lcMain: TdxLayoutControl
  LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1
  ...
end
```

---

## 3. Компоненты системы

### 3.1. `TSkinManager` (новый класс в `Common`)

```pascal
unit uSkinManager;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  System.JSON, System.IOUtils,
  cxLookAndFeels, cxLookAndFeelPainters,
  intf_skin, dxSkinsForm, dxLayoutLookAndFeels;

type
  TSkinManager = class
  private
    FCurrentSkin: string;
    FNativeStyle: Boolean;
    FOnSkinChanged: TProc<string, Boolean>;
    FSubscribers: TList<ISkinAware>;
    FConfigFile: string;
    procedure SetCurrentSkin(const Value: string);
    procedure SetNativeStyle(const Value: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Загрузить скин из settings.json</summary>
    procedure LoadSettings;
    /// <summary>Сохранить скин в settings.json</summary>
    procedure SaveSettings;
    /// <summary>Заполнить комбобокс списком скинов</summary>
    procedure PopulateSkinList(AComboBox: TcxComboBox);
    /// <summary>Применить скин к главной форме (RootLookAndFeel + Ribbon)</summary>
    procedure ApplyToMainForm(ARootLookAndFeel: TcxLookAndFeel; ARibbon: TdxRibbon = nil);

    /// <summary>Регистрация подписчика (DLL с открытой формой) для live-обновления</summary>
    procedure RegisterSubscriber(const ASubscriber: ISkinAware);
    procedure UnregisterSubscriber(const ASubscriber: ISkinAware);

    property CurrentSkin: string read FCurrentSkin write SetCurrentSkin;
    property NativeStyle: Boolean read FNativeStyle write SetNativeStyle;
    property OnSkinChanged: TProc<string, Boolean> read FOnSkinChanged write FOnSkinChanged;
  end;

implementation

{ TSkinManager }

constructor TSkinManager.Create;
begin
  inherited Create;
  FSubscribers := TList<ISkinAware>.Create;
  FCurrentSkin := 'DevExpressStyle';
  FNativeStyle := False;
  // JSON-файл рядом с loader.exe — портативность, не требует прав администратора
  FConfigFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'settings.json');
end;

destructor TSkinManager.Destroy;
begin
  FSubscribers.Free;
  inherited;
end;

procedure TSkinManager.LoadSettings;
var
  JSON: TJSONObject;
begin
  if not TFile.Exists(FConfigFile) then
    Exit; // оставляем дефолты

  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FConfigFile)) as TJSONObject;
  if JSON = nil then Exit;
  try
    FCurrentSkin := JSON.GetValue<string>('skin_name', 'DevExpressStyle');
    FNativeStyle := JSON.GetValue<Boolean>('native_style', False);
  finally
    JSON.Free;
  end;
end;

procedure TSkinManager.SaveSettings;
var
  JSON: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('skin_name', FCurrentSkin);
    JSON.AddPair('native_style', TJSONBool.Create(FNativeStyle));
    TFile.WriteAllText(FConfigFile, JSON.ToString);
  finally
    JSON.Free;
  end;
end;

procedure TSkinManager.PopulateSkinList(AComboBox: TcxComboBox);
var
  SkinNames: TStringList;
  i: Integer;
begin
  SkinNames := TStringList.Create;
  try
    cxLookAndFeelPaintersManager.PopulateSkinNames(SkinNames);
    AComboBox.Properties.Items.Clear;
    for i := 0 to SkinNames.Count - 1 do
      AComboBox.Properties.Items.Add(SkinNames[i]);
  finally
    SkinNames.Free;
  end;
end;

procedure TSkinManager.ApplyToMainForm(ARootLookAndFeel: TcxLookAndFeel; ARibbon: TdxRibbon);
begin
  ARootLookAndFeel.BeginUpdate;
  try
    ARootLookAndFeel.SkinName := FCurrentSkin;
    ARootLookAndFeel.NativeStyle := FNativeStyle;
    if Assigned(ARibbon) then
      ARibbon.ColorSchemeName := FCurrentSkin;
  finally
    ARootLookAndFeel.EndUpdate;
  end;
end;

procedure TSkinManager.SetCurrentSkin(const Value: string);
var
  sub: ISkinAware;
begin
  if FCurrentSkin = Value then Exit;
  FCurrentSkin := Value;
  // КРИТИЧНО: явно дёргаем колбэк — иначе SaveSettings и ApplyToMainForm не вызовутся
  if Assigned(FOnSkinChanged) then
    FOnSkinChanged(FCurrentSkin, FNativeStyle);
  // Оповещаем подписчиков (открытые немодальные формы DLL)
  for sub in FSubscribers do
    try
      sub.ApplySkin(FCurrentSkin, FNativeStyle);
    except
      // подписчик мог выгрузиться — игнорируем
    end;
end;

procedure TSkinManager.SetNativeStyle(const Value: Boolean);
var
  sub: ISkinAware;
begin
  if FNativeStyle = Value then Exit;
  FNativeStyle := Value;
  if Assigned(FOnSkinChanged) then
    FOnSkinChanged(FCurrentSkin, FNativeStyle);
  for sub in FSubscribers do
    try
      sub.ApplySkin(FCurrentSkin, FNativeStyle);
    except
    end;
end;

procedure TSkinManager.RegisterSubscriber(const ASubscriber: ISkinAware);
begin
  if not FSubscribers.Contains(ASubscriber) then
    FSubscribers.Add(ASubscriber);
end;

procedure TSkinManager.UnregisterSubscriber(const ASubscriber: ISkinAware);
begin
  FSubscribers.Remove(ASubscriber);
end;

end.
```

**Ключевые решения:**

1. **Не синглтон.** `TSkinManager` создаётся как поле `FSkinManager: TSkinManager` в `TfrmMain.FormCreate`, освобождается в `FormDestroy`. Глобальный `function SkinManager` не делается — это создаёт неоднозначность с жизненным циклом в DLL-приложении.

2. **JSON-хранилище** (`settings.json` рядом с `loader.exe`). Приложение плагинное, важна портативность — Registry привязывает к машине и требует прав.

3. **`SetCurrentSkin` и `SetNativeStyle` явно вызывают `FOnSkinChanged`** и проходят по списку подписчиков. Без этого `SaveSettings` и `ApplyToMainForm` никогда не сработают.

4. **Список подписчиков `FSubscribers: TList<ISkinAware>`** — для live-обновления уже открытых немодальных форм DLL при смене скина в `loader.exe`. Для модальных форм не используется (они и так открываются с актуальным скином через `ApplySkin` перед `Show`).

### 3.2. `uSkinHelper` (расширенный)

```pascal
unit uSkinHelper;

interface

uses
  Vcl.Forms, System.Classes,
  cxLookAndFeels,
  dxSkinsForm, dxLayoutLookAndFeels;

/// <summary>Применить скин к RootLookAndFeel формы (и её Ribbon при наличии).</summary>
procedure ApplySkinToForm(AForm: TForm; const ASkinName: string;
  ANativeStyle: Boolean; ARibbon: TObject = nil);

/// <summary>
/// Синхронизировать центральный TdxSkinController и TdxLayoutSkinLookAndFeel
/// в DataModule. Используется для скининга TdxLayoutControl.
/// </summary>
procedure ApplySkinToDataModule(ADM: TDataModule;
  ASkinController: TdxSkinController;
  ALayoutSkinLookAndFeel: TdxLayoutSkinLookAndFeel;
  const ASkinName: string; ANativeStyle: Boolean);

implementation

uses
  dxRibbon;  // для приведения ARibbon к TdxRibbon

procedure ApplySkinToForm(AForm: TForm; const ASkinName: string;
  ANativeStyle: Boolean; ARibbon: TObject = nil);
var
  Ribbon: TdxRibbon;
begin
  if ASkinName = '' then Exit;
  AForm.RootLookAndFeel.BeginUpdate;
  try
    AForm.RootLookAndFeel.SkinName := ASkinName;
    AForm.RootLookAndFeel.NativeStyle := ANativeStyle;
  finally
    AForm.RootLookAndFeel.EndUpdate;
  end;
  if Assigned(ARibbon) and (ARibbon is TdxRibbon) then
  begin
    Ribbon := TdxRibbon(ARibbon);
    Ribbon.ColorSchemeName := ASkinName;
  end;
end;

procedure ApplySkinToDataModule(ADM: TDataModule;
  ASkinController: TdxSkinController;
  ALayoutSkinLookAndFeel: TdxLayoutSkinLookAndFeel;
  const ASkinName: string; ANativeStyle: Boolean);
begin
  if ASkinName = '' then Exit;
  if Assigned(ASkinController) then
  begin
    ASkinController.SkinName := ASkinName;
    ASkinController.NativeStyle := ANativeStyle;
  end;
  if Assigned(ALayoutSkinLookAndFeel) then
  begin
    ALayoutSkinLookAndFeel.LookAndFeel.NativeStyle := ANativeStyle;
    ALayoutSkinLookAndFeel.LookAndFeel.SkinName := ASkinName;
  end;
end;

end.
```

### 3.3. DataModule `dmSkin` для `loader.exe`

`loader.exe` не имеет DataModule. Layout-контрол один (`lcMain` в `uMain.dfm`), но паттерн DataModule предпочтительнее для единообразия с DLL и для будущих форм.

**`Source/dmSkin.pas`:**

```pascal
unit dmSkin;

interface

uses
  System.SysUtils, System.Classes,
  cxClasses, cxLookAndFeels,
  dxSkinsForm, dxLayoutLookAndFeels;

type
  TdmSkin = class(TDataModule)
    dxSkinController: TdxSkinController;
    dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dmSkin: TdmSkin;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

end.
```

**`Source/dmSkin.dfm`:**

```dfm
object dmSkin: TdmSkin
  Height = 240
  Width = 320
  object dxSkinController: TdxSkinController
    SkinName = 'DevExpressStyle'
    Left = 48
    Top = 24
  end
  object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
    Left = 48
    Top = 96
    object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
      GroupOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      GroupOptions.CaptionOptions.Font.Color = clWindowText
      GroupOptions.CaptionOptions.Font.Height = -12
      GroupOptions.CaptionOptions.Font.Name = 'Segoe UI'
      GroupOptions.CaptionOptions.Font.Style = []
      GroupOptions.CaptionOptions.UseDefaultFont = False
      ItemOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      ItemOptions.CaptionOptions.Font.Color = clWindowText
      ItemOptions.CaptionOptions.Font.Height = -12
      ItemOptions.CaptionOptions.Font.Name = 'Segoe UI'
      ItemOptions.CaptionOptions.Font.Style = []
      ItemOptions.CaptionOptions.UseDefaultFont = False
      LookAndFeel.Kind = lfUltraFlat
      LookAndFeel.NativeStyle = False
      PixelsPerInch = 96
    end
  end
end
```

### 3.4. Модификация `TfrmMain` (`loader\Source\uMain.pas`)

**В `uses` добавить:**

```pascal
uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters,
  dxCore, dxRibbonSkins, dxRibbonCustomizationForm,
  System.Actions, Vcl.ActnList, System.ImageList, Vcl.ImgList, cxImageList,
  dxLayoutContainer, dxLayoutControl, cxClasses, dxBar, dxRibbon,
  DllManager, intf_dll, intf_common, System.Generics.Collections,
  intf_dll_manager, cxVirtualTreeListHelper, cxFilter,
  cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL, cxTLdxBarBuiltInMenu,
  cxInplaceContainer, cxTLData, cxTextEdit, dxLayoutcxEditAdapters, cxContainer,
  cxEdit, cxMaskEdit, cxDropDownEdit,
  // НОВОЕ:
  intf_skin,          // ISkinAware
  uSkinManager,       // TSkinManager
  uSkinHelper,        // ApplySkinToForm / ApplySkinToDataModule
  dmSkin,             // TdmSkin DataModule
  dxSkinsForm,        // TdxSkinController
  dxLayoutLookAndFeels, // TdxLayoutLookAndFeelList
  dxSkinsdxRibbonPainter; // для корректного скининга TdxRibbon
```

**В `private` добавить:**

```pascal
private
  FDllManager: IDllManager;
  FSLog: TVTLoadAllDataSource<TVTVLog>;
  FButtons: TButtonEntryList;
  FSkinManager: TSkinManager;          // НОВОЕ
  procedure AddMsg(const AMsg: WideString);
  procedure OnButtonClick(Sender: TObject);
  procedure LoadAllDlls;
  procedure InitializeSkinSelector;     // НОВОЕ
  procedure DoSkinChanged(const ASkinName: string; ANativeStyle: Boolean);  // НОВОЕ
  procedure cmbSkinsPropertiesChange(Sender: TObject);  // НОВОЕ
```

**Реализация:**

```pascal
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FDllManager := TDllManager.Create;
  FButtons := TButtonEntryList.Create;

  // --- НОВОЕ: инициализация скинов ---
  dmSkin := TdmSkin.Create(Self);   // Self владеет, освободится автоматически
  FSkinManager := TSkinManager.Create;
  FSkinManager.LoadSettings;
  FSkinManager.OnSkinChanged := DoSkinChanged;
  InitializeSkinSelector;
  // Применяем загруженный скин к главной форме и DataModule
  DoSkinChanged(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);
  // ----------------------------------

  // Реестр кнопок: кнопка + TDLLInfo + опциональная инициализация
  FButtons.AddEntry(btnSimpleNumbers, DISimpleNumbers, nil);
  FButtons.AddEntry(btnCalcPrice,     DICalcPrice,     nil);
  FButtons.AddEntry(btnExplorer,      DIExplorer,      nil);
  FButtons.AddEntry(btnRunTasks,      DIRunTasks,      nil);
  FButtons.AddEntry(btnLogData,       DILogData,       nil);
  FButtons.AddEntry(btnCatalogParts,  DICatalogParts,  nil);

  LoadAllDlls;
  FSLog := TVTLoadAllDataSource<TVTVLog>.Create(vtlLog);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FDllManager) then
  begin
    FDllManager.UnloadAll;
    FDllManager := nil;
  end;
  FreeAndNil(FButtons);
  FreeAndNil(FSLog);
  FreeAndNil(FSkinManager);  // dmSkin освободится через владение Self
end;

procedure TfrmMain.InitializeSkinSelector;
begin
  FSkinManager.PopulateSkinList(cmbSkins);
  cmbSkins.EditValue := FSkinManager.CurrentSkin;
  cmbSkins.Properties.OnChange := cmbSkinsPropertiesChange;
end;

procedure TfrmMain.cmbSkinsPropertiesChange(Sender: TObject);
begin
  FSkinManager.CurrentSkin := VarToStr(cmbSkins.EditValue);
  FSkinManager.NativeStyle := False;
  // SetCurrentSkin внутри TSkinManager сам вызовет DoSkinChanged
end;

procedure TfrmMain.DoSkinChanged(const ASkinName: string; ANativeStyle: Boolean);
begin
  // 1. RootLookAndFeel главной формы
  RootLookAndFeel.BeginUpdate;
  try
    RootLookAndFeel.SkinName := ASkinName;
    RootLookAndFeel.NativeStyle := ANativeStyle;
    rbMain.ColorSchemeName := ASkinName;
  finally
    RootLookAndFeel.EndUpdate;
  end;

  // 2. Центральный SkinController и LayoutSkinLookAndFeel в dmSkin
  ApplySkinToDataModule(dmSkin,
    dmSkin.dxSkinController,
    dmSkin.dxLayoutSkinLookAndFeel1,
    ASkinName, ANativeStyle);

  // 3. Сохранить настройку
  FSkinManager.SaveSettings;
end;
```

**В `uMain.dfm` добавить ссылку на общий LookAndFeel для `lcMain`:**

```dfm
object lcMain: TdxLayoutControl
  Left = 0
  Top = 101
  Width = 879
  Height = 530
  Align = alClient
  TabOrder = 1
  LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1   // ← НОВОЕ
  ...
end
```

### 3.5. Модификация `OnButtonClick` — передача скина в DLL

```pascal
procedure TfrmMain.OnButtonClick(Sender: TObject);
var
  btn: TdxBarLargeButton;
  entry: TButtonEntry;
  intfRun: IDllIntfRun;
  skinAware: ISkinAware;     // НОВОЕ
  i: Integer;
begin
  btn := Sender as TdxBarLargeButton;
  entry := nil;

  for i := 0 to FButtons.Count - 1 do
    if FButtons[i].Button = btn then
    begin
      entry := FButtons[i];
      Break;
    end;

  if not Assigned(entry) then
  begin
    AddMsg('Кнопка не найдена в реестре: ' + btn.Caption);
    Exit;
  end;

  if not Supports(FDllManager.GetIntf(entry.DllInfo.guid), IDllIntfRun, intfRun) then
  begin
    AddMsg('Интерфейс IDllIntfRun не поддерживается: ' + btn.Caption);
    Exit;
  end;

  // --- НОВОЕ: передаём скин в DLL, если она поддерживает ISkinAware ---
  if Supports(intfRun, ISkinAware, skinAware) then
  begin
    skinAware.ApplySkin(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);
    FSkinManager.RegisterSubscriber(skinAware);  // для live-обновления
  end;
  // -------------------------------------------------------------------

  if Assigned(entry.InitProc) then
    entry.InitProc();

  intfRun.Run(procedure(AMsg: WideString)
  begin
    AddMsg(AMsg);
  end, Application.Handle);
end;
```

DLL, не реализующие `ISkinAware`, молча пропускаются — обратная совместимость сохраняется.

---

## 4. Скиниг `TdxLayoutControl` (центральный раздел спецификации)

### 4.1. Суть проблемы

`TdxLayoutControl` имеет **собственный** пайнтер (отрисовщик), который **не наследует** скин от `Root.LookAndFeel` или `RootLookAndFeel` формы. По умолчанию используется `StandardLookAndFeel` — серая «классическая» заливка групп.

Чтобы layout-контрол следовал скину, **необходимо**:

1. Создать объект `TdxLayoutSkinLookAndFeel` (помещённый в `TdxLayoutLookAndFeelList`).
2. Зафиксировать `LookAndFeel.NativeStyle = False` в его свойствах.
3. Назначить ссылку на этот объект в свойство `LayoutLookAndFeel` каждого `TdxLayoutControl` (через DFM или код).
4. Для глобального применения — дополнительно разместить `TdxSkinController` и синхронизировать его `SkinName` при смене скина. `TdxSkinController` автоматически применяет скин ко всем DevExpress-контролам, включая `TdxLayoutSkinLookAndFeel.LookAndFeel`.

Без пункта 4 layout будет отображать скин, но не будет реагировать на **смену** скина в рантайме (зафиксируется тот скин, который был при создании формы).

### 4.2. Образец реализации (из PartsCatalogDLL)

В `PartsCatalogDLL/Source/dmDatabase.pas` объявлены:

```pascal
TdmDB = class(TDataModule)
  ...
  dxSkinController: TdxSkinController;
  dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
  dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
end;
```

В DFM захардкожено:

```dfm
object dxSkinController: TdxSkinController
  SkinName = 'DevExpressStyle'
end
object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
  object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
    LookAndFeel.Kind = lfUltraFlat
    LookAndFeel.NativeStyle = False
  end
end
```

Все 6 форм PartsCatalog ссылаются на общий LookAndFeel:

```dfm
object lcMain: TdxLayoutControl
  LayoutLookAndFeel = dmDB.dxLayoutSkinLookAndFeel1
end
```

### 4.3. Две стратегии внедрения в остальных проектах

В зависимости от количества форм с `TdxLayoutControl` в проекте, выбирается одна из двух стратегий.

#### Стратегия A — DataModule с общим LookAndFeel (для проектов с 2+ формами или Ribbon)

Применяется к: `loader.exe`, `LogDataDLL`, `RunTasksDLL`, `PartsCatalogDLL` (уже реализовано).

**Шаги:**

1. Создать `dmSkin.pas` + `dmSkin.dfm` по образцу §3.3.
2. В DPR добавить в `uses`: `dmSkin, dxSkinsForm, dxLayoutLookAndFeels`.
3. В каждой форме с `TdxLayoutControl` добавить в DFM:
   ```dfm
   object lcMain: TdxLayoutControl
     LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1
   end
   ```
4. В `uses` каждой формы добавить `dmSkin`.
5. В `ApplySkin` (реализация `ISkinAware`) вызывать:
   ```pascal
   ApplySkinToDataModule(dmSkin,
     dmSkin.dxSkinController,
     dmSkin.dxLayoutSkinLookAndFeel1,
     ASkinName, ANativeStyle);
   ```
6. `dmSkin` должен создаваться **до** показа любой формы. Лучшее место — в методе `Init` DLL-обёртки или в первой строке `Run`.

#### Стратегия B — Локальный `TdxLayoutSkinLookAndFeel` на форме (для проектов с одной формой)

Применяется к: `ExplorerDLL`, `CalcPriceDLL`, `SimpleNumbersDLL`.

**Шаги:**

1. В `published`-секции формы добавить три невизуальных компонента:
   ```pascal
   type
     TfrmExplorer = class(TForm)
       lcExplorer: TdxLayoutControl;
       // НОВОЕ:
       dxSkinController1: TdxSkinController;
       dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
       dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
       ...
     end;
   ```
2. В DFM формы добавить эти компоненты и прописать ссылку:
   ```dfm
   object lcExplorer: TdxLayoutControl
     LayoutLookAndFeel = dxLayoutSkinLookAndFeel1
     ...
   end
   object dxSkinController1: TdxSkinController
     SkinName = 'DevExpressStyle'
   end
   object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
     object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
       LookAndFeel.NativeStyle = False
       LookAndFeel.Kind = lfUltraFlat
     end
   end
   ```
3. В DPR в `uses` добавить: `dxSkinsForm, dxLayoutLookAndFeels`.
4. В `ApplySkin` (реализация `ISkinAware`) вызывать:
   ```pascal
   ApplySkinToForm(frmExplorer, ASkinName, ANativeStyle);
   ApplySkinToDataModule(nil,  // ADM не используется
     dxSkinController1,
     dxLayoutSkinLookAndFeel1,
     ASkinName, ANativeStyle);
   ```

### 4.4. Сводная таблица стратегий по проектам

| Проект | Стратегия | DataModule | Локальные компоненты | Примечание |
|---|---|---|---|---|
| `loader.exe` | A | `dmSkin` (новый) | — | 1 layout-контрол, но DataModule для единообразия |
| `ExplorerDLL` | B | — | на форме `uExplorer` | 1 форма, без Ribbon |
| `CalcPriceDLL` | B | — | на форме `uCalcPrice` | 1 форма, без Ribbon |
| `SimpleNumbersDLL` | B | — | на форме `main` | 1 форма, без Ribbon |
| `RunTasksDLL` | A | `dmSkin` (новый) | — | 1 форма, но есть Ribbon — сложный случай |
| `LogDataDLL` | A | `dmSkin` (новый) | — | 2 формы (`uLogData` + `uConnectionParams`) |
| `PartsCatalogDLL` | A | `dmDatabase` (существ.) | — | Уже реализовано, нужна только синхронизация `dxSkinController.SkinName` |
| `RunTaskFindDLL` | — | — | — | Невизуальная, не трогать |
| `RunTaskShellExecuteDLL` | — | — | — | Невизуальная, не трогать |

---

## 5. Модификация PartsCatalogDLL

### 5.1. Удалить локальный выбор скина

Из `PartsCatalogDLL/Source/uMain.pas` **удалить:**
- Поля `cmbSkins: TcxComboBox`, `lgSkins: TdxLayoutGroup`, `liSkins: TdxLayoutItem` (в `published`-секции и в DFM).
- Метод `InitializeSkinList`.
- Обработчик `cmbSkinsPropertiesChange`.
- Вызов `InitializeSkinList` в `FormShow`.
- Из `uses`: `dxSkinNames`, `dxSkinsForm`, `dxSkinsdxRibbonPainter`, `dxLayoutLookAndFeels`, `dxLayoutPainters` (эти модули есть в `dmDatabase.pas`, форма их получит транзитивно). Также убрать `dxSkinBlack`, `dxSkinBlue`, `dxSkinOffice2007Silver`, `dxSkinOffice2010Blue` — привести к каноническому набору из 9 модулей.

### 5.2. Реализовать `ISkinAware` в форме

```pascal
unit uMain;

interface

uses
  // ... существующие uses ...
  intf_skin, uSkinHelper;  // ← НОВОЕ

type
  TfrmMain = class(TForm, ISkinAware)  // ← НОВОЕ
    // ... существующие компоненты ...
  private
    // ... существующие поля ...
  public
    class function RunForm(ACallback: TProc<WideString>;
      var AMsg: WideString;
      const ASkinName: string = '';
      ANativeStyle: Boolean = False): boolean;

    // ISkinAware
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

implementation

// ...

procedure TfrmMain.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  // 1. Синхронизируем центральный SkinController в DataModule.
  //    dxLayoutSkinLookAndFeel1 следует за ним автоматически.
  ApplySkinToDataModule(dmDB,
    dmDB.dxSkinController,
    dmDB.dxLayoutSkinLookAndFeel1,
    ASkinName, ANativeStyle);

  // 2. RootLookAndFeel формы (для неконтролируемых SkinController'ом элементов)
  ApplySkinToForm(Self, ASkinName, ANativeStyle, rbMain);
end;

class function TfrmMain.RunForm(ACallback: TProc<WideString>;
  var AMsg: WideString;
  const ASkinName: string = '';
  ANativeStyle: Boolean = False): boolean;
begin
  try
    dmDB := TdmDB.Create(nil);
    try
      frmMain := TfrmMain.Create(nil);
      try
        frmMain.FCallback := ACallback;
        // Применяем скин ДО ShowModal
        if ASkinName <> '' then
          frmMain.ApplySkin(ASkinName, ANativeStyle);
        Result := true;
        frmMain.ShowModal;
      finally
        FreeAndNil(frmMain);
      end;
    finally
      FreeAndNil(dmDB);
    end;
  except
    on E: Exception do
    begin
      Result := false;
      AMsg := E.Message;
    end;
  end;
end;

end.
```

### 5.3. Модификация `TDLLPartsCatalog`

```pascal
type
  TDLLPartsCatalog = class(TInterfacedObject, IDLLIntf, IDllIntfRun,
                            IUsesDllManager, IPartsCatalog, ISkinAware)
  private
    FDllManager: IDllManager;
    FSkinName: string;
    FNativeStyle: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // IDLLIntf
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;

    // IDllIntfRun
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;

    // IUsesDllManager
    procedure SetDllManager(AMgr: IDllManager); safecall;

    // ISkinAware
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

procedure TDLLPartsCatalog.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
  // Если форма уже создана — применить немедленно
  if Assigned(frmMain) then
    frmMain.ApplySkin(ASkinName, ANativeStyle);
end;

procedure TDLLPartsCatalog.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
var
  AMsg: WideString;
  OldHandle: HWnd;
begin
  AMsg := '';
  OldHandle := Application.Handle;
  try
    TfrmMain.RunForm(ACallbackProc, AMsg, FSkinName, FNativeStyle);
  finally
    Application.Handle := OldHandle;
  end;
end;
```

### 5.4. Дополнить DPR PartsCatalog

В `PartsCatalog.dpr` в `uses` добавить:

```pascal
intf_skin in '..\..\..\Common\intf_skin.pas',
uSkinHelper in '..\..\..\Common\uSkinHelper.pas',
uSkinManager in '..\..\..\Common\uSkinManager.pas',
dxSkinsdxRibbonPainter;   // для корректного скининга TdxRibbon
```

(`dxSkinsForm` и `dxLayoutLookAndFeels` уже подключены через `dmDatabase.pas`.)

---

## 6. Модификация остальных DLL (шаблоны)

### 6.1. Шаблон DLL со Стратегией A (DataModule) — для `LogDataDLL`, `RunTasksDLL`

**В DPR добавить в `uses`:**

```pascal
dxSkinsCore,
dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
dxSkinOffice2007Blue, dxSkinOffice2010Silver,
dxSkinOffice2013LightGray, dxSkinOffice2016Dark, dxSkinVS2010,
dxSkinsForm,
dxLayoutLookAndFeels,
dxSkinsdxRibbonPainter,   // если есть TdxRibbon (RunTasks — да, LogData — да)
intf_skin in '..\..\..\Common\intf_skin.pas',
uSkinHelper in '..\..\..\Common\uSkinHelper.pas',
uSkinManager in '..\..\..\Common\uSkinManager.pas',
dmSkin in 'dmSkin.pas' {dmSkin: TDataModule};
```

**Создать `dmSkin.pas` + `dmSkin.dfm`** по образцу §3.3.

**В классе DLL-обёртки добавить `ISkinAware`:**

```pascal
type
  TLogDataImpl = class(TInterfacedObject, IDLLIntf, IDllIntfRun,
                        IUsesDllManager, ILogData, ISkinAware)
  private
    FDllManager: IDllManager;
    FSkinName: string;
    FNativeStyle: Boolean;
  public
    // ... существующие методы ...
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

procedure TLogDataImpl.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
  // Если формы уже созданы — применить немедленно
  if Assigned(frmLogData) then
  begin
    ApplySkinToDataModule(dmSkin,
      dmSkin.dxSkinController,
      dmSkin.dxLayoutSkinLookAndFeel1,
      ASkinName, ANativeStyle);
    ApplySkinToForm(frmLogData, ASkinName, ANativeStyle, frmLogData.rbActions);
  end;
  if Assigned(frmConnectionParams) then
    ApplySkinToForm(frmConnectionParams, ASkinName, ANativeStyle);
end;

procedure TLogDataImpl.Init;
begin
  // Создаём dmSkin ДО показа любых форм
  if not Assigned(dmSkin) then
    dmSkin := TdmSkin.Create(nil);
end;

procedure TLogDataImpl.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  if not Assigned(dmSkin) then
    dmSkin := TdmSkin.Create(nil);
  // Применяем текущий скин ко всем будущим формам
  if FSkinName <> '' then
    ApplySkinToDataModule(dmSkin,
      dmSkin.dxSkinController,
      dmSkin.dxLayoutSkinLookAndFeel1,
      FSkinName, FNativeStyle);
  // Дальше — показ формы
  frmLogData := TfrmLogData.Create(nil);
  try
    if FSkinName <> '' then
      ApplySkinToForm(frmLogData, FSkinName, FNativeStyle, frmLogData.rbActions);
    frmLogData.ShowModal;
  finally
    FreeAndNil(frmLogData);
  end;
end;
```

**В DFM формы с `TdxLayoutControl` добавить ссылку:**

```dfm
object lcConnectionParams: TdxLayoutControl
  LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1
  ...
end
```

### 6.2. Шаблон DLL со Стратегией B (локальные компоненты) — для `ExplorerDLL`, `CalcPriceDLL`, `SimpleNumbersDLL`

**В DPR добавить в `uses`:**

```pascal
dxSkinsCore,
dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
dxSkinOffice2007Blue, dxSkinOffice2010Silver,
dxSkinOffice2013LightGray, dxSkinOffice2016Dark, dxSkinVS2010,
dxSkinsForm,
dxLayoutLookAndFeels,
intf_skin in '..\..\..\Common\intf_skin.pas',
uSkinHelper in '..\..\..\Common\uSkinHelper.pas',
uSkinManager in '..\..\..\Common\uSkinManager.pas';
```

**В классе формы добавить невизуальные компоненты:**

```pascal
type
  TfrmScanLocalDisks = class(TForm, ISkinAware)
    lcExplorer: TdxLayoutControl;
    // НОВОЕ: невизуальные компоненты для скининга
    dxSkinController1: TdxSkinController;
    dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
    // ... остальные ...
  public
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

procedure TfrmScanLocalDisks.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  ApplySkinToDataModule(nil,
    dxSkinController1,
    dxLayoutSkinLookAndFeel1,
    ASkinName, ANativeStyle);
  ApplySkinToForm(Self, ASkinName, ANativeStyle);
end;
```

**В DFM:**

```dfm
object lcExplorer: TdxLayoutControl
  LayoutLookAndFeel = dxLayoutSkinLookAndFeel1
  ...
end
object dxSkinController1: TdxSkinController
  SkinName = 'DevExpressStyle'
  Left = 480
  Top = 12
end
object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
  Left = 480
  Top = 68
  object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
    LookAndFeel.Kind = lfUltraFlat
    LookAndFeel.NativeStyle = False
    PixelsPerInch = 96
  end
end
```

**В классе DLL-обёртки:**

```pascal
type
  TExplorerDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun,
                        IUsesDllManager, IExplorer, ISkinAware)
  private
    FDllManager: IDllManager;
    FSkinName: string;
    FNativeStyle: Boolean;
    FE: TfrmScanLocalDisks;
    FFindIntf: IRunTaskFindInDir;
  public
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    // ...
  end;

procedure TExplorerDLL.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
  if Assigned(FE) then
    FE.ApplySkin(ASkinName, ANativeStyle);
end;

procedure TExplorerDLL.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  if not Assigned(FE) then
    FE := TfrmScanLocalDisks.Create(nil);
  if FSkinName <> '' then
    FE.ApplySkin(FSkinName, FNativeStyle);
  FE.Show;
end;
```

---

## 7. Сохранение настроек

### 7.1. JSON-файл (рекомендуемый вариант)

Файл `settings.json` размещается **рядом с `loader.exe`** — это даёт портативность: папку можно переносить между машинами без потери настроек. Не требует прав администратора (в отличие от Registry) и не привязывается к конкретной ОС/пользователю.

```json
{
  "skin_name": "Office2016Dark",
  "native_style": false
}
```

Реализация `LoadSettings` / `SaveSettings` приведена в §3.1.

### 7.2. Registry (альтернативный вариант)

Registry уместен только если приложение инсталлируется инсталлятором и настройки должны быть на уровне пользователя. Реализация:

```pascal
procedure TSkinManager.LoadSettings;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Loader\Skins') then
    begin
      FCurrentSkin := Reg.ReadString('SkinName');
      if FCurrentSkin = '' then
        FCurrentSkin := 'DevExpressStyle';
      FNativeStyle := Reg.ReadBool('NativeStyle');
      Reg.CloseKey;
    end
    else
    begin
      FCurrentSkin := 'DevExpressStyle';
      FNativeStyle := False;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TSkinManager.SaveSettings;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Software\Loader\Skins', True) then
    begin
      Reg.WriteString('SkinName', FCurrentSkin);
      Reg.WriteBool('NativeStyle', FNativeStyle);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
```

**Рекомендация:** использовать JSON (§7.1).

---

## 8. Порядок внедрения (план работ)

### Этап 0. Подготовка окружения

1. Убедиться, что репозиторий `Common/` клонирован рядом с `loader/` (структура `repo/common/` + `repo/loader/`).
2. Скомпилировать `loader.dpr` и все 8 DLL в текущем виде — это baseline.
3. Зафиксировать канонический список из 9 скин-модулей: `dxSkinsCore, dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle, dxSkinOffice2007Blue, dxSkinOffice2010Silver, dxSkinOffice2013LightGray, dxSkinOffice2016Dark, dxSkinVS2010`. Этот набор должен быть **идентичным** во всех визуальных DLL после рефакторинга.

### Этап 1. Новые файлы в `Common/`

1. Создать `Common/intf_skin.pas` с интерфейсами `ISkinAware` и `ISkinProvider` (§2.2).
2. Создать `Common/uSkinManager.pas` с классом `TSkinManager` (§3.1) — не синглтон, JSON-хранилище, явный вызов `OnSkinChanged` из сеттеров, список подписчиков `ISkinAware`.
3. Создать `Common/uSkinHelper.pas` с процедурами `ApplySkinToForm` и `ApplySkinToDataModule` (§3.2).

### Этап 2. Главное приложение `loader.exe`

1. Создать `Source/dmSkin.pas` + `Source/dmSkin.dfm` (§3.3) — DataModule с `TdxSkinController` + `TdxLayoutLookAndFeelList` + `TdxLayoutSkinLookAndFeel`.
2. В `loader.dpr` добавить в `uses`: `dmSkin, intf_skin, uSkinManager, uSkinHelper, dxSkinsForm, dxLayoutLookAndFeels, dxSkinsdxRibbonPainter`.
3. В `Source/uMain.pas`:
   - Добавить в `uses`: `intf_skin, uSkinManager, uSkinHelper, dmSkin, dxSkinsForm, dxLayoutLookAndFeels, dxSkinsdxRibbonPainter`.
   - В `private` добавить `FSkinManager`, методы `InitializeSkinSelector`, `DoSkinChanged`, `cmbSkinsPropertiesChange`.
   - В `FormCreate` — инициализация `dmSkin` + `FSkinManager`, вызов `DoSkinChanged` с загруженным скином.
   - В `FormDestroy` — освобождение `FSkinManager`.
   - Модифицировать `OnButtonClick` — вызов `ISkinAware.ApplySkin` и `RegisterSubscriber`.
4. В `Source/uMain.dfm` — добавить `LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1` к `lcMain`.
5. Проверить: скин меняется в главной форме, `TdxLayoutControl` и Ribbon корректно скинится, выбор сохраняется в `settings.json`.

### Этап 3. Рефакторинг PartsCatalogDLL

1. Удалить из `uMain.pas`: `cmbSkins`, `lgSkins`, `liSkins`, методы `InitializeSkinList`, `cmbSkinsPropertiesChange`. Также удалить эти объекты из DFM.
2. Удалить из `uses` формы: `dxSkinNames`, `dxSkinsForm`, `dxSkinsdxRibbonPainter`, `dxLayoutLookAndFeels`, `dxLayoutPainters`, лишние `dxSkin*` модули.
3. Добавить `ISkinAware` в класс `TfrmMain`, реализовать `ApplySkin` (§5.2) с вызовом `ApplySkinToDataModule` для `dmDB.dxSkinController` и `dmDB.dxLayoutSkinLookAndFeel1`.
4. Модифицировать `RunForm` — приём параметров `ASkinName` + `ANativeStyle`, применение скина до `ShowModal`.
5. В `PartsCatalog.dpr` добавить `ISkinAware` в объявление класса `TDLLPartsCatalog`, поля `FSkinName` + `FNativeStyle`, реализацию `ApplySkin`. Передать скин в `RunForm`.
6. В DPR добавить в `uses`: `intf_skin, uSkinHelper, uSkinManager, dxSkinsdxRibbonPainter`.
7. Проверить: PartsCatalogDLL запускается со скином из `loader.exe`, локального комбобокса скинов нет, все 6 форм в одном скине.

### Этап 4. DLL со Стратегией A (DataModule) — `LogDataDLL`, `RunTasksDLL`

Для каждой DLL:

1. Создать `dmSkin.pas` + `dmSkin.dfm` по образцу §3.3.
2. В DPR добавить в `uses`: `dmSkin`, `dxSkinsForm`, `dxLayoutLookAndFeels`, `dxSkinsdxRibbonPainter` (для Ribbon), `intf_skin`, `uSkinHelper`, `uSkinManager`, + канонический набор `dxSkin*`.
3. В класс DLL-обёртки добавить `ISkinAware`, поля `FSkinName` + `FNativeStyle`, метод `ApplySkin`.
4. В `Init` или в начале `Run` — создать `dmSkin`.
5. В `ApplySkin` — синхронизировать `dmSkin.dxSkinController.SkinName` через `ApplySkinToDataModule`, применить скин к каждой существующей форме через `ApplySkinToForm`.
6. В DFM всех форм с `TdxLayoutControl` — добавить `LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel1`.
7. В `uses` форм добавить `dmSkin`.
8. Тестировать: открыть DLL, проверить, что layout и Ribbon (если есть) в выбранном скине.

### Этап 5. DLL со Стратегией B (локальные компоненты) — `ExplorerDLL`, `CalcPriceDLL`, `SimpleNumbersDLL`

Для каждой DLL:

1. В форму добавить невизуальные компоненты: `dxSkinController1`, `dxLayoutLookAndFeelList1`, `dxLayoutSkinLookAndFeel1` (с `LookAndFeel.NativeStyle = False`).
2. В DFM формы к `TdxLayoutControl` добавить `LayoutLookAndFeel = dxLayoutSkinLookAndFeel1`.
3. В DPR добавить в `uses`: `dxSkinsForm`, `dxLayoutLookAndFeels`, `intf_skin`, `uSkinHelper`, `uSkinManager`, + канонический набор `dxSkin*`.
4. В класс DLL-обёртки добавить `ISkinAware`, поля `FSkinName` + `FNativeStyle`, метод `ApplySkin`.
5. В `ApplySkin` — вызвать `ApplySkinToDataModule(nil, dxSkinController1, dxLayoutSkinLookAndFeel1, ...)` и `ApplySkinToForm(Self, ...)`.
6. В `Run` — применить скин к форме до показа.
7. Тестировать.

### Этап 6. Невизуальные DLL — без изменений

`RunTaskFindDLL` и `RunTaskShellExecuteDLL` не трогать. `ISkinAware` в них не реализуется.

### Этап 7. Очистка

1. Проверить идентичность наборов `dxSkin*` в `loader.dpr` и во всех 5 визуальных DLL + `PartsCatalog.dpr`.
2. Убедиться, что из `PartsCatalogDLL/Source/uMain.pas` удалены модули, нужные только для `dmDatabase.pas`.
3. Проверить, что `dxSkinController.SkinName` не захардкожен в DFM-файлах в значениях, отличных от `'DevExpressStyle'` (значение по умолчанию — норма, оно будет перезаписано в рантайме).

### Этап 8. Опциональные улучшения

1. **Live-обновление открытых форм DLL** — `TSkinManager.RegisterSubscriber` при открытии DLL, `UnregisterSubscriber` при закрытии. Реализовано в `TSkinManager` через `FSubscribers: TList<ISkinAware>`. Для модальных форм не критично (они открываются с актуальным скином).
2. **Бонусная чистка** — битая кириллица в `GetDescription` (`'Óïðàâëåíèå...'`) в `LogData.dpr`, `CalcPrice.dpr`, `SimpleNumbers.dpr`, `PartsCatalog.dpr`. Привести файлы к UTF-8 with BOM. Не связано со скинами.

---

## 9. Технические замечания

### 9.1. Модули скинов в DPR

В **`loader.exe`** DPR должен содержать все используемые модули скинов:

```pascal
uses
  // ...
  dxSkinsCore,
  dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinOffice2016Dark, dxSkinVS2010,
  dxSkinsForm,                // TdxSkinController
  dxSkinsdxRibbonPainter;     // для TdxRibbon
```

**Все визуальные DLL** должны содержать **идентичный** набор `dxSkin*` + `dxSkinsForm` + `dxLayoutLookAndFeels` (для Стратегии A — также `dmSkin`).

DLL **не должны** дублировать `dxSkinsdxRibbonPainter` если у них нет Ribbon.

### 9.2. `dxInitialize` / `dxFinalize`

Каждая DLL уже вызывает `dxCore.dxInitialize` / `dxCore.dxFinalize`. Это корректно — DevExpress корректно работает в DLL при правильной паре Initialize/Finalize.

### 9.3. `RootLookAndFeel` vs `TdxSkinController`

- **`TdxSkinController`** — предпочтительный способ для DLL и главного приложения. Глобально применяет скин ко всем DevExpress-контролам, включая `TdxLayoutSkinLookAndFeel.LookAndFeel`. Достаточно обновить `dxSkinController.SkinName` — и форма, и layout, и контролы обновятся.
- **`RootLookAndFeel` формы** — дополнительно страховка для контролов, не охваченных `TdxSkinController` (редкие случаи). Рекомендуется вызывать `ApplySkinToForm` всегда, параллельно с `ApplySkinToDataModule`.
- **`dxSkinsUserSkinLoadBitmap`** — если используются пользовательские скины (загружаемые из `.skinres`), нужно вызвать перед назначением `SkinName`.

### 9.4. Потокобезопасность

- `cxLookAndFeelPaintersManager.PopulateSkinNames` вызывается только в главном потоке (`FormCreate`) — это безопасно.
- `TSkinManager.SetCurrentSkin` также вызывается только в главном потоке (из обработчика `OnChange` комбобокса) — синхронизация не требуется.
- Если скин будет меняться из фонового потока (например, из callback'а DLL), нужно добавить `TThread.Synchronize` или `TThread.Queue` в `SetCurrentSkin`.

### 9.5. Жизненный цикл `dmSkin` в DLL

`dmSkin` должен создаваться **до** показа любой формы DLL. Лучшее место — в методе `Init` класса DLL-обёртки (если есть) или в первой строке `Run`. Освобождается `dmSkin` в `Fin` или в `Destroy` класса-обёртки.

Если `dmSkin` создаётся в `Run`, а форма показывается через `ShowModal`, после закрытия формы `dmSkin` нужно освобождать, иначе при повторном открытии DLL будет создан второй экземпляр. Альтернатива — глобальная переменная с проверкой `if not Assigned(dmSkin) then dmSkin := TdmSkin.Create(nil);`.

### 9.6. Идентичность наборов `dxSkin*`

**Критическое требование:** набор `dxSkin*` модулей в DPR должен быть **строго идентичен** между `loader.exe` и всеми DLL. Если в DLL отсутствует какой-то модуль скина, при переключении на этот скин в `loader.exe` DLL молча откатится на `DevExpressStyle` — пользователь увидит рассинхронизацию.

### 9.7. `dxLayoutSkinLookAndFeel1.LookAndFeel.NativeStyle`

Должно быть `False` в DFM. Если `True` — скин игнорируется, layout рендерится в нативном стиле Windows. За этим нужно следить при создании новых форм.

---

## 10. Сценарии приёмки

| № | Сценарий | Ожидаемый результат |
|---|---|---|
| 1 | Запуск `loader.exe` → скин из `settings.json` применён к главной форме, Ribbon и `TdxLayoutControl` | ✅ |
| 2 | Смена скина в `cmbSkins` → мгновенное обновление главной формы + Ribbon + layout + `TdxRibbon`, запись в `settings.json` | ✅ |
| 3 | Перезапуск `loader.exe` → выбранный скин восстанавливается | ✅ |
| 4 | Открытие PartsCatalog → главная форма + все 5 диалогов в выбранном скине, локального `cmbSkins` в PartsCatalog нет | ✅ |
| 5 | Открытие Explorer → `TdxLayoutControl` (`lcExplorer`) и все вложенные группы в выбранном скине | ✅ |
| 6 | Открытие CalcPrice → `TdxLayoutControl` (`lcCalcPrice`) в выбранном скине | ✅ |
| 7 | Открытие RunTasks → и `TdxRibbon`, и `TdxLayoutControl` (`lcRunTasks`) в одном скине | ✅ |
| 8 | Открытие SimpleNumbers → `TdxLayoutControl` (`lcMain`) в выбранном скине | ✅ |
| 9 | Открытие LogData → главная форма с Ribbon + диалог `uConnectionParams` с `TdxLayoutControl` — оба в одном скине | ✅ |
| 10 | DLL, не реализующая `ISkinAware` (например, в процессе миграции) → не падает, работает со скином по умолчанию | ✅ (через `Supports`) |
| 11 | Открыть PartsCatalog, сменить скин в `loader.exe` → PartsCatalog обновляется на лету (если реализован список подписчиков) | ⚠️ опционально |
| 12 | `dxLayoutSkinLookAndFeel1.LookAndFeel.NativeStyle = True` (ошибка в DFM) → layout остаётся серым, тест падает | ❌ ожидаемо, проверить и исправить |

---

## 11. Результат

| Было | Стало |
|------|-------|
| Скин выбирается в каждой DLL отдельно | Скин выбирается один раз в `loader.exe` |
| PartsCatalogDLL имеет свой список скинов | Все DLL получают скин через `ISkinAware` |
| Настройки не сохраняются | Скин сохраняется в `settings.json` рядом с `loader.exe` |
| 6 DLL без управления скинами | Все 8 DLL (6 визуальных + PartsCatalog) поддерживают единый скин |
| Дублирование кода выбора скина | Один `TSkinManager` в `loader.exe` |
| `RootLookAndFeel` не синхронизирован | Все формы используют один скин через `TdxSkinController` |
| **`TdxLayoutControl` рендерится стандартным отрисовщиком в 6 формах** | **Все `TdxLayoutControl` используют `TdxLayoutSkinLookAndFeel`** |
| **Нет `TdxSkinController` нигде, кроме PartsCatalog** | **`TdxSkinController` в `loader.exe` и во всех визуальных DLL** |
| Скин не применяется к открытым немодальным формам DLL | (Опционально) Live-обновление через подписчиков `ISkinAware` |
