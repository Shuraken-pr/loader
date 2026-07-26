unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxClasses, dxLayoutContainer, dxLayoutControl, cxVirtualTreeListHelper,
  Vcl.ExtCtrls, System.Generics.Collections,
  uEntities, uCatalogService, dmDatabase,
  dxLayoutcxEditAdapters, dxLayoutControlAdapters, cxContainer, cxEdit,
  Vcl.Menus, Vcl.StdCtrls, cxButtons, cxTextEdit, fPartEdit, uXmlExporter, uXmlImporter,
  dxCore, dxRibbonSkins, dxRibbonCustomizationForm, System.ImageList,
  Vcl.ImgList, cxImageList, dxBar, dxRibbon, System.Actions, Vcl.ActnList,
  fCategoryEdit, fAttributeEdit, System.UITypes, fAttributeSelect, fAttributeDelete,
  cxFilter, cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL, dxSkinNames,
  cxTLdxBarBuiltInMenu, cxInplaceContainer, cxTLData, cxMaskEdit, cxDropDownEdit,
  dxSkinsCore, dxLayoutLookAndFeels, dxSkinsdxRibbonPainter,        // ← для TdxRibbon + TdxBarManager
  dxLayoutPainters, uSkinHelper, dmSkins, dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle, dxSkinOffice2007Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinVS2010;

type
  TfrmMain = class(TForm)
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    lgFind: TdxLayoutGroup;
    edtSearch: TcxTextEdit;
    liSearchField: TdxLayoutItem;
    btnSearch: TcxButton;
    liSearchAction: TdxLayoutItem;
    btnClear: TcxButton;
    liClearAction: TdxLayoutItem;
    pnlView: TPanel;
    Splitter1: TSplitter;
    rtMain: TdxRibbonTab;
    rbMain: TdxRibbon;
    bmMain: TdxBarManager;
    brCategories: TdxBar;
    brAttributes: TdxBar;
    brParts: TdxBar;
    brXML: TdxBar;
    ilBig: TcxImageList;
    ilSmall: TcxImageList;
    alMain: TActionList;
    acDeleteCategory: TAction;
    acEditCategory: TAction;
    acAddAttribute: TAction;
    acAddPart: TAction;
    acEditPart: TAction;
    acDeletePart: TAction;
    acImport: TAction;
    acExport: TAction;
    acAddCategory: TAction;
    lbtnAddCategory: TdxBarLargeButton;
    lbtnEditCategory: TdxBarLargeButton;
    lbtnDeleteCategory: TdxBarLargeButton;
    lbtnAddAttribute: TdxBarLargeButton;
    lbtnAddPart: TdxBarLargeButton;
    lbtnEditPart: TdxBarLargeButton;
    lbtnDeletePart: TdxBarLargeButton;
    lbtnImport: TdxBarLargeButton;
    lbtnExport: TdxBarLargeButton;
    acDelAttribute: TAction;
    lbtnDelAttribute: TdxBarLargeButton;
    acEditAttribute: TAction;
    lbtnEditAttribute: TdxBarLargeButton;
    vtlCategories: TcxVirtualTreeList;
    vtlParts: TcxVirtualTreeList;
    vtlCategoriesName: TcxTreeListColumn;
    lgSkins: TdxLayoutGroup;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnAddPartClick(Sender: TObject);
    procedure btnEditPartClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure acAddPartUpdate(Sender: TObject);
    procedure acDeletePartUpdate(Sender: TObject);
    procedure acImportExecute(Sender: TObject);
    procedure acExportExecute(Sender: TObject);
    procedure acAddCategoryExecute(Sender: TObject);
    procedure acEditCategoryExecute(Sender: TObject);
    procedure acDeleteCategoryExecute(Sender: TObject);
    procedure acAddAttributeExecute(Sender: TObject);
    procedure acAddPartExecute(Sender: TObject);
    procedure acEditPartExecute(Sender: TObject);
    procedure acDeletePartExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure acDelAttributeExecute(Sender: TObject);
    procedure acEditAttributeExecute(Sender: TObject);
    procedure vtlCategoriesFocusedNodeChanged(Sender: TcxCustomTreeList;
      APrevFocusedNode, AFocusedNode: TcxTreeListNode);
    procedure vtlCategoriesExpanding(Sender: TcxCustomTreeList;
      ANode: TcxTreeListNode; var Allow: Boolean);
  private
    { Private declarations }
    FCallback: TProc<WideString>;
    FCatalogService: TCatalogService;
    FCurrentAttributes: TArray<TAttributeDef>;
    FCurrentCategoryID: Integer;
    FCategoryDS: TVTSmartDataSource<TCategoryNodeData>;
    FPartDS: TVTLoadAllDataSource<TPartNodeData>;

    function GetSelectedCategoryID: Integer;
    function GetSelectedCategoryName: string;
    function GetSelectedCategoryParentID: Integer;
    function GetSelectedPartID: Integer;
    function GetSelectedPartCode: string;

    procedure BuildCategoryTree;
    procedure LoadCategoryData(ACategoryID: Integer);
    procedure BuildPartsColumns;
  public
    { Public declarations }
    class function RunForm(ACallback: TProc<WideString>; var AMsg: WideString; ASkinName: WideString; ANativeStyle: boolean): boolean;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  dmDB.Connect;
  FCatalogService := TCatalogService.Create(dmDB);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FPartDS.Free;
  FCategoryDS.Free;
  FCatalogService.Free;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  if not dmDB.PGConn.Connected then
    Application.Terminate;
  // Инициализация нативных источников данных DevExpress
  FCategoryDS := TVTSmartDataSource<TCategoryNodeData>.Create(vtlCategories);
  FPartDS := TVTLoadAllDataSource<TPartNodeData>.Create(vtlParts);

  BuildCategoryTree;
