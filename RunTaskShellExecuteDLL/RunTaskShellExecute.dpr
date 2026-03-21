library RunTaskShellExecute;

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  system.StrUtils,
  System.Generics.Collections,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\common\intf_common.pas',
  intf_tasks in '..\..\common\intf_tasks.pas',
  uAutonomiusThreadPool in '..\..\common\uAutonomiusThreadPool.pas';

type
  TRunTaskShellExecute = class(TInterfacedObject, IDLLIntf, IRunTask, IRunTaskShellExecute)
  private
    FProcessNumber: integer;
    FRunDict: TDictionary<integer, THandle>;
    FThreadDict: TDictionary<TThread, integer>;
    FThreadManager: TThreadPoolManager;
    FStartCallback: TProc<WideString>;
    FBreakCallback: TProc<WideString>;
    FErrorCallback: TProc<WideString>;
    FFinishCallback: TProc<WideString>;
    procedure DoStartCallback(AMsg: WideString);
    procedure DoBreakCallback(AMsg: WideString);
    procedure DoErrorCallback(AMsg: WideString);
    procedure DoFinishCallback(AMsg: WideString);
    procedure ExecuteShellCommand(const Command: WideString; WorkingDir: WideString; AProcessNumber: integer);
    procedure TerminateProcesses;
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
  end;

{$R *.res}

function InitRunTaskShellExecute: IRunTaskShellExecute;
begin
  Result := TRunTaskShellExecute.Create;
end;

exports
  InitRunTaskShellExecute;

{ TRunTaskShellExecute }

constructor TRunTaskShellExecute.Create;
begin
  FThreadManager := TThreadPoolManager.Create;
  FRunDict := TDictionary<integer, THandle>.Create;
  FThreadDict := TDictionary<TThread, integer>.Create;
  FProcessNumber := 0;
end;

destructor TRunTaskShellExecute.Destroy;
begin
  TerminateProcesses;
  FreeAndNil(FThreadDict);
  FreeAndNil(FRunDict);
  FreeAndNil(FThreadManager);
  inherited;
end;

procedure TRunTaskShellExecute.DoBreakCallback(AMsg: WideString);
begin
  if Assigned(FBreakCallback) then
    FBreakCallback(AMsg);
end;

procedure TRunTaskShellExecute.DoErrorCallback(AMsg: WideString);
begin
  if Assigned(FErrorCallback) then
    FErrorCallback(AMsg);
end;

procedure TRunTaskShellExecute.DoFinishCallback(AMsg: WideString);
begin
  if Assigned(FFinishCallback) then
    FFinishCallback(AMsg);
end;

procedure TRunTaskShellExecute.DoStartCallback(AMsg: WideString);
begin
  if Assigned(FStartCallback) then
    FStartCallback(AMsg);
end;

procedure TRunTaskShellExecute.ExecuteShellCommand(
  const Command: WideString; WorkingDir: WideString; AProcessNumber: integer);
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  cmdLine: string;
  pWorkingDir: PChar;
begin
  if DirectoryExists(WorkingDir) then
    pWorkingDir := PChar(WorkingDir)
  else
    pWorkingDir := nil;

  cmdLine := Command;
  UniqueString(cmdLine);

  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_SHOW;

  if CreateProcess(nil, PChar(cmdLine), nil, nil, false,
    0, nil, pWorkingDir, StartupInfo, ProcessInfo) then
  begin
    try
      if Assigned(FRunDict) then
        FRunDict.AddOrSetValue(AProcessNumber, ProcessInfo.hProcess);
      WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    finally
      CloseHandle(ProcessInfo.hThread);
      CloseHandle(ProcessInfo.hProcess);
    end;
  end
    else
    DoErrorCallback('Ошибка запуска: ' + SysErrorMessage(GetLastError))
end;

procedure TRunTaskShellExecute.Fin;
begin

end;

function TRunTaskShellExecute.GetDescription: WideString;
begin
  Result := 'Асинхронное выполнение shell команды';
end;

function TRunTaskShellExecute.Info: WideString;
begin
  Result := 'Для работы необходимо задать 2 параметра: '#13#10+
            '1. Команду для выполнения, например, '#13#10 +
            '"C:\Program Files\7-Zip\7z.exe" a "archive.7z" "C:\MyFiles\*" '#13#10+
            'Убедитесь, что все пути указаны верно. '#13#10 +
            '2. Рабочий каталог. Необязательный параметр';
end;

procedure TRunTaskShellExecute.Init;
begin

end;

procedure TRunTaskShellExecute.SetCallbacks(StartCallback, BreakCallback, ErrorCallback,
  FinishCallback: TProc<WideString>);
begin
  FStartCallback := StartCallback;
  FBreakCallback := BreakCallback;
  FErrorCallback := ErrorCallback;
  FFinishCallback := FinishCallback;
end;

function TRunTaskShellExecute.Start(ACommand, AParams: WideString): TThread;
begin
  inc(FProcessNumber);
  Result := FThreadManager.Start(
  procedure
  var
    pn: integer;
  begin
    pn := FProcessNumber;
    DoStartCallback('Выполнение команды ' + ACommand + ' запущено!');
    ExecuteShellCommand(ACommand, AParams, pn);
    if Assigned(FRunDict) then
      FRunDict.Remove(pn);
    DoFinishCallback('Выполнение команды ' + ACommand + ' завершено!')
  end
  );
  FThreadDict.AddOrSetValue(Result, FProcessNumber);
end;

procedure TRunTaskShellExecute.Stop(AThread: TThread);
var
  hProcess: THandle;
  pn: integer;
begin
  if FThreadDict.TryGetValue(AThread, pn) then
    if FRunDict.TryGetValue(pn, hProcess) then
    begin
      FRunDict.Remove(pn);
      TerminateProcess(hProcess, 1);
    end;

  if FThreadManager.Stop(AThread) then
  begin
    FThreadDict.Remove(AThread);
    DoBreakCallback('Выполнение команды прервано');
  end;
end;

procedure TRunTaskShellExecute.TerminateProcesses;
var
  hProcess: THandle;
  pairThreadDict: TPair<TThread, integer>;
begin
  for pairThreadDict in FThreadDict do
  begin
    if pairThreadDict.Key.ThreadID <> 0 then
    begin
      if FRunDict.TryGetValue(pairThreadDict.Value, hProcess) then
      begin
        FRunDict.Remove(pairThreadDict.Value);
        TerminateProcess(hProcess, 0);
      end;
    end;
  end;
end;

begin
end.
