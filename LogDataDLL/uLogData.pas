unit uLogData;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, dxCore, dxRibbonSkins, dxRibbonCustomizationForm,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  VirtualTrees, dxBar, cxClasses, dxRibbon, uDMConn, System.Actions,
  Vcl.ActnList, VirtualTrees.Obj, Data.DB, System.ImageList, Vcl.ImgList,
  cxImageList, cxLocalization, VirtualTrees.Types, System.Generics.Collections,
  System.StrUtils, vstHelper;

type
  TVSTLogData = class(TBaseRecord)
  private
    FCol_length: WideString;
    FHave_trg: boolean;
    FColumn_name: WideString;
    FId: integer;
    FTable_name: WideString;
    FCol_type: WideString;
    FHave_log: boolean;
    FLevel: integer;
    FScheme: WideString;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure LoadFromDS(ADS: TDataSet);
    property id: integer read FId write FId;
    property Level: integer read FLevel write FLevel;
    property scheme: WideString read FScheme write FScheme;
    property table_name: WideString read FTable_name write FTable_name;
    property column_name: WideString read FColumn_name write FColumn_name;
    property col_type: WideString read FCol_type write FCol_type;
    property col_length: WideString read FCol_length write FCol_length;
    property have_trg: boolean read FHave_trg write FHave_trg;
    property have_log: boolean read FHave_log write FHave_log;
  end;

  TColumnInfo = record
    ColumnName: string;
    ColType: string;
    ColLength: string;
  end;

  TTableInfo = record
    SchemaName: string;
    TableName: string;
    Columns: TList<TColumnInfo>;
  end;

  TfrmLogData = class(TForm)
    bmActions: TdxBarManager;
    rtAll: TdxRibbonTab;
    rbActions: TdxRibbon;
    bParams: TdxBar;
    bActionsDB: TdxBar;
    vstLogData: TVirtualStringTree;
    alLogData: TActionList;
    acReconnect: TAction;
    acSave: TAction;
    acDelTriggers: TAction;
    acExpandAll: TAction;
    acCollapseAll: TAction;
    bCustomActions: TdxBar;
    btnReconnect: TdxBarLargeButton;
    btnSave: TdxBarLargeButton;
    btnDel: TdxBarLargeButton;
    btnExpandAll: TdxBarLargeButton;
    btnCollapseAll: TdxBarLargeButton;
    ilBig: TcxImageList;
    ilSmall: TcxImageList;
    cxLocalizer1: TcxLocalizer;
    dxBarLargeButton1: TdxBarLargeButton;
    acRefresh: TAction;
    procedure acReconnectExecute(Sender: TObject);
    procedure acSaveExecute(Sender: TObject);
    procedure acDelTriggersExecute(Sender: TObject);
    procedure acExpandAllExecute(Sender: TObject);
    procedure acCollapseAllExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure vstLogDataGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure acRefreshExecute(Sender: TObject);
  private
    { Private declarations }
    FDM: TdmConn;
    FCurBD: TAvailiableConnection;
    FCheckList: TStringList;
    FCreateList: TStringList;
    FTrgList: TStringList;
    FCallback: TProc<WideString>;
    function LoadResourceToStringList(const AResName: WideString; AList: TStringList): boolean;
    procedure FillGrid;
    procedure SetDM;
    function CollectSelectedTables: TDictionary<string, TTableInfo>;
    function BuildColumnDefinitions(AColumns: TList<TColumnInfo>): string;
    function BuildColumnNamesList(AColumns: TList<TColumnInfo>): string;
    function BuildNewColumns(AColumns: TList<TColumnInfo>): string;
    function BuildOldColumns(AColumns: TList<TColumnInfo>): string;
    function BuildCreateTableSQL(ASchema, ATableName: string; AColumns: TList<TColumnInfo>): string;
    function BuildCreateTriggerSQL(ASchema, ATableName: string; AColumns: TList<TColumnInfo>): string;
    function BuildDropTriggerSQL(ASchema, ATableName: string): string;
    function BuildDropFunctionSQL(ASchema, ATableName: string): string;
    procedure ReplaceTemplateVars(ATemplate: TStringList; ASchema, ATableName, AColDefs,
      AColNames, ANewCols, AOldCols: string);
  public
    { Public declarations }
    class function RunForm(ADM: TdmConn; ACallback: TProc<WideString>; var AMsg: WideString): boolean;
  end;

