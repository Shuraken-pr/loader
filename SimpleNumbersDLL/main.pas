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
    { Private declarations }
    procedure CheckAndFillSimpleNumbers(const crit: TCriticalSection; var NumList: TList<Integer>;
      var ASNLists: TStringList; const AVST: TVirtualStringTree; const AFileName: string);
  public
    { Public declarations }
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
  i: integer;
  thread1, thread2: TThread;
  lthreads: TStringList;
  cs: TCriticalSection;
  NL: TList<integer>;
  delta: TDateTime;
  vst1, vst2: TVirtualStringTree;
begin
  NL := TList<integer>.Create;
  try
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
    NL.Add(1);
    NL.Add(2);
    i := 3;
    while i < maxNum do
    begin
      NL.Add(i);
      inc(i, 2);
    end;

    cs := TCriticalSection.Create;
    try
      lthreads := TStringList.Create;
      try
        thread1 := TThread.CreateAnonymousThread(procedure
        begin
          CheckAndFillSimpleNumbers(cs, NL, lthreads, vst1, 'thread1.txt');
        end
        );
        thread1.FreeOnTerminate := false;

        thread2 := TThread.CreateAnonymousThread(procedure
        begin
          CheckAndFillSimpleNumbers(cs, NL, lthreads, vst2, 'thread2.txt');
        end
        );
        thread2.FreeOnTerminate := false;
        Screen.Cursor := crSQLWait;
        delta := Now;
        DoCallbackProc(Format('Расчёт простых чисел двумя потоками запущен. Диапазон: 1..%d', [maxNum]));
        try
          thread1.Start;
          thread2.Start;

          thread1.WaitFor;
          thread2.WaitFor;

          if Assigned(thread1) then
            FreeAndNil(thread1);
          if Assigned(thread2) then
            FreeAndNil(thread2);
        finally
          Screen.Cursor := crDefault;
          DoCallbackProc(Format('Расчёт простых чисел двумя потоками завершён за %s',
          [FormatDateTime('hh:nn:ss.zzz', Now - delta)]));
        end;
      finally
        if lthreads.Count > 0 then
          lthreads.SaveToFile('threads.txt');
        FreeAndNil(lthreads);
      end;
    finally
      FreeAndNil(cs);
    end;
  finally
    FreeAndNil(NL);
  end;
end;

procedure TfrmSimpleNumbers.btnRunClick(Sender: TObject);
var
  maxNum: integer;
begin
  maxNum := seMaxLimSimpleNumbers.Value;
  Run(maxNum);
end;

procedure TfrmSimpleNumbers.CheckAndFillSimpleNumbers(const crit: TCriticalSection;
  var NumList: TList<Integer>;  var ASNLists: TStringList;
  const AVST: TVirtualStringTree; const AFileName: string);
var
  ANum: integer;
  FList: TStringList;
begin
  FList := TStringList.Create;
  try
    while NumList.Count > 0 do
    begin
      crit.Enter;
      try
        ANum := NumList[0];
        NumList.Delete(0);
      finally
        crit.Leave;
      end;

      if CheckSimpleNumber(ANum) then
      begin
        FList.Add(IntToStr(ANum));
        if Assigned(AVST) then
          TThread.Synchronize(nil, procedure
          var
            sn: TVSTSimpleNum;
          begin
            if Assigned(AVST) then
            begin
              sn := AVST.Add<TVSTSimpleNum>;
              if Assigned(sn) then
                sn.SimpleNumber := ANum;
            end;
          end);
        crit.Enter;
        try
          ASNLists.Add(IntToStr(ANum));
        finally
          crit.Leave;
        end;
      end;
    end;
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
