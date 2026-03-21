unit uExplorer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, vstHelper, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxLayoutContainer, cxSplitter,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, cxClasses, dxLayoutControl, dxLayoutcxEditAdapters,
  dxLayoutControlAdapters, cxCheckBox, cxContainer, cxEdit, Vcl.Menus,
  Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit, cxDropDownEdit,
  cxCheckComboBox, System.Threading, System.SyncObjs, cxLabel, intf_tasks,
  DateUtils, cxImage, cxMemo, Vcl.Imaging.jpeg, cxPC, dxDockControl, dxDockPanel;

type
  TExplorerRecord = class(TBaseRecord)
  private
    FFullPath: string;
    FValue: string;
    FIsFile: boolean;
  public
    constructor Create; override;
    property FullPath: string read FFullPath write FFullPath;
    property Value: string read FValue write FValue;
  end;

  TfrmScanLocalDisks = class(TForm)
    lcExplorerGroup_Root: TdxLayoutGroup;
    lcExplorer: TdxLayoutControl;
    lgParams: TdxLayoutGroup;
    vstExplorer: TVirtualStringTree;
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
    liExplorer: TdxLayoutItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnScanDirClick(Sender: TObject);
    procedure vstExplorerGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstExplorerCompareNodes(Sender: TBaseVirtualTree; Node1,
      Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure vstExplorerHeaderClick(Sender: TVTHeader;
      HitInfo: TVTHeaderHitInfo);
    procedure vstExplorerChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
  private
    FDTStartUpdateInfo: TDateTime;
    FThread: TThread;
    FCallbackProc: TProc<WideString>;
    FExtList: TStringList;
    FCrit: TCriticalSection;
    FRunTaskFind: IRunTaskFindInDir;
    procedure DoCallbackProc(AMsg: WideString);
    procedure FillVst(APath: string);
    procedure FillLocalDrives;
    procedure UpdateScanInfo(APath: string);
    { Private declarations }
  public
    { Public declarations }
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
    property FindIntf: IRunTaskFindInDir read FRunTaskFind write FRunTaskFind;
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
    if FThread <> nil then
    begin
      FRunTaskFind.Stop(FThread);
      FThread := nil;
      btnScanDir.Caption := '—канировать';
      UpdateScanInfo('');
      Exit;
    end
      else
    begin
      btnScanDir.Caption := 'ѕрервать';
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
    procedure(AMsg: WideString)  //StartCallback,  уведомл€ем о запуске
    begin
      DoCallbackProc(AMsg);
    end,
    procedure(APath: WideString)  //RunCallback, отображаем ход выполнени€
    begin
      if SecondsBetween(FDTStartUpdateInfo, Now) >= 2 then //чтобы не зависало, обновл€ем каждые 2 секунды.
      begin
        UpdateScanInfo(APath);
        FDTStartUpdateInfo := Now;
      end;
    end,
    procedure(AMsg: WideString)  // BreakCallback, уведомл€ем о прерывании
    begin
      DoCallbackProc(AMsg);
      TThread.Synchronize(nil,
      procedure
      begin
        with vstExplorer, vstExplorer.Header do
        begin
          SortColumn := 1;
          SortDirection := sdAscending;
          SortTree(SortColumn, SortDirection)
        end;
      end);
    end,
    procedure(AMsg: WideString)  //FinishCallback, уведомл€ем о завершении
    begin
      DoCallbackProc(AMsg);
      FThread := nil;
      btnScanDir.Caption := '—канировать';
      UpdateScanInfo('');
      TThread.Synchronize(nil,
      procedure
      begin
        with vstExplorer, vstExplorer.Header do
        begin
          SortColumn := 1;
          SortDirection := sdAscending;
          SortTree(SortColumn, SortDirection)
        end;
      end);
    end,
    procedure(APath: WideString)  //SyncCallback, выполн€ем синхронизацию
    begin
      TThread.Synchronize(nil,
      procedure
      begin
        FillVst(APath);
      end);
    end
    );
    FThread := FRunTaskFind.Start(dir, ext);
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
  curV, childV: PVirtualNode;
  exp: TExplorerRecord;
  i, start_num, end_num: integer;
  curPath, FullPath: string;
  PathArray: TArray<string>;
