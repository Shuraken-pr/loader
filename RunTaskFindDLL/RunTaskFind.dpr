library RunTaskFind;

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  system.StrUtils,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uAutonomiusThreadPool in '..\..\common\uAutonomiusThreadPool.pas';

type
  TRunTaskFindInDir = class(TInterfacedObject, IDLLIntf, IRunTask, IRunTaskFindInDir)
  private
    FResultList: TArray<WideString>;
    FThreadManager: TThreadPoolManager;
    FExtList: TStringList;
    FStartCallback: TProc<WideString>;
    FRunCallback: TProc<WideString>;
    FSyncCallback: TProc<WideString>;
    FBreakCallback: TProc<WideString>;
    FFinishCallback: TProc<WideString>;
    procedure ScanDir(ARooDir: WideString);
    procedure DoStartCallback(AMsg: WideString);
    procedure DoRunCallback(AMsg: WideString);
    procedure DoSyncCallback(AMsg: WideString);
    procedure DoBreakCallback(AMsg: WideString);
    procedure DoFinishCallback(AMsg: WideString);
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    function Start(ACommand: WideString; AParams: WideString): TThread; safecall;
    procedure Stop(AThread: TThread); safecall;
    function Info: WideString; safecall;
    procedure SetCallbacks(StartCallback,  //уведомляем о запуске
                           RunCallback,    //отображаем ход выполнения
                           BreakCallback,  //уведомляем о прерывании
                           FinishCallback, //уведомляем о завершении
                           SyncCallback:   //выполняем синхронизацию
                           TProc<WideString>); safecall;
    function ResultList: TArray<WideString>; safecall;
  end;

  TRunTaskFindInExeFile = class(TInterfacedObject, IDLLIntf, IRunTask, IRunTaskFindInExeFile)
  private
    FResultList: TArray<WideString>;
    FThreadManager: TThreadPoolManager;
    FStartCallback: TProc<WideString>;
    FBreakCallback: TProc<WideString>;
    FFinishCallback: TProc<WideString>;
    FErrorCallback: TProc<WideString>;
    procedure CalcTextOnExeFile(AFileName: WideString; AFindText: WideString);
    procedure DoStartCallback(AMsg: WideString);
    procedure DoBreakCallback(AMsg: WideString);
    procedure DoFinishCallback(AMsg: WideString);
    procedure DoErrorCallback(AMsg: WideString);
  public
    constructor Create;
    destructor Destroy; override;
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    function Start(ACommand: WideString; AParams: WideString): TThread; safecall;
    procedure Stop(AThread: TThread); safecall;
    function Info: WideString; safecall;
    procedure SetCallbacks(StartCallback,  //уведомляем о запуске
                           BreakCallback,  //уведомляем о прерывании
                           ErrorCallback,  //уведомляем об ошибке
                           FinishCallback:   //выполняем синхронизацию
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

{ TRunTaskFindInDir }

constructor TRunTaskFindInDir.Create;
begin
  FResultList := nil;
  FExtList := TStringList.Create;
  FThreadManager := TThreadPoolManager.Create;
end;

destructor TRunTaskFindInDir.Destroy;
begin
  FreeAndNil(FThreadManager);
  FreeAndNil(FExtList);
  FResultList := nil;
  inherited;
end;

procedure TRunTaskFindInDir.DoBreakCallback(AMsg: WideString);
begin
  if Assigned(FBreakCallback) then
    FBreakCallback(AMsg);
end;

procedure TRunTaskFindInDir.DoFinishCallback(AMsg: WideString);
begin
  if Assigned(FFinishCallback) then
    FFinishCallback(AMsg);
end;

procedure TRunTaskFindInDir.DoRunCallback(AMsg: WideString);
begin
  if Assigned(FRunCallback) then
    FRunCallback(AMsg);
end;

procedure TRunTaskFindInDir.DoStartCallback(AMsg: WideString);
begin
  if Assigned(FStartCallback) then
    FStartCallback(AMsg);
end;

procedure TRunTaskFindInDir.DoSyncCallback(AMsg: WideString);
begin
  if Assigned(FSyncCallback) then
    FSyncCallback(AMsg);
end;

procedure TRunTaskFindInDir.Fin;
begin

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

function TRunTaskFindInDir.ResultList: TArray<WideString>;
begin
  Result := FResultList;
end;

procedure TRunTaskFindInDir.ScanDir(ARooDir: WideString);
var
  SR: TSearchRec;
  Res: Integer;
  ResFilePath: string;
  i: integer;
  FileExt: string;
begin
  // Обходим файлы в текущем каталоге
  Res := FindFirst(IncludeTrailingPathDelimiter(ARooDir) + '*.*', faAnyFile, SR);
  try
    while Res = 0 do
    begin
      // Игнорируем . и ..
      if (SR.Name = '.') or (SR.Name = '..') then
      begin
        Res := FindNext(SR);
        Continue;
      end;

      ResFilePath := IncludeTrailingPathDelimiter(ARooDir) + SR.Name;
      DoRunCallback(ResFilePath);

      if (SR.Attr and faDirectory) <> 0 then
      begin
        // Это папка: рекурсивно углубляемся
        ScanDir(ResFilePath);
      end
        else
      begin
        if Assigned(FExtList) and (FExtList.Count > 0) then
        begin
          // Проверяем расширение файла
          FileExt := LowerCase(ExtractFileExt(SR.Name));
          for i := 0 to FExtList.Count - 1 do
          begin
            if (FileExt = FExtList[i]) then
            begin
              SetLength(FResultList, length(FResultList) + 1);
              FResultList[High(FResultList)] := ResFilePath;
              DoSyncCallback(ResFilePath);
              Break;
            end;
          end;
        end
          else
        begin
          SetLength(FResultList, length(FResultList) + 1);
          FResultList[High(FResultList)] := ResFilePath;
          DoSyncCallback(ResFilePath);
        end;
      end;

      Res := FindNext(SR);
    end;
  finally
    FindClose(SR);
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

function TRunTaskFindInDir.Start(ACommand, AParams: WideString): TThread;
var
  exts: TArray<string>;
  ext: string;
  FileExtMsg: WideString;
  i: integer;
begin
  FExtList.Clear;
  exts := SplitString(AParams, ',');
  for i := low(exts) to High(exts) do
  begin
    ext := trim(AnsiReplaceText(Exts[i], '.', ''));
    if ext <> '' then
      FExtList.Add('.' + ext);
  end;
  if FExtList.Count > 0 then
    FileExtMsg := ' по файлам с расширениями: ' + FExtList.DelimitedText
  else
    FileExtMsg := ' по всем файлам';

  FResultList := nil;

  if DirectoryExists(ACommand) then
  begin
    Result := FThreadManager.Start(
    procedure
    begin
      DoStartCallback('Запущено сканирование каталога ' + ACommand + FileExtMsg);
      ScanDir(ACommand);
      DoFinishCallback('Cканирование каталога ' + ACommand + ' завершено')
    end)
  end
    else
  begin
    Result := FThreadManager.Start(
    procedure
    var
      c: char;
      s: string;
      i: integer;
      lDisks: TStringList;
    begin

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
            DoStartCallback('Запущено сканирование локальных дисков ' +  lDisks.DelimitedText + FileExtMsg)
          else
            DoStartCallback('Запущено сканирование локального диска ' +  lDisks[0] + FileExtMsg);
          for i := 0 to lDisks.Count - 1 do
          begin
            s := lDisks[i];
            ScanDir(s);
          end;
          DoFinishCallback('Cканирование локальных дисков завершено')
        end;
      finally
        FreeAndNil(lDisks);
      end;
    end);
  end;
end;

procedure TRunTaskFindInDir.Stop(AThread: TThread);
begin
  DoBreakCallback('Сканирование прервано');
  FThreadManager.Stop(AThread);
end;

{ TRunTaskFindInExeFile }

procedure TRunTaskFindInExeFile.CalcTextOnExeFile(AFileName,
  AFindText: WideString);
var
  FS: TFileStream;
  FileBytes, FindBytes: TBytes;
  Exts: TArray<string>;
  ext: string;
  lExts: TStringList;
  i, j, pos: integer;
begin
  lExts := TStringList.Create;
  try
    FResultList := nil;
    Exts := SplitString(AFindText,',');
    for i := Low(exts) to High(Exts) do
    begin
      ext := AnsiReplaceText(Exts[i], '.', '');
      if trim(ext) <> '' then
        lExts.Add(ext);
    end;
    if lExts.Count = 0 then
      Exit;
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(FileBytes, FS.Size);
      if length(FileBytes) > 0 then
        FS.Read(FileBytes[0], length(FileBytes));
    finally
      FS.Free;
    end;

    for i := 0 to lExts.Count - 1 do
    begin
      ext := lExts[i];
      FindBytes := TEncoding.UTF8.GetBytes(ext);
      pos := 0;
      while pos <= length(FileBytes) - length(FindBytes) do
      begin
        for j := Low(FindBytes) to High(FindBytes) do
        begin
          if FileBytes[Pos + j] <> FindBytes[j] then
            break;
          if j = High(FindBytes) then
          begin
            SetLength(FResultList, length(FResultList) + 1);
            FResultList[High(FResultList)] := IntToStr(Pos) + '=' + ext;
          end;
        end;
        inc(pos);
      end;
    end;
  finally
    FreeAndNil(lExts);
  end;
end;

constructor TRunTaskFindInExeFile.Create;
begin
  FResultList := nil;
  FThreadManager := TThreadPoolManager.Create;
end;

destructor TRunTaskFindInExeFile.Destroy;
begin
  FreeAndNil(FThreadManager);
  FResultList := nil;
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
  Result := FResultList;
end;

procedure TRunTaskFindInExeFile.SetCallbacks(StartCallback,
  BreakCallback, ErrorCallback, FinishCallback: TProc<WideString>);
begin
  FStartCallback := StartCallback;
  FBreakCallback := BreakCallback;
  FErrorCallback := ErrorCallback;
  FFinishCallback := FinishCallback;
end;

function TRunTaskFindInExeFile.Start(ACommand, AParams: WideString): TThread;
begin
  if not FileExists(ACommand) then
  begin
    DoErrorCallback('Файл ' + ACommand + ' не найден');
    Exit;
  end;
  if ExtractFileExt(ACommand) <> '.exe' then
  begin
    DoErrorCallback('Файл ' + ACommand + ' не является приложением');
    Exit;
  end;
  if trim(AParams) = '' then
  begin
    DoErrorCallback('Не задан текст для поиска');
    Exit;
  end;
  Result := FThreadManager.Start(
  procedure
  begin
    DoStartCallback('Запущен поиск "' + AParams + '"в файле ' + ACommand);
    CalcTextOnExeFile(ACommand, AParams);
    DoFinishCallback('Поиск в файле ' + ACommand + ' завершён');
  end)
end;

procedure TRunTaskFindInExeFile.Stop(AThread: TThread);
begin
  DoBreakCallback('Сканирование прервано');
  FThreadManager.Stop(AThread);
end;

begin
end.