var
  frmLogData: TfrmLogData;

implementation

uses
  uConnectionParams;

{$R *.dfm}

{ TfrmLogData }

const
  ResStrName: array[TAvailiableConnection] of string = ('Postgre', 'MSSQL', 'Oracle', 'None');

procedure TfrmLogData.acCollapseAllExecute(Sender: TObject);
begin
  vstLogData.FullCollapse;
end;

procedure TfrmLogData.acDelTriggersExecute(Sender: TObject);
var
  Node: PVirtualNode;
  Data: TVSTLogData;
  TableKey: string;
  SQL: string;
  DropCount: Integer;
  ProcessedTables: TStringList;
begin
  ProcessedTables := TStringList.Create;
  DropCount := 0;
  try
    // Собираем выбранные таблицы (уровень 0), у которых есть триггер
    Node := vstLogData.GetFirst;
    while Assigned(Node) do
    begin
      Data := vstLogData.Obj<TVSTLogData>(Node);
      if Assigned(Data) and (Data.Level = 0) and (vstLogData.CheckState[Node] in [csCheckedNormal, csCheckedPressed]) then
      begin
        if Data.have_trg then
        begin
          TableKey := Data.scheme + '.' + Data.table_name;
          if ProcessedTables.IndexOf(TableKey) = -1 then
            ProcessedTables.Add(TableKey);
        end;
      end;
      Node := vstLogData.GetNext(Node);
    end;

    if ProcessedTables.Count = 0 then
    begin
      FCallback('Не выбрано ни одной таблицы с триггером для удаления');
      Exit;
    end;

    // Удаляем триггеры
    for TableKey in ProcessedTables do
    begin
      try
        // Извлекаем схему и имя таблицы
        SQL := BuildDropTriggerSQL(
          TableKey.Split(['.'])[0],
          TableKey.Split(['.'])[1]);
        if not SQL.IsEmpty then
          FDM.ConnLogData.ExecSQL(SQL);

        // Для PostgreSQL отдельно удаляем функцию
        if FCurBD = tacPostGre then
        begin
          SQL := BuildDropFunctionSQL(
            TableKey.Split(['.'])[0],
            TableKey.Split(['.'])[1]);
          if not SQL.IsEmpty then
            FDM.ConnLogData.ExecSQL(SQL);
        end;

        Inc(DropCount);
        FCallback('Триггер удалён для ' + TableKey);
      except
        on E: Exception do
          FCallback('Ошибка удаления триггера для ' + TableKey + ': ' + E.Message);
      end;
    end;

    if DropCount > 0 then
      FCallback('Удалено триггеров: ' + IntToStr(DropCount));

    FillGrid;
  finally
    ProcessedTables.Free;
  end;
end;

procedure TfrmLogData.acExpandAllExecute(Sender: TObject);
begin
  vstLogData.FullExpand;
end;

procedure TfrmLogData.acReconnectExecute(Sender: TObject);
var
  AMsg: WideString;
begin
  if TfrmConnections.RunForm(FDM, AMsg) then
  begin
    FCallback('Переподключение к БД выполнено');
    SetDM;
    FillGrid;
  end;
end;

procedure TfrmLogData.acRefreshExecute(Sender: TObject);
begin
  FillGrid;
end;

procedure TfrmLogData.acSaveExecute(Sender: TObject);
var
  TablesToProcess: TDictionary<string, TTableInfo>;
  SchemaTable: string;
  TableInfo: TTableInfo;
  CreateTableSQL, CreateTriggerSQL: string;
  CreatedCount: Integer;
