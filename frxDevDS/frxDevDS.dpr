library frxDevDS;

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Vcl.Forms,
  cxTL,
  cxTLData,
  frxClass,
  frxDBSet,
  frxFDComponents,
  Data.DB,
  FireDAC.Stan.Intf,
  System.Generics.Collections,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_dll_manager in '..\..\Common\intf_dll_manager.pas',
  cxVirtualTreeListHelper in '..\..\Common\cxVirtualTreeListHelper.pas',
  frxDevDSIntf in '..\..\Common\frxDevDSIntf.pas',
  frxDevCustomDataSet in 'frxDevCustomDataSet.pas',
  uSkinHelper in '..\..\Common\uSkinHelper.pas',
  dmFastReport in 'dmFastReport.pas' {dmFR: TDataModule},
  uFrxRTTIAddons in 'uFrxRTTIAddons.pas';

type
  TDLLFrxDevDS = class(TInterfacedObject, IDLLIntf, IFrxDevDS, IUsesDllManager)
  private
    FDM: TdmFR;
    FList: TObjectList<TfrxDataset>;
    FDllManager: IDllManager;
    FRegistered: Boolean;
    procedure RegisterDataSet;
    procedure UnregisterDataSet;
    procedure CreateReportPage;
    function FillReportByTVT(ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
      ATreeLists: array of TcxVirtualTreeList): boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { IDLLIntf }
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;

    { IFrxDevDS }
    procedure DesignReport(
      ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
      ATreeLists: array of TcxVirtualTreeList;
      const AReportFile: WideString = ''); safecall;
    procedure PreviewReport(
      ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
      ATreeLists: array of TcxVirtualTreeList;
      const AReportFile: WideString = ''); safecall;
    procedure SetCustomFunction(AFunc: TFunc<WideString, WideString, variant>); safecall;
    procedure DesignDBReport(
      ASQLs: array of WideString;
      ADataSetNames: array of WideString;
      const AConnectionString: WideString;
      const AReportFile: WideString = ''); safecall;
    procedure PreviewDBReport(
      const AConnectionString: WideString;
      const AReportFile: WideString = ''); safecall;

    { IUsesDllManager }
    procedure SetDllManager(AMgr: IDllManager); safecall;
  end;

{$R *.res}

function InitFrxDevDS: IFrxDevDS;
begin
  Result := TDLLFrxDevDS.Create;
end;

exports InitFrxDevDS;

{ ========== TDLLFrxDevDS ========== }

constructor TDLLFrxDevDS.Create;
begin
  inherited;
  FDM := TdmFR.Create(nil);
  FList := TObjectList<TfrxDataset>.Create(true);
  FRegistered := False;
end;

destructor TDLLFrxDevDS.Destroy;
begin
  if FRegistered then
    UnregisterDataSet;
  FreeAndNil(FList);
  if Assigned(FDM) then
    FreeAndNil(FDM);
  inherited;
end;

procedure TDLLFrxDevDS.SetCustomFunction(
  AFunc: TFunc<WideString, WideString, variant>);
begin
  if Assigned(FDM) and Assigned(AFunc) then
    FDM.CustomFunc := AFunc;
end;

procedure TDLLFrxDevDS.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
end;

function TDLLFrxDevDS.GetDescription: WideString;
begin
  Result := 'FastReport DataSource (DevExpress Integration)';
end;

procedure TDLLFrxDevDS.Init;
begin
  RegisterDataSet;
end;

procedure TDLLFrxDevDS.Fin;
begin
  UnregisterDataSet;
end;

procedure TDLLFrxDevDS.RegisterDataSet;
begin
  if FRegistered then Exit;
  try
    RegisterFrxDevCustomDataSet;
    FRegistered := True;
  except
    on E: Exception do
    begin
      FRegistered := False;
      raise;
    end;
  end;
end;

procedure TDLLFrxDevDS.UnregisterDataSet;
begin
  if not FRegistered then Exit;
  try
    UnregisterFrxDevCustomDataSet;
  finally
    FRegistered := False;
  end;
end;

function TDLLFrxDevDS.FillReportByTVT(
  ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList): boolean;
var
  I: Integer;
  FrxDS: TfrxDevCustomDataSet;
