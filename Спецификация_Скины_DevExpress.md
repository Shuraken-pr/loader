# Спецификация: Единый механизм скинов DevExpress для проекта Loader

## 1. Анализ текущего состояния

### 1.1. Архитектура приложения

```
loader.exe (основное приложение)
├── TDllManager — загружает DLL-плагины по интерфейсам
├── Главная форма TfrmMain (dxRibbon + dxBarManager)
└── DLL-плагины (8 штук):
    ├── SimpleNumbers.dll
    ├── CalcPrice.dll
    ├── Explorer.dll
    ├── RunTasks.dll
    ├── LogData.dll
    ├── RunTaskFind.dll
    ├── RunTaskShellExecute.dll
    └── PartsCatalog.dll  ← единственный с выбором скина
```

### 1.2. Как сейчас работают скины

**PartsCatalogDLL** (`loader\PartsCatalogDLL\Source\uMain.pas`):

```pascal
// Список скинов заполняется локально
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
    // Устанавливаем текущий скин
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

**Используемые модули скинов в PartsCatalogDLL:**
```pascal
uses
  dxSkinsCore, dxSkinBasic, dxSkinBlack, dxSkinBlue,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2007Silver, dxSkinOffice2010Blue,
  dxSkinOffice2010Silver, dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark, dxSkinVS2010, dxSkinsForm, dxSkinsdxRibbonPainter;