begin
  TablesToProcess := CollectSelectedTables;
  if TablesToProcess.Count = 0 then
  begin
    FCallback('Не выбрано ни одной таблицы для создания лог-таблиц');
    Exit;
  end;

  CreatedCount := 0;
  try
    for SchemaTable in TablesToProcess.Keys do
    begin
      TableInfo := TablesToProcess[SchemaTable];
      if TableInfo.Columns.Count = 0 then
        Continue;

      try
        // Создаём лог-таблицу
        CreateTableSQL := BuildCreateTableSQL(TableInfo.SchemaName, TableInfo.TableName, TableInfo.Columns);
        if not CreateTableSQL.IsEmpty then
        begin
          CreateTableSQL := AnsiReplaceText(CreateTableSQL, '"', '');
          FDM.ConnLogData.ExecSQL(CreateTableSQL);
        end;

        // Создаём триггер
        CreateTriggerSQL := BuildCreateTriggerSQL(TableInfo.SchemaName, TableInfo.TableName, TableInfo.Columns);
        if not CreateTriggerSQL.IsEmpty then
        begin
          CreateTriggerSQL := AnsiReplaceText(CreateTriggerSQL, '"', '');
          FDM.ConnLogData.ExecSQL(CreateTriggerSQL);
        end;

        Inc(CreatedCount);
        FCallback('Создана лог-таблица для ' + SchemaTable);
      except
        on E: Exception do
          FCallback('Ошибка создания лог-таблицы для ' + SchemaTable + ': ' + E.Message);
      end;
    end;

    if CreatedCount > 0 then
      FCallback('Создано лог-таблиц: ' + IntToStr(CreatedCount));

    FillGrid;
  finally
    // Освобождаем коллекции
    for SchemaTable in TablesToProcess.Keys do
      TablesToProcess[SchemaTable].Columns.Free;
    TablesToProcess.Free;
  end;
end;

procedure TfrmLogData.FillGrid;
var
  curtable_name, table_name: string;
  curNode, parentNode: PVirtualNode;
  level: integer;
  logData: TVSTLogData;

  procedure FillLogData(ANode: PVirtualNode; ALevel: integer);
  begin
    LogData := vstLogData.Add<TVSTLogData>(ANode);
    LogData.LoadFromDS(FDM.qrLogData);
    logData.Level := ALevel;
    vstLogData.CheckType[curNode] := ctTriStateCheckBox;
    if parentNode <> nil then
      curNode := ParentNode;
  end;

begin
  if FCurBD <> tacNone then
  begin
    vstLogData.BeginUpdate;
    try
      vstLogData.Clear;
      if LoadResourceToStringList('Check' + ResStrName[FCurBD], FCheckList) then
      begin
        with FDM.qrLogData do
        begin
          Close;
          SQL.Assign(FCheckList);
          try
            Open;
            First;
            curtable_name := '';
            table_name := '';
            curNode := nil;
            while not Eof do
            begin
              table_name := FieldByName('table_name').AsWideString;
              if curtable_name <> table_name then
              begin
                curtable_name := table_name;
                curNode := vstLogData.AddChild(vstLogData.RootNode);
                parentNode := nil;
                level := 0;
                FillLogData(curNode, level);
              end;
              if AnsiLowerCase(FieldByName('column_name').AsWideString) <> 'id' then
              begin
                parentNode := curNode;
                curNode := vstLogData.AddChild(parentNode);
                level := 1;
                FillLogData(curNode, level);
              end;
              Next;
            end;
          except
            on E: Exception do
              FCallback('Ошибка выполнения запроса: ' + E.Message);
          end;
        end;
      end
      else
      begin
        FCallback('Не удалось загрузить SQL-запрос из ресурсов');
      end;
    finally
      vstLogData.EndUpdate;
    end;
  end;
end;

procedure TfrmLogData.FormCreate(Sender: TObject);
begin
  FCheckList := TStringList.Create;
  FCreateList := TStringList.Create;
  FTrgList := TStringList.Create;
  vstLogData.NodeDataSize := SizeOf(TVSTLogData);
end;

procedure TfrmLogData.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FTrgList);
  FreeAndNil(FCreateList);
  FreeAndNil(FCheckList);
end;

procedure TfrmLogData.FormShow(Sender: TObject);
begin
  FillGrid;
end;