begin
  if Length(ADataSources) <> Length(ATreeLists) then
    raise Exception.Create(
      'Length of DataSources and TreeLists arrays must match');

  { Очистка отчёта }
  FDM.report.Clear;
  FList.Clear;

  { Добавление новых DataSet'ов }
  for I := Low(ADataSources) to High(ADataSources) do
  begin
    if not Assigned(ADataSources[I]) then
      raise Exception.CreateFmt('DataSource at index %d must not be nil', [I]);
    if not Assigned(ATreeLists[I]) then
      raise Exception.CreateFmt('TreeList at index %d must not be nil', [I]);

    //Управление данными идёт из приложения, поэтому сами управляем временем жизни набора.
    FrxDS := TfrxDevCustomDataSet.Create(nil);
    try
      FrxDS.AssignDataSource(ADataSources[I], ATreeLists[I]);
      FrxDS.Name := Format('frxDS%d', [I]);
      FDM.Report.DataSets.Add(FrxDS);
      FList.Add(FrxDS);
    except
      FrxDS.Free;
      raise;
    end;
  end;

  CreateReportPage;
  result := true;
end;

procedure TDLLFrxDevDS.DesignReport(ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList;
      const AReportFile: WideString = '');
begin
  if not FillReportByTVT(ADataSources, ATreeLists) then
    exit;

  if (AReportFile <> '') and FileExists(AReportFile) then
    FDM.Report.LoadFromFile(AReportFile);

  { Открытие дизайнера }
  FDM.Report.DesignReport;
end;

procedure TDLLFrxDevDS.PreviewReport(
  ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList;
  const AReportFile: WideString = '');
begin
  { Загрузка шаблона отчёта, если указан }
  if (AReportFile <> '') and FileExists(AReportFile) then
  begin
    if not FillReportByTVT(ADataSources, ATreeLists) then
      exit;

    FDM.Report.LoadFromFile(AReportFile);

    { Открытие превью }
    FDM.Report.ShowReport(True);
  end;
end;

procedure TDLLFrxDevDS.CreateReportPage;
begin
  //Обходной путь создания полноценного отчёта. Если среди созданных страниц нет страницы отчёта (page),
  //создадим её. Владельцем будет отчёт, он и будет отвечать за жизнь страницы.
  if FDM.Report.PagesCount > 0 then
  begin
    var ExistReportPage: boolean := false;
    for var i := 0 to FDM.Report.PagesCount - 1 do
    begin
      ExistReportPage := FDM.Report.Pages[i] is TfrxReportPage;
      if ExistReportPage then
        break;
    end;
    if not ExistReportPage then
    begin
      var page: TfrxReportPage := TfrxReportPage.Create(FDM.Report);
      page.Name := 'Page1';
      page.SetDefaults;
    end;
  end;
end;

procedure TDLLFrxDevDS.DesignDBReport(
  ASQLs: array of WideString;
  ADataSetNames: array of WideString;
  const AConnectionString: WideString;
  const AReportFile: WideString);
var
  I: Integer;
  FrxDB: TfrxFDQuery;
begin
  if Length(ASQLs) <> Length(ADataSetNames) then
    raise Exception.Create(
      'Length of DataSets and DataSetNames arrays must match');

  { Очистка старых DataSet'ов }
//  FDM.report.DataSets.Clear;
  FDM.Report.Clear;
  FDM.FDConn.ConnectionString := AConnectionString;
  FDM.FDConn.Params.MonitorBy := mbNone;

  { Загрузка шаблона отчёта, если указан }
  if (AReportFile <> '') and FileExists(AReportFile) then
    FDM.Report.LoadFromFile(AReportFile)
  else begin
    { Если шаблон не указан, добавляем наборы и создаём страницу отчёта }
    for I := Low(ASQLs) to High(ASQLs) do
    begin
      if (trim(ASQLs[I]) = '') then
        raise Exception.Create('SQL empty');
      //Fast Report создаёт такие объекты, как страницы. По этой причине при вызове дизайнера
      //создаются только закладки Code, Data.
      FrxDB := TfrxFDQuery.Create(FDM.Report);
      try
        FrxDB.SQL.Add(ASQLs[I]);
        FrxDB.UserName := ADataSetNames[I];
        FrxDB.Name := ADataSetNames[I];
        FDM.Report.DataSets.Add(FrxDB);
      except
        FrxDB.Free;
        raise;
      end;
    end;

    CreateReportPage;
  end;

  { Открытие дизайнера }
  FDM.Report.DesignReport;
end;

procedure TDLLFrxDevDS.PreviewDBReport(
  const AConnectionString: WideString;
  const AReportFile: WideString);
begin
  { Загрузка шаблона отчёта, если указан }
  if (AReportFile <> '') and FileExists(AReportFile) then
  begin
    FDM.FDConn.ConnectionString := AConnectionString;
    FDM.FDConn.Params.MonitorBy := mbNone;

    FDM.Report.LoadFromFile(AReportFile);

    { Открытие превью }
    FDM.Report.ShowReport(True);
  end;
end;

begin
end.
