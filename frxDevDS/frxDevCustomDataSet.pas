unit frxDevCustomDataSet;

interface

uses
  frxClass,
  frxDsgnIntf,
  System.Classes,
  System.SysUtils,
  System.Variants,
  System.Generics.Collections,
  cxVirtualTreeListHelper,
  cxTL,
  cxTLData,
  cxCustomData;

type
  { ========== TVTRecordAdapter ========== }
  { Адаптер одной записи TVTBaseRecord в интерфейс TfrxDataSet }

  TVTRecordAdapter = class(TfrxDataSet)
  private
    FSource: TVTBaseRecord;           { Обёрнутая запись }
    FFieldNames: TStringList;         { Имена полей }
    FFieldIndexes: TList<Integer>;    { Исходные индексы колонок }
    FFieldTypes: TList<TfrxFieldType>; { Типы FastReport }
    FCurrentRecNo: Integer;           { 0 = не начинали, 1 = на записи, 2+ = EOF }
    FEofFlag: Boolean;
  protected
    function GetValue(Index: string): Variant; override;
    function GetDisplayText(Index: string): WideString; override;
    function GetFieldType(Index: string): TfrxFieldType; override;
    property FieldIndexes: TList<Integer> read FFieldIndexes;
    property FieldTypes: TList<TfrxFieldType> read FFieldTypes;
  public
    constructor Create(AOwner: TComponent; ASource: TVTBaseRecord;
      AFieldNames: TStringList; AFieldIndexes: TList<Integer>;
      AFieldTypes: TList<TfrxFieldType>); reintroduce;
    destructor Destroy; override;
    procedure Open; override;
    procedure Close; override;
    procedure First; override;
    procedure Next; override;
    function Eof: Boolean; override;
    procedure GetFieldList(List: TStrings); override;
    property SourceRecord: TVTBaseRecord read FSource;
    function FieldsCount: Integer; override;
    function RecordCount: Integer; override;
  end;

  { ========== TfrxDevCustomDataSet ========== }
  { Главный класс адаптера TVTBaseDataSource для FastReport }

  TfrxDevCustomDataSet = class(TfrxUserDataSet)
  private
    FDataSource: TVTBaseDataSource<TVTBaseRecord>;
    FTreeList: TcxVirtualTreeList;
    FAdapters: TObjectList<TVTRecordAdapter>;
    FActiveAdapter: TVTRecordAdapter;
    FFieldIndexes: TList<Integer>;
    FFieldTypes: TList<TfrxFieldType>;
    FCurrentIndex: Integer;           { Index в RootHandle.Children[] }
    FCurrentNode: TcxTreeListNode;

    procedure BuildFieldListFromTreeList;
    function FieldIndex(const FieldName: string): Integer;
    function FieldType(const FieldName: string): TfrxFieldType;
    procedure InternalFirst;
    procedure InternalNext;
    function InternalEof: Boolean;
  protected
    function GetValue(Index: string): Variant; override;
    function GetDisplayText(Index: string): WideString; override;
    function GetFieldType(Index: string): TfrxFieldType; override;
    property FieldIndexes: TList<Integer> read FFieldIndexes;
    property FieldTypes: TList<TfrxFieldType> read FFieldTypes;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Привязка к конкретному экземпляру TVTBaseDataSource }
    procedure AssignDataSource(ADataSource: TVTBaseDataSource<TVTBaseRecord>;
      ATreeList: TcxVirtualTreeList);

    { Получение адаптера для записи (для Master-Detail) }
    function GetAdapterForRecord(ARecord: TVTBaseRecord): TVTRecordAdapter;

    procedure Open; override;
    procedure Close; override;
    procedure First; override;
    procedure Next; override;
    function Eof: Boolean; override;
    procedure GetFieldList(List: TStrings); override;
    function FieldsCount: Integer; override;
    function IsBlobField(const FieldName: string): Boolean; override;
    function RecordCount: Integer; override;
    property DataSource: TVTBaseDataSource<TVTBaseRecord> read FDataSource;
    property TreeList: TcxVirtualTreeList read FTreeList;
    property CurrentNode: TcxTreeListNode read FCurrentNode;
  end;

  { Регистрация типов в FastReport }
  procedure RegisterFrxDevCustomDataSet;
  procedure UnregisterFrxDevCustomDataSet;