begin
  vstExplorer.BeginUpdate;
  try
    PathArray := SplitString(APath, '\');
    curV := vstExplorer.RootNode;
    FullPath := '';
    start_num := Low(PathArray);
    end_num := High(PathArray);
    for i := start_num to end_num do
    begin
      curPath := PathArray[i];
      if FullPath = '' then
        FullPath := curPath
      else
        FullPath := IncludeTrailingPathDelimiter(FullPath) + curPath;
      childV := vstExplorer.GetFirstChild(curV);
      while childV <> nil do
      begin
        exp := vstExplorer.Obj<TExplorerRecord>(childV);
        if Assigned(exp) then
        begin
          if (exp.Value = curPath) and (exp.FullPath = FullPath) then
          begin
            curV := childV;
            break;
          end;
        end;
        childV := vstExplorer.GetNextSibling(childV);
      end;

      if not Assigned(childV) then
      begin
        childV := vstExplorer.AddChild(curV);
        exp := vstExplorer.Add<TExplorerRecord>(childV);
        exp.Value := curPath;
        exp.FullPath := FullPath;
        exp.FIsFile := i = end_num;
        curV := childV;
      end;
    end;
  finally
    vstExplorer.EndUpdate;
  end;
end;

procedure TfrmScanLocalDisks.FormCreate(Sender: TObject);
begin
  FExtList := TStringList.Create;
  vstExplorer.NodeDataSize := SizeOf(TExplorerRecord);
  FCrit := TCriticalSection.Create;
  FRunTaskFind := nil;
  FillLocalDrives;
end;

procedure TfrmScanLocalDisks.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FExtList);
  FCallbackProc := nil;
  FreeAndNil(FCrit);
  if Assigned(FRunTaskFind) then
    FRunTaskFind := nil;
end;

procedure TfrmScanLocalDisks.UpdateScanInfo(APath: string);
begin
  if Assigned(lbInfo) and Assigned(FCrit) then
  begin
    FCrit.Enter;
    try
      if (APath <> '') then
          lbInfo.Caption := '—канируетс€ ' + APath
      else
        lbInfo.Caption := '';

      lbInfo.Refresh;
    finally
      FCrit.Leave;
    end;
  end;
end;

procedure TfrmScanLocalDisks.vstExplorerChange(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
const
  pictureExts = '.bmp;.jpg;.jpeg;.png';

var
  obj: TExplorerRecord;
  ext: string;
begin
  obj := Sender.Obj<TExplorerRecord>(Node);
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

procedure TfrmScanLocalDisks.vstExplorerCompareNodes(Sender: TBaseVirtualTree;
  Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var
  obj1, obj2: TExplorerRecord;
  intDir: integer;

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
  obj1 := Sender.Obj<TExplorerRecord>(Node1);
  obj2 := Sender.Obj<TExplorerRecord>(Node2);
  if Assigned(obj1) and Assigned(obj2) then
  begin
    if obj1.FIsFile <> obj2.FIsFile then
    begin
      if Sender.Header.SortDirection = sdAscending then
        intDir := 1
      else
        intDir := -1;
      Result := intDir * CompareBool(obj1.FIsFile, obj2.FIsFile);
    end  else
    begin
      case column of
        0: Result := CompareText(obj1.Value, obj2.Value);
        1: Result := CompareText(obj1.FullPath, obj2.FullPath);
      end;
    end;
  end;
end;

procedure TfrmScanLocalDisks.vstExplorerGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  obj: TExplorerRecord;
begin
  cellText := '';
  obj := Sender.Obj<TExplorerRecord>(Node);
  if Assigned(obj) then
  begin
    case Column of
      0: CellText := obj.Value;
      1: CellText := obj.FullPath;
    end;
  end;
end;

procedure TfrmScanLocalDisks.vstExplorerHeaderClick(Sender: TVTHeader;
  HitInfo: TVTHeaderHitInfo);
begin
  if HitInfo.Button = TMouseButton.mbLeft then
  begin
    if HitInfo.Column = Sender.SortColumn then
    begin
      if Sender.SortDirection = sdAscending then
        Sender.SortDirection := sdDescending
      else
        Sender.SortDirection := sdAscending
    end
      else
    begin
      if ssShift in HitInfo.Shift then
        Sender.SortDirection := sdDescending
      else
        Sender.SortDirection := sdAscending
    end;
    Sender.SortColumn := HitInfo.Column;
    vstExplorer.SortTree(Sender.SortColumn, Sender.SortDirection)
  end;
end;

{ TExplorerRecord }

constructor TExplorerRecord.Create;
begin
  inherited;
  FFullPath := '';
  FValue := '';
  FIsFile := false;
end;

end.
