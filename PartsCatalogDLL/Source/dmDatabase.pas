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
  dxSkinsForm, dxLayoutLookAndFeels, FireDAC.Moni.Base, FireDAC.Moni.Custom;

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
    FDMonitor: TFDMoniCustomClientLink;
    FDStoredProc1: TFDStoredProc;
    procedure FDMonitorOutput(ASender: TFDMoniClientLinkBase; const AClassName,
      AObjName, AMessage: string);       // Вставка или обновление значения атрибута
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

uses Winapi.Windows, Winapi.Messages, Vcl.Forms;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure SendMonitorMessage(const s: string);
var
  CopyData: TCopyDataStruct;  // ← стек, не требует New/Dispose
  MonitorHandle: THandle;
  Utf8Data: UTF8String;       // ← буфер живёт до конца процедуры
begin
  MonitorHandle := FindWindow(PChar('TfrmSQLLogger'),
                               PChar('SQL Logger'));
  if MonitorHandle = 0 then
    Exit;

  // Конвертируем заранее — переменная живёт до конца блока
  Utf8Data := UTF8String(s);

  // Заполняем структуру
  CopyData.dwData := 1;
  CopyData.cbData := Length(Utf8Data);
  CopyData.lpData := PAnsiChar(Utf8Data);  // ← указатель валиден, пока жив Utf8Data

  // WM_COPYDATA синхронен: данные копируются ДО возврата из SendMessage
  SendMessage(MonitorHandle, WM_COPYDATA, WPARAM(0), LPARAM(@CopyData));

  // Utf8Data освобождается здесь — после того как данные уже скопированы
end;

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

procedure TdmDB.FDMonitorOutput(ASender: TFDMoniClientLinkBase;
  const AClassName, AObjName, AMessage: string);
var
  i, j: integer;
  AppName, ObjName, Msg, ParamStr: string;
  cmd: TFDDataSet;
  qry: TFDQuery;
  sp: TFDStoredProc;
begin
  cmd := nil;
  AppName := ExtractFileName(Application.ExeName);
  ObjName := AObjName;
  if AMessage.Contains('>> Open') or AMessage.Contains('>> Execute') then
  begin
    msg := AMessage;
    for i := 0 to ComponentCount - 1 do
    begin
      if (Components[i] is TFDDataSet) and (TFDDataSet(Components[i]).Name = ObjName) then
      begin
        cmd := TFDDataSet(Components[i]);
        break;
      end;
    end;
    if Assigned(cmd) then
    begin
      ParamStr := '';
      if cmd is TFDQuery then
      begin
        qry := TFDQuery(cmd);
        msg := qry.SQL.Text;
        for j := 0 to qry.Params.Count - 1 do
        begin
          if j = 0 then
            paramStr := 'declare' + #13#10;
          if not (qry.Params[j].DataType in [ftBlob, ftUnknown]) then
          begin
            paramStr := paramStr + qry.Params[j].Name + '=' + qry.Params[j].AsString + #13#10;
          end;
        end;
      end
        else if cmd is TFDStoredProc then
      begin
        sp := TFDStoredProc(cmd);
        msg := sp.StoredProcName;
        for j := 0 to sp.Params.Count - 1 do
        begin
          if j = 0 then
            paramStr := 'declare' + #13#10;
          if not (sp.Params[j].DataType in [ftBlob, ftUnknown]) then
          begin
            paramStr := paramStr + sp.Params[j].Name + '=' + sp.Params[j].AsString + #13#10;
          end;
        end;
      end;
      msg := paramStr + msg;
      SendMonitorMessage(ObjName + '~' + AppName + '~' + msg);
    end;
  end;
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
