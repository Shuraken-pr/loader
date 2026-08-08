unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxLayoutcxEditAdapters, dxLayoutControlAdapters,
  dxLayoutContainer, cxContainer, cxEdit, Vcl.Menus, cxSplitter,
  Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit, cxSpinEdit,
  cxClasses, dxLayoutControl, System.Generics.Collections,
  System.SyncObjs, System.Threading, cxFilter, cxCustomData, cxStyles,
  dxScrollbarAnnotations, cxTL, cxTLdxBarBuiltInMenu, cxInplaceContainer,
  cxTLData, dmSkins, dxSkinsCore, dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle, dxSkinOffice2007Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinVS2010, intf_dll_manager, frxDevDSIntf;

type
  TfrmSimpleNumbers = class(TForm)
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    lgMain: TdxLayoutGroup;
    seMaxLimSimpleNumbers: TcxSpinEdit;
    liMaxLimSimpleNumbers: TdxLayoutItem;
    btnRun: TcxButton;
    liRun: TdxLayoutItem;
    lgLog: TdxLayoutGroup;
    vtlThread1: TcxVirtualTreeList;
    liThread1: TdxLayoutItem;
    vtlThread2: TcxVirtualTreeList;
    liThread2: TdxLayoutItem;
    colNumberT1: TcxTreeListColumn;
    colNumberT2: TcxTreeListColumn;
    btnFastReport: TcxButton;
    liFastReport: TdxLayoutItem;
    pmFastReport: TPopupMenu;
    miFRDesigner: TMenuItem;
    miFRPreview: TMenuItem;
    procedure btnRunClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure miFRDesignerClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FCallbackProc: TProc<WideString>;
    FList1: TList<integer>;
    FList2: TList<integer>;
    FFRCntSplit1, FFRCntSplit2: integer;
    FFRTotalCount, FFRSplitValue: integer;
    FRunThreads: boolean;
    FDllManager: IDllManager;
    FIntfFR: IFrxDevDS;
    procedure CheckFastReport(ADllManager: IDllManager);
    procedure vtlGetChildCount(Sender: TcxCustomTreeList;
      AParentNode: TcxTreeListNode; var ACount: Integer);
    procedure vtlGetNodeValue(Sender: TcxCustomTreeList;
      ANode: TcxTreeListNode; AColumn: TcxTreeListColumn; var AValue: Variant);
    procedure DoCallbackProc(AMsg: WideString);
    procedure CheckAndFillSimpleNumbers(var NextNum: Integer; MaxNum: Integer;
      var ASNLists: TStringList; var ResultList: TList<integer>;
      ListsCS: TCriticalSection; const AFileName: string);
    function FRCustomFunction(AFuncName: WideString; ASourceName: WideString): variant;
    procedure Run(MaxNum: integer; isSilent: boolean = false);
  public
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
    property DLLManager: IDllManager read FDllManager write FDllManager;
    class procedure RunForm(MaxNum: integer; ACallbackProc: TProc<WideString>; ADLLManager: IDllManager; isSilent: boolean = false);
  end;

var
  frmSimpleNumbers: TfrmSimpleNumbers;

implementation


uses System.Math, System.IOUtils, System.StrUtils;

{$R *.dfm}

//Для выгрузки в FastReport, чтобы грузить по частям.
const DefaultSplitValue = 10000;

function CheckSimpleNumber(ANum: integer): boolean;
var
  i, sqrtNum: integer;
begin
  Result := true;
  if ANum <= 3 then
    exit;
  sqrtNum := trunc(Sqrt(ANum));
  for i := 2 to sqrtNum do
  begin
    if (ANum mod i) = 0 then
    begin
      result := false;
      exit;
    end;
  end;
end;

procedure TfrmSimpleNumbers.Run(MaxNum: integer; isSilent: boolean);
var
  thread1, thread2: TThread;
  lthreads: TStringList;
  NextNum: Integer;
  ListsCS: TCriticalSection;
  delta: TDateTime;
  vtl1, vtl2: TcxVirtualTreeList;
