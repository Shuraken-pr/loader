unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxLayoutcxEditAdapters, dxLayoutControlAdapters,
  dxLayoutContainer, cxContainer, cxEdit, Vcl.Menus, cxSplitter,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, Vcl.StdCtrls, cxButtons, cxTextEdit, cxMaskEdit, cxSpinEdit,
  cxClasses, dxLayoutControl, System.Generics.Collections, VSTHelper,
  System.SyncObjs, System.Threading;

type
  TfrmSimpleNumbers = class(TForm)
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    lgMain: TdxLayoutGroup;
    seMaxLimSimpleNumbers: TcxSpinEdit;
    liMaxLimSimpleNumbers: TdxLayoutItem;
    btnRun: TcxButton;
    liRun: TdxLayoutItem;
    vstThread1: TVirtualStringTree;
    liThread1: TdxLayoutItem;
    lgLog: TdxLayoutGroup;
    spThreads: TcxSplitter;
    liSeparator: TdxLayoutItem;
    vstThread2: TVirtualStringTree;
    liThread2: TdxLayoutItem;
    procedure btnRunClick(Sender: TObject);
    procedure vstThread1GetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FCallbackProc: TProc<WideString>;
    FList1: TList<integer>;
    FList2: TList<integer>;
    procedure DoCallbackProc(AMsg: WideString);
    procedure CheckAndFillSimpleNumbers(var NextNum: Integer; MaxNum: Integer;
      var ASNLists: TStringList; var ResultList: TList<integer>; ListsCS: TCriticalSection;
      const AVST: TVirtualStringTree; const AFileName: string);
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
  vst1, vst2: TVirtualStringTree;
begin
  if isSilent then
  begin
    vst1 := nil;
    vst2 := nil;
  end
    else
  begin
    vst1 := vstThread1;
    vst2 := vstThread2;
    vst1.Clear;
    vst2.Clear;
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
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, Flist1, ListsCS, vst1, 'thread1.txt');
      end);
      thread1.FreeOnTerminate := false;

      thread2 := TThread.CreateAnonymousThread(procedure
      begin
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, Flist2, ListsCS, vst2, 'thread2.txt');
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
  MaxNum: Integer; var ASNLists: TStringList; var ResultList: TList<integer>; ListsCS: TCriticalSection;
  const AVST: TVirtualStringTree; const AFileName: string);
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
        FList.Add(IntToStr(ANum));
        ListsCS.Enter;
        try
          ASNLists.Add(IntToStr(ANum));
          ResultList.add(ANum);
        finally
          ListsCS.Leave;
        end;
      end;
    until False;
  finally
    if FList.Count > 0 then
    begin
      FList.SaveToFile(AFileName);
      if Assigned(AVST) then
        TThread.Synchronize(nil, procedure
        begin
          AVST.RootNodeCount := FList.Count;
        end);
    end;
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

procedure TfrmSimpleNumbers.vstThread1GetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
begin
  CellText := '';
  if (Sender.Tag = 1) and (int(node.Index) <= FList1.Count - 1) then
    CellText := IntToStr(flist1[Node.Index])
  else if (Sender.Tag = 2) and (int(node.Index) <= FList2.Count - 1) then
    CellText := IntToStr(flist2[Node.Index]);
end;

end.
