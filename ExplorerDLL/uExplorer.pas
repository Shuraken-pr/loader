unit uExplorer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxLayoutContainer, cxSplitter,
  cxClasses, dxLayoutControl, dxLayoutcxEditAdapters,
  dxLayoutControlAdapters, cxCheckBox, cxContainer, cxEdit, Vcl.Menus,
  Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit, cxDropDownEdit,
  cxCheckComboBox, System.Threading, System.SyncObjs, cxLabel, intf_tasks,
  DateUtils, cxImage, cxMemo, Vcl.Imaging.jpeg, cxPC, dxDockControl, dxDockPanel,
  System.Generics.Collections, cxFilter, cxCustomData, cxStyles,
  dxScrollbarAnnotations, cxTL, cxTLdxBarBuiltInMenu, cxInplaceContainer,
  cxTLData, cxVirtualTreeListHelper, dxCore, dxCoreClasses, dmSkins, frxDevDSIntf,
  dxSkinsCore, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2010Silver, dxSkinOffice2013LightGray,
  dxSkinVS2010, frxClass, dxBar, dxRibbon, dxRibbonGallery;

type
  TExplorerRecord = class(TVTBaseRecord)
  private
    FFullPath: string;
    FValue: string;
    FIsFile: boolean;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    { Сохраняет значение для указанного индекса колонки. }
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    property FullPath: string read FFullPath write FFullPath;
    property Value: string read FValue write FValue;
  end;

  TfrmScanLocalDisks = class(TForm)
    lcExplorerGroup_Root: TdxLayoutGroup;
    lcExplorer: TdxLayoutControl;
    lgParams: TdxLayoutGroup;
    splitInfo: TcxSplitter;
    ccbLocalDisks: TcxCheckComboBox;
    liLocalDisks: TdxLayoutItem;
    edFilterExt: TcxTextEdit;
    liFilterExt: TdxLayoutItem;
    btnScanDir: TcxButton;
    liScanDir: TdxLayoutItem;
    lbInfo: TcxLabel;
    liInfo: TdxLayoutItem;
    dpShowFile: TdxDockPanel;
    dxFloatDockSite1: TdxFloatDockSite;
    mTextFile: TcxMemo;
    imGraphFile: TcxImage;
    vtvExplorer: TcxVirtualTreeList;
    liExplorer: TdxLayoutItem;
    colValue: TcxTreeListColumn;
    colFullPath: TcxTreeListColumn;
    btnFastReport: TcxButton;
    liFastReport: TdxLayoutItem;
    pmFastReport: TPopupMenu;
    miFRDesigner: TMenuItem;
    miFRPreview: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnScanDirClick(Sender: TObject);
    procedure vtvExplorerFocusedNodeChanged(Sender: TcxCustomTreeList;
      APrevFocusedNode, AFocusedNode: TcxTreeListNode);
    procedure vtvExplorerCompare(Sender: TcxCustomTreeList; ANode1,
      ANode2: TcxTreeListNode; var ACompare: Integer);
    procedure vtvExplorerColumnHeaderClick(Sender: TcxCustomTreeList;
      AColumn: TcxTreeListColumn);
    procedure miFRDesignerClick(Sender: TObject);
  private
    FDTStartUpdateInfo: TDateTime;
    FTaskCtrl: TResultType;
    FCallbackProc: TProc<WideString>;
    FExtList: TStringList;
    FCrit: TCriticalSection;
    FRunTaskFind: IRunTaskFindInDir;
    FIntfFR: IFrxDevDS;
    FPathToNode: TDictionary<string, TExplorerRecord>;
    FPathBuffer: TList<string>;
    FDSExplorer: TVTSmartDataSource<TExplorerRecord>;
    procedure DoCallbackProc(AMsg: WideString);
    procedure FillVst(APath: string);
    procedure FillVstFromBuffer;
    procedure FillLocalDrives;
    procedure UpdateScanInfo(APath: string);
    function FRCustomFunction(AFuncName: WideString; ASourceName: WideString): variant;
  public
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
    property FindIntf: IRunTaskFindInDir read FRunTaskFind write FRunTaskFind;
    property FRIntf: IFrxDevDS read FIntfFR write FIntfFR;
  end;

