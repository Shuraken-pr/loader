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
  dxSkinsForm, dxLayoutLookAndFeels, FireDAC.Moni.Base, FireDAC.Moni.Custom.Logger;

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
    procedure FDMonitorOutput(ASender: TFDMoniClientLinkBase; const AClassName,
      AObjName, AMessage: string);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);       // Вставка или обновление значения атрибута
  private
    { Private declarations }
    FFDMonitor: TFDMoniCustomClientLink;
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

procedure TdmDB.DataModuleCreate(Sender: TObject);
begin
  FFDMonitor := TFDMoniCustomClientLink.Create(Self);
  FFDMonitor.Tracing := true;
  FFDMonitor.EventKinds := [ekCmdExecute, ekSQL];
  FFDMonitor.OnOutput := FDMonitorOutput;
end;

procedure TdmDB.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FFDMonitor);
end;

type
  THackFDPhysCommand = class(TFDPhysCommand);

procedure TdmDB.FDMonitorOutput(ASender: TFDMoniClientLinkBase;
  const AClassName, AObjName, AMessage: string);
var
  j: integer;
  obj: TObject;
  AppName, ObjName, Msg, ParamStr: string;
  cmd: THackFDPhysCommand;
begin
  cmd := nil;
  AppName := ExtractFileName(Application.ExeName);
  ObjName := AObjName;
  if AMessage.Contains('>> Open') or AMessage.Contains('>> Execute') then
  begin
    msg := AMessage;
    obj := TFDMoniCustomClient(FFDMonitor.CClient).CurSender;
    if Assigned(obj) and (obj is TFDPhysCommand) then
      cmd := THackFDPhysCommand(obj);

    if Assigned(cmd) then
    begin
      ParamStr := '';
      msg := cmd.GetCommandText;
      for j := 0 to cmd.GetParams.Count - 1 do
      begin
        if j = 0 then
          paramStr := 'declare' + #13#10;
        if not (cmd.GetParams[j].DataType in [ftBlob, ftUnknown]) then
        begin
          paramStr := paramStr + cmd.GetParams[j].Name + '=' + cmd.GetParams[j].AsString + #13#10;
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