function TfrmLogData.LoadResourceToStringList(const AResName: WideString;
  AList: TStringList): boolean;
var
  hResInfo: HRSRC;
  hResData: HGLOBAL;
  pData: Pointer;
  SizeRes: DWORD;
  ms: TMemoryStream;
begin
  Result := False;
  if (AList = nil) or (AResName = '') then Exit;

  hResInfo := FindResourceW(HInstance, PWideChar(AResName), RT_RCDATA);
  if hResInfo = 0 then
    Exit;

  hResData := LoadResource(HInstance, hResInfo);
  if hResData = 0 then
    Exit;

  SizeRes := SizeOfResource(HInstance, hResInfo);
  if SizeRes = 0 then
    Exit;

  pData := LockResource(hResData);
  if pData = nil then
    Exit;

  ms := TMemoryStream.Create;
  try
    ms.WriteBuffer(pData^, SizeRes);
    ms.Position := 0;
    try
      AList.LoadFromStream(ms);
      Result := True;
    except
      Result := False;
    end;
  finally
    ms.Free;
  end;
end;

class function TfrmLogData.RunForm(ADM: TdmConn; ACallback: TProc<WideString>; var AMsg: WideString): boolean;
begin
  Result := Assigned(ADM);
  if not Result then
  begin
    AMsg := 'Не задан dmConn';
    exit;
  end;
  try
    if not Assigned(frmLogData) then
      frmLogData := TfrmLogData.Create(nil);
    try
      frmLogData.FDM := ADM;
      frmLogData.FCallback := ACallback;
      frmLogData.SetDM;
      frmLogData.ShowModal;
    finally
      FreeAndNil(frmLogData);
    end;
  except
    on E: Exception do
    begin
      Result := false;
      AMsg := E.Message;
    end;
  end;
end;

procedure TfrmLogData.SetDM;
begin
  if FDM.ConnLogData.DriverName = 'PG' then
    FCurBD := tacPostGre
  else if FDM.ConnLogData.DriverName = 'MSSQL' then
    FCurBD := tacMSSql
  else if FDM.ConnLogData.DriverName = 'Ora' then
    FCurBD := tacOracle
  else
    FCurBD := tacNone;
end;

function TfrmLogData.BuildColumnDefinitions(AColumns: TList<TColumnInfo>): string;
var
  i: Integer;
  SL: TStringList;
  TypeStr, LenStr: string;
  ColDef: string;
