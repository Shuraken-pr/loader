unit uDllManagerFixture;

interface

uses
  System.SysUtils, System.Classes, DUnitX.TestFramework, DllManager, intf_dll, intf_common, System.win.ComObj,
  System.Threading, Winapi.Windows;

type
  [TestFixture]
  TTestDLLManager = class
  private
    FDLLManager: TDllManager;
    FValidDLLInfo: TDLLInfo;
    FValidStubPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    //успешная загрузка
    procedure Load_KnownDll_ReturnsTrue_AndIntfAvailable;

    [Test]
    //файл не найден
    procedure Load_MissingFile_ShowsErrorRaisesException;

    [Test]
    //дублирующая загрузка
    procedure Load_AlreadyLoaded_ShowsErrorRaisesException;

    [Test]
    //не найден InitProc;
    procedure Load_MissingInitProc_RaisesException;

    [Test]
    //InitProc возвращает nil
    procedure Load_InitProcReturnsNil_RaisesException;

    [Test]
    //Интерфейс не поддерживает IDLLIntf;
    procedure Load_IntfNotSupported_RaisesException;

    [Test]
    //Проверка выгрузки загруженной DLL
    procedure UnLoad_LoadedDll_ReturnsTrue_AndIntfNotAvailable;

    [Test]
    //выгрузка незагруженного интерфейса.
    procedure UnLoad_NotLoaded_ReturnsFalse;

    [Test]
    //выгрузка нескольких интерфейсов
    procedure UnloadAll_ClearsAllProvidersAndModules;

    [Test]
    //Проверка на возвращение конкретного интерфейса
    procedure GetIntf_ExistingGUID_ReturnsIntf;

    [Test]
    //несуществующий guid
    procedure GetIntf_UnknownGUID_ReturnsNil;

    [Test]
    //проверка потокобезопасности
    procedure ThreadSafety_MultipleLoadsAndUnloads_NoAV;

    [Test]
    //Успешная загрузка Generics
    procedure LoadGeneric_SuccessAndGetIntfGeneric_ReturnsT;

    [Test]
    //Получение через Generic незагруженного интерфейса
    procedure GetIntfGeneric_NotLoaded_ReturnsNil;
  end;

  TLoadUnloadThread = class(TThread)
  private
    FDLLManager: TDllManager;
    FDLLInfo: TDLLInfo;
  protected
    procedure Execute; override;
  public
    constructor Create(ADLLManager: TDllManager; ADLLInfo: TDLLInfo);
  end;

implementation

procedure TTestDLLManager.Setup;
begin
  FDLLManager := TDllManager.Create;
  FValidStubPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'TestDLL.dll';
  FValidDLLInfo.FileName := FValidStubPath;
  FValidDLLInfo.InitProc := 'InitProc';
  FValidDLLInfo.intfName := 'IDLLIntf';
  FValidDLLInfo.guid := IDLLIntf;
end;

procedure TTestDLLManager.TearDown;
begin
  FDLLManager.UnloadAll;
  FreeAndNil(FDLLManager);
end;

procedure TTestDLLManager.GetIntf_UnknownGUID_ReturnsNil;
begin
  FDLLManager.InternalLoad(FValidDLLInfo);
  FValidDLLInfo.guid := StringToGUID('{B3753E4F-F00D-416C-B6C6-C92DBADB7273}'); //начало IDllIntfRun + окончание IDllIntf
  Assert.IsFalse(FDLLManager.GetIntf(FValidDLLInfo.guid) <> nil, 'Несуществующий GUID');
end;

procedure TTestDLLManager.Load_AlreadyLoaded_ShowsErrorRaisesException;
var
  mgr: TDllManager;
begin
  mgr := TDllManager.Create;
  try
    mgr.InternalLoad(FValidDLLInfo, false);
    Assert.WillRaiseWithMessage(procedure
    begin
      mgr.InternalLoad(FValidDLLInfo, true);
    end,
    Exception,
    'Interface already loaded',
    'При повторной загрузке с ShowError=True должно выбрасываться Exception');
    var res: boolean := mgr.InternalLoad(FValidDLLInfo, false);
    Assert.IsFalse(res, 'Без ошибок');
  finally
    FreeAndNil(mgr);
  end;
end;

procedure TTestDLLManager.Load_InitProcReturnsNil_RaisesException;
begin
  FValidDLLInfo.InitProc := 'FakeInitProc';
  var ErrMsg: string := Format('%s returned nil', [FValidDLLInfo.InitProc]);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FDLLManager.InternalLoad(FValidDLLInfo, True);
    end,
    Exception,
    ErrMsg,
    'Exception "... returned nil"'
  );
