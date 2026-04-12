library RunTaskFind;

{$I ..\..\Common\pool_config.inc}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  system.StrUtils,
{$ifdef use_otl}
  OtlTaskControl,
  OtlTask,
  uOmniThreadPoolManager in '..\..\common\uOmniThreadPoolManager.pas',
{$else}
  uAutonomiusThreadPool in '..\..\common\uAutonomiusThreadPool.pas',
{$endif}
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\common\intf_dll_manager.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas';

type
  /// <summary>
  /// Изолированный контекст одного сканирования.
  /// Создаётся заново при каждом Start() — гарантирует отсутствие
  /// гонок данных при повторных вызовах или одновременных сканах.
  /// </summary>
  TScanContext = class
  public
    ResultList: TList<WideString>;
    ExtList: TStringList;
    FileCount: Integer;
    LastCallbackTime: TDateTime;
    StartCallback: TProc<WideString>;
    RunCallback: TProc<WideString>;
    SyncCallback: TProc<WideString>;
    BreakCallback: TProc<WideString>;
    FinishCallback: TProc<WideString>;
    Terminated: boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TRunTaskFindInDir = class(TInterfacedObject, IDLLIntf, IRunTask, IRunTaskFindInDir)
  private
    FResultList: TList<WideString>;     // копируется сюда по завершении
    FThreadManager: TOmniThreadPoolManager;
    FTaskCtrl: TResultType;              // текущая активная задача
    FScanCtx: TScanContext;              // контекст текущего сканирования
    FStartCallback: TProc<WideString>;
    FRunCallback: TProc<WideString>;
    FSyncCallback: TProc<WideString>;
    FBreakCallback: TProc<WideString>;
    FFinishCallback: TProc<WideString>;
    procedure ScanDir(ACtx: TScanContext; ARootDir: WideString);
    procedure DoCallback(const ACtx: TScanContext; ACallback: TProc<WideString>; AMsg: WideString);
    procedure RunScan(ACommand, AParams: WideString);
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    function Start(ACommand: WideString; AParams: WideString): TResultType; safecall;
    procedure Stop(const AResult: TResultType); safecall;
    function Info: WideString; safecall;
    procedure SetCallbacks(StartCallback,
                           RunCallback,
                           BreakCallback,
                           FinishCallback,
                           SyncCallback:
                           TProc<WideString>); safecall;
    function ResultList: TArray<WideString>; safecall;
  end;

  TRunTaskFindInExeFile = class(TInterfacedObject, IDLLIntf, IRunTask, IRunTaskFindInExeFile)
  private
    FResultList: TList<WideString>;
    FThreadManager: TOmniThreadPoolManager;
    FTaskCtrl: TResultType;
    FStartCallback: TProc<WideString>;
    FBreakCallback: TProc<WideString>;
    FFinishCallback: TProc<WideString>;
    FErrorCallback: TProc<WideString>;
    procedure CalcTextOnExeFile(AFileName: WideString; AFindText: WideString; AResultList: TList<WideString>);
    procedure DoStartCallback(AMsg: WideString);
    procedure DoBreakCallback(AMsg: WideString);
    procedure DoFinishCallback(AMsg: WideString);
    procedure DoErrorCallback(AMsg: WideString);
    procedure RunExeSearch(ACommand, AFindText: WideString);
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    function Start(ACommand: WideString; AParams: WideString): TResultType; safecall;
    procedure Stop(const AResult: TResultType); safecall;
    function Info: WideString; safecall;
    procedure SetCallbacks(StartCallback,
                           BreakCallback,
                           ErrorCallback,
                           FinishCallback:
                           TProc<WideString>); safecall;
    function ResultList: TArray<WideString>; safecall;
  end;

{$R *.res}

function InitRunTaskFindInDir: IRunTaskFindInDir;
begin
  Result := TRunTaskFindInDir.Create;
end;

function InitRunTaskFindInExeFile: IRunTaskFindInExeFile;
begin
  Result := TRunTaskFindInExeFile.Create;
end;

exports
  InitRunTaskFindInDir,
  InitRunTaskFindInExeFile;

constructor TScanContext.Create;
begin
  inherited Create;
  ResultList := TList<WideString>.Create;
  ExtList := TStringList.Create;
  FileCount := 0;
  LastCallbackTime := 0;
  Terminated := false;
