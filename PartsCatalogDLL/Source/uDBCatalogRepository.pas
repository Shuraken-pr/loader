unit uDBCatalogRepository;

interface

uses
  System.SysUtils, System.Classes, System.Variants, Data.DB, FireDAC.Stan.Param,
  dmDatabase, uCatalogRepositoryIntf;

type
  TdmDBCatalogRepository = class(TInterfacedObject, ICatalogRepository)
  private
    FDM: TdmDB;
  public
    constructor Create(ADM: TdmDB);

    // Транзакции
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;

    // Чтение
    function SelectCategories: TArray<TDBCategory>;
    function SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
    function SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;
    function FindAttribute(ACategoryID: Integer; const AName: string; out AAttrID: Integer; out ATypeStr: string): Boolean;

    // Запись
    function InsertCategory(const AName: string; AParentID: Integer): Integer;
    function UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;
    function InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
    function UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;
    function UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer;
    procedure UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);

    // Удаление
    procedure DeleteAttribute(AAttributeID: Integer);
    procedure DeletePart(APartID: Integer);
    procedure DeleteCategory(ACategoryID: Integer);
  end;

implementation

{ TdmDBCatalogRepository }

constructor TdmDBCatalogRepository.Create(ADM: TdmDB);
begin
  inherited Create;
  FDM := ADM;
end;

procedure TdmDBCatalogRepository.BeginTransaction;
begin
  FDM.BeginTransaction;
end;

procedure TdmDBCatalogRepository.CommitTransaction;
begin
  FDM.CommitTransaction;
end;

procedure TdmDBCatalogRepository.RollbackTransaction;
begin
  FDM.RollbackTransaction;
end;

function TdmDBCatalogRepository.SelectCategories: TArray<TDBCategory>;
var
  Count: Integer;
begin
  FDM.qryCategories.Close;
  FDM.qryCategories.Open;

  Count := 0;
  SetLength(Result, FDM.qryCategories.RecordCount);
  while not FDM.qryCategories.Eof do
  begin
    Result[Count].ID := FDM.qryCategories.FieldByName('id').AsInteger;
    Result[Count].ParentID := FDM.qryCategories.FieldByName('parent_id').AsInteger;
    Result[Count].Name := FDM.qryCategories.FieldByName('name').AsString;
    Result[Count].ChildCount := FDM.qryCategories.FieldByName('child_count').AsInteger;
    Inc(Count);
    FDM.qryCategories.Next;
  end;
  FDM.qryCategories.Close;
end;

function TdmDBCatalogRepository.SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
var
  Count: Integer;
begin
  FDM.qryAttributes.Close;
  FDM.qryAttributes.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryAttributes.Open;

  Count := 0;
  SetLength(Result, FDM.qryAttributes.RecordCount);
  while not FDM.qryAttributes.Eof do
  begin
    Result[Count].ID := FDM.qryAttributes.FieldByName('id').AsInteger;
    Result[Count].Name := FDM.qryAttributes.FieldByName('name').AsString;
    Result[Count].TypeStr := FDM.qryAttributes.FieldByName('attr_type').AsString;
    Inc(Count);
    FDM.qryAttributes.Next;
  end;
  FDM.qryAttributes.Close;
end;

function TdmDBCatalogRepository.SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;
var
  Count: Integer;
begin
  FDM.qryParts.Close;
  FDM.qryParts.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryParts.ParamByName('search_term').AsString := ASearchTerm;
  FDM.qryParts.Open;

  Count := 0;
  SetLength(Result, FDM.qryParts.RecordCount);
  while not FDM.qryParts.Eof do
  begin
    Result[Count].PartID := FDM.qryParts.FieldByName('part_id').AsInteger;
    Result[Count].Code := FDM.qryParts.FieldByName('code').AsString;
    Result[Count].AttrName := FDM.qryParts.FieldByName('attr_name').AsString;

    if not FDM.qryParts.FieldByName('value_string').IsNull then
      Result[Count].ValStr := FDM.qryParts.FieldByName('value_string').AsString
    else
      Result[Count].ValStr := Null;

    if not FDM.qryParts.FieldByName('value_number').IsNull then
      Result[Count].ValNum := FDM.qryParts.FieldByName('value_number').AsFloat
    else
      Result[Count].ValNum := Null;

    if not FDM.qryParts.FieldByName('value_date').IsNull then
      Result[Count].ValDate := FDM.qryParts.FieldByName('value_date').AsDateTime
    else
      Result[Count].ValDate := Null;

    if not FDM.qryParts.FieldByName('value_bool').IsNull then
      Result[Count].ValBool := FDM.qryParts.FieldByName('value_bool').AsBoolean
    else
      Result[Count].ValBool := Null;

    Inc(Count);
    FDM.qryParts.Next;
  end;
  FDM.qryParts.Close;
end;

function TdmDBCatalogRepository.FindAttribute(ACategoryID: Integer; const AName: string;
  out AAttrID: Integer; out ATypeStr: string): Boolean;
begin
  FDM.qryGetAttribute.Close;
  FDM.qryGetAttribute.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryGetAttribute.ParamByName('name').AsString := AName;
  FDM.qryGetAttribute.Open;

  Result := not FDM.qryGetAttribute.IsEmpty;
  if Result then
  begin
    AAttrID := FDM.qryGetAttribute.FieldByName('id').AsInteger;
    ATypeStr := FDM.qryGetAttribute.FieldByName('attr_type').AsString;
  end;
  FDM.qryGetAttribute.Close;