end;

procedure TfrmMain.acAddAttributeExecute(Sender: TObject);
begin
  if TfrmAttributeEdit.Execute(FCatalogService, GetSelectedCategoryID, 0, '', atString) then
    LoadCategoryData(GetSelectedCategoryID); // Перезагружаем таблицу, чтобы увидеть новую колонку
end;

procedure TfrmMain.acAddCategoryExecute(Sender: TObject);
begin
  if TfrmCategoryEdit.Execute(FCatalogService, 0, '', 0) then
    BuildCategoryTree;
end;

procedure TfrmMain.acAddPartExecute(Sender: TObject);
begin
  if TfPartEdit.Execute(FCatalogService, GetSelectedCategoryID, 0, '') then
    LoadCategoryData(GetSelectedCategoryID);
end;

procedure TfrmMain.acAddPartUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := GetSelectedCategoryID > 0;
end;

procedure TfrmMain.acDelAttributeExecute(Sender: TObject);
var
  CatID: Integer;
begin
  CatID := GetSelectedCategoryID;
  if CatID > 0 then
  begin
    // Показываем форму выбора атрибута
    if TfAttributeDelete.Execute(FCatalogService, CatID) then
    begin
      // Если удаление прошло успешно, перезагружаем данные категории,
      // чтобы таблица деталей перестроилась без удаленной колонки
      LoadCategoryData(CatID);
    end;
  end;
end;

procedure TfrmMain.acDeleteCategoryExecute(Sender: TObject);
var
  CatID: Integer;
  ErrMsg: string;