```

### 1.3. Проблемы текущего подхода

| Проблема | Описание |
|----------|----------|
| **Фрагментация** | Скины выбираются только в PartsCatalogDLL; остальные 7 DLL живут со скином по умолчанию |
| **Отсутствие единообразия** | Каждая DLL имеет свой `RootLookAndFeel` — переключение в одной не влияет на другие |
| **Дублирование кода** | Если добавить выбор скина в каждую DLL — код `InitializeSkinList` и `cmbSkinsPropertiesChange` дублируется 8 раз |
| **Нет централизации** | Главное приложение не знает о скинах и не управляет ими |
| **Сохранение настроек** | Выбранный скин не сохраняется между запусками; при перезапуске PartsCatalogDLL сбрасывается на `'DevExpressStyle'` |
| **Синхронизация Ribbon** | `rbMain.ColorSchemeName` синхронизируется вручную — легко забыть при добавлении новых форм |

---

## 2. Целевая архитектура

### 2.1. Принцип: «Один скин — все DLL»

Главная форма `loader.exe` становится **единственным источником истины** для скина. При запуске любой DLL выбранный скин передаётся внутрь.

```
┌─────────────────────────────────────────┐
│  loader.exe (TfrmMain)                  │
│  ├─ dxSkinSelector: TcxComboBox         │
│  ├─ FCurrentSkin: string                │
│  ├─ FSkinManager: ISkinManager          │
│  └─ Настройки в Registry/JSON           │
└─────────────────────────────────────────┘
                    │
                    ▼ при Run()
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌────────────┐
│Explorer│    │LogData   │    │PartsCatalog│
│  .dll  │    │  .dll    │    │   .dll     │
└────────┘    └──────────┘    └────────────┘
```

### 2.2. Новый интерфейс `ISkinAware`

Добавить в `Common\intf_dll.pas` (или новый `intf_skin.pas`):

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

### 2.3. Модификация интерфейса запуска

В `intf_dll.pas` расширить `IDllIntfRun` (или добавить новый интерфейс):

```pascal
type
  IDllIntfRun = interface(IDLLIntf)
    ['{B3753E4F-F00D-416C-97E5-9BF72E5F251D}']
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
    /// <summary>
    /// Передать параметры визуализации в DLL. Вызывается до Run().
    /// </summary>
    procedure SetVisualParams(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;
```

**Альтернатива** (если не хотим ломать существующие интерфейсы): создать отдельный интерфейс `IDllIntfRunEx`, наследующий `IDllIntfRun`.

---

## 3. Компоненты системы

### 3.1. `TSkinManager` (новый класс в Common или loader)

```pascal
unit uSkinManager;

interface

uses
  System.Classes, System.SysUtils, cxLookAndFeels, dxSkinsCore;

type
  TSkinManager = class
  private
    FCurrentSkin: string;
    FNativeStyle: Boolean;
    FOnSkinChanged: TProc<string, Boolean>;
    procedure SetCurrentSkin(const Value: string);
    procedure SetNativeStyle(const Value: Boolean);
  public
    constructor Create;
    /// <summary>Загрузить скин из настроек (Registry/JSON)</summary>
    procedure LoadSettings;
    /// <summary>Сохранить скин в настройки</summary>
    procedure SaveSettings;
    /// <summary>Заполнить комбобокс списком скинов</summary>
    procedure PopulateSkinList(AComboBox: TcxComboBox);
    /// <summary>Применить скин к RootLookAndFeel главной формы</summary>
    procedure ApplyToMainForm(ARootLookAndFeel: TcxLookAndFeel);

    property CurrentSkin: string read FCurrentSkin write SetCurrentSkin;
    property NativeStyle: Boolean read FNativeStyle write SetNativeStyle;
    property OnSkinChanged: TProc<string, Boolean> read FOnSkinChanged write FOnSkinChanged;
  end;

  /// <summary>
  /// Глобальный доступ к менеджеру скинов.
  /// Создаётся в TfrmMain.FormCreate, освобождается в FormDestroy.
  /// </summary>
function SkinManager: TSkinManager;

implementation

// Реализация синглтона...

end.
```

### 3.2. Модификация `TfrmMain` (loader\Source\uMain.pas)

**Добавить в секцию published:**
```pascal
  cmbSkinSelector: TcxComboBox;  // или TdxBarCombo — в Ribbon
  btnApplySkin: TdxBarLargeButton;
```

**Добавить в private:**
```pascal
  FSkinManager: TSkinManager;
  procedure InitializeSkinSelector;
  procedure OnSkinChanged(const ASkinName: string; ANativeStyle: Boolean);
```

**Реализация:**
```pascal
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FDllManager := TDllManager.Create;
  FButtons := TButtonEntryList.Create;

  // Инициализация менеджера скинов
  FSkinManager := TSkinManager.Create;
  FSkinManager.LoadSettings;
  FSkinManager.OnSkinChanged := OnSkinChanged;
  InitializeSkinSelector;
  FSkinManager.ApplyToMainForm(RootLookAndFeel);

  // Реестр кнопок...
  FButtons.AddEntry(btnSimpleNumbers, DISimpleNumbers, nil);
  // ...

  LoadAllDlls;
  FSLog := TVTLoadAllDataSource<TVTVLog>.Create(vtlLog);
end;

procedure TfrmMain.InitializeSkinSelector;
begin
  FSkinManager.PopulateSkinList(cmbSkinSelector);
  cmbSkinSelector.EditValue := FSkinManager.CurrentSkin;
  cmbSkinSelector.Properties.OnChange := procedure(Sender: TObject)
    begin
      FSkinManager.CurrentSkin := VarToStr(cmbSkinSelector.EditValue);
      FSkinManager.NativeStyle := False;
      FSkinManager.ApplyToMainForm(RootLookAndFeel);
      // Синхронизация Ribbon
      rbMain.ColorSchemeName := FSkinManager.CurrentSkin;
    end;
end;

procedure TfrmMain.OnSkinChanged(const ASkinName: string; ANativeStyle: Boolean);
begin
  // Применить скин к главной форме
  RootLookAndFeel.BeginUpdate;
  try
    RootLookAndFeel.SkinName := ASkinName;
    RootLookAndFeel.NativeStyle := ANativeStyle;
    rbMain.ColorSchemeName := ASkinName;
  finally
    RootLookAndFeel.EndUpdate;
  end;
  FSkinManager.SaveSettings;
end;
```

### 3.3. Модификация `OnButtonClick` — передача скина в DLL

```pascal
procedure TfrmMain.OnButtonClick(Sender: TObject);
var
  btn: TdxBarLargeButton;
  entry: TButtonEntry;
  intfRun: IDllIntfRun;
  skinAware: ISkinAware;
  i: Integer;
begin
  btn := Sender as TdxBarLargeButton;
  entry := nil;

  // Найти запись реестра по кнопке
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

  // --- НОВОЕ: Передача скина в DLL ---
  if Supports(intfRun, ISkinAware, skinAware) then
  begin
    skinAware.ApplySkin(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);
  end;
  // Альтернатива через SetVisualParams (если расширяем IDllIntfRun):
  // intfRun.SetVisualParams(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);

  // Опциональная инициализация
  if Assigned(entry.InitProc) then
    entry.InitProc();

  // Запуск
  intfRun.Run(procedure(AMsg: WideString)
  begin
    AddMsg(AMsg);
  end, Application.Handle);
end;
```

---

## 4. Модификация PartsCatalogDLL

### 4.1. Удалить локальный выбор скина

Из `uMain.pas` PartsCatalogDLL **удалить:**
- Поле `cmbSkins: TcxComboBox`
- Группу `lgSkins: TdxLayoutGroup`
- Метод `InitializeSkinList`
- Обработчик `cmbSkinsPropertiesChange`
- Использование `dxSkinNames`, `dxSkinsForm` и модулей конкретных скинов (перенести в DPR или убрать)

### 4.2. Реализовать `ISkinAware`

```pascal
unit uMain;

interface

uses
  // ... существующие uses ...
  intf_skin;  // ← новый интерфейс

type
  TfrmMain = class(TForm, ISkinAware)  // ← реализуем интерфейс
    // ... существующие компоненты ...
  private
    // ... существующие поля ...
  public
    class function RunForm(ACallback: TProc<WideString>; var AMsg: WideString): boolean;
    // ISkinAware
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

implementation

// ... существующий код ...

procedure TfrmMain.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  RootLookAndFeel.BeginUpdate;
  try
    RootLookAndFeel.SkinName := ASkinName;
    RootLookAndFeel.NativeStyle := ANativeStyle;
    if Assigned(rbMain) then
      rbMain.ColorSchemeName := ASkinName;
  finally
    RootLookAndFeel.EndUpdate;
  end;
end;

end.
```

### 4.3. Модификация `TDLLPartsCatalog`

```pascal
type
  TDLLPartsCatalog = class(TInterfacedObject, IDLLIntf, IDllIntfRun,
                            IUsesDllManager, IPartsCatalog, ISkinAware)
  private
    FDllManager: IDllManager;
    FSkinName: string;
    FNativeStyle: Boolean;
  public
    // ... существующие методы ...
    // ISkinAware
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
  end;

procedure TDLLPartsCatalog.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
  // Если форма уже создана — применить сразу
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
    // Применяем скин ПЕРЕД показом формы
    TfrmMain.RunForm(ACallbackProc, AMsg, FSkinName, FNativeStyle);
  finally
    Application.Handle := OldHandle;
  end;
end;
```

**Модификация `TfrmMain.RunForm`:**
```pascal
class function TfrmMain.RunForm(ACallback: TProc<WideString>;
  var AMsg: WideString; const ASkinName: string = ''; ANativeStyle: Boolean = False): boolean;
begin
  try
    dmDB := TdmDB.Create(nil);
    try
      frmMain := TfrmMain.Create(nil);
      try
        frmMain.FCallback := ACallback;
        // Применяем скин до ShowModal
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
```

---

## 5. Модификация остальных DLL (шаблон)

Для каждой DLL, использующей DevExpress (Explorer, LogData, CalcPrice, RunTasks, SimpleNumbers):

### 5.1. Минимальные изменения

**В DPR-файле DLL:**
```pascal
type
  TYourDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, ISkinAware)
  private
    FSkinName: string;
    FNativeStyle: Boolean;
    // ...
  public
    // ISkinAware
    procedure ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean); safecall;
    // ...
  end;