begin
  if isSilent then
  begin
    vtl1 := nil;
    vtl2 := nil;
  end
    else
  begin
    vtl1 := vtlThread1;
    vtl2 := vtlThread2;
    vtl1.Clear;
    vtl2.Clear;
  end;

  NextNum := 0;
  FList1.Clear;
  FList2.Clear;
  ListsCS := TCriticalSection.Create;
  try
    FRunThreads := true;
    lthreads := TStringList.Create;
    try
      thread1 := TThread.CreateAnonymousThread(procedure
      begin
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, Flist1, ListsCS, 'thread1.txt');
      end);
      thread1.FreeOnTerminate := false;

      thread2 := TThread.CreateAnonymousThread(procedure
      begin
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, Flist2, ListsCS, 'thread2.txt');
      end);
      thread2.FreeOnTerminate := false;

      Screen.Cursor := crSQLWait;
      delta := Now;
      DoCallbackProc('Расчёт простых чисел двумя потоками запущен. Диапазон: 1..' + IntToStr(maxNum));
      try
        thread1.Start;
        thread2.Start;

        thread1.WaitFor;
        thread2.WaitFor;

        FreeAndNil(thread1);
        FreeAndNil(thread2);
      finally
        if Assigned(vtl1) and Assigned(vtl2) then
        begin
          vtl1.OnGetChildCount := vtlGetChildCount;
          vtl1.OnGetNodeValue := vtlGetNodeValue;
          vtl2.OnGetChildCount := vtlGetChildCount;
          vtl2.OnGetNodeValue := vtlGetNodeValue;
          vtl1.FullRefresh;
          vtl2.FullRefresh;
        end;
        Screen.Cursor := crDefault;
        DoCallbackProc('Расчёт простых чисел двумя потоками завершён за '+
          FormatDateTime('hh:nn:ss.zzz', Now - delta));
      end;
    finally
      if lthreads.Count > 0 then
        lthreads.SaveToFile('threads.txt');
      FreeAndNil(lthreads);
    end;
  finally
    FreeAndNil(ListsCS);
    FRunThreads := false;
  end;
end;

class procedure TfrmSimpleNumbers.RunForm(MaxNum: integer;
  ACallbackProc: TProc<WideString>; ADLLManager: IDllManager;
  isSilent: boolean);
begin
  frmSimpleNumbers := TfrmSimpleNumbers.Create(nil);
  try
    if not isSilent then
    begin
      frmSimpleNumbers.CallbackProc := ACallbackProc;
      frmSimpleNumbers.DLLManager := ADLLManager;
      frmSimpleNumbers.ShowModal;
    end
      else
    begin
      frmSimpleNumbers.Run(MaxNum, true);
    end;
  finally
    FreeAndNil(frmSimpleNumbers);
  end;
end;

procedure TfrmSimpleNumbers.btnRunClick(Sender: TObject);
var
  maxNum: integer;
begin
  maxNum := seMaxLimSimpleNumbers.Value;
  Run(maxNum);
  liFastReport.Enabled := Assigned(FIntfFR) and Assigned(FList1) and Assigned(FList2);
end;

procedure TfrmSimpleNumbers.CheckAndFillSimpleNumbers(var NextNum: Integer;
  MaxNum: Integer; var ASNLists: TStringList; var ResultList: TList<integer>;
  ListsCS: TCriticalSection; const AFileName: string);
var
  ANum: integer;
  FList: TStringList;
  idx: Integer;
begin
  FList := TStringList.Create;
  try
    repeat
      // Атомарно получаем следующий индекс — без Delete(0) и без CS
      idx := TInterlocked.Increment(NextNum) - 1;

      case idx of
        0: ANum := 1;
        1: ANum := 2;
      else
        ANum := 3 + (idx - 2) * 2;  // 3, 5, 7, 9, ...
      end;
      if ANum > MaxNum then Break;

      if CheckSimpleNumber(ANum) then
      begin
        if Assigned(FList) then
          FList.Add(IntToStr(ANum));
        ListsCS.Enter;
        try
          if Assigned(ASNLists) then
            ASNLists.Add(IntToStr(ANum));
          if Assigned(ResultList) then
            ResultList.add(ANum);
        finally
          ListsCS.Leave;
        end;
      end;
    until False;
  finally
    if Assigned(FList) and (FList.Count > 0) then
      FList.SaveToFile(AFileName);
  end;
end;

procedure TfrmSimpleNumbers.CheckFastReport(ADllManager: IDllManager);
var
  intf: IInterface;
begin
  if not Assigned(FDllManager) then
    FDllManager := ADllManager;
  if not Assigned(FIntfFR) then
  begin
    intf := FDllManager.GetIntf(IFrxDevDS);
    if Supports(intf, IFrxDevDS, FIntfFR) then
      liFastReport.Visible := true;
  end;
end;

