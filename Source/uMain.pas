unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxCore, dxRibbonSkins, dxRibbonCustomizationForm,
  System.Actions, Vcl.ActnList, System.ImageList, Vcl.ImgList, cxImageList,
  dxLayoutContainer, dxLayoutControl, cxClasses, dxBar, dxRibbon, vstHelper,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, DllManager, intf_dll, intf_common, System.Generics.Collections,
  VirtualTrees.Types;

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

  TVSTLog = class(TBaseRecord)
  private
    FMsg: WideString;
    FLogDate: TDateTime;
  public
    constructor Create; override;
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
    vstLog: TVirtualStringTree;
    liLog: TdxLayoutItem;
    rbMainTab1: TdxRibbonTab;
    bInterfaces: TdxBar;
    btnSimpleNumbers: TdxBarLargeButton;
    btnCalcPrice: TdxBarLargeButton;
    btnExplorer: TdxBarLargeButton;
    btnRunTasks: TdxBarLargeButton;
    btnLogData: TdxBarLargeButton;
    procedure vstLogGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure vstLogFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vstLogDrawText(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const Text: string;
      const CellRect: TRect; var DefaultDraw: Boolean);
    procedure vstLogMeasureItem(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; var NodeHeight: TDimension);
  private
    FDllManager: TDllManager;
    FButtons: TButtonEntryList;
    procedure AddMsg(const AMsg: WideString);
    procedure OnButtonClick(Sender: TObject);
    procedure LoadAllDlls;
  public
  end;

var
  frmMain: TfrmMain;

implementation

uses
  intf_dll_manager, intf_tasks, System.Math;

{$R *.dfm}

{ TVSTLog }

constructor TVSTLog.Create;
begin
  inherited;
  FLogDate := Now;
  FMsg := '';
end;

{ TfrmMain }

procedure TfrmMain.AddMsg(const AMsg: WideString);
var
  log: TVSTLog;
begin
  log := vstLog.Add<TVSTLog>;
  if Assigned(log) then
  begin
    vstLog.MultiLine[log.Node] := true;
    log.Msg := AMsg;
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

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  vstLog.NodeDataSize := SizeOf(TVSTLog);
  FDllManager := TDllManager.Create;
  FButtons := TButtonEntryList.Create;

  // Реестр кнопок: кнопка + TDLLInfo + опциональная инициализация

  FButtons.AddEntry(btnSimpleNumbers, DISimpleNumbers, nil);
  FButtons.AddEntry(btnCalcPrice, DICalcPrice, nil);
  FButtons.AddEntry(btnExplorer, DIExplorer, nil);
  FButtons.AddEntry(btnRunTasks, DIRunTasks, nil);
  FButtons.AddEntry(btnLogData, DILogData, nil);

  LoadAllDlls;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
var
  DllMgrIntf: IDllManager;
begin
  // Освобождаем через интерфейс — корректный RefCount
  if Assigned(FDllManager) then
  begin
    DllMgrIntf := FDllManager;
    FDllManager := nil;
    DllMgrIntf.UnloadAll;
    DllMgrIntf := nil;  // RefCount=0 → вызывается Destroy
  end;
  FreeAndNil(FButtons);
end;

procedure TfrmMain.vstLogDrawText(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
var
  DrawRect: TRect;
begin
  DefaultDraw := False;
  DrawRect := CellRect;
  DrawTextW(TargetCanvas.Handle, PWideChar(Text), Length(Text), DrawRect,
    DT_WORDBREAK or DT_NOPREFIX or DT_EDITCONTROL or DT_END_ELLIPSIS);
end;

procedure TfrmMain.vstLogFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  log: TVSTLog;
begin
  log := Sender.Obj<TVSTLog>(Node);
  if Assigned(log) then
    FreeAndNil(log);
end;

procedure TfrmMain.vstLogGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  log: TVSTLog;
begin
  cellText := '';
  if TextType = ttNormal then
  begin
    log := Sender.Obj<TVSTLog>(Node);
    if Assigned(log) then
    begin
      case column of
        0: CellText := FormatDateTime('dd.mm.yyyy hh:nn:ss', log.LogDate);
        1: CellText := log.Msg;
      end;
    end;
  end;
end;

procedure TfrmMain.vstLogMeasureItem(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; var NodeHeight: TDimension);
var
  maxNodeHeight: TDimension;
  i: integer;
begin
  maxNodeHeight := vstLog.DefaultNodeHeight;
  for i := 0 to Sender.Header.Columns.Count - 1 do
    maxNodeHeight := Max(maxNodeHeight, vstLog.ComputeNodeHeight(TargetCanvas, Node, i, vstLog.Text[Node, i]));
  if maxNodeHeight > vstLog.DefaultNodeHeight then
    NodeHeight := vstLog.DefaultNodeHeight * (1 + maxNodeHeight div vstLog.DefaultNodeHeight);
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