implementation

{ ========== TVTRecordAdapter Implementation ========== }

constructor TVTRecordAdapter.Create(AOwner: TComponent;
  ASource: TVTBaseRecord; AFieldNames: TStringList;
  AFieldIndexes: TList<Integer>; AFieldTypes: TList<TfrxFieldType>);
begin
  inherited Create(AOwner);
  FSource := ASource;
  FFieldNames := TStringList.Create;
  FFieldIndexes := TList<Integer>.Create;
  FFieldTypes := TList<TfrxFieldType>.Create;
  if Assigned(AFieldNames) then
    FFieldNames.Assign(AFieldNames);
  if Assigned(AFieldIndexes) then
    FFieldIndexes.AddRange(AFieldIndexes);
  if Assigned(AFieldTypes) then
    FFieldTypes.AddRange(AFieldTypes);
  FCurrentRecNo := 0;
  FEofFlag := False;
end;

destructor TVTRecordAdapter.Destroy;
begin
  FFieldNames.Free;
  FFieldIndexes.Free;
  FFieldTypes.Free;
  inherited;
end;

procedure TVTRecordAdapter.Open;
begin
  FCurrentRecNo := 0;
  FEofFlag := False;
  inherited;
end;

procedure TVTRecordAdapter.Close;
begin
  inherited;
end;

procedure TVTRecordAdapter.First;
begin
  FCurrentRecNo := 0;
  FEofFlag := False;
  inherited;
end;

procedure TVTRecordAdapter.Next;
begin
  Inc(FCurrentRecNo);
  FEofFlag := FCurrentRecNo >= 1;  { Одна запись на адаптер }
  if Assigned(OnNext) then
    OnNext(Self);
end;

function TVTRecordAdapter.Eof: Boolean;
begin
  Result := FEofFlag;
  if Assigned(OnCheckEOF) then
    OnCheckEOF(Self, Result);
end;

function TVTRecordAdapter.GetValue(Index: string): Variant;
var
  ColIdx: Integer;
begin
  Result := Null;
  if not Assigned(FSource) then Exit;

  ColIdx := FFieldNames.IndexOf(Index);
  if (ColIdx >= 0) and (ColIdx < FFieldIndexes.Count) then
    Result := FSource.GetValue(FFieldIndexes[ColIdx]);
end;

function TVTRecordAdapter.GetDisplayText(Index: string): WideString;
var
  V: Variant;
begin
  V := GetValue(Index);
  if VarIsNull(V) then
    Result := ''
  else if VarIsStr(V) then
    Result := V
  else if VarType(V) = varBoolean then
    Result := BoolToStr(Boolean(V), True)
  else
    Result := VarToWideStr(V);
end;

procedure TVTRecordAdapter.GetFieldList(List: TStrings);
begin
  List.Assign(FFieldNames);
end;

function TVTRecordAdapter.FieldsCount: Integer;
begin
  Result := FFieldNames.Count;
end;

function TVTRecordAdapter.GetFieldType(Index: string): TfrxFieldType;
var
  ColIdx: Integer;
begin
  Result := fftString;
  ColIdx := FFieldNames.IndexOf(Index);
  if (ColIdx >= 0) and (ColIdx < FFieldTypes.Count) then
  begin
    Result := FFieldTypes[ColIdx];
  end;
end;

function TVTRecordAdapter.RecordCount: Integer;
begin
  Result := 1;  { Адаптер всегда представляет одну запись }
end;

{ ========== TfrxDevCustomDataSet Implementation ========== }