procedure TfrmSimpleNumbers.DoCallbackProc(AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
    FCallbackProc(AMsg);
end;

procedure TfrmSimpleNumbers.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  CanClose := not FRunThreads;
end;

procedure TfrmSimpleNumbers.FormCreate(Sender: TObject);
begin
  FCallbackProc := nil;
  FRunThreads := false;
  FList1 := TList<integer>.Create;
  FList2 := TList<integer>.Create;
  FDllManager := nil;
  FIntfFR := nil;
end;

procedure TfrmSimpleNumbers.FormDestroy(Sender: TObject);
begin
  FDllManager := nil;
  FIntfFR := nil;
  FreeAndNil(FList1);
  FreeAndNil(FList2);
end;

procedure TfrmSimpleNumbers.FormShow(Sender: TObject);
begin
  if Assigned(FDLLManager) then
    CheckFastReport(FDllManager);
end;

function TfrmSimpleNumbers.FRCustomFunction(AFuncName,
  ASourceName: WideString): variant;
var
  value: WideString;
  i, cnt: integer;
begin
  Result := null;
  if AFuncName = 'TotalCount' then
  begin
    Result := 0;
    if (ASourceName = 'List1') then
    begin
      if Assigned(FList1) then
        Result := FList1.Count
    end
      else if (ASourceName = 'List2') then
    begin
      if Assigned(FList2) then
        Result := FList2.Count;
    end;
  end
    else if AFuncName = 'AllValues' then
  begin
    value := '';
    if (ASourceName = 'List1') then
    begin
      if FileExists('thread1.txt') then
      begin
        value := TFile.ReadAllText('thread1.txt');
        value := ReplaceText(value, #13#10, ', ');
      end;
    end
      else if (ASourceName = 'List2') then
    begin
      if FileExists('thread2.txt') then
      begin
        value := TFile.ReadAllText('thread2.txt');
        value := ReplaceText(value, #13#10, ', ');
      end;
    end;
    Result := value;
  end
  //разобьём все значения по частям. Будем отталкиваться от списка, где значений больше.
    else if AFuncName = 'CountOfSplitAllValues' then
  begin
    Result := 1;
    if not TryStrToInt(ASourceName, cnt) then
      cnt := DefaultSplitValue;
    FFRSplitValue := cnt;
    if Assigned(FList1) and Assigned(FList2) then
    begin
      if FList1.Count > FList2.Count then
        Result := (FList1.Count div cnt) + 1
      else
        Result := (FList2.Count div cnt) + 1;
      FFRTotalCount := Result;
    end;
  end
    else if AFuncName = 'GetPartValues' then
  begin
    value := '';
    if ASourceName = 'List1' then
    begin
      if Assigned(FList1) then
      begin
        cnt := FFRCntSplit1;
        inc(FFRCntSplit1, FFRSplitValue);
        for i := cnt to FFRCntSplit1 - 1 do
        begin
          if i >= FList1.Count then
            break;
          if value = '' then
            value := FList1[i].ToString
          else
            value := value + ',' + FList1[i].ToString;
        end;
      end;
    end
      else if ASourceName = 'List2' then
    begin
      if Assigned(FList2) then
      begin
        cnt := FFRCntSplit2;
        inc(FFRCntSplit2, FFRSplitValue);
        for i := cnt to FFRCntSplit2 - 1 do
        begin
          if i >= FList2.Count then
            break;
          if value = '' then
            value := FList2[i].ToString
          else
            value := value + ',' + FList2[i].ToString;
        end;
      end;
    end;
    Result := value;
  end;
end;

procedure TfrmSimpleNumbers.miFRDesignerClick(Sender: TObject);
begin
  if Assigned(FIntfFR) then
  begin
    FFRCntSplit1 := 0;
    FFRCntSplit2 := 0;
    FFRTotalCount := 1;
    FFRSplitValue := DefaultSplitValue;
    FIntfFR.SetCustomFunction(FRCustomFunction);
    var ReportFile: string := ExtractFilePath(ParamStr(0)) + 'FastReportTemplates\SimpleNumbers.fr3';
    if TMenuItem(Sender).Tag = 0 then
      FIntfFR.DesignReport([], [], ReportFile)
    else
      FIntfFR.PreviewReport([], [], ReportFile);
  end;
end;

procedure TfrmSimpleNumbers.vtlGetChildCount(Sender: TcxCustomTreeList;
  AParentNode: TcxTreeListNode; var ACount: Integer);
begin
  ACount := 0;
  if Assigned(Sender) and Assigned(AParentNode) and (AParentNode.Level = -1) then
  begin
    if (Sender.Tag = 1) and Assigned(FList1) then
      ACount := FList1.Count
    else if (Sender.Tag = 2) and Assigned(FList2) then
      ACount := FList2.Count;
  end;
end;

procedure TfrmSimpleNumbers.vtlGetNodeValue(Sender: TcxCustomTreeList;
  ANode: TcxTreeListNode; AColumn: TcxTreeListColumn; var AValue: Variant);
begin
  AValue := null;
  if Assigned(Sender) and Assigned(ANode) and (ANode.Level = 0) then
  begin
    if (Sender.Tag = 1) and Assigned(FList1) then
      AValue := FList1[ANode.AbsoluteIndex]
    else if (Sender.Tag = 2) and Assigned(FList2) then
      AValue := FList2[ANode.AbsoluteIndex];
  end;
end;

end.
