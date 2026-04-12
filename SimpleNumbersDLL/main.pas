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
  TVSTSimpleNum = class(TBaseRecord)
  private
    FSimpleNumber: integer;
  public
    property SimpleNumber: integer read FSimpleNumber write FSimpleNumber;
  end;

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
    procedure vstThread1FreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vstThread1GetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure FormCreate(Sender: TObject);
  private
    FCallbackProc: TProc<WideString>;
    procedure DoCallbackProc(AMsg: WideString);
    procedure CheckAndFillSimpleNumbers(var NextNum: Integer; MaxNum: Integer;
      var ASNLists: TStringList; ListsCS: TCriticalSection;
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
  ListsCS := TCriticalSection.Create;
  try
    lthreads := TStringList.Create;
    try
      thread1 := TThread.CreateAnonymousThread(procedure
      begin
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, ListsCS, vst1, 'thread1.txt');
      end);
      thread1.FreeOnTerminate := false;

      thread2 := TThread.CreateAnonymousThread(procedure
      begin
        CheckAndFillSimpleNumbers(NextNum, MaxNum, lthreads, ListsCS, vst2, 'thread2.txt');
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
  MaxNum: Integer; var ASNLists: TStringList; ListsCS: TCriticalSection;
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
        if Assigned(AVST) then
          TThread.Synchronize(nil, procedure
          var
            sn: TVSTSimpleNum;
          begin
            sn := AVST.Add<TVSTSimpleNum>;
            if Assigned(sn) then
              sn.SimpleNumber := ANum;
          end);
        ListsCS.Enter;
        try
          ASNLists.Add(IntToStr(ANum));
        finally
          ListsCS.Leave;
        end;
      end;
    until False;
  finally
    if FList.Count > 0 then
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
  vstThread1.NodeDataSize := SizeOf(TVSTSimpleNum);
  vstThread2.NodeDataSize := SizeOf(TVSTSimpleNum);
  FCallbackProc := nil;
end;

procedure TfrmSimpleNumbers.vstThread1FreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  simpleNumber: TVSTSimpleNum;
begin
  simpleNumber := Sender.Obj<TVSTSimpleNum>(Node);
  if Assigned(simpleNumber) then
    FreeAndNil(simpleNumber);
end;

procedure TfrmSimpleNumbers.vstThread1GetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  simpleNumber: TVSTSimpleNum;
begin
  CellText := '';
  simpleNumber := Sender.Obj<TVSTSimpleNum>(Node);
  if Assigned(simpleNumber) then
    CellText := IntToStr(simpleNumber.SimpleNumber);
end;

end.