end;

destructor TScanContext.Destroy;
begin
  FreeAndNil(ExtList);
  FreeAndNil(ResultList);
  inherited;
end;

{ ==================== TRunTaskFindInDir ==================== }

constructor TRunTaskFindInDir.Create;
begin
  FResultList := TList<WideString>.Create;
  FThreadManager := TOmniThreadPoolManager.Create;
  FTaskCtrl := nil;
  FScanCtx := nil;
  FStartCallback := nil;
  FRunCallback := nil;
  FSyncCallback := nil;
  FBreakCallback := nil;
  FFinishCallback := nil;
end;

destructor TRunTaskFindInDir.Destroy;
begin
{$ifdef use_otl}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate(3000);
{$else}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate;
{$endif}
  FreeAndNil(FScanCtx);
  FreeAndNil(FThreadManager);
  FreeAndNil(FResultList);
  inherited;
end;

procedure TRunTaskFindInDir.DoCallback(const ACtx: TScanContext; ACallback: TProc<WideString>; AMsg: WideString);
begin
  if Assigned(ACallback) then
    ACallback(AMsg);
end;

procedure TRunTaskFindInDir.ScanDir(ACtx: TScanContext; ARootDir: WideString);
var
  DirStack: TStack<WideString>;
  curDir: WideString;
  SR: TSearchRec;
  Res: Integer;
  ResFilePath: string;
  i: integer;
  FileExt: string;
begin
  DirStack := TStack<WideString>.Create;
  try
    DirStack.Push(ARootDir);

    while DirStack.Count > 0 do
    begin
//      if TThread.CheckTerminated then Exit;
      if ACtx.Terminated then
        exit;

      curDir := DirStack.Pop;

      Res := FindFirst(IncludeTrailingPathDelimiter(curDir) + '*.*', faAnyFile, SR);
      try
        while Res = 0 do
        begin
//          if TThread.CheckTerminated then Exit;
          if ACtx.Terminated then
            exit;

          if (SR.Name = '.') or (SR.Name = '..') then
          begin
            Res := FindNext(SR);
            Continue;
          end;

          ResFilePath := IncludeTrailingPathDelimiter(curDir) + SR.Name;

          if (SR.Attr and faDirectory) <> 0 then
          begin
            DirStack.Push(ResFilePath);
          end
          else
          begin
            inc(ACtx.FileCount);

            DoCallback(ACtx, ACtx.RunCallback, ResFilePath);

            if ACtx.ExtList.Count > 0 then
            begin
              FileExt := LowerCase(ExtractFileExt(SR.Name));
              for i := 0 to ACtx.ExtList.Count - 1 do
              begin
                if FileExt = ACtx.ExtList[i] then
                begin
                  ACtx.ResultList.Add(ResFilePath);
                  DoCallback(ACtx, ACtx.SyncCallback, ResFilePath);
                  Break;
                end;
              end;
            end
            else
            begin
              ACtx.ResultList.Add(ResFilePath);
              DoCallback(ACtx, ACtx.SyncCallback, ResFilePath);
            end;
          end;

          Res := FindNext(SR);
        end;
      finally
        FindClose(SR);
      end;
    end;
  finally
    FreeAndNil(DirStack);
  end;
end;

procedure TRunTaskFindInDir.RunScan(ACommand, AParams: WideString);
var
  exts: TArray<string>;
  ext: string;
  FileExtMsg: WideString;
  i: integer;
  lDisks: TStringList;
  c: char;
  s: string;
  SrcCount: Integer;