constructor TfrxDevCustomDataSet.Create(AOwner: TComponent);
begin
  inherited;
  FAdapters := TObjectList<TVTRecordAdapter>.Create(True);  { OwnsObjects = True }
  FFieldIndexes := TList<Integer>.Create;
  FFieldTypes := TList<TfrxFieldType>.Create;
  FCurrentIndex := -1;
  FCurrentNode := nil;
end;

destructor TfrxDevCustomDataSet.Destroy;
begin
  FAdapters.Free;
  FFieldIndexes.Free;
  FFieldTypes.Free;
  inherited;
end;

function TfrxDevCustomDataSet.FieldIndex(const FieldName: string): Integer;
begin
  Result := Fields.IndexOf(FieldName);
  if (Result < 0) or (Result >= FFieldIndexes.Count) then
    Result := -1;
end;

function TfrxDevCustomDataSet.FieldType(const FieldName: string): TfrxFieldType;
var
  I: Integer;
begin
  Result := fftString;
  I := FieldIndex(FieldName);
  if (I >= 0) and (I < FFieldTypes.Count) then
    Result := FFieldTypes[I];
end;

procedure TfrxDevCustomDataSet.BuildFieldListFromTreeList;
var
  I, SourceType: Integer;
  Col: TcxTreeListColumn;
  FieldName: string;
  UsedNames: TStringList;
begin
  Fields.Clear;
  FFieldIndexes.Clear;
  FFieldTypes.Clear;
  UsedNames := TStringList.Create;
  try
    if Assigned(FTreeList) then
      for I := 0 to FTreeList.ColumnCount - 1 do
      begin
        Col := FTreeList.Columns[I];
        if not Col.Visible then
          Continue;

        FieldName := Trim(Col.Caption.Text);
        if FieldName = '' then
          FieldName := Format('Col%d', [I]);
        if UsedNames.IndexOf(FieldName) >= 0 then
          FieldName := Format('%s_%d', [FieldName, I]);
        UsedNames.Add(FieldName);
        Fields.Add(FieldName);
        FFieldIndexes.Add(I);

        SourceType := 0;
        if Assigned(FDataSource) and Assigned(FDataSource.RootHandle) and
          (FDataSource.RootHandle.ChildCount > 0) then
          SourceType := TVTBaseRecord(FDataSource.RootHandle[0]).GetFieldType(I);
        case SourceType of
          varInteger, varSmallInt, varInt64, varCurrency: FFieldTypes.Add(fftNumeric);
          varSingle, varDouble: FFieldTypes.Add(fftNumeric);
          varDate: FFieldTypes.Add(fftDateTime);
          varBoolean: FFieldTypes.Add(fftBoolean);
        else
          FFieldTypes.Add(fftString);
        end;
      end;
  finally
    UsedNames.Free;
  end;
end;

procedure TfrxDevCustomDataSet.AssignDataSource(ADataSource: TVTBaseDataSource<TVTBaseRecord>;
  ATreeList: TcxVirtualTreeList);
begin
  if not Assigned(ADataSource) then
    raise EArgumentNilException.Create('ADataSource must not be nil');
  if not Assigned(ATreeList) then
    raise EArgumentNilException.Create('ATreeList must not be nil');

  Close;
  FAdapters.Clear;
  FDataSource := ADataSource;
  FTreeList := ATreeList;
  BuildFieldListFromTreeList;
end;

function TfrxDevCustomDataSet.GetAdapterForRecord(
  ARecord: TVTBaseRecord): TVTRecordAdapter;
var
  Adapter: TVTRecordAdapter;
  FieldNames: TStringList;
  FieldIndexes: TList<Integer>;
begin
  { Поиск существующего адаптера }
  for Adapter in FAdapters do
    if Adapter.SourceRecord = ARecord then
      Exit(Adapter);

  { Создание нового адаптера }
  FieldNames := TStringList.Create;
  FieldIndexes := TList<Integer>.Create;
  try
    GetFieldList(FieldNames);
    FieldIndexes.AddRange(FFieldIndexes);
    Result := TVTRecordAdapter.Create(Self, ARecord, FieldNames,
      FieldIndexes, FFieldTypes);
    FAdapters.Add(Result);
  finally
    FieldNames.Free;
    FieldIndexes.Free;
  end;
