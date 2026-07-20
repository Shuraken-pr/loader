unit uRunTasks;

{$I pool_config.inc}

(*
Время запуска
Время окончания
Информация о задании
Статус
*)

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, intf_tasks, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxLayoutContainer,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, cxClasses, dxLayoutControl, cxVirtualTreeListHelper, System.Generics.Collections,
  dxLayoutcxEditAdapters, dxLayoutControlAdapters, cxContainer, cxEdit,
  Vcl.Menus, cxButtonEdit, Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit,
{$ifdef use_otl}
  OtlTaskControl, OtlTask,
{$endif}
  cxDropDownEdit, IOUtils, cxPC, dxDockControl, dxDockPanel, dxCoreGraphics,
  cxFilter, cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL,
  cxTLdxBarBuiltInMenu, cxInplaceContainer, cxTLData;

type
  TRunTaskStatus = (rtsNone, rtsExecute, rtsBreak, rtsFinish, rtsError);

  TResultRecord = class(TVTBaseRecord)
  private
    FFirstValue: WideString;
    FSecondValue: WideString;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    property FirstValue: WideString read FFirstValue write FFirstValue;
    property SecondValue: WideString read FSecondValue write FSecondValue;
  end;

  TRunTaskRecord = class(TVTBaseRecord)
  private
    FID: integer;
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
    constructor Create(AParent: TVTBase); override;
    destructor Destroy; override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
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
    vtlRunTasks: TcxVirtualTreeList;
    liRunTasks: TdxLayoutItem;
    colDTStart: TcxTreeListColumn;
    colDTEnd: TcxTreeListColumn;
    colInfo: TcxTreeListColumn;
    colStatus: TcxTreeListColumn;
    vtlResults: TcxVirtualTreeList;
    colFile: TcxTreeListColumn;
    colValue: TcxTreeListColumn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbTasksPropertiesChange(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnShowResultClick(Sender: TObject);
    procedure vtlRunTasksFocusedNodeChanged(Sender: TcxCustomTreeList;
      APrevFocusedNode, AFocusedNode: TcxTreeListNode);
  private
    FCallbackProc: TProc<WideString>;
    FIntfList: TInterfaceList;
    FDSResults: TVTLoadAllDataSource<TResultRecord>;
    FDSRunTasks: TVTLoadAllDataSource<TRunTaskRecord>;
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
  obj := FDSRunTasks.CurrentObj;
  if Assigned(obj) and obj.CanShowResult then
  begin
    dpResult.Show;
    vtlResults.BeginUpdate;
    try
      FDSResults.Clear;
      use1Column := Supports(obj.TaskIntf, IRunTaskFindInDir);
      if use1Column then
      begin
        vtlResults.Columns[0].Caption.Text := 'Файл';
        vtlResults.Columns[1].Visible := false;
      end
        else
      begin
        vtlResults.Columns[0].Caption.Text := 'Текст для поиска';
        vtlResults.Columns[1].Visible := true;
      end;

      for i := 0 to obj.ResultList.Count - 1 do
      begin
        curValue := obj.ResultList[i];
        robj := FDSResults.InsertRecordHandle(FDSResults.RootHandle, true);
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
      FDSResults.DataChanged;
      vtlResults.EndUpdate;
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
      if Assigned(liStop) and (FDSRunTasks.CurrentObj <> nil) and (FDSRunTasks.CurrentObj.FID = AObj.FID) then
        liStop.Visible := false;
      if AStatus in [rtsBreak, rtsFinish] then
      begin
        AObj.dtEnd := Now;
        if supports(AObj.TaskIntf, IRunTaskFindInExeFile) then
        begin
          AObj.ResultList.Clear;
          curArray := IRunTaskFindInExeFile(AObj.TaskIntf).ResultList;
          for i := Low(curArray) to High(curArray) do
            AObj.ResultList.Add(curArray[i]);
        end
      end;
      FDSRunTasks.DataChanged;
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
    vtlRunTasks.BeginUpdate;
    try
      obj := FDSRunTasks.InsertRecordHandle(FDSRunTasks.RootHandle, true);
      obj.FID := FDSRunTasks.RootHandle.ChildCount;
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
        nil,
        procedure(AMsg: WideString)  //BreakCallback
        begin
          ChangeStatus(obj, rtsBreak, AMsg);
        end,
        procedure(AMsg: WideString)  //FinishCallback
        begin
          ChangeStatus(obj, rtsFinish, AMsg);
        end,
        procedure(APath: WideString)
        begin
          if Assigned(obj) then //записываем результат.
            obj.ResultList.Add(APath);
        end //SyncCallback
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
      FDSRunTasks.DataChanged;
      vtlRunTasks.EndUpdate;
    end;
  end;
end;

procedure TfrmRunTasks.btnStopClick(Sender: TObject);
var
  obj: TRunTaskRecord;
begin
  obj := FDSRunTasks.CurrentObj;
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
  FIntfList := TInterfaceList.Create;
  FDSResults := TVTLoadAllDataSource<TResultRecord>.Create(vtlResults);
  FDSRunTasks := TVTLoadAllDataSource<TRunTaskRecord>.Create(vtlRunTasks);
end;

procedure TfrmRunTasks.FormDestroy(Sender: TObject);
var
  obj: TRunTaskRecord;
begin
  for var i := 0 to FDSRunTasks.RootHandle.ChildCount - 1 do
  begin
    obj := TRunTaskRecord(FDSRunTasks.RootHandle[i]);
    if Assigned(obj) and (obj.Status = rtsExecute) and Assigned(obj.TaskIntf) then
    begin
      obj.TaskIntf.Stop(obj.TaskCtrl);
    end;
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

procedure TfrmRunTasks.vtlRunTasksFocusedNodeChanged(Sender: TcxCustomTreeList;
  APrevFocusedNode, AFocusedNode: TcxTreeListNode);
var
  obj: TRunTaskRecord;
begin
  obj := FDSRunTasks.Obj(AFocusedNode);
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

{ TRunTaskRecord }

constructor TRunTaskRecord.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FID := 0;
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

function TRunTaskRecord.GetValue(ColIdx: Integer): Variant;
begin
  Result := null;
  case ColIdx of
    0: Result := dtStart;
    1: if Status in [rtsBreak, rtsFinish] then
         Result := dtEnd;
    2: Result := info;
    3: Result := RunTaskStatusStr[Status];
  end;
end;

procedure TRunTaskRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  inherited;
  case ColIdx of
    0: dtStart := AValue;
    1: dtEnd := AValue;
    2: info := AValue;
    3: Status := TRunTaskStatus(integer(AValue));
  end;
end;

{ TResultRecord }

constructor TResultRecord.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FFirstValue := '';
  FSecondValue := '';
end;

function TResultRecord.GetValue(ColIdx: Integer): Variant;
begin
  Result := null;
  case ColIdx of
    0: Result := FFirstValue;
    1: Result := FSecondValue;
  end;
end;

procedure TResultRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  inherited;

end;

end.