procedure TYourDLL.ApplySkin(const ASkinName: WideString; ANativeStyle: Boolean);
begin
  FSkinName := ASkinName;
  FNativeStyle := ANativeStyle;
end;

procedure TYourDLL.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin
  Application.Handle := MainAppHandle;
  // Применяем скин к форме перед показом
  if FSkinName <> '' then
  begin
    RootLookAndFeel.SkinName := FSkinName;
    RootLookAndFeel.NativeStyle := FNativeStyle;
  end;
  FYourForm.Show;
end;
```

### 5.2. Альтернатива: общий хелпер

Создать `Common\uSkinHelper.pas`:

```pascal
unit uSkinHelper;

interface

uses
  cxLookAndFeels;

procedure ApplySkinToForm(AForm: TForm; const ASkinName: string; ANativeStyle: Boolean);

implementation

procedure ApplySkinToForm(AForm: TForm; const ASkinName: string; ANativeStyle: Boolean);
begin
  if ASkinName = '' then Exit;
  AForm.RootLookAndFeel.BeginUpdate;
  try
    AForm.RootLookAndFeel.SkinName := ASkinName;
    AForm.RootLookAndFeel.NativeStyle := ANativeStyle;
  finally
    AForm.RootLookAndFeel.EndUpdate;
  end;