end;

procedure TfrxDevCustomDataSet.Open;
begin
  FCurrentIndex := -1;
  inherited;
end;

procedure TfrxDevCustomDataSet.Close;
begin
  FCurrentIndex := -1;
  FActiveAdapter := nil;
  inherited;
end;

procedure TfrxDevCustomDataSet.InternalFirst;
begin
  FCurrentIndex := 0;
  if Assigned(FDataSource) and Assigned(FDataSource.RootHandle) and
     Assigned(FTreeList) and Assigned(FTreeList.Root) and
    (FDataSource.RootHandle.TotalCount > 0) then
  begin
    FCurrentNode := FTreeList.Root.getFirstChild;
    FDataSource.CalcNode := FCurrentNode;
    FActiveAdapter := GetAdapterForRecord(TVTBaseRecord(FDataSource.Obj(FCurrentNode)));
  end
  else
    FActiveAdapter := nil;
end;

procedure TfrxDevCustomDataSet.First;
begin
  InternalFirst;
  inherited;
end;

procedure TfrxDevCustomDataSet.InternalNext;
begin
  Inc(FCurrentIndex);
  if Assigned(FCurrentNode) then
    FCurrentNode := FCurrentNode.GetNext;
  FDataSource.CalcNode := FCurrentNode;
  if Assigned(FDataSource) and Assigned(FCurrentNode) then
  begin
      FActiveAdapter := GetAdapterForRecord(TVTBaseRecord(FDataSource.Obj(FCurrentNode)))
  end
  else
    FActiveAdapter := nil;
end;

procedure TfrxDevCustomDataSet.Next;
begin
  InternalNext;
  inherited;
end;

function TfrxDevCustomDataSet.InternalEof: Boolean;
begin
  if not Assigned(FDataSource) or not Assigned(FDataSource.RootHandle) then
    Result := True
  else
    Result := not Assigned(FCurrentNode);
end;

function TfrxDevCustomDataSet.Eof: Boolean;
begin
  Result := InternalEof;
end;

function TfrxDevCustomDataSet.RecordCount: Integer;
begin
  if Assigned(FDataSource) and Assigned(FDataSource.RootHandle) then
    Result := FDataSource.RootHandle.TotalCount
  else
    Result := 0;
end;

function TfrxDevCustomDataSet.GetValue(Index: string): Variant;
begin
  if Assigned(FActiveAdapter) then
    Result := FActiveAdapter.GetValue(Index)
  else
    Result := Null;
end;

function TfrxDevCustomDataSet.GetDisplayText(Index: string): WideString;
begin
  if Assigned(FActiveAdapter) then
    Result := FActiveAdapter.GetDisplayText(Index)
  else
    Result := '';
end;

procedure TfrxDevCustomDataSet.GetFieldList(List: TStrings);
begin
  inherited;  { TfrxUserDataSet.GetFieldList → FFields }
end;

function TfrxDevCustomDataSet.FieldsCount: Integer;
begin
  Result := inherited FieldsCount;
end;

function TfrxDevCustomDataSet.GetFieldType(Index: string): TfrxFieldType;
begin
  Result := FieldType(Index);
end;

function TfrxDevCustomDataSet.IsBlobField(const FieldName: string): Boolean;
begin
  Result := False;  { TVTBaseRecord не поддерживает BLOB }
end;

procedure RegisterFrxDevCustomDataSet;
begin
  if frxObjects <> nil then
    frxObjects.RegisterObject1(TfrxDevCustomDataSet, nil,
      'frxDevCustomDataSet');
end;

procedure UnregisterFrxDevCustomDataSet;
begin
  if frxObjects <> nil then
    frxObjects.Unregister(TfrxDevCustomDataSet);
end;

end.