begin
  CatID := GetSelectedCategoryID;
  if CatID > 0 then
  begin
    if MessageDlg('Вы уверены, что хотите удалить категорию "' + GetSelectedCategoryName + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      if FCatalogService.DeleteCategory(CatID, ErrMsg) then
      begin
        BuildCategoryTree;
        FPartDS.Clear; // Очищаем таблицу деталей
      end
      else
        ShowMessage(ErrMsg);
    end;
  end;
end;

procedure TfrmMain.acDeletePartExecute(Sender: TObject);
var
  PartID: Integer;
  Code: string;
begin
  PartID := GetSelectedPartID;
  if PartID > 0 then
  begin
    Code := GetSelectedPartCode;
    if MessageDlg('Вы уверены, что хотите удалить деталь с кодом "' + Code + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      if FCatalogService.DeletePart(PartID) then
        LoadCategoryData(GetSelectedCategoryID)
      else
        ShowMessage('Не удалось удалить деталь.');
    end;
  end;
end;

procedure TfrmMain.acDeletePartUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := GetSelectedPartID > 0;
end;

procedure TfrmMain.acEditAttributeExecute(Sender: TObject);
var
  CatID, AttrID: Integer;
  AttrName: string;
  AttrType: TAttrType;
begin
  CatID := GetSelectedCategoryID;
  if CatID > 0 then
  begin
    // 1. Спрашиваем пользователя, какой атрибут редактировать
    if TfAttributeSelect.Execute(FCatalogService, CatID, AttrID, AttrName, AttrType) then
    begin
      // 2. Открываем форму редактирования с предзаполненными данными
      if TfrmAttributeEdit.Execute(FCatalogService, CatID, AttrID, AttrName, AttrType) then
      begin
        // 3. Если сохранение прошло успешно, перезагружаем данные категории.
        // Это критически важно: имя колонки или её тип могли измениться,
        // и vtlParts должен перестроить заголовки.
        LoadCategoryData(CatID);
      end;
    end;
  end;
end;

procedure TfrmMain.acEditCategoryExecute(Sender: TObject);
var
  CatID: Integer;
begin
  CatID := GetSelectedCategoryID;
  if CatID > 0 then
  begin
    if TfrmCategoryEdit.Execute(FCatalogService, CatID, GetSelectedCategoryName, GetSelectedCategoryParentID) then
      BuildCategoryTree;
  end;
end;

procedure TfrmMain.acEditPartExecute(Sender: TObject);
var
  PartID: Integer;
  Code: string;
begin
  PartID := GetSelectedPartID;
  if PartID > 0 then
  begin
    Code := GetSelectedPartCode;
    if TfPartEdit.Execute(FCatalogService, GetSelectedCategoryID, PartID, Code) then
      LoadCategoryData(GetSelectedCategoryID);
  end;
end;

procedure TfrmMain.acExportExecute(Sender: TObject);
var
  SaveDialog: TSaveDialog;
  Exporter: TXmlExporter;
begin
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Filter := 'XML Files|*.xml';
    SaveDialog.FileName := 'catalog_export.xml';
    if SaveDialog.Execute then
    begin
      Screen.Cursor := crHourGlass;
      try
        Exporter := TXmlExporter.Create(dmDb);
        try
          Exporter.ExportToFile(SaveDialog.FileName);
          ShowMessage('Экспорт успешно завершен!');
        finally
          Exporter.Free;
        end;
      finally
        Screen.Cursor := crDefault;
      end;
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TfrmMain.acImportExecute(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  Importer: TXmlImporter;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    OpenDialog.Filter := 'XML Files|*.xml';
    OpenDialog.FileName := 'sample_catalog.xml';
    if OpenDialog.Execute then
    begin
      Screen.Cursor := crHourGlass;
      try
        Importer := TXmlImporter.Create(dmDb);
        try
          Importer.ImportFromFile(OpenDialog.FileName);
          ShowMessage('Импорт успешно завершен!');
          BuildCategoryTree; // Перестраиваем дерево, т.к. могли добавиться новые категории
        finally
          Importer.Free;
        end;
      finally
        Screen.Cursor := crDefault;
      end;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TfrmMain.btnAddPartClick(Sender: TObject);
begin
  if FCurrentCategoryID > 0 then
  begin
    if TfPartEdit.Execute(FCatalogService, FCurrentCategoryID, 0, '') then
      LoadCategoryData(FCurrentCategoryID); // Обновить таблицу
  end
  else
    ShowMessage('Сначала выберите категорию.');
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  edtSearch.Text := '';
  if FCurrentCategoryID > 0 then
    LoadCategoryData(FCurrentCategoryID);
end;

procedure TfrmMain.btnEditPartClick(Sender: TObject);
var
  Data: TPartNodeData;
  Code: string;
begin
  Data := FPartDS.CurrentObj;
  if Assigned(Data) then
  begin
    Code := Data.Code;
    if TfPartEdit.Execute(FCatalogService, FCurrentCategoryID, Data.PartID, Code) then
      LoadCategoryData(FCurrentCategoryID);
  end;
end;

procedure TfrmMain.btnExportClick(Sender: TObject);
var
  Exporter: TXmlExporter;
  SaveDialog: TSaveDialog;
begin
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Filter := 'XML Files|*.xml';
    SaveDialog.FileName := 'catalog_export.xml';
    if SaveDialog.Execute then
    begin
      Exporter := TXmlExporter.Create(dmDb);
      try
        Exporter.ExportToFile(SaveDialog.FileName);
        ShowMessage('Экспорт успешно завершен!');
      finally
        Exporter.Free;
      end;
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TfrmMain.btnSearchClick(Sender: TObject);
begin
  if FCurrentCategoryID > 0 then
    LoadCategoryData(FCurrentCategoryID);
end;

procedure TfrmMain.BuildCategoryTree;
var
  Categories: TArray<TCategory>;
begin
  vtlCategories.BeginUpdate;
  try
    FCategoryDS.Clear;
    Categories := FCatalogService.GetCategories;

    // Загружаем только корневые категории (ParentID = 0).
    // Дети будут загружены лениво при раскрытии (SmartLoad).
    FCategoryDS.InitChildren(FCategoryDS.RootHandle,
      procedure(AParent: TVTBaseRecord)
      var
        i: integer;
        NewNode: TCategoryNodeData;
      begin
        for i := 0 to High(Categories) do
        begin
          if Categories[i].ParentID = 0 then
          begin
            NewNode := TCategoryNodeData(FCategoryDS.InsertRecordHandle(AParent, True));
            NewNode.CategoryID := Categories[i].ID;
            NewNode.ParentID := Categories[i].ParentID;
            NewNode.Name := Categories[i].Name;
            NewNode.ChildCount := Categories[i].ChildCount;
          end;
        end;
      end);

    vtlCategories.FullExpand; // Это триггернет OnExpanding для загрузки следующего уровня
  finally
    vtlCategories.EndUpdate;
  end;
end;

procedure TfrmMain.BuildPartsColumns;
var
  i: Integer;
  Col: TcxTreeListColumn;
begin
  // Колонка "Код"
  Col := vtlParts.CreateColumn(nil);
  Col.Caption.Text := 'Код детали';
  Col.Width := 120;

  // Динамические колонки атрибутов
  for i := 0 to High(FCurrentAttributes) do
  begin
    Col := vtlParts.CreateColumn(nil);
    Col.Caption.Text := FCurrentAttributes[i].Name;
    Col.Width := 150;
  end;
end;

function TfrmMain.GetSelectedCategoryID: Integer;
var
  Data: TCategoryNodeData;
begin
  Result := 0;
  Data := FCategoryDS.CurrentObj;
  if Assigned(Data) then
    Result := Data.CategoryID;
end;

function TfrmMain.GetSelectedCategoryName: string;
var
  Data: TCategoryNodeData;
begin
  Result := '';
  Data := FCategoryDS.CurrentObj;
  if Assigned(Data) then
    Result := Data.Name;
end;

function TfrmMain.GetSelectedCategoryParentID: Integer;
var
  Data: TCategoryNodeData;
begin
  Result := 0;
  Data := FCategoryDS.CurrentObj;
  if Assigned(Data) then
    Result := Data.ParentID;
end;

function TfrmMain.GetSelectedPartCode: string;
var
  Data: TPartNodeData;
begin
  Result := '';
  Data := FPartDS.CurrentObj;
  if Assigned(Data) then
    Result := Data.Code;
end;

function TfrmMain.GetSelectedPartID: Integer;
var
  Data: TPartNodeData;
begin
  Result := 0;
  Data := FPartDS.CurrentObj;
  if Assigned(Data) then
    Result := Data.PartID;
end;

procedure TfrmMain.LoadCategoryData(ACategoryID: Integer);
var
  i: Integer;
  Parts: TArray<TPartRow>;
  NewNode: TPartNodeData;
  Pair: TPair<string, string>;
begin
  FCurrentCategoryID := ACategoryID;

  vtlParts.BeginUpdate;
  try
    FPartDS.Clear;
    vtlParts.DeleteAllColumns;

    FCurrentAttributes := FCatalogService.GetCategoryAttributes(ACategoryID);

    // Создаем колонки
    BuildPartsColumns;

    Parts := FCatalogService.GetParts(ACategoryID, edtSearch.Text);

    for i := 0 to High(Parts) do
    begin
      NewNode := TPartNodeData(FPartDS.InsertRecordHandle(FPartDS.RootHandle, True));
      NewNode.PartID := Parts[i].PartID;
      NewNode.Code := Parts[i].Code;
      NewNode.Attributes := Copy(FCurrentAttributes); // Копируем для маппинга колонок

      // Копируем значения из временного объекта Parts[i] в постоянный узел
      for Pair in Parts[i].Values do
        NewNode.Values.Add(Pair.Key, Pair.Value);

      Parts[i].Free; // Освобождаем временный объект, данные уже в узле
    end;
    SetLength(Parts, 0);
  finally
    FPartDS.DataChanged;
    vtlParts.EndUpdate;
  end;
end;

class function TfrmMain.RunForm(ACallback: TProc<WideString>;
  var AMsg: WideString; ASkinName: WideString; ANativeStyle: boolean): boolean;
begin
  try
    dmDB := TdmDB.Create(nil);
    try
      frmMain := TfrmMain.Create(nil);
      try
        ApplySkinToForm(frmMain, ASkinName, ANativeStyle, frmMain.rbMain);
        frmMain.FCallback := ACallback;
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

procedure TfrmMain.vtlCategoriesExpanding(Sender: TcxCustomTreeList;
  ANode: TcxTreeListNode; var Allow: Boolean);
var
  CatData: TCategoryNodeData;
  Categories: TArray<TCategory>;
begin
  CatData := FCategoryDS.Obj(ANode);
  Allow := Assigned(CatData) and (CatData.ChildCount > 0);
  if Allow and not CatData.DataLoaded then
  begin
    Categories := FCatalogService.GetCategories;
    FCategoryDS.InitChildren(CatData,
      procedure(AParent: TVTBaseRecord)
      var
        i: integer;
        NewNode: TCategoryNodeData;
      begin
        for i := 0 to High(Categories) do
        begin
          if Categories[i].ParentID = CatData.CategoryID then
          begin
            NewNode := TCategoryNodeData(FCategoryDS.InsertRecordHandle(AParent, True));
            NewNode.CategoryID := Categories[i].ID;
            NewNode.ParentID := Categories[i].ParentID;
            NewNode.Name := Categories[i].Name;
            NewNode.ChildCount := Categories[i].ChildCount;
          end;
        end;
      end);
  end;
end;

procedure TfrmMain.vtlCategoriesFocusedNodeChanged(Sender: TcxCustomTreeList;
  APrevFocusedNode, AFocusedNode: TcxTreeListNode);
var
  CatData: TCategoryNodeData;
begin
  CatData := FCategoryDS.CurrentObj;
  if Assigned(CatData) and (CatData.CategoryID > 0) then
    LoadCategoryData(CatData.CategoryID);
end;

end.