end;

end.
```

---

## 6. Сохранение настроек

### 6.1. Registry (простой вариант)

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

### 6.2. JSON-файл (без Registry)

```pascal
uses
  System.JSON, System.IOUtils;

procedure TSkinManager.LoadSettings;
var
  JSON: TJSONObject;
  FileName: string;
begin
  FileName := TPath.Combine(TPath.GetDocumentsPath, 'loader_config.json');
  if not TFile.Exists(FileName) then
  begin
    FCurrentSkin := 'DevExpressStyle';
    FNativeStyle := False;
    Exit;
  end;

  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
  try
    FCurrentSkin := JSON.GetValue('skin_name', 'DevExpressStyle').Value;
    FNativeStyle := JSON.GetValue('native_style', False).AsType<Boolean>;
  finally
    JSON.Free;
  end;
end;
```

---

## 7. Порядок внедрения (план работ)

### Этап 1: Подготовка (без риска)
1. Создать `Common\intf_skin.pas` с интерфейсом `ISkinAware`
2. Создать `Common\uSkinManager.pas` с классом `TSkinManager`
3. Добавить uses в `loader.dpr`

### Этап 2: Главное приложение
1. В `TfrmMain` добавить `FSkinManager` и селектор скина
2. Добавить `InitializeSkinSelector`
3. Модифицировать `OnButtonClick` для вызова `ISkinAware.ApplySkin`
4. Проверить: скин меняется в главной форме, сохраняется в настройки

### Этап 3: PartsCatalogDLL (рефакторинг)
1. Удалить локальный `cmbSkins` и `InitializeSkinList`
2. Реализовать `ISkinAware` в `TDLLPartsCatalog`
3. Модифицировать `RunForm` для приёма параметров скина
4. Проверить: PartsCatalogDLL запускается со скином из loader.exe

### Этап 4: Остальные DLL (по одной)
Для каждой DLL (Explorer, LogData, CalcPrice, RunTasks, SimpleNumbers):
1. Добавить `ISkinAware` в класс-реализацию
2. В `Run` применить скин к форме
3. Тестировать

### Этап 5: Очистка
1. Убрать дублирующие модули скинов из PartsCatalogDLL (оставить только в loader.exe)
2. Проверить, что все DLL используют один набор `dxSkin*.pas`

---

## 8. Технические замечания

### 8.1. Модули скинов в DPR

В **loader.exe** DPR должен содержать все используемые модули скинов:
```pascal
uses
  // ...
  dxSkinsCore,
  dxSkinBasic, dxSkinBlack, dxSkinBlue,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2007Silver,
  dxSkinOffice2010Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinOffice2016Dark,
  dxSkinVS2010,
  dxSkinsdxRibbonPainter;
```

DLL **не должны** дублировать эти модули в своих DPR (иначе возможны конфликты при загрузке).

### 8.2. dxInitialize / dxFinalize

Каждая DLL уже вызывает `dxCore.dxInitialize` / `dxCore.dxFinalize`. Это корректно — DevExpress корректно работает в DLL при правильной паре Initialize/Finalize.

### 8.3. RootLookAndFeel vs Application.DefaultLookAndFeel

- `RootLookAndFeel` (на уровне формы) — предпочтительнее для DLL, так как изолирован
- `dxSkinsUserSkinLoadBitmap` — если используются пользовательские скины

### 8.4. Потокобезопасность

`cxLookAndFeelPaintersManager.PopulateSkinNames` вызывается только в главном потоке (FormCreate) — это безопасно.

---

## 9. Результат

| Было | Стало |
|------|-------|
| Скин выбирается в каждой DLL отдельно | Скин выбирается один раз в loader.exe |
| PartsCatalogDLL имеет свой список скинов | Все DLL получают скин через `ISkinAware` |
| Настройки не сохраняются | Скин сохраняется в Registry/JSON |
| 7 DLL без управления скинами | Все 8 DLL поддерживают единый скин |
| Дублирование кода выбора скина | Один `TSkinManager` в loader.exe |
| RootLookAndFeel не синхронизирован | Все формы используют один скин |