begin
  SL := TStringList.Create;
  try
    for i := 0 to AColumns.Count - 1 do
    begin
      TypeStr := AnsiLowerCase(AColumns[i].ColType);
      LenStr := AColumns[i].ColLength;

      case FCurBD of
        tacPostGre:
          begin
            if TypeStr.Contains('varchar') or TypeStr.Contains('char') then
            begin
              if LenStr.IsEmpty or (LenStr = '0') then
                ColDef := AColumns[i].ColumnName + ' varchar'
              else
                ColDef := Format('%s varchar(%s)', [AColumns[i].ColumnName, LenStr]);
            end
            else if TypeStr.Contains('int') then
              ColDef := AColumns[i].ColumnName + ' int4'
            else if TypeStr.Contains('timestamp') then
              ColDef := AColumns[i].ColumnName + ' timestamp'
            else if TypeStr.Contains('date') then
              ColDef := AColumns[i].ColumnName + ' date'
            else if TypeStr.Contains('numeric') or TypeStr.Contains('decimal') then
            begin
              if not LenStr.IsEmpty then
                ColDef := Format('%s numeric(%s)', [AColumns[i].ColumnName, LenStr])
              else
                ColDef := AColumns[i].ColumnName + ' numeric';
            end
            else if TypeStr.Contains('float') or TypeStr.Contains('double') or TypeStr.Contains('real') then
              ColDef := AColumns[i].ColumnName + ' float8'
            else if TypeStr.Contains('bool') then
              ColDef := AColumns[i].ColumnName + ' bool'
            else
              ColDef := AColumns[i].ColumnName + ' text';
          end;
        tacMSSql:
          begin
            if TypeStr.Contains('varchar') or TypeStr.Contains('char') then
            begin
              if LenStr.IsEmpty or (LenStr = '0') then
                ColDef := '[' + AColumns[i].ColumnName + '] varchar(100)'
              else if LenStr = 'max' then
                ColDef := '[' + AColumns[i].ColumnName + '] varchar(max)'
              else
                ColDef := Format('[%s] varchar(%s)', [AColumns[i].ColumnName, LenStr]);
            end
            else if TypeStr.Contains('int') then
              ColDef := '[' + AColumns[i].ColumnName + '] int'
            else if TypeStr.Contains('datetime') then
              ColDef := '[' + AColumns[i].ColumnName + '] datetime'
            else if TypeStr.Contains('date') then
              ColDef := '[' + AColumns[i].ColumnName + '] date'
            else if TypeStr.Contains('numeric') or TypeStr.Contains('decimal') then
            begin
              if not LenStr.IsEmpty then
                ColDef := Format('[%s] numeric(%s)', [AColumns[i].ColumnName, LenStr])
              else
                ColDef := '[' + AColumns[i].ColumnName + '] numeric';
            end
            else if TypeStr.Contains('float') or TypeStr.Contains('double') then
              ColDef := '[' + AColumns[i].ColumnName + '] float'
            else if TypeStr.Contains('real') then
              ColDef := '[' + AColumns[i].ColumnName + '] real'
            else if TypeStr.Contains('bool') or TypeStr.Contains('bit') then
              ColDef := '[' + AColumns[i].ColumnName + '] bit'
            else
              ColDef := '[' + AColumns[i].ColumnName + '] nvarchar(100)';
          end;
        tacOracle:
          begin
            if TypeStr.Contains('varchar') or TypeStr.Contains('char') then
            begin
              if LenStr.IsEmpty or (LenStr = '0') then
                ColDef := AColumns[i].ColumnName + ' VARCHAR2(100)'
              else
              begin
                LenStr := StringReplace(LenStr, ' CHAR', '', [rfIgnoreCase]);
                LenStr := StringReplace(LenStr, '(', '', []);
                LenStr := StringReplace(LenStr, ')', '', []);
                ColDef := Format('%s VARCHAR2(%s)', [AColumns[i].ColumnName, Trim(LenStr)]);
              end;
            end
            else if TypeStr.Contains('number') then
            begin
              if not LenStr.IsEmpty and (LenStr <> '()') then
              begin
                LenStr := StringReplace(LenStr, '(', '', []);
                LenStr := StringReplace(LenStr, ')', '', []);
                ColDef := Format('%s NUMBER(%s)', [AColumns[i].ColumnName, Trim(LenStr)]);
              end
              else
                ColDef := AColumns[i].ColumnName + ' NUMBER';
            end
            else if TypeStr.Contains('timestamp') then
              ColDef := AColumns[i].ColumnName + ' TIMESTAMP'
            else if TypeStr.Contains('date') then
              ColDef := AColumns[i].ColumnName + ' DATE'
            else if TypeStr.Contains('float') or TypeStr.Contains('double') then
              ColDef := AColumns[i].ColumnName + ' FLOAT'
            else
              ColDef := AColumns[i].ColumnName + ' VARCHAR2(100)';
          end;
      else
        ColDef := AColumns[i].ColumnName + ' varchar';
      end;
      SL.Add(ColDef);
    end;
    Result := SL.CommaText;
  finally
    SL.Free;
  end;
end;

function TfrmLogData.BuildColumnNamesList(AColumns: TList<TColumnInfo>): string;
var
  i: Integer;
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    for i := 0 to AColumns.Count - 1 do
      SL.Add(AColumns[i].ColumnName);
    Result := SL.CommaText;
  finally
    SL.Free;
  end;
end;

function TfrmLogData.BuildNewColumns(AColumns: TList<TColumnInfo>): string;
var
  i: Integer;
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    for i := 0 to AColumns.Count - 1 do
    begin
      case FCurBD of
        tacPostGre:
          SL.Add('NEW.' + AColumns[i].ColumnName);
        tacMSSql:
          SL.Add('i.' + AColumns[i].ColumnName);
        tacOracle:
          SL.Add(':NEW.' + AColumns[i].ColumnName);
      else
        SL.Add(AColumns[i].ColumnName);
      end;
    end;
    Result := SL.CommaText;
  finally
    SL.Free;
  end;