begin
  // Создаём ИЗОЛИРОВАННЫЙ контекст — никаких гонок с предыдущим/следующим сканом
  FScanCtx := TScanContext.Create;
  try
    // Парсим расширения
    exts := SplitString(AParams, ',');
    for i := low(exts) to High(exts) do
    begin
      ext := trim(AnsiReplaceText(Exts[i], '.', ''));
      if ext <> '' then
        FScanCtx.ExtList.Add('.' + ext);
    end;
    if FScanCtx.ExtList.Count > 0 then
      FileExtMsg := ' по файлам с расширениями: ' + FScanCtx.ExtList.DelimitedText
    else
      FileExtMsg := ' по всем файлам';

    // Копируем callback'и в контекст (чтобы Start() не мог их изменить во время работы)
    FScanCtx.StartCallback := FStartCallback;
    FScanCtx.RunCallback := FRunCallback;
    FScanCtx.SyncCallback := FSyncCallback;
    FScanCtx.BreakCallback := FBreakCallback;
    FScanCtx.FinishCallback := FFinishCallback;
    FScanCtx.LastCallbackTime := Now;

    if DirectoryExists(ACommand) then
    begin
      // Сканирование одного каталога
      DoCallback(FScanCtx, FScanCtx.StartCallback,
        'Запущено сканирование каталога ' + ACommand + FileExtMsg);
      ScanDir(FScanCtx, ACommand);
//      if not TThread.CheckTerminated then
      if not FScanCtx.Terminated then
        DoCallback(FScanCtx, FScanCtx.FinishCallback,
          'Cканирование каталога ' + ACommand + ' завершено');
    end
    else
    begin
      // Сканирование локальных дисков
      lDisks := TStringList.Create;
      try
        if ACommand <> '' then
        begin
          exts := SplitString(ACommand, ';');
          for i := Low(exts) to High(exts) do
          begin
            ext := exts[i];
            if (ext <> '') and DirectoryExists(ext) then
              lDisks.Add(ext);
          end;
        end
        else
        begin
          for c := 'A' to 'Z' do
          begin
            s := c + ':';
            if GetDriveType(PChar(s)) = DRIVE_FIXED then
              lDisks.Add(s);
          end;
        end;

        if lDisks.Count > 0 then
        begin
          lDisks.Delimiter := ';';
          if lDisks.Count > 1 then
            DoCallback(FScanCtx, FScanCtx.StartCallback,
              'Запущено сканирование локальных дисков ' + lDisks.DelimitedText + FileExtMsg)
          else
            DoCallback(FScanCtx, FScanCtx.StartCallback,
              'Запущено сканирование локального диска ' + lDisks[0] + FileExtMsg);

          for i := 0 to lDisks.Count - 1 do
          begin
//            if TThread.CheckTerminated then Exit;
            if FScanCtx.Terminated then
              exit;
            ScanDir(FScanCtx, lDisks[i]);
          end;

//          if not TThread.CheckTerminated then
          if not FScanCtx.Terminated then
            DoCallback(FScanCtx, FScanCtx.FinishCallback,
              'Cканирование локальных дисков завершено');
        end;
      finally
        FreeAndNil(lDisks);
      end;
    end;
  finally
    // Переносим результаты в FResultList (потокобезопасно — поток уже завершился)
    if Assigned(FScanCtx) then
    begin
      SrcCount := FScanCtx.ResultList.Count;
      FResultList.Clear;
      FResultList.Capacity := SrcCount;
      for i := 0 to SrcCount - 1 do
        FResultList.Add(FScanCtx.ResultList[i]);
      FreeAndNil(FScanCtx);
    end;
  end;
end;

procedure TRunTaskFindInDir.SetCallbacks(StartCallback, RunCallback,
  BreakCallback, FinishCallback, SyncCallback: TProc<WideString>);
begin
  FStartCallback := StartCallback;
  FRunCallback := RunCallback;
  FBreakCallback := BreakCallback;
  FFinishCallback := FinishCallback;
  FSyncCallback := SyncCallback;
end;

function TRunTaskFindInDir.Start(ACommand: WideString; AParams: WideString): TResultType;
begin
  // Если предыдущий скан ещё работает — останавливаем
{$ifdef use_otl}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate(3000);
{$else}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate;
{$endif}

  // Запускаем новый скан
  Result := FThreadManager.Start(
    procedure
    begin
      RunScan(ACommand, AParams);
    end);
  FTaskCtrl := Result;
end;

procedure TRunTaskFindInDir.Stop(const AResult: TResultType);
begin
  if Assigned(FScanCtx) then
  begin
    DoCallback(FScanCtx, FScanCtx.BreakCallback, 'Сканирование прервано');
    FScanCtx.Terminated := true;
  end;
  FThreadManager.Stop(AResult);
end;

function TRunTaskFindInDir.ResultList: TArray<WideString>;
begin
  Result := FResultList.ToArray;
end;

