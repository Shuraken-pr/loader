unit uDllManagerFixture;

interface

uses
  System.SysUtils, DUnitX.TestFramework, DllManager, intf_dll, System.win.ComObj;

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
  end;

implementation

procedure TTestDLLManager.Load_AlreadyLoaded_ShowsErrorRaisesException;
var
  mgr: TDllManager;
begin
  mgr := TDllManager.Create;
  try
    mgr.Load(FValidDLLInfo, false);
    Assert.WillRaise(procedure
    begin
      mgr.InternalLoad(FValidDLLInfo, true);
    end,
    Exception,
    'Повторная загрузка должна вызвать Exception "Interface already loaded"');
    var res: boolean := mgr.Load(FValidDLLInfo, false);
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

procedure TTestDLLManager.Load_KnownDll_ReturnsTrue_AndIntfAvailable;
var
  res: boolean;
  intf: IInterface;
begin
  Assert.IsTrue(FileExists(FValidDLLInfo.FileName), 'TestDLL.dll не найдена. Проверьте настройки');

  res := FDLLManager.Load(FValidDLLInfo, false);
  Assert.IsTrue(res, 'Load должен вернуть true');
  Assert.IsTrue(FDLLManager.IsLoaded(FValidDLLInfo.intfName), 'IsLoaded должен вернуть true');

  intf := FDLLManager.GetIntf(FValidDLLInfo.guid);
  Assert.IsTrue(Assigned(intf), 'GetIntf должен вернуть валидный IDLLIntf');
end;

procedure TTestDLLManager.Load_MissingFile_ShowsErrorRaisesException;
var
  mgr: TDllManager; // Используем конкретный класс, а не интерфейс!
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

initialization
  TDUnitX.RegisterTestFixture(TTestDLLManager);

end.
