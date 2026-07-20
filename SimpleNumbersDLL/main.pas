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
  dxSkinOffice2013LightGray, dxSkinVS2010;

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
    dxLayoutItem1: TdxLayoutItem;
    colNumberT1: TcxTreeListColumn;
    colNumberT2: TcxTreeListColumn;
    procedure btnRunClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FCallbackProc: TProc<WideString>;
    FList1: TList<integer>;
    FList2: TList<integer>;
    procedure vtlGetChildCount(Sender: TcxCustomTreeList;
      AParentNode: TcxTreeListNode; var ACount: Integer);
    procedure vtlGetNodeValue(Sender: TcxCustomTreeList;
      ANode: TcxTreeListNode; AColumn: TcxTreeListColumn; var AValue: Variant);
    procedure DoCallbackProc(AMsg: WideString);
    procedure CheckAndFillSimpleNumbers(var NextNum: Integer; MaxNum: Integer;
      var ASNLists: TStringList; var ResultList: TList<integer>;
      ListsCS: TCriticalSection; const AFileName: string);
  public
    property CallbackProc: TProc<WideString> read FCallbackProc write FCallbackProc;
    procedure Run(MaxNum: integer; isSilent: boolean = false);
  end;

var
  frmSimpleNumbers: TfrmSimpleNumbers;

implementation

uses Math;

{$R *.dfm}

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
    vtl2.Clear;
    vtl2.Clear;
  end;

  NextNum := 0;
  FList1.Clear;
  FList2.Clear;
  ListsCS := TCriticalSection.Create;
  try
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
  end;
end;

procedure TfrmSimpleNumbers.btnRunClick(Sender: TObject);
var
  maxNum: integer;
begin
  maxNum := seMaxLimSimpleNumbers.Value;
  Run(maxNum);
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

procedure TfrmSimpleNumbers.DoCallbackProc(AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
    FCallbackProc(AMsg);
end;

procedure TfrmSimpleNumbers.FormCreate(Sender: TObject);
begin
  FCallbackProc := nil;
  FList1 := TList<integer>.Create;
  FList2 := TList<integer>.Create;
end;

procedure TfrmSimpleNumbers.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FList1);
  FreeAndNil(FList2);
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