function TRunTaskFindInDir.GetDescription: WideString;
begin
  Result := 'Асинхронный рекурсивный поиск файлов по маске в указанной директории';
end;

function TRunTaskFindInDir.Info: WideString;
begin
  Result := 'Для работы указываются 2 параметра: '#13#10 +
            '1. ACommand: первоначальный каталог для поиска. Может быть пустым. '#13#10 +
            'В этом случае поиск идёт по всем локальным дискам'#13#10+
            '2. AParams: маски файлов через запятую (например, txt,bmp). Если не заданы, выбираются все файлы.'#13#10 +
            'Результаты поиска заносятся в ResultList';
end;

procedure TRunTaskFindInDir.Init;
begin
end;

procedure TRunTaskFindInDir.Fin;
begin
end;

{ ==================== TRunTaskFindInExeFile ==================== }

// Boyer-Moore: построение таблицы сдвигов
function BuildBadCharTable(const Pattern: TBytes): TArray<Integer>;
var
  i, m: Integer;
begin
  m := Length(Pattern);
  SetLength(Result, 256);
  for i := 0 to 255 do
    Result[i] := m;
  for i := 0 to m - 2 do
    Result[Pattern[i] and $FF] := m - 1 - i;
end;

procedure TRunTaskFindInExeFile.CalcTextOnExeFile(AFileName, AFindText: WideString; AResultList: TList<WideString>);
const
  ChunkSize = 4 * 1024 * 1024;  // 4 МБ чанки
var
  FS: TFileStream;
  Exts: TArray<string>;
  ext: string;
  lExts: TStringList;
  i, j: integer;
  FindBytes: TBytes;
  badTable: TArray<Integer>;
  n, m, s: Integer;
  chunk: TBytes;
  chunkLen: Integer;
  offsetInFile: Int64;
  shift: Integer;
begin
  lExts := TStringList.Create;
  try
    Exts := SplitString(AFindText, ',');
    for i := Low(Exts) to High(Exts) do
    begin
      ext := AnsiReplaceText(Exts[i], '.', '');
      if trim(ext) <> '' then
        lExts.Add(ext);
    end;
    if lExts.Count = 0 then
      Exit;

    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      n := FS.Size;
      if n = 0 then
        Exit;

      for i := 0 to lExts.Count - 1 do
      begin
        if TThread.CheckTerminated then Exit;
        ext := lExts[i];
        FindBytes := TEncoding.UTF8.GetBytes(ext);
        m := Length(FindBytes);
        if m = 0 then Continue;

        // Boyer-Moore bad character table
        badTable := BuildBadCharTable(FindBytes);

        // Чтение чанками с перекрытием
        offsetInFile := 0;
        while offsetInFile < n do
        begin
          if TThread.CheckTerminated then Exit;
          FS.Position := offsetInFile;
          chunkLen := Min(ChunkSize + m - 1, n - offsetInFile);
          SetLength(chunk, chunkLen);
          FS.ReadBuffer(chunk[0], chunkLen);

          // Поиск в чанке (Бойер-Мур)
          s := 0;
          while s <= chunkLen - m do
          begin
            j := m - 1;
            while (j >= 0) and (chunk[s + j] = FindBytes[j]) do
              Dec(j);
            if j < 0 then
            begin
              // Найдено!
              AResultList.Add(IntToStr(offsetInFile + s) + '=' + ext);
              Inc(s);
            end
            else
            begin
              // Сдвиг по таблице плохих символов
              if s + m >= chunkLen then
                shift := m
              else
                shift := badTable[chunk[s + m - 1] and $FF];
              Inc(s, Max(1, shift));
            end;
          end;

          // Сдвиг с перекрытием для поиска на границах чанков
          if chunkLen < m then
            offsetInFile := offsetInFile + chunkLen
          else
            offsetInFile := offsetInFile + chunkLen - m + 1;
        end;
      end;
    finally
      FS.Free;
    end;
  finally
    FreeAndNil(lExts);
  end;
end;

procedure TRunTaskFindInExeFile.RunExeSearch(ACommand, AFindText: WideString);
var
  LocalList: TList<WideString>;
  i: Integer;
