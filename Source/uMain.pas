unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxCore, dxRibbonSkins, dxRibbonCustomizationForm,
  System.Actions, Vcl.ActnList, System.ImageList, Vcl.ImgList, cxImageList,
  dxLayoutContainer, dxLayoutControl, cxClasses, dxBar, dxRibbon,
  DllManager, intf_dll, intf_common, System.Generics.Collections,
  intf_dll_manager, cxVirtualTreeListHelper, cxFilter,
  cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL, cxTLdxBarBuiltInMenu,
  cxInplaceContainer, cxTLData, cxTextEdit, dxLayoutcxEditAdapters, cxContainer,
  cxEdit, cxMaskEdit, cxDropDownEdit, dxSkinsCore, dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle, dxSkinOffice2007Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinVS2010,
  intf_skin,          // ISkinAware
  uSkinManager,       // TSkinManager
  uSkinHelper,        // ApplySkinToForm / ApplySkinToDataModule
  dmSkins,             // TdmSkin DataModule
  dxSkinsForm,        // TdxSkinController
  dxLayoutLookAndFeels, // TdxLayoutLookAndFeelList
  dxSkinsdxRibbonPainter; // для корректного скининга TdxRibbon


type
  /// <summary>
  /// Связь кнопки с DLL: кнопка, описание DLL, опциональная доп. инициализация.
  /// </summary>
  TButtonEntry = class
    Button: TdxBarLargeButton;
    DllInfo: TDLLInfo;
    // Опциональная процедура инициализации зависимостей перед Run().
    // Если nil — зависимости загружены автоматически через IUsesDllManager.
    InitProc: TProc;
  end;

  TButtonEntryList = class(TObjectList<TButtonEntry>)
    procedure AddEntry(Button: TdxBarLargeButton; DllInfo: TDLLInfo; InitProc: TProc);
  end;

  TVTVLog = class(TVTBaseRecord)
  private
    FMsg: WideString;
    FLogDate: TDateTime;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    { Сохраняет значение для указанного индекса колонки. }
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    property LogDate: TDateTime read FLogDate write FLogDate;
    property Msg: WideString read FMsg write FMsg;
  end;

  TfrmMain = class(TForm)
    rbMain: TdxRibbon;
    bmMain: TdxBarManager;
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    ilBig: TcxImageList;
    ilSmall: TcxImageList;
    alMain: TActionList;
    rbMainTab1: TdxRibbonTab;
    bInterfaces: TdxBar;
    btnSimpleNumbers: TdxBarLargeButton;
    btnCalcPrice: TdxBarLargeButton;
    btnExplorer: TdxBarLargeButton;
    btnRunTasks: TdxBarLargeButton;
    btnLogData: TdxBarLargeButton;
    btnCatalogParts: TdxBarLargeButton;
    vtlLog: TcxVirtualTreeList;
    liLog: TdxLayoutItem;
    colDate: TcxTreeListColumn;
    colMsg: TcxTreeListColumn;
    cmbSkins: TcxComboBox;
    liSkins: TdxLayoutItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FDllManager: IDllManager;
    FSLog: TVTLoadAllDataSource<TVTVLog>;
    FButtons: TButtonEntryList;
    FSkinManager: TSkinManager;          // НОВОЕ
    procedure InitializeSkinSelector;     // НОВОЕ
    procedure DoSkinChanged(ASkinName: string; ANativeStyle: Boolean);  // НОВОЕ
    procedure cmbSkinsPropertiesChange(Sender: TObject);  // НОВОЕ
    procedure AddMsg(const AMsg: WideString);
    procedure OnButtonClick(Sender: TObject);
    procedure LoadAllDlls;
  public
  end;

var
  frmMain: TfrmMain;

implementation

uses
  intf_tasks, System.Math;

{$R *.dfm}

{ TVTVLog }

constructor TVTVLog.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FLogDate := Now;
  FMsg := '';
end;

function TVTVLog.GetValue(ColIdx: Integer): Variant;
begin
  Result := null;
  case ColIdx of
    0: Result := FLogDate;
    1: Result := FMsg;
  end;
end;

procedure TVTVLog.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  case ColIdx of
    0: FLogDate := AValue;
    1: FMsg := AValue;
  end;
end;

{ TfrmMain }

procedure TfrmMain.AddMsg(const AMsg: WideString);
var
  log: TVTVLog;
begin
  log := FSLog.InsertRecordHandle(FSLog.RootHandle, true);
  if Assigned(log) then
  begin
    log.Msg := AMsg;
    FSLog.DataChanged;
  end;
end;