end;

function TfrmLogData.BuildOldColumns(AColumns: TList<TColumnInfo>): string;
var
  i: Integer;
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    for i := 0 to AColumns.Count - 1 do
    begin
      case FCurBD of
        tacPostGre:
          SL.Add('OLD.' + AColumns[i].ColumnName);
        tacMSSql:
          SL.Add('d.' + AColumns[i].ColumnName);
        tacOracle:
          SL.Add(':OLD.' + AColumns[i].ColumnName);
      else
        SL.Add(AColumns[i].ColumnName);
      end;
    end;
    Result := SL.CommaText;
  finally
    SL.Free;
  end;
end;

procedure TfrmLogData.ReplaceTemplateVars(ATemplate: TStringList; ASchema, ATableName,
  AColDefs, AColNames, ANewCols, AOldCols: string);
var
  i: Integer;
  S: string;
begin
  for i := 0 to ATemplate.Count - 1 do
  begin
    S := ATemplate[i];
    S := StringReplace(S, 'schemaname', ASchema, [rfReplaceAll]);
    S := StringReplace(S, 'tablename', ATableName, [rfReplaceAll]);
    S := StringReplace(S, 'columnsname', AColDefs, [rfReplaceAll]);
    S := StringReplace(S, 'newcolumns', ANewCols, [rfReplaceAll]);
    S := StringReplace(S, 'oldcolumns', AOldCols, [rfReplaceAll]);
    ATemplate[i] := S;
  end;
end;

function TfrmLogData.BuildCreateTableSQL(ASchema, ATableName: string;
  AColumns: TList<TColumnInfo>): string;
var
  Template: TStringList;
  ColDefs: string;
  LogTableName: string;
begin
  Result := '';
  LogTableName := ATableName + '_log';

  // Формируем определения колонок с orig_id
  ColDefs := BuildColumnDefinitions(AColumns);

  // Загружаем шаблон из ресурсов
  Template := TStringList.Create;
  try
    if not LoadResourceToStringList('Create' + ResStrName[FCurBD], Template) then
      Exit;

    // Заменяем: tablename -> tablename_log, columnsname -> col_defs
    ReplaceTemplateVars(Template, ASchema, LogTableName, ColDefs, '', '', '');

    Result := Template.Text;
  finally
    Template.Free;
  end;
end;

function TfrmLogData.BuildCreateTriggerSQL(ASchema, ATableName: string;
  AColumns: TList<TColumnInfo>): string;
var
  Template: TStringList;
  ColNames, NewCols, OldCols: string;
  LogTableName: string;
begin
  Result := '';
  LogTableName := ASchema + '.' + ATableName + '_log';

  ColNames := BuildColumnNamesList(AColumns);
  NewCols := BuildNewColumns(AColumns);
  OldCols := BuildOldColumns(AColumns);

  Template := TStringList.Create;
  try
    if not LoadResourceToStringList('Trg' + ResStrName[FCurBD], Template) then
      Exit;

    ReplaceTemplateVars(Template, ASchema, ATableName, ColNames, ColNames, NewCols, OldCols);

    Result := Template.Text;
  finally
    Template.Free;
  end;
end;

function TfrmLogData.CollectSelectedTables: TDictionary<string, TTableInfo>;
var
  Node: PVirtualNode;
  Data: TVSTLogData;
  TableKey: string;
  TableInfo: TTableInfo;
  ColInfo: TColumnInfo;
  CheckedState: TCheckState;
  LastParent: PVirtualNode;
  LastParentData: TVSTLogData;