begin
  // Локальный список результатов — изоляция от других поисков
  LocalList := TList<WideString>.Create;
  try
    CalcTextOnExeFile(ACommand, AFindText, LocalList);
    // Копируем результаты в FResultList (потокобезопасно — поток уже завершился)
    FResultList.Clear;
    FResultList.Capacity := LocalList.Count;
    for i := 0 to LocalList.Count - 1 do
      FResultList.Add(LocalList[i]);
  finally
    FreeAndNil(LocalList);
  end;
end;

constructor TRunTaskFindInExeFile.Create;
begin
  FResultList := TList<WideString>.Create;
  FThreadManager := TOmniThreadPoolManager.Create;
  FTaskCtrl := nil;
  FStartCallback := nil;
  FBreakCallback := nil;
  FFinishCallback := nil;
  FErrorCallback := nil;
end;

destructor TRunTaskFindInExeFile.Destroy;
begin
{$ifdef use_otl}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate(3000);
{$else}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate;
{$endif}
  FreeAndNil(FThreadManager);
  FreeAndNil(FResultList);
  inherited;
end;

procedure TRunTaskFindInExeFile.DoBreakCallback(AMsg: WideString);
begin
  if Assigned(FBreakCallback) then
    FBreakCallback(AMsg);
end;

procedure TRunTaskFindInExeFile.DoErrorCallback(AMsg: WideString);
begin
  if Assigned(FErrorCallback) then
    FErrorCallback(AMsg);
end;

procedure TRunTaskFindInExeFile.DoFinishCallback(AMsg: WideString);
begin
  if Assigned(FFinishCallback) then
    FFinishCallback(AMsg);
end;

procedure TRunTaskFindInExeFile.DoStartCallback(AMsg: WideString);
begin
  if Assigned(FStartCallback) then
    FStartCallback(AMsg);
end;

procedure TRunTaskFindInExeFile.Fin;
begin
end;

function TRunTaskFindInExeFile.GetDescription: WideString;
begin
  Result := 'Асинхронный поиск последовательностей символов в exe-файле';
end;

function TRunTaskFindInExeFile.Info: WideString;
begin
  Result := 'Для работы указываются 2 параметра: '#13#10 +
            '1. ACommand: Путь к exe-файлу. Файл должен существовать. '#13#10 +
            '2. AParams: Последовательности символов для поиска, разделённые запятой.'#13#10 +
            'Результаты поиска заносятся в ResultList';
end;

procedure TRunTaskFindInExeFile.Init;
begin
end;

function TRunTaskFindInExeFile.ResultList: TArray<WideString>;
begin
  Result := FResultList.ToArray;
end;

procedure TRunTaskFindInExeFile.SetCallbacks(StartCallback,
  BreakCallback, ErrorCallback, FinishCallback: TProc<WideString>);
begin
  FStartCallback := StartCallback;
  FBreakCallback := BreakCallback;
  FErrorCallback := ErrorCallback;
  FFinishCallback := FinishCallback;
end;

function TRunTaskFindInExeFile.Start(ACommand: WideString; AParams: WideString): TResultType;
begin
  if not FileExists(ACommand) then
  begin
    DoErrorCallback('Файл ' + ACommand + ' не найден');
    Exit(nil);
  end;
  if ExtractFileExt(ACommand) <> '.exe' then
  begin
    DoErrorCallback('Файл ' + ACommand + ' не является приложением');
    Exit(nil);
  end;
  if trim(AParams) = '' then
  begin
    DoErrorCallback('Не задан текст для поиска');
    Exit(nil);
  end;

  // Если предыдущий поиск ещё работает — останавливаем
{$ifdef use_otl}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate(3000);
{$else}
  if Assigned(FTaskCtrl) then
    FTaskCtrl.Terminate;
{$endif}

  Result := FThreadManager.Start(
  procedure
  begin
    DoStartCallback('Запущен поиск "' + AParams + '" в файле ' + ACommand);
    RunExeSearch(ACommand, AParams);
    if not TThread.CheckTerminated then
      DoFinishCallback('Поиск в файле ' + ACommand + ' завершён');
  end);
  FTaskCtrl := Result;
end;

procedure TRunTaskFindInExeFile.Stop(const AResult: TResultType);
begin
  DoBreakCallback('Поиск прерван');
  FThreadManager.Stop(AResult);
end;

begin
end.