var
  frmScanLocalDisks: TfrmScanLocalDisks;

implementation

uses
  StrUtils;

{$R *.dfm}

procedure TfrmScanLocalDisks.btnScanDirClick(Sender: TObject);
var
  ext, dir: string;
  i: integer;
begin
  FDTStartUpdateInfo := now;
  if Assigned(FRunTaskFind) then
  begin
    if FTaskCtrl <> nil then
    begin
      FRunTaskFind.Stop(FTaskCtrl);
      FTaskCtrl := nil;
      liFastReport.Visible := Assigned(FIntfFR) and (FDSExplorer.RootHandle.ChildCount > 0);
      btnScanDir.Caption := 'Сканировать';
      UpdateScanInfo('');
      Exit;
    end
      else
    begin
      btnScanDir.Caption := 'Прервать';
      liFastReport.Visible := false;
      FDSExplorer.Clear;
      FPathToNode.Clear;
      FPathBuffer.Clear;
    end;
    dir := '';
    ext := edFilterExt.Text;
    for i := 0 to ccbLocalDisks.Properties.Items.Count - 1 do
      if ccbLocalDisks.States[i] = cbsChecked then
      begin
        if dir = '' then
          dir := ccbLocalDisks.Properties.Items[i].Description
        else
          dir := dir + ';' + ccbLocalDisks.Properties.Items[i].Description;
      end;
    FRunTaskFind.SetCallbacks(
    procedure(AMsg: WideString)  //StartCallback,  уведомляем о запуске
    begin
      DoCallbackProc(AMsg);
    end,
    procedure(APath: WideString)  //RunCallback, отображаем ход выполнения
    begin
      if SecondsBetween(FDTStartUpdateInfo, Now) >= 2 then //чтобы не зависало, обновляем каждые 2 секунды.
      begin
        UpdateScanInfo(APath);
        FDTStartUpdateInfo := Now;
      end;
    end,
    procedure(AMsg: WideString)  // BreakCallback, уведомляем о прерывании
    begin
      DoCallbackProc(AMsg);
      TThread.Synchronize(nil,
      procedure
      begin
        FillVstFromBuffer;
        colFullPath.SortOrder := soAscending;
        liFastReport.Visible := Assigned(FIntfFR) and (FDSExplorer.RootHandle.ChildCount > 0);
      end);
    end,
    procedure(AMsg: WideString)  //FinishCallback, уведомляем о завершении
    begin
      DoCallbackProc(AMsg);
      FTaskCtrl := nil;
      btnScanDir.Caption := 'Сканировать';
      UpdateScanInfo('');
      TThread.Synchronize(nil,
      procedure
      begin
        // Сбрасываем остаток буфера перед сортировкой
        FillVstFromBuffer;
        colFullPath.SortOrder := soAscending;
        liFastReport.Visible := Assigned(FIntfFR) and (FDSExplorer.RootHandle.ChildCount > 0);
      end);
    end,
    procedure(APath: WideString)  //SyncCallback, добавляем путь в буфер
    begin
      FCrit.Enter;
      try
        FPathBuffer.Add(APath);
      finally
        FCrit.Leave;
      end;
    end
    );
    FTaskCtrl := FRunTaskFind.Start(dir, ext);
  end;
end;

