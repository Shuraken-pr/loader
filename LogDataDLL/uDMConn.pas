unit uDMConn;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FDMoniCustomLoggerHelper;

type
  TAvailiableConnection = (tacPostGre, tacMSSql, tacOracle, tacNone);

  TdmConn = class(TDataModule)
    ConnLogData: TFDConnection;
    qrLogData: TFDQuery;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    { Private declarations }
    FFDMonitor: TFDMoniCustomLogger;
  public
    { Public declarations }
    function Connect(var AMsg: WideString; NeedReconnect: boolean = false): boolean;
  end;

var
  dmConn: TdmConn;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses Vcl.Forms, uDBConnectionSettings, uMultiDBSettingsForm;


function TdmConn.Connect(var AMsg: WideString; NeedReconnect: boolean): boolean;
var
  Settings: TDBConnectionSettings;
  NeedShowForm: boolean;
  ErrMsg: string;
  SettingsFile: string;
begin
  Result := false;
  Settings := TDBConnectionSettings.Create;
  try
    SettingsFile := ExtractFilePath(Application.ExeName) + 'LogData.xml';
    if FileExists(SettingsFile) then
      Settings.LoadFromFile(SettingsFile, []);
    if NeedReconnect then
      NeedShowForm := true
    else
      NeedShowForm := not (Settings.IsValid(ErrMsg) and Settings.TestConnection(ErrMsg));
    if NeedShowForm then
    begin
      if TfrmMultiDBSettings.Execute(Settings) then
        Settings.SaveToFile('LogData.xml', [])
      else
        exit;
    end;
    Settings.ApplyToConnection(ConnLogData);
    try
      ConnLogData.Connected := True;
      Result := true;
    except
      on E: Exception do
      begin
        AMsg := E.Message;
      end;
    end;
  finally
    FreeAndNil(Settings);
  end;
end;

procedure TdmConn.DataModuleCreate(Sender: TObject);
begin
  FFDMonitor := TFDMoniCustomLogger.Create(Self);
  FFDMonitor.SetConnection(ConnLogData);
end;

procedure TdmConn.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FFDMonitor);
end;

end.
