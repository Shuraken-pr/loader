unit uRunTasks;

{$I pool_config.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, intf_tasks, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxLayoutContainer,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, cxClasses, dxLayoutControl, vstHelper, System.Generics.Collections,
  dxLayoutcxEditAdapters, dxLayoutControlAdapters, cxContainer, cxEdit,
  Vcl.Menus, cxButtonEdit, Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit,
{$ifdef use_otl}
  OtlTaskControl, OtlTask,
{$endif}
  cxDropDownEdit, IOUtils, cxPC, dxDockControl, dxDockPanel, dxCoreGraphics;

type
  TRunTaskStatus = (rtsNone, rtsExecute, rtsBreak, rtsFinish, rtsError);

  TResultRecord = class(TBaseRecord)
  private
    FFirstValue: WideString;
    FSecondValue: WideString;
  public
    constructor Create; override;
    property FirstValue: WideString read FFirstValue write FFirstValue;
    property SecondValue: WideString read FSecondValue write FSecondValue;
  end;

  TRunTaskRecord = class(TBaseRecord)
  private
    FDTEnd: TDateTime;
    FStatus: TRunTaskStatus;
    FInfo: string;
    FDTStart: TDateTime;
    FCanShowResult: boolean;
    FTaskIntf: IRunTask;
    FTaskCtrl: TResultType;
    FParams: WideString;
    FCommand: WideString;
    FResultList: TList<WideString>;
  public
    constructor Create; override;
    destructor Destroy; override;
    property dtStart: TDateTime read FDTStart write FDTStart;  // время запуска задания
    property dtEnd: TDateTime read FDTEnd write FDTEnd;        // время окончания задания
    property info: string read FInfo write FInfo;              // информация о задании
    property Status: TRunTaskStatus read FStatus write FStatus; // статус
    property TaskCtrl: TResultType read FTaskCtrl write FTaskCtrl; // OTL-задача задания
    property CanShowResult: boolean read FCanShowResult write FCanShowResult; // можно ли показать результат (для поиска)
    property TaskIntf: IRunTask read FTaskIntf write FTaskIntf;  // какой интерфейс выполняет задачу
    property Command: WideString read FCommand write FCommand;
    property Params: WideString read FParams write FParams;
    property ResultList: TList<WideString> read FResultList;
  end;

  TfrmRunTasks = class(TForm)
    lcRunTasksGroup_Root: TdxLayoutGroup;
    lcRunTasks: TdxLayoutControl;
    lgExecute: TdxLayoutGroup;
    lgParams: TdxLayoutGroup;
    liInfo: TdxLayoutItem;
    vstRunTasks: TVirtualStringTree;
    liRunTasks: TdxLayoutItem;
    cbTasks: TcxComboBox;
    liTasks: TdxLayoutItem;
    btnStart: TcxButton;
    liStart: TdxLayoutItem;
    btnStop: TcxButton;
    liStop: TdxLayoutItem;
    btnShowResult: TcxButton;
    liShowResult: TdxLayoutItem;
    beCommand: TcxButtonEdit;
    liCommand: TdxLayoutItem;
    beParams: TcxButtonEdit;
    liParams: TdxLayoutItem;
    odExeFile: TOpenDialog;
    dpResult: TdxDockPanel;
    dxFloatDockSite1: TdxFloatDockSite;
    vstResults: TVirtualStringTree;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure vstRunTasksGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstRunTasksFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure cbTasksPropertiesChange(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure vstRunTasksMeasureItem(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; var NodeHeight: TDimension);
    procedure btnStopClick(Sender: TObject);
    procedure vstRunTasksChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vstRunTasksDrawText(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
    procedure btnShowResultClick(Sender: TObject);
    procedure vstResultsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstResultsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
  private
    FCallbackProc: TProc<WideString>;
    FIntfList: TInterfaceList;
    procedure DoCallbackProc(AMsg: WideString);
    procedure btnSelectDir(Sender: TObject; AButtonIndex: Integer);
    procedure btnSelectExeFile(Sender: TObject; AButtonIndex: Integer);
    procedure ChangeStatus(AObj: TRunTaskRecord; AStatus: TRunTaskStatus; AMsg: WideString);
    { Private declarations }
  public
    { Public declarations }
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
    procedure initRunTasks(AFindInDir: IRunTaskFindInDir;
                           AFindInExeFile: IRunTaskFindInExeFile;
                           AShellExecute: IRunTaskShellExecute);
    property IntfList: TInterfaceList read FIntfList write FIntfList;
  end;

var
  frmRunTasks: TfrmRunTasks;

implementation

uses
  math;

const RunTaskStatusStr: array[TRunTaskStatus] of string = ('', 'Выполняется', 'Прервано', 'Закончено', 'Ошибка');

{$R *.dfm}

procedure TfrmRunTasks.btnSelectDir(Sender: TObject; AButtonIndex: Integer);
var
  fo: TFileOpenDialog;
  curDir: string;
begin
  fo := TFileOpenDialog.Create(Self);
  try
    fo.Options := [fdoPickFolders];
    curDir := TcxButtonEdit(Sender).Text;
    if DirectoryExists(curDir) then
      fo.DefaultFolder := curDir;

    if fo.Execute then
      TcxButtonEdit(Sender).Text := fo.FileName;
  finally
    FreeAndNil(fo);
  end;
end;

procedure TfrmRunTasks.btnSelectExeFile(Sender: TObject; AButtonIndex: Integer);
begin
  if odExeFile.Execute then
    beCommand.Text := odExeFile.FileName;
end;

procedure TfrmRunTasks.btnShowResultClick(Sender: TObject);
var
  obj: TRunTaskRecord;
  robj: TResultRecord;
  i: integer;
  use1Column: boolean;
  curValue: WideString;
begin
  obj := vstRunTasks.CurrentObj<TRunTaskRecord>;
  if Assigned(obj) and obj.CanShowResult then
  begin
    dpResult.Show;
    vstResults.BeginUpdate;
    try
      vstResults.Clear;
      use1Column := Supports(obj.TaskIntf, IRunTaskFindInDir);
      if use1Column then
      begin
        vstResults.Header.Columns[0].Text := 'Файл';
        vstResults.Header.Columns[1].Options := vstResults.Header.Columns[1].Options - [coVisible];
      end
        else
      begin
        vstResults.Header.Columns[0].Text := 'Текст для поиска';
        vstResults.Header.Columns[1].Options := vstResults.Header.Columns[1].Options + [coVisible];
      end;

      for i := 0 to obj.ResultList.Count - 1 do
      begin
        curValue := obj.ResultList[i];
        robj := vstResults.Add<TResultRecord>;
        if Assigned(robj) then
        begin
          if use1Column then
            robj.FirstValue := curValue
          else begin
            robj.SecondValue := copy(curValue, 1, pos('=', curValue) - 1);
            robj.FirstValue := copy(curValue, pos('=', curValue) + 1, length(curValue));
          end;
        end;
      end;
    finally
      vstResults.EndUpdate;
    end;
  end
    else
    dpResult.Hide;
end;

procedure TfrmRunTasks.ChangeStatus(AObj: TRunTaskRecord; AStatus: TRunTaskStatus; AMsg: WideString);
var
  curArray: TArray<WideString>;
begin
  DoCallbackProc(AMsg);
  if Assigned(AObj) then
  begin
    TThread.Synchronize(nil, procedure
    var
      i: integer;
    begin
      AObj.Status := AStatus;
      if Assigned(liStop) and (vstRunTasks.FocusedNode = AObj.Node) then
        liStop.Visible := false;
      if AStatus in [rtsBreak, rtsFinish] then
      begin
        AObj.dtEnd := Now;
        if supports(AObj.TaskIntf, IRunTaskFindInDir) then
        begin
          AObj.ResultList.Clear;
          curArray := IRunTaskFindInDir(AObj.TaskIntf).ResultList;
          for i := Low(curArray) to High(curArray) do
            AObj.ResultList.Add(curArray[i]);
        end
          else if supports(AObj.TaskIntf, IRunTaskFindInExeFile) then
        begin
          AObj.ResultList.Clear;
          curArray := IRunTaskFindInExeFile(AObj.TaskIntf).ResultList;
          for i := Low(curArray) to High(curArray) do
            AObj.ResultList.Add(curArray[i]);
        end
      end;
      vstRunTasks.InvalidateNode(AObj.Node);
    end);
  end;
end;

procedure TfrmRunTasks.btnStartClick(Sender: TObject);
var
  obj: TRunTaskRecord;
  command, params, infocommand, infoparams: WideString;
  curIntf: IInterface;

  function CheckParams: boolean;
  begin
    Result := false;
    if Supports(curIntf, IRunTaskFindInDir) then
      result := true
    else if Supports(curIntf, IRunTaskFindInExeFile) then
    begin
      Result := FileExists(command);
      if Result then
        Result := ExtractFileExt(command) = '.exe';
      if Result then
        Result := trim(params) <> '';
    end
      else if Supports(curIntf, IRunTaskShellExecute) then
        Result := trim(command) <> '';
  end;

  function iif_str(match: boolean; true_res: string; false_res: string): string;
  begin
    if match then
      Result := true_res
    else
      Result := false_res;
  end;

begin
  command := trim(beCommand.Text);
  params := trim(beParams.Text);
  curIntf := FIntfList[cbTasks.ItemIndex];
  if CheckParams then
  begin
    vstRunTasks.BeginUpdate;
    try
      obj := vstRunTasks.Add<TRunTaskRecord>;
      vstRunTasks.MultiLine[obj.Node] := true;
      infocommand := command;
      infoparams := params;
      obj.info := cbTasks.Text + '. ' + liCommand.CaptionOptions.Text + ': ' + command + '. ' +
                  liParams.CaptionOptions.Text + ': ' + params;
      if supports(curIntf, IRunTaskFindInDir) then
      begin
        if (infocommand = '') or (infoparams = '') then
          obj.info := cbTasks.Text + '. ' + liCommand.CaptionOptions.Text +
          iif_str(infocommand = '', ': локальные диски. ', ': ' + command + '. ') +
          liParams.CaptionOptions.Text +
          iif_str(infoparams = '', ': все файлы', ': ' + params);
        obj.CanShowResult := true;
        IRunTaskFindInDir(curIntf).SetCallbacks(
        procedure(AMsg: WideString)  //StartCallback
        begin
          ChangeStatus(obj, rtsExecute, AMsg);
        end,
        nil,                         //RunCallback
        procedure(AMsg: WideString)  //BreakCallback
        begin
          ChangeStatus(obj, rtsBreak, AMsg);
        end,
        procedure(AMsg: WideString)  //FinishCallback
        begin
          ChangeStatus(obj, rtsFinish, AMsg);
        end,
        nil                          //SyncCallback
        );
        obj.TaskIntf := IRunTaskFindInDir(curIntf);
        obj.Command := command;
        obj.Params := params;
        obj.TaskCtrl := IRunTaskFindInDir(curIntf).Start(command, params);
      end
        else if supports(curIntf, IRunTaskFindInExeFile) then
      begin
        obj.CanShowResult := true;
        IRunTaskFindInExeFile(curIntf).SetCallbacks(
        procedure(AMsg: WideString)  //StartCallback
        begin
          ChangeStatus(obj, rtsExecute, AMsg);
        end,
        procedure(AMsg: WideString)  //BreakCallback
        begin
          ChangeStatus(obj, rtsBreak, AMsg);
        end,
        procedure(AMsg: WideString)  //ErrorCallback
        begin
          ChangeStatus(obj, rtsError, AMsg);
        end,
        procedure(AMsg: WideString)  //FinishCallback
        begin
          ChangeStatus(obj, rtsFinish, AMsg);
        end
        );
        obj.TaskIntf := IRunTaskFindInExeFile(curIntf);
        obj.Command := command;
        obj.Params := params;
        obj.TaskCtrl := IRunTaskFindInExeFile(curIntf).Start(command, params);
      end
        else if supports(curIntf, IRunTaskShellExecute) then
      begin
        obj.CanShowResult := false;
        IRunTaskShellExecute(curIntf).SetCallbacks(
        procedure(AMsg: WideString)  //StartCallback
        begin
          ChangeStatus(obj, rtsExecute, AMsg);
        end,
        procedure(AMsg: WideString)  //BreakCallback
        begin
          ChangeStatus(obj, rtsBreak, AMsg);
        end,
        procedure(AMsg: WideString)  //ErrorCallback
        begin
          ChangeStatus(obj, rtsError, AMsg);
        end,
        procedure(AMsg: WideString)  //FinishCallback
        begin
          ChangeStatus(obj, rtsFinish, AMsg);
        end
        );
        obj.TaskIntf := IRunTaskShellExecute(curIntf);
        obj.Command := command;
        obj.Params := params;
        obj.TaskCtrl := IRunTaskShellExecute(curIntf).Start(command, params);
      end;
    finally
      vstRunTasks.EndUpdate;
    end;
  end;
end;

procedure TfrmRunTasks.btnStopClick(Sender: TObject);
var
  obj: TRunTaskRecord;
begin
  obj := vstRunTasks.CurrentObj<TRunTaskRecord>;
  if Assigned(obj) then
  begin
    if obj.Status = rtsExecute then
      obj.TaskIntf.Stop(obj.TaskCtrl);
  end;
end;

procedure TfrmRunTasks.cbTasksPropertiesChange(Sender: TObject);
var
  curIntf: IInterface;
begin
  curIntf := FIntfList[cbTasks.ItemIndex];
  liInfo.CaptionOptions.Text := IRunTask(curIntf).Info;
  beCommand.Text := '';
  beParams.Text := '';
  if Supports(curIntf, IRunTaskFindInDir) then
  begin
    liCommand.CaptionOptions.Text := 'Каталог';
    liParams.CaptionOptions.Text := 'Расширения через запятую';
    beCommand.Properties.OnButtonClick := btnSelectDir;
    beCommand.Properties.Buttons[0].Visible := true;
    beParams.Properties.Buttons[0].Visible := false;
  end
    else if Supports(curIntf, IRunTaskFindInExeFile) then
  begin
    liCommand.CaptionOptions.Text := 'Путь к exe-файлу';
    liParams.CaptionOptions.Text := 'Текст для поиска';
    beCommand.Properties.OnButtonClick := btnSelectExeFile;
    beCommand.Properties.Buttons[0].Visible := true;
    beParams.Properties.Buttons[0].Visible := false;
  end
    else if Supports(curIntf, IRunTaskShellExecute) then
  begin
    liCommand.CaptionOptions.Text := 'Команда для выполнения';
    liParams.CaptionOptions.Text := 'Рабочая директория';
    beCommand.Properties.Buttons[0].Visible := false;
    beParams.Properties.Buttons[0].Visible := true;
    beParams.Properties.OnButtonClick := btnSelectDir;
  end
end;

procedure TfrmRunTasks.DoCallbackProc(AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
  TThread.Synchronize(nil, procedure
  begin
    FCallbackProc(AMsg);
  end);
end;

procedure TfrmRunTasks.FormCreate(Sender: TObject);
begin
  vstRunTasks.NodeDataSize := SizeOf(TRunTaskRecord);
  FIntfList := TInterfaceList.Create;
end;

procedure TfrmRunTasks.FormDestroy(Sender: TObject);
var
  obj: TRunTaskRecord;
  node: PVirtualNode;
begin
  node := vstRunTasks.GetFirst;
  while Assigned(node) do
  begin
    obj := vstRunTasks.Obj<TRunTaskRecord>(node);
    if Assigned(obj) and (obj.Status = rtsExecute) and Assigned(obj.TaskIntf) then
    begin
      obj.TaskIntf.Stop(obj.TaskCtrl);
    end;
    node := vstRunTasks.GetNext(node);
  end;
  FreeAndNil(FIntfList);
end;

procedure TfrmRunTasks.initRunTasks(AFindInDir: IRunTaskFindInDir;
  AFindInExeFile: IRunTaskFindInExeFile; AShellExecute: IRunTaskShellExecute);
begin
  FIntfList.Clear;
  if Assigned(AFindInDir) then
  begin
    FIntfList.Add(AFindInDir);
    cbTasks.Properties.Items.Add(AFindInDir.GetDescription);
  end;
  if Assigned(AFindInExeFile) then
  begin
    FIntfList.Add(AFindInExeFile);
    cbTasks.Properties.Items.Add(AFindInExeFile.GetDescription);
  end;
  if Assigned(AShellExecute) then
  begin
    FIntfList.Add(AShellExecute);
    cbTasks.Properties.Items.Add(AShellExecute.GetDescription);
  end;
  if cbTasks.Properties.Items.Count > 0 then
  begin
    cbTasks.ItemIndex := 0;
    liInfo.CaptionOptions.Text := IRunTask(FIntfList[0]).Info;
  end;
end;

procedure TfrmRunTasks.vstResultsFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  obj: TResultRecord;
begin
  obj := Sender.Obj<TResultRecord>(Node);
  if Assigned(obj) then
    FreeAndNil(obj);
end;

procedure TfrmRunTasks.vstResultsGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  obj: TResultRecord;
begin
  CellText := '';
  obj := Sender.Obj<TResultRecord>(Node);
  if Assigned(obj) then
  begin
    case Column of
      0: CellText := obj.FirstValue;
      1: CellText := obj.SecondValue;
    end;
  end;
end;

procedure TfrmRunTasks.vstRunTasksChange(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  obj: TRunTaskRecord;
begin
  obj := Sender.Obj<TRunTaskRecord>(Node);
  if Assigned(obj) then
  begin
    liShowResult.Visible := obj.CanShowResult;
    liStop.Visible := obj.Status = rtsExecute;
    if dpResult.Visible then
      btnShowResultClick(btnShowResult);
  end
    else
    dpResult.Hide;
end;

procedure TfrmRunTasks.vstRunTasksDrawText(Sender: TBaseVirtualTree;
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

procedure TfrmRunTasks.vstRunTasksFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  obj: TRunTaskRecord;
begin
  obj := Sender.Obj<TRunTaskRecord>(Node);
  if Assigned(obj) then
    FreeAndNil(obj);
end;

procedure TfrmRunTasks.vstRunTasksGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  obj: TRunTaskRecord;
begin
  CellText := '';
  obj := Sender.Obj<TRunTaskRecord>(Node);
  if Assigned(obj) then
  begin
    case Column of
      0: CellText := DateTimeToStr(obj.dtStart);
      1: if obj.Status in [rtsBreak, rtsFinish] then
           CellText := DateTimeToStr(obj.dtEnd);
      2: CellText := obj.info;
      3: CellText := RunTaskStatusStr[obj.Status];
    end;
  end;
end;

procedure TfrmRunTasks.vstRunTasksMeasureItem(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; var NodeHeight: TDimension);
var
  maxNodeHeight: TDimension;
  i: integer;
begin
  maxNodeHeight := vstRunTasks.DefaultNodeHeight;
  for i := 0 to Sender.Header.Columns.Count - 1 do
    maxNodeHeight := Max(maxNodeHeight, vstRunTasks.ComputeNodeHeight(TargetCanvas, Node, i, vstRunTasks.Text[Node, i]));
  if maxNodeHeight > vstRunTasks.DefaultNodeHeight then
    NodeHeight := vstRunTasks.DefaultNodeHeight * (1 + maxNodeHeight div vstRunTasks.DefaultNodeHeight);
end;

{ TRunTaskRecord }

constructor TRunTaskRecord.Create;
begin
  inherited;
  FDTStart := Now;
  FDTEnd := Now;
  FStatus := rtsNone;
  FInfo := '';
  FCanShowResult := false;
  FTaskCtrl := nil;
  FTaskIntf := nil;
  FResultList := TList<WideString>.Create;
  FCommand := '';
  FParams := '';
end;

destructor TRunTaskRecord.Destroy;
begin
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate(3000);
  if Assigned(FTaskIntf) then
    FTaskIntf := nil;
  FreeAndNil(FResultList);
  inherited;
end;

{ TResultRecord }

constructor TResultRecord.Create;
begin
  inherited;
  FFirstValue := '';
  FSecondValue := '';
end;

end.