/// <summary>
/// Единый обработчик для всех кнопок.
/// Получает интерфейс через IDllIntfRun.Run(callback, Handle).
/// </summary>
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

  // Найти запись реестра по кнопке
  for i := 0 to FButtons.Count - 1 do
  begin
    if FButtons[i].Button = btn then
    begin
      entry := FButtons[i];
      Break;
    end;
  end;

  if not Assigned(entry) then
  begin
    AddMsg('Кнопка не найдена в реестре: ' + btn.Caption);
    Exit;
  end;

  // Получить интерфейс IDllIntfRun из DllManager
  if not Supports(FDllManager.GetIntf(entry.DllInfo.guid), IDllIntfRun, intfRun) then
  begin
    AddMsg('Интерфейс IDllIntfRun не поддерживается: ' + btn.Caption);
    Exit;
  end;

  if Supports(intfRun, ISkinAware, skinAware) then
  begin
    skinAware.ApplySkin(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);
    FSkinManager.RegisterSubscriber(skinAware);  // для live-обновления
  end;

  // Опциональная инициализация (для обратной совместимости)
  if Assigned(entry.InitProc) then
    entry.InitProc();

  // Запуск
  intfRun.Run(procedure(AMsg: WideString)
  begin
    AddMsg(AMsg);
  end, Application.Handle);
end;

/// <summary>
/// Загрузить все DLL и привязать кнопки к единому обработчику.
/// </summary>
procedure TfrmMain.LoadAllDlls;
var
  i: Integer;
  entry: TButtonEntry;
  baseIntf: IDllIntf;
begin
  for i := 0 to FButtons.Count - 1 do
  begin
    entry := FButtons[i];

    // Скрыть кнопку до успешной загрузки
    entry.Button.Visible := ivNever;

    // Загрузить DLL (автоматически вызовет SetDllManager если IUsesDllManager)
    FDllManager.Load(entry.DllInfo, False);

    if FDllManager.IsLoaded(entry.DllInfo.intfName) then
    begin
      // Получить описание и обновить кнопку
      if Supports(FDllManager.GetIntf(entry.DllInfo.guid), IDllIntf, baseIntf) then
      begin
        entry.Button.Caption := baseIntf.GetDescription;
      end;
      entry.Button.Visible := ivAlways;
      entry.Button.OnClick := OnButtonClick;  // единый обработчик
    end
    else
    begin
      AddMsg('Не удалось загрузить: ' + entry.DllInfo.FileName);
    end;
  end;
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

procedure TfrmMain.DoSkinChanged(ASkinName: string;
  ANativeStyle: Boolean);
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
    dmSkin.dxLayoutSkinLookAndFeel,
    ASkinName, ANativeStyle);

  // 3. Сохранить настройку
  FSkinManager.SaveSettings;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FDllManager := TDllManager.Create;
  FButtons := TButtonEntryList.Create;

  dmSkin := TdmSkin.Create(Self);   // Self владеет, освободится автоматически
  FSkinManager := TSkinManager.Create;
  FSkinManager.LoadSettings;
  FSkinManager.OnSkinChanged := DoSkinChanged;
  InitializeSkinSelector;
  // Применяем загруженный скин к главной форме и DataModule
  DoSkinChanged(FSkinManager.CurrentSkin, FSkinManager.NativeStyle);

  // Реестр кнопок: кнопка + TDLLInfo + опциональная инициализация

  FButtons.AddEntry(btnSimpleNumbers, DISimpleNumbers, nil);
  FButtons.AddEntry(btnCalcPrice, DICalcPrice, nil);
  FButtons.AddEntry(btnExplorer, DIExplorer, nil);
  FButtons.AddEntry(btnRunTasks, DIRunTasks, nil);
  FButtons.AddEntry(btnLogData, DILogData, nil);
  FButtons.AddEntry(btnCatalogParts, DICatalogParts, nil);

  LoadAllDlls;
  FSLog := TVTLoadAllDataSource<TVTVLog>.Create(vtlLog);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  // Освобождаем через интерфейс — корректный RefCount
  FreeAndNil(FSkinManager);  // dmSkin освободится через владение Self
  if Assigned(FDllManager) then
  begin
    FDllManager.UnloadAll;
    FDllManager := nil;  // RefCount=0 → вызывается Destroy
  end;
  FreeAndNil(FButtons);
  FreeAndNil(FSLog);
end;

{ TButtonEntryList }

procedure TButtonEntryList.AddEntry(Button: TdxBarLargeButton;
  DllInfo: TDLLInfo; InitProc: TProc);
var
  res: TButtonEntry;
begin
  res := TButtonEntry.Create;
  res.Button := Button;
  res.DllInfo := DLLInfo;
  res.InitProc := InitProc;
  Add(res);
end;

end.