end;

procedure TTestDLLManager.Load_IntfNotSupported_RaisesException;
begin
  FValidDLLInfo.InitProc := 'InitNoDllIntf';
  Assert.WillRaise(procedure
  begin
    FDLLManager.InternalLoad(FValidDLLInfo, true);
  end,
  Exception,
  'Exception "IDllIntf interface not supported"');
end;

procedure TTestDLLManager.Load_KnownDll_ReturnsTrue_AndIntfAvailable;
var
  res: boolean;
  intf: IInterface;
begin
  Assert.IsTrue(FileExists(FValidDLLInfo.FileName), 'TestDLL.dll не найдена. Проверьте настройки');

  res := FDLLManager.InternalLoad(FValidDLLInfo, false);
  Assert.IsTrue(res, 'Load должен вернуть true');
  Assert.IsTrue(FDLLManager.IsLoaded(FValidDLLInfo.intfName), 'IsLoaded должен вернуть true');

  intf := FDLLManager.GetIntf(FValidDLLInfo.guid);
  Assert.IsTrue(Assigned(intf), 'GetIntf должен вернуть валидный IDLLIntf');
end;

procedure TTestDLLManager.Load_MissingFile_ShowsErrorRaisesException;
var
  expectedMsg: string;
begin
  FValidDLLInfo.FileName := 'C:\Totally_Fake_DLL_12345.dll';

  expectedMsg := Format('File %s not found', [FValidDLLInfo.FileName]);

    // Вызываем напрямую через класс, чтобы обойти safecall-обертку интерфейса.
    // Это позволяет сохранить оригинальный тип исключения EArgumentException.

  Assert.WillRaiseWithMessage(
    procedure
    begin
      FDLLManager.InternalLoad(FValidDLLInfo, True);
    end,
    EArgumentException,
    expectedMsg,
    'Отсутствие файла при ShowError=True выбрасывает EArgumentException'
  );

  Assert.WillRaise(
    procedure
    begin
      FDLLManager.Load(FValidDLLInfo, True);
    end,
    EOleException,
    'Safecall при ShowError=True выдаёт EOleException'
  );
end;

procedure TTestDLLManager.Load_MissingInitProc_RaisesException;
begin
  FValidDLLInfo.InitProc := '';
  Assert.WillRaise(procedure
  begin
    FDLLManager.InternalLoad(FValidDLLInfo, true);
  end,
  Exception,
  'Отсутствие InitProc при ShowError = true вызывает Exception "Function ... not found"');
  var res: boolean := FDLLManager.InternalLoad(FValidDLLInfo, false);
  Assert.IsFalse(res, 'Отсутствие InitProc при ShowError = false ошибок не вызывает');
end;

procedure TTestDLLManager.ThreadSafety_MultipleLoadsAndUnloads_NoAV;
var
  threads: array [0..3] of TLoadUnloadThread;
  handles: array [0..3] of THandle;
  i: integer;
begin
  for i := 0 to 3 do
  begin
    threads[i] := TLoadUnloadThread.Create(FDLLManager, FValidDLLInfo);
    handles[i] := threads[i].Handle;
  end;

  WaitForMultipleObjects(4, @handles, true, 60000);

  for i := 0 to 3 do
  begin
    if Assigned(threads[i].FatalException) then
      Assert.Fail('Thread crashed with AV or Exception');
    FreeAndNil(threads[i]);
  end;
  Assert.IsFalse(FDLLManager.IsLoaded(FValidDLLInfo.intfName));
  Assert.IsTrue(FDLLManager.GetLoadedCount = 0, 'Должны выгрузиться все DLL');
end;

