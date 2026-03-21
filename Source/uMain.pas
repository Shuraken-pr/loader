unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxCore, dxRibbonSkins, dxRibbonCustomizationForm,
  System.Actions, Vcl.ActnList, System.ImageList, Vcl.ImgList, cxImageList,
  dxLayoutContainer, dxLayoutControl, cxClasses, dxBar, dxRibbon, vstHelper,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, DLLManager, intf_dll, intf_common, intf_tasks;

type
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
    procedure vstLogGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure vstLogFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure btnSimpleNumbersClick(Sender: TObject);
    procedure btnCalcPriceClick(Sender: TObject);
    procedure btnExplorerClick(Sender: TObject);
    procedure btnRunTasksClick(Sender: TObject);
  private
    { Private declarations }
    FDllManager: TDllManager;
    FSimpleNumbers: ISimpleNumbers;
    FCalcPrice: ICalcPrice;
    FRunTaskFindInDir: IRunTaskFindInDir;
    FRunTaskFindInExeFile: IRunTaskFindInExeFile;
    FRunTaskShellExecute: IRunTaskShellExecute;
    FExplorer: IExplorer;
    FRunTasks: IRunTasks;
    procedure CheckIntf<T: IDllIntf>(var AIntf: T; DI: TDLLInfo; dxButton: TdxBarLargeButton = nil);
    procedure AddMsg(const AMsg: WideString);
    procedure CheckIntfAndRun<T: IDllIntf>(Intf: T);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

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
    log.Msg := AMsg;
end;

procedure TfrmMain.btnCalcPriceClick(Sender: TObject);
begin
  CheckIntfAndRun<ICalcPrice>(FCalcPrice);
end;

procedure TfrmMain.btnExplorerClick(Sender: TObject);
begin
  if Assigned(FRunTaskFindInDir) then
    FExplorer.initFindIntf(FRunTaskFindInDir);
  CheckIntfAndRun<IExplorer>(FExplorer);
end;

procedure TfrmMain.btnRunTasksClick(Sender: TObject);
begin
  FRunTasks.initRunTasks(FRunTaskFindInDir, FRunTaskFindInExeFile, FRunTaskShellExecute);
  CheckIntfAndRun<IRunTasks>(FRunTasks);
end;

procedure TfrmMain.btnSimpleNumbersClick(Sender: TObject);
begin
  CheckIntfAndRun<ISimpleNumbers>(FSimpleNumbers);
end;

procedure TfrmMain.CheckIntf<T>(var AIntf: T; DI: TDLLInfo;
  dxButton: TdxBarLargeButton);
begin
  if dxButton <> nil then
    dxButton.Visible := ivNever;
  if FDllManager.Load<T>(DI, false) then
    AIntf := FDllManager.GetIntf<T>(DI)
  else
    AIntf := nil;
  if Assigned(AIntf) and (dxButton <> nil) then
  begin
    dxButton.Caption := AIntf.GetDescription;
    dxButton.Visible := ivAlways;
  end;
end;

procedure TfrmMain.CheckIntfAndRun<T>(Intf: T);
var
  intfRun: IDllIntfRun;
begin
  if Assigned(intf) and Supports(Intf, IDLLIntfRun, intfRun) then
    intfRun.Run(procedure(AMsg: WideString)
    begin
      AddMsg(AMsg);
    end, Application.Handle);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  vstLog.NodeDataSize := SizeOf(TVSTLog);
  FDllManager := TDllManager.Create;
  CheckIntf<ISimpleNumbers>(FSimpleNumbers, DISimpleNumbers, btnSimpleNumbers);
  CheckIntf<ICalcPrice>(FCalcPrice, DICalcPrice, btnCalcPrice);
  CheckIntf<IRunTaskFindInDir>(FRunTaskFindInDir, DIRunTaskFindInDir);
  CheckIntf<IRunTaskFindInExeFile>(FRunTaskFindInExeFile, DIRunTaskFindInExeFile);
  CheckIntf<IRunTaskShellExecute>(FRunTaskShellExecute, DIRunTaskShellExecute);
  CheckIntf<IExplorer>(FExplorer, DIExplorer, btnExplorer);
  CheckIntf<IRunTasks>(FRunTasks, DIRunTasks, btnRunTasks);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FSimpleNumbers) then
    FSimpleNumbers := nil;
  if Assigned(FCalcPrice) then
    FCalcPrice := nil;
  if Assigned(FRunTaskFindInDir) then
    FRunTaskFindInDir := nil;
  if Assigned(FRunTaskFindInExeFile) then
    FRunTaskFindInExeFile := nil;
  if Assigned(FRunTaskShellExecute) then
    FRunTaskShellExecute := nil;
  if Assigned(FExplorer) then
    FExplorer := nil;
  if Assigned(FRunTasks) then
    FRunTasks := nil;
  FreeAndNil(FDllManager);
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
  log := Sender.Obj<TVSTLog>(Node);
  if Assigned(log) then
    begin
    case column of
      0: CellText := FormatDateTime('dd.mm.yyyy hh:nn:ss', log.LogDate);
      1: CellText := log.Msg;
    end;
  end;
end;

end.
