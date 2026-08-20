program CatalogServiceFixture;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  uCatalogServiceFixture in 'uCatalogServiceFixture.pas',
  dmDatabase in '..\..\PartsCatalogDLL\Source\dmDatabase.pas' {dmDB: TDataModule},
  fAttributeDelete in '..\..\PartsCatalogDLL\Source\fAttributeDelete.pas' {fAttributeDelete},
  fAttributeEdit in '..\..\PartsCatalogDLL\Source\fAttributeEdit.pas' {frmAttributeEdit},
  fAttributeSelect in '..\..\PartsCatalogDLL\Source\fAttributeSelect.pas' {fAttributeSelect},
  fCategoryEdit in '..\..\PartsCatalogDLL\Source\fCategoryEdit.pas' {frmCategoryEdit},
  fPartEdit in '..\..\PartsCatalogDLL\Source\fPartEdit.pas' {fPartEdit},
  uCatalogService in '..\..\PartsCatalogDLL\Source\uCatalogService.pas',
  uEntities in '..\..\PartsCatalogDLL\Source\uEntities.pas',
  uXmlExporter in '..\..\PartsCatalogDLL\Source\uXmlExporter.pas',
  uXmlImporter in '..\..\PartsCatalogDLL\Source\uXmlImporter.pas',
  uDBConnectionSettings in '..\..\..\Common\uDBConnectionSettings.pas',
  uMultiDBSettingsForm in '..\..\..\Common\uMultiDBSettingsForm.pas' {frmMultiDBSettings},
  dmSkins in '..\..\..\Common\dmSkins.pas' {dmSkin: TDataModule},
  uMockCatalogRepository in 'uMockCatalogRepository.pas',
  uCatalogRepositoryIntf in '..\..\PartsCatalogDLL\Source\uCatalogRepositoryIntf.pas',
  uDBCatalogRepository in '..\..\PartsCatalogDLL\Source\uDBCatalogRepository.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);
    TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.