procedure TTestDLLManager.UnloadAll_ClearsAllProvidersAndModules;
begin
  FDLLManager.InternalLoad(FValidDLLInfo, true); //IDLLIntf
  FValidDLLInfo.InitProc := 'InitPCDLL';
  FValidDLLInfo.intfName := 'IPartsCatalog';
  FValidDLLInfo.guid := IPartsCatalog;
  FDLLManager.InternalLoad(FValidDLLInfo, true); //IPartsCatalog
  FValidDLLInfo.InitProc := 'InitLDDLL';
  FValidDLLInfo.intfName := 'ILogData';
  FValidDLLInfo.guid := ILogData;
  FDLLManager.InternalLoad(FValidDLLInfo, true); //ILogData
  FDLLManager.UnloadAll;
  Assert.IsFalse(FDLLManager.IsLoaded('IDLLIntf'), 'После UnloadAll IDLLIntf не загружена');
  Assert.IsFalse(FDLLManager.IsLoaded('IPartsCatalog'), 'После UnloadAll IPartsCatalog не загружена');
  Assert.IsFalse(FDLLManager.IsLoaded('ILogData'), 'После UnloadAll ILogData не загружена');
  Assert.IsTrue(FDLLManager.GetIntf(IDLLIntf) = nil, 'После UnloadAll GetIntf(IDLLIntf) = nil');
  Assert.IsTrue(FDLLManager.GetIntf(IPartsCatalog) = nil, 'После UnloadAll GetIntf(IPartsCatalog) = nil');
  Assert.IsTrue(FDLLManager.GetIntf(ILogData) = nil, 'После UnloadAll GetIntf(ILogData) = nil');
end;

procedure TTestDLLManager.GetIntfGeneric_NotLoaded_ReturnsNil;
begin
  FDLLManager.InternalLoad(FValidDLLInfo, true); //IDLLIntf;
  FValidDLLInfo.intfName := 'IPartsCatalog';
  Assert.IsFalse(FDLLManager.GetIntfGeneric<IPartsCatalog>(FValidDLLInfo) <> nil,
    'Проверка загруженного IPartsCatalog через Generic даёт false для загруженного IDLLIntf');
end;

procedure TTestDLLManager.GetIntf_ExistingGUID_ReturnsIntf;
begin
  FValidDLLInfo.InitProc := 'InitPCDLL';
  FValidDLLInfo.intfName := 'IPartsCatalog';
  FValidDLLInfo.guid := IPartsCatalog;
  FDLLManager.InternalLoad(FValidDLLInfo, true); //IPartsCatalog
  Assert.IsTrue(FDLLManager.GetIntfGeneric<IPartsCatalog>(FValidDLLInfo) <> nil, 'Result = найденный интерфейс IPartsCatalog');
end;

procedure TTestDLLManager.LoadGeneric_SuccessAndGetIntfGeneric_ReturnsT;
begin
  FValidDLLInfo.InitProc := 'InitPCDLL';
  FValidDLLInfo.intfName := 'IPartsCatalog';
  FValidDLLInfo.guid := IPartsCatalog;
  Assert.IsTrue(FDLLManager.LoadGeneric<IPartsCatalog>(FValidDLLInfo, true), 'Загрузка IPartsCatalog через Generic');
  Assert.IsTrue(FDLLManager.GetIntfGeneric<IPartsCatalog>(FValidDLLInfo) <> nil, 'Получение IPartsCatalog через Generic');
end;

procedure TTestDLLManager.UnLoad_LoadedDll_ReturnsTrue_AndIntfNotAvailable;
begin
  FDLLManager.InternalLoad(FValidDLLInfo, true);
  Assert.IsTrue(FDLLManager.UnLoad(FValidDLLInfo), 'Успешная выгрузка');
  Assert.IsFalse(FDLLManager.IsLoaded(FValidDLLInfo.intfName), 'IsLoaded = false для выгруженной DLL');
  Assert.IsTrue(FDLLManager.GetIntf(FValidDLLInfo.guid) = nil, 'GetIntf возвращает nil для выгруженной DLL');
end;

procedure TTestDLLManager.UnLoad_NotLoaded_ReturnsFalse;
begin
  FDLLManager.InternalLoad(FValidDLLInfo, true);
  FValidDLLInfo.intfName := 'IFake';
  Assert.IsFalse(FDLLManager.InternalUnLoad(FValidDLLInfo), 'Попытка выгрузить несуществующий интерфейс = false');
end;

{ TLoadUnloadThread }

constructor TLoadUnloadThread.Create(ADLLManager: TDllManager;
  ADLLInfo: TDLLInfo);
begin
  inherited Create(false);
  FreeOnTerminate := false;
  FDLLManager := ADLLManager;
  FDLLInfo := ADLLInfo;
end;

procedure TLoadUnloadThread.Execute;
begin
  inherited;
  for var i: integer := 1 to 20 do
  begin
    FDLLManager.InternalLoad(FDLLInfo, false);
    TThread.Sleep(20);
    FDLLManager.IsLoaded(FDLLInfo.intfName);
    FDLLManager.InternalUnLoad(FDLLInfo);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDLLManager);

end.