end;

function TdmDBCatalogRepository.InsertCategory(const AName: string; AParentID: Integer): Integer;
begin
  FDM.qryInsertCategory.Close;
  FDM.qryInsertCategory.ParamByName('name').AsString := AName;
  if AParentID = 0 then
    FDM.qryInsertCategory.ParamByName('parent_id').Clear
  else
    FDM.qryInsertCategory.ParamByName('parent_id').AsInteger := AParentID;
  FDM.qryInsertCategory.Open;
  Result := FDM.qryInsertCategory.Fields[0].AsInteger;
  FDM.qryInsertCategory.Close;
end;

function TdmDBCatalogRepository.UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;
begin
  FDM.qryUpdateCategory.Close;
  FDM.qryUpdateCategory.ParamByName('name').AsString := AName;
  if AParentID = 0 then
    FDM.qryUpdateCategory.ParamByName('parent_id').Clear
  else
    FDM.qryUpdateCategory.ParamByName('parent_id').AsInteger := AParentID;
  FDM.qryUpdateCategory.ParamByName('id').AsInteger := ACategoryID;
  FDM.qryUpdateCategory.ExecSQL;
  Result := True;
end;

function TdmDBCatalogRepository.InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
begin
  FDM.qryInsertAttribute.Close;
  FDM.qryInsertAttribute.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryInsertAttribute.ParamByName('name').AsString := AName;
  FDM.qryInsertAttribute.ParamByName('attr_type').AsString := ATypeStr;
  FDM.qryInsertAttribute.Open;
  Result := FDM.qryInsertAttribute.Fields[0].AsInteger;
  FDM.qryInsertAttribute.Close;
end;

function TdmDBCatalogRepository.UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;
begin
  FDM.qryUpdateAttribute.Close;
  FDM.qryUpdateAttribute.ParamByName('name').AsString := AName;
  FDM.qryUpdateAttribute.ParamByName('attr_type').AsString := ATypeStr;
  FDM.qryUpdateAttribute.ParamByName('id').AsInteger := AAttributeID;
  FDM.qryUpdateAttribute.ExecSQL;
  Result := True;
end;

function TdmDBCatalogRepository.UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer;
begin
  FDM.qryUpsertPart.Close;
  FDM.qryUpsertPart.ParamByName('code').AsString := ACode;
  FDM.qryUpsertPart.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryUpsertPart.Open;
  Result := FDM.qryUpsertPart.Fields[0].AsInteger;
  FDM.qryUpsertPart.Close;
end;

procedure TdmDBCatalogRepository.UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);
var
  ValInt: Integer;
begin
  FDM.qryUpsertValue.Close;
  FDM.qryUpsertValue.ParamByName('part_id').AsInteger := APartID;
  FDM.qryUpsertValue.ParamByName('attribute_id').AsInteger := AAttrID;

  if SameText(ATypeStr, 'string') then
  begin
    FDM.qryUpsertValue.ParamByName('value_string').AsString := AValStr;
    FDM.qryUpsertValue.ParamByName('value_number').Clear;
    FDM.qryUpsertValue.ParamByName('value_date').Clear;
    FDM.qryUpsertValue.ParamByName('value_bool').Clear;
  end
  else if SameText(ATypeStr, 'number') then
  begin
    FDM.qryUpsertValue.ParamByName('value_string').Clear;
    if TryStrToInt(AValStr, ValInt) then
      FDM.qryUpsertValue.ParamByName('value_number').AsInteger := ValInt
    else
      FDM.qryUpsertValue.ParamByName('value_number').AsInteger := 0;
    FDM.qryUpsertValue.ParamByName('value_date').Clear;
    FDM.qryUpsertValue.ParamByName('value_bool').Clear;
  end
  else if SameText(ATypeStr, 'date') then
  begin
    FDM.qryUpsertValue.ParamByName('value_string').Clear;
    FDM.qryUpsertValue.ParamByName('value_number').Clear;
    FDM.qryUpsertValue.ParamByName('value_date').AsDate := StrToDate(AValStr);
    FDM.qryUpsertValue.ParamByName('value_bool').Clear;
  end
  else if SameText(ATypeStr, 'boolean') then
  begin
    FDM.qryUpsertValue.ParamByName('value_string').Clear;
    FDM.qryUpsertValue.ParamByName('value_number').Clear;
    FDM.qryUpsertValue.ParamByName('value_date').Clear;
    FDM.qryUpsertValue.ParamByName('value_bool').AsBoolean := SameText(AValStr, 'true') or SameText(AValStr, 'Да');
  end;

  FDM.qryUpsertValue.ExecSQL;
end;

procedure TdmDBCatalogRepository.DeleteAttribute(AAttributeID: Integer);
begin
  FDM.qryDeleteAttribute.Close;
  FDM.qryDeleteAttribute.ParamByName('id').AsInteger := AAttributeID;
  FDM.qryDeleteAttribute.ExecSQL;
end;

procedure TdmDBCatalogRepository.DeletePart(APartID: Integer);
begin
  FDM.qryDeletePart.Close;
  FDM.qryDeletePart.ParamByName('id').AsInteger := APartID;
  FDM.qryDeletePart.ExecSQL;
end;

procedure TdmDBCatalogRepository.DeleteCategory(ACategoryID: Integer);
begin
  FDM.qryDeleteCategory.Close;
  FDM.qryDeleteCategory.ParamByName('id').AsInteger := ACategoryID;
  FDM.qryDeleteCategory.ExecSQL;
end;

end.