procedure TfrmScanLocalDisks.DoCallbackProc(AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
  TThread.Synchronize(nil, procedure
  begin
    FCallbackProc(AMsg);
  end);
end;

procedure TfrmScanLocalDisks.FillLocalDrives;
var
  c: char;
  s: string;
begin
  ccbLocalDisks.Properties.Items.Clear;
  for c := 'A' to 'Z' do
  begin
    s := c + ':';
    if GetDriveType(PChar(s)) = DRIVE_FIXED then
      ccbLocalDisks.Properties.Items.AddCheckItem(s);
  end;
end;

procedure TfrmScanLocalDisks.FillVst(APath: string);
var
  curV, childV: TExplorerRecord;
  i, end_num: integer;
  curPath, FullPath: string;
  PathArray: TArray<string>;
begin
  PathArray := SplitString(APath, '\');
  curV := FDSExplorer.RootHandle;
  FullPath := '';
  end_num := High(PathArray);

  for i := Low(PathArray) to end_num do
  begin
    curPath := PathArray[i];
    if FullPath = '' then
      FullPath := curPath
    else
      FullPath := IncludeTrailingPathDelimiter(FullPath) + curPath;

    if FPathToNode.TryGetValue(FullPath, childV) then
    begin
      curV := childV;
    end
    else
    begin
      childV := FDSExplorer.InsertRecordHandle(curV, true);
      childV.Value := curPath;
      childV.FullPath := FullPath;
      childV.FIsFile := i = end_num;
      FPathToNode.Add(FullPath, childV);
      curV := childV;
    end;
  end;
end;

procedure TfrmScanLocalDisks.FillVstFromBuffer;
var
  paths: TArray<string>;
  path: string;
begin
  // Забираем всё из буфера
  FCrit.Enter;
  try
    if FPathBuffer.Count = 0 then
      Exit;
    paths := FPathBuffer.ToArray;
    FPathBuffer.Clear;
  finally
    FCrit.Leave;
  end;

  // Обновляем VST одним BeginUpdate/EndUpdate
  vtvExplorer.BeginUpdate;
  try
    for path in paths do
      FillVst(path);
  finally
    FDSExplorer.DataChanged;
    vtvExplorer.EndUpdate;
  end;
end;

procedure TfrmScanLocalDisks.FormCreate(Sender: TObject);
begin
  FExtList := TStringList.Create;
  FCrit := TCriticalSection.Create;
  FPathToNode := TDictionary<string, TExplorerRecord>.Create;
  FPathBuffer := TList<string>.Create;
  FRunTaskFind := nil;
  FDSExplorer := TVTSmartDataSource<TExplorerRecord>.Create(vtvExplorer);
  FillLocalDrives;
end;

procedure TfrmScanLocalDisks.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FExtList);
  FCallbackProc := nil;
  FreeAndNil(FCrit);
  FreeAndNil(FPathToNode);
  FreeAndNil(FPathBuffer);
  if Assigned(FRunTaskFind) then
    FRunTaskFind := nil;
end;

function TfrmScanLocalDisks.FRCustomFunction(AFuncName,
  ASourceName: WideString): variant;
var
  DS: TfrxDataSet;
begin
  Result := null;
  if (ASourceName = 'DSExplorer') then
  begin
    if Assigned(FIntfFR) then
    begin
      DS := FIntfFR.GetDSByName('frxDS0');
      if AFuncName = 'GetCurrentLevel' then
      begin
        if Assigned(DS) and Assigned(FDSExplorer.CalcNode) then
          Result := FDSExplorer.CalcNode.Level;
      end
        else if AFuncName = 'IsFile' then
      begin
        if Assigned(DS) and Assigned(FDSExplorer.CalcNode) then
          Result := FDSExplorer.Obj(FDSExplorer.CalcNode).FIsFile;
      end;
    end;
  end;
end;

procedure TfrmScanLocalDisks.miFRDesignerClick(Sender: TObject);
begin
  if Assigned(FIntfFR) then
  begin
    FIntfFR.SetCustomFunction(FRCustomFunction);
    var ReportFile: string := ExtractFilePath(ParamStr(0)) + 'FastReportTemplates\Explorer.fr3';
    if TMenuItem(Sender).Tag = 1 then
      FIntfFR.PreviewReport([TVTBaseDataSource<TVTBaseRecord>(FDSExplorer)], [vtvExplorer], ReportFile)
    else
      FIntfFR.DesignReport([TVTBaseDataSource<TVTBaseRecord>(FDSExplorer)], [vtvExplorer], ReportFile);
  end;
end;

procedure TfrmScanLocalDisks.UpdateScanInfo(APath: string);
begin
  if Assigned(lbInfo) and Assigned(FCrit) then
  begin
    FCrit.Enter;
    try
      if (APath <> '') then
          lbInfo.Caption := 'Сканируется ' + APath
      else
        lbInfo.Caption := '';

      lbInfo.Refresh;
    finally
      FCrit.Leave;
    end;
  end;
end;

procedure TfrmScanLocalDisks.vtvExplorerFocusedNodeChanged(
  Sender: TcxCustomTreeList; APrevFocusedNode, AFocusedNode: TcxTreeListNode);
const
  pictureExts = '.bmp;.jpg;.jpeg;.png';

var
  obj: TExplorerRecord;
  ext: string;
begin
  obj :=  FDSExplorer.Obj(AFocusedNode);
  if Assigned(obj) and obj.FIsFile then
  begin
    ext := ExtractFileExt(obj.FullPath);
    if ext = '.txt' then
    begin
      dpShowFile.Visible := true;
      mTextFile.Visible := true;
      imGraphFile.Visible := false;
      mTextFile.Lines.LoadFromFile(obj.FullPath);
    end
      else if pos(ext, pictureExts) > 0 then
    begin
      dpShowFile.Visible := true;
      mTextFile.Visible := false;
      imGraphFile.Visible := true;
      imGraphFile.Picture.LoadFromFile(obj.FullPath);
    end
      else
    begin
      dpShowFile.Visible := false;
    end;
  end
    else
    dpShowFile.Visible := false;
end;

procedure TfrmScanLocalDisks.vtvExplorerCompare(Sender: TcxCustomTreeList;
  ANode1, ANode2: TcxTreeListNode; var ACompare: Integer);
var
  obj1, obj2: TExplorerRecord;
  intDir, SortCol: integer;

  function CompareBool(b1, b2: boolean): integer;
  begin
    if (b1 = b2) then
      Result := 0
    else if (b1 = false) and (b2 = true) then
      Result := -1
    else
      Result := 1;
  end;

begin
  obj1 := FDSExplorer.Obj(ANode1);
  obj2 := FDSExplorer.Obj(ANode2);
  sortCol := -1;
  for var i := 0 to Sender.ColumnCount - 1 do
  begin
    if Sender.Columns[i].SortOrder <> soNone then
    begin
      sortCol := i;
      break;
    end;
  end;
  if sortCol < 0 then
    exit;

  if Assigned(obj1) and Assigned(obj2) then
  begin
    if obj1.FIsFile <> obj2.FIsFile then
    begin
      if Sender.Columns[sortCol].SortOrder = soAscending then
        intDir := 1
      else
        intDir := -1;
      ACompare := intDir * CompareBool(obj1.FIsFile, obj2.FIsFile);
    end  else
    begin
      case sortCol of
        0: ACompare := CompareText(obj1.Value, obj2.Value);
        1: ACompare := CompareText(obj1.FullPath, obj2.FullPath);
      end;
    end;
  end;

end;

procedure TfrmScanLocalDisks.vtvExplorerColumnHeaderClick(
  Sender: TcxCustomTreeList; AColumn: TcxTreeListColumn);
begin
  if AColumn.SortOrder = soAscending then
    AColumn.SortOrder := soDescending
  else
    AColumn.SortOrder := soAscending;
end;

{ TExplorerRecord }

constructor TExplorerRecord.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FFullPath := '';
  FValue := '';
  FIsFile := false;
end;

function TExplorerRecord.GetValue(ColIdx: Integer): Variant;
begin
  Result := null;
  case ColIdx of
    0: Result := FValue;
    1: Result := FFullPath;
  end;
end;

procedure TExplorerRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  case ColIdx of
    0: FValue := AValue;
    1: FFullPath := AValue;
  end;
end;

end.