begin
  Result := TDictionary<string, TTableInfo>.Create;
  try
    LastParent := nil;
    LastParentData := nil;

    // Проходим по всем узлам, собираем колонки уровня 1, которые выбраны
    Node := vstLogData.GetFirst;
    while Assigned(Node) do
    begin
      Data := vstLogData.Obj<TVSTLogData>(Node);
      if Assigned(Data) then
      begin
        if Data.Level = 0 then
        begin
          // Запоминаем последний родительский узел
          LastParent := Node;
          LastParentData := Data;
        end
        else if Data.Level = 1 then
        begin
          // Это колонка
          CheckedState := vstLogData.CheckState[Node];
          if CheckedState in [csCheckedNormal, csCheckedPressed] then
          begin
            if Assigned(LastParent) and Assigned(LastParentData) then
            begin
              // Если таблица уже имеет лог-таблицу, пропускаем
              if not LastParentData.have_log then
              begin
                TableKey := LastParentData.scheme + '.' + LastParentData.table_name;

                if not Result.ContainsKey(TableKey) then
                begin
                  TableInfo.SchemaName := LastParentData.scheme;
                  TableInfo.TableName := LastParentData.table_name;
                  TableInfo.Columns := TList<TColumnInfo>.Create;
                  Result.Add(TableKey, TableInfo);
                end;

                TableInfo := Result[TableKey];
                ColInfo.ColumnName := Data.column_name;
                ColInfo.ColType := Data.col_type;
                ColInfo.ColLength := Data.col_length;
                TableInfo.Columns.Add(ColInfo);
              end;
            end;
          end;
        end;
      end;
      Node := vstLogData.GetNext(Node);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TfrmLogData.BuildDropTriggerSQL(ASchema, ATableName: string): string;
var
  TriggerName: string;
begin
  TriggerName := 'trg_' + ATableName + '_fill_log';
  case FCurBD of
    tacPostGre:
      Result := Format('DROP TRIGGER IF EXISTS %s ON %s.%s;',
        [TriggerName, ASchema, ATableName]);
    tacMSSql:
      Result := Format('DROP TRIGGER IF EXISTS %s.%s;',
        [ASchema, TriggerName]);
    tacOracle:
      Result := Format('DROP TRIGGER %s', [TriggerName]);
  else
    Result := '';
  end;
end;

function TfrmLogData.BuildDropFunctionSQL(ASchema, ATableName: string): string;
begin
  // Только для PostgreSQL — удаляем функцию триггера
  if FCurBD = tacPostGre then
    Result := Format('DROP FUNCTION IF EXISTS %s.trg_%s_fill_log();',
      [ASchema, ATableName])
  else
    Result := '';
end;

procedure TfrmLogData.vstLogDataGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
const
  RusArrBool: array[boolean] of string = ('Нет', 'Да');
var
  data: TVSTLogData;
begin
  CellText := '';
  if TextType = ttNormal then
  begin
    data := Sender.obj<TVSTLogData>(Node);
    if assigned(data) then
    begin
      if data.level = 0 then
      begin
        case column of
          0: CellText := data.scheme + '.' + data.table_name;
          2: CellText := RusArrBool[data.have_trg];
          3: CellText := RusArrBool[data.have_log];
        end;
      end
        else
      begin
        if Column = 1 then
          CellText := data.column_name;
      end;
    end;
  end;
end;

{ TVSTLogData }

constructor TVSTLogData.Create;
begin
  inherited;
  FId := 0;
  FLevel := 0;
  FScheme := '';
  FTable_name := '';
  FColumn_name := '';
  FCol_type := '';
  FCol_length := '';
  FHave_trg := false;
  FHave_log := false;
end;

destructor TVSTLogData.Destroy;
begin
  inherited;
end;

procedure TVSTLogData.LoadFromDS(ADS: TDataSet);
begin
  FScheme := ADS.FieldByName('table_schema').AsWideString;
  FTable_name := ADS.FieldByName('table_name').AsWideString;
  FColumn_name := ADS.FieldByName('column_name').AsWideString;
  FCol_type := ADS.FieldByName('col_type').AsWideString;
  FCol_length := ADS.FieldByName('col_length').AsWideString;
  FHave_trg := ADS.FieldByName('have_trg').AsBoolean;
  FHave_log := ADS.FieldByName('have_log').AsBoolean;
end;

end.
