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
  dxSkinsForm, dxLayoutLookAndFeels;

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
    dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel;       // Вставка или обновление значения атрибута
  private
    { Private declarations }
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
begin
  if not PGConn.Connected then
    PGConn.Connected := True;
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
