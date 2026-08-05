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
  end;

var
  dmConn: TdmConn;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

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
