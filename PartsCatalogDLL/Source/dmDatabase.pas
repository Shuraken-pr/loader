unit dmDatabase;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FireDAC.VCLUI.Login, FireDAC.Comp.UI, dxSkinsCore,
  dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2010Silver, dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark, dxSkinVS2010, dxCore, cxClasses, cxLookAndFeels,
  dxSkinsForm, dxLayoutLookAndFeels, FDMoniCustomLoggerHelper;

type
  TdmDB = class(TDataModule)
    PGConn: TFDConnection;
    PGTrans: TFDTransaction;
    // --- Категории ---
    qryGetCategory: TFDQuery;       // Поиск категории по имени и parent_id
    qryInsertCategory: TFDQuery;    // Создание категории

    // --- Атрибуты ---
    qryGetAttribute: TFDQuery;      // Поиск атрибута по имени и category_id
    qryInsertAttribute: TFDQuery;   // Создание атрибута

    // --- Детали ---
    qryGetPart: TFDQuery;           // Поиск детали по коду
    qryUpsertPart: TFDQuery;        // Вставка или обновление детали

    // --- Значения ---
    qryUpsertValue: TFDQuery;
    LDPg: TFDGUIxLoginDialog;
    qryCategories: TFDQuery;
    qryAttributes: TFDQuery;
    qryParts: TFDQuery;
    qryGetCategoryName: TFDQuery;
    qryExportParts: TFDQuery;
    qryChildCategories: TFDQuery;
    qryRootCategories: TFDQuery;
    qryUpdateCategory: TFDQuery;
    qryUpdateAttribute: TFDQuery;
    qryDeleteAttribute: TFDQuery;
    qryDeletePart: TFDQuery;
    qryDeleteCategory: TFDQuery;
    dxSkinController: TdxSkinController;
    dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;
    qryReportCategories: TFDQuery;
    qryReportParts: TFDQuery;
    qryReportCategoriesid: TIntegerField;
    qryReportCategoriesparent_id: TIntegerField;
    qryReportCategorieslevel: TIntegerField;
    qryReportCategoriesname: TWideStringField;
    qryReportCategoriespath: TWideMemoField;
    qryReportCategoriesvisual_tree: TWideMemoField;
    qryReportPartspart_id: TIntegerField;
    qryReportPartscode: TWideStringField;
    qryReportPartscategory_id: TIntegerField;
    qryReportPartsattributes_str: TWideMemoField;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);       // Вставка или обновление значения атрибута
  private
    { Private declarations }
    FFDMonitor: TFDMoniCustomLogger;
  public
    { Public declarations }
    procedure Connect;
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
  end;

var
  dmDB: TdmDB;

function IfThen(AValue: Boolean; const ATrue: string; const AFalse: string): string;

implementation

uses Winapi.Windows, Winapi.Messages, Vcl.Forms, uDBConnectionSettings, uMultiDBSettingsForm;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

function IfThen(AValue: Boolean; const ATrue: string; const AFalse: string): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

procedure TdmDB.Connect;
var
  Settings: TDBConnectionSettings;
  NeedShowForm: boolean;
  ErrMsg: string;
  SettingsFile: string;
begin
  if not PGConn.Connected then
  begin
    Settings := TDBConnectionSettings.Create;
    try
      SettingsFile := ExtractFilePath(Application.ExeName) + 'PartsCatalog.xml';
      if FileExists(SettingsFile) then
        Settings.LoadFromFile(SettingsFile, []);
      NeedShowForm := not (Settings.IsValid(ErrMsg) and Settings.TestConnection(ErrMsg));
      if NeedShowForm then
      begin
        Settings.DBType := dbPostgreSQL;
        Settings.ShowDBTypeSelector := false;
        if TfrmMultiDBSettings.Execute(Settings) then
          Settings.SaveToFile('PartsCatalog.xml', [])
        else
          exit;
      end;
      Settings.ApplyToConnection(PGConn);
      PGConn.Connected := True;
    finally
      FreeAndNil(Settings);
    end;
  end;
end;

procedure TdmDB.DataModuleCreate(Sender: TObject);
begin
  FFDMonitor := TFDMoniCustomLogger.Create(Self);
  FFDMonitor.SetConnection(PGConn);
end;

procedure TdmDB.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FFDMonitor);
end;

procedure TdmDB.BeginTransaction;
begin
  if not PGTrans.Active then
    PGTrans.StartTransaction;
end;

procedure TdmDB.CommitTransaction;
begin
  if PGTrans.Active then
    PGTrans.Commit;
end;

procedure TdmDB.RollbackTransaction;
begin
  if PGTrans.Active then
    PGTrans.Rollback;
end;

end.
