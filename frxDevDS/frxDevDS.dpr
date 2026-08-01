library frxDevDS;

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Vcl.Forms,
  cxTL,
  cxTLData,
  frxClass,
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
    FDllManager: IDllManager;
    FRegistered: Boolean;
    procedure RegisterDataSet;
    procedure UnregisterDataSet;
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
      ATreeLists: array of TcxVirtualTreeList); safecall;
    procedure PreviewReport(
      ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
      ATreeLists: array of TcxVirtualTreeList); safecall;
    procedure SetCustomFunction(AFunc: TFunc<WideString, WideString, variant>); safecall;

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
  FRegistered := False;
end;

destructor TDLLFrxDevDS.Destroy;
begin
  if FRegistered then
    UnregisterDataSet;
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

procedure TDLLFrxDevDS.DesignReport(ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList);
var
  I: Integer;
  FrxDS: TfrxDevCustomDataSet;
begin
  if Length(ADataSources) <> Length(ATreeLists) then
    raise Exception.Create(
      'Length of DataSources and TreeLists arrays must match');

  { Очистка старых DataSet'ов }
  FDM.report.DataSets.Clear;

  { Добавление новых DataSet'ов }
  for I := Low(ADataSources) to High(ADataSources) do
  begin
    if not Assigned(ADataSources[I]) then
      raise Exception.CreateFmt('DataSource at index %d must not be nil', [I]);
    if not Assigned(ATreeLists[I]) then
      raise Exception.CreateFmt('TreeList at index %d must not be nil', [I]);

    FrxDS := TfrxDevCustomDataSet.Create(nil);
    try
      FrxDS.AssignDataSource(ADataSources[I], ATreeLists[I]);
      FrxDS.Name := Format('frxDS%d', [I]);
      FDM.Report.DataSets.Add(FrxDS);
    except
      FrxDS.Free;
      raise;
    end;
  end;

  { Открытие дизайнера }
  FDM.Report.DesignReport;
end;

procedure TDLLFrxDevDS.PreviewReport(
  ADataSources: array of TVTBaseDataSource<TVTBaseRecord>;
  ATreeLists: array of TcxVirtualTreeList);
var
  I: Integer;
  FrxDS: TfrxDevCustomDataSet;
begin
  if Length(ADataSources) <> Length(ATreeLists) then
    raise Exception.Create(
      'Length of DataSources and TreeLists arrays must match');

  { Очистка старых DataSet'ов }
  FDM.report.DataSets.Clear;

  { Добавление новых DataSet'ов }
  for I := Low(ADataSources) to High(ADataSources) do
  begin
    if not Assigned(ADataSources[I]) then
      raise Exception.CreateFmt('DataSource at index %d must not be nil', [I]);
    if not Assigned(ATreeLists[I]) then
      raise Exception.CreateFmt('TreeList at index %d must not be nil', [I]);

    FrxDS := TfrxDevCustomDataSet.Create(nil);
    try
      FrxDS.AssignDataSource(ADataSources[I], ATreeLists[I]);
      FrxDS.Name := Format('frxDS%d', [I]);
      FDM.Report.DataSets.Add(FrxDS);
    except
      FrxDS.Free;
      raise;
    end;
  end;

  { Открытие превью }
  FDM.Report.ShowReport(True);
end;

begin
end.
