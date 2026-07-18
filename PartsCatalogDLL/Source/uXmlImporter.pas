unit uXmlImporter;

interface

uses
  System.SysUtils, System.Classes, Xml.XmlDoc, Xml.XmlIntf,
  uEntities, dmDatabase, FireDAC.Comp.Client, FireDAC.Stan.Param, Data.DB;

type
  EImportError = class(Exception);

  TXmlImporter = class
  private
    FDM: TdmDB;

    // Вспомогательные методы
    function FindOrCreateCategory(const AName: string; AParentID: Integer): Integer;
    function FindOrCreateAttribute(ACategoryID: Integer; const AName: string; AType: TAttrType): Integer;
    function ParseAttrType(const ATypeName: string): TAttrType;
    function AttrTypeToString(AType: TAttrType): string;
    procedure ProcessCategoryNode(ANode: IXMLNode; AParentID: Integer);
    procedure ProcessPartNode(ANode: IXMLNode; ACategoryID: Integer);
  public
    constructor Create(ADM: TdmDB);
    procedure ImportFromFile(const AFileName: string);
  end;

implementation

{ TXmlImporter }

constructor TXmlImporter.Create(ADM: TdmDB);
begin
  inherited Create;
  FDM := ADM;
end;

function TXmlImporter.ParseAttrType(const ATypeName: string): TAttrType;
begin
  if SameText(ATypeName, 'string') then Result := atString
  else if SameText(ATypeName, 'number') then Result := atNumber
  else if SameText(ATypeName, 'date') then Result := atDate
  else if SameText(ATypeName, 'boolean') then Result := atBoolean
  else raise EImportError.CreateFmt('Неизвестный тип атрибута: %s', [ATypeName]);
end;

function TXmlImporter.AttrTypeToString(AType: TAttrType): string;
begin
  case AType of
    atString: Result := 'string';
    atNumber: Result := 'number';
    atDate: Result := 'date';
    atBoolean: Result := 'boolean';
  else
    Result := 'string';
  end;
end;

function TXmlImporter.FindOrCreateCategory(const AName: string; AParentID: Integer): Integer;
begin
  FDM.qryGetCategory.Close;
  FDM.qryGetCategory.ParamByName('name').AsString := AName;
  if AParentID = 0 then
    FDM.qryGetCategory.ParamByName('parent_id').Clear
  else
    FDM.qryGetCategory.ParamByName('parent_id').AsInteger := AParentID;
  FDM.qryGetCategory.Open;

  if FDM.qryGetCategory.IsEmpty then
  begin
    FDM.qryInsertCategory.Close;
    FDM.qryInsertCategory.ParamByName('name').AsString := AName;
    if AParentID = 0 then
      FDM.qryInsertCategory.ParamByName('parent_id').Clear
    else
      FDM.qryInsertCategory.ParamByName('parent_id').AsInteger := AParentID;
    FDM.qryInsertCategory.Open; // RETURNING id
    Result := FDM.qryInsertCategory.Fields[0].AsInteger;
    FDM.qryInsertCategory.Close;
  end
  else
    Result := FDM.qryGetCategory.FieldByName('id').AsInteger;

  FDM.qryGetCategory.Close;
end;

function TXmlImporter.FindOrCreateAttribute(ACategoryID: Integer; const AName: string; AType: TAttrType): Integer;
var
  ExistingType: string;
begin
  FDM.qryGetAttribute.Close;
  FDM.qryGetAttribute.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryGetAttribute.ParamByName('name').AsString := AName;
  FDM.qryGetAttribute.Open;

  if FDM.qryGetAttribute.IsEmpty then
  begin
    FDM.qryInsertAttribute.Close;
    FDM.qryInsertAttribute.ParamByName('category_id').AsInteger := ACategoryID;
    FDM.qryInsertAttribute.ParamByName('name').AsString := AName;
    FDM.qryInsertAttribute.ParamByName('attr_type').AsString := AttrTypeToString(AType);
    FDM.qryInsertAttribute.Open; // RETURNING id
    Result := FDM.qryInsertAttribute.Fields[0].AsInteger;
    FDM.qryInsertAttribute.Close;
  end
  else
  begin
    Result := FDM.qryGetAttribute.FieldByName('id').AsInteger;
    ExistingType := FDM.qryGetAttribute.FieldByName('attr_type').AsString;
    // Строгая проверка: если тип в XML отличается от типа в БД -> откат транзакции
    if not SameText(ExistingType, AttrTypeToString(AType)) then
      raise EImportError.CreateFmt(
        'Конфликт типов атрибута "%s". В БД: %s, в XML: %s',
        [AName, ExistingType, AttrTypeToString(AType)]);
  end;

  FDM.qryGetAttribute.Close;
end;

procedure TXmlImporter.ProcessCategoryNode(ANode: IXMLNode; AParentID: Integer);
var
  i: Integer;
  ChildNode: IXMLNode;
  CurrentCategoryID: Integer;
  CategoryName: string;
begin
  CategoryName := ANode.Attributes['name'];
  if CategoryName = '' then
    raise EImportError.Create('У категории отсутствует атрибут name');

  CurrentCategoryID := FindOrCreateCategory(CategoryName, AParentID);

  // Обрабатываем дочерние узлы
  for i := 0 to ANode.ChildNodes.Count - 1 do
  begin
    ChildNode := ANode.ChildNodes[i];
    if SameText(ChildNode.NodeName, 'category') then
      ProcessCategoryNode(ChildNode, CurrentCategoryID)
    else if SameText(ChildNode.NodeName, 'attribute') then
      FindOrCreateAttribute(CurrentCategoryID, ChildNode.Attributes['name'], ParseAttrType(ChildNode.Attributes['type']))
    else if SameText(ChildNode.NodeName, 'part') then
      ProcessPartNode(ChildNode, CurrentCategoryID);
  end;
end;

procedure TXmlImporter.ProcessPartNode(ANode: IXMLNode; ACategoryID: Integer);
var
  i: Integer;
  PartCode: string;
  PartID: Integer;
  ValueNode: IXMLNode;
  AttrName: string;
  AttrID: Integer;
  ValStr: string;
begin
  PartCode := ANode.Attributes['code'];
  if PartCode = '' then
    raise EImportError.Create('У детали отсутствует атрибут code');

  // Upsert детали
  FDM.qryUpsertPart.Close;
  FDM.qryUpsertPart.ParamByName('code').AsString := PartCode;
  FDM.qryUpsertPart.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryUpsertPart.Open; // RETURNING id
  PartID := FDM.qryUpsertPart.Fields[0].AsInteger;
  FDM.qryUpsertPart.Close;

  // Обработка значений атрибутов детали
  for i := 0 to ANode.ChildNodes.Count - 1 do
  begin
    ValueNode := ANode.ChildNodes[i];
    if SameText(ValueNode.NodeName, 'value') then
    begin
      AttrName := ValueNode.Attributes['attribute'];
      ValStr := ValueNode.Text;

      // Находим ID атрибута (он уже должен быть создан на этапе парсинга category)
      // Для упрощения здесь мы делаем поиск, но в продакшене можно кэшировать словарь AttrName -> AttrID для категории
      FDM.qryGetAttribute.Close;
      FDM.qryGetAttribute.ParamByName('category_id').AsInteger := ACategoryID;
      FDM.qryGetAttribute.ParamByName('name').AsString := AttrName;
      FDM.qryGetAttribute.Open;

      if FDM.qryGetAttribute.IsEmpty then
        raise EImportError.CreateFmt('Атрибут "%s" не найден в категории для детали "%s"', [AttrName, PartCode]);

      AttrID := FDM.qryGetAttribute.FieldByName('id').AsInteger;

      // Подготовка параметров для Upsert значения в зависимости от типа
      FDM.qryUpsertValue.Close;
      FDM.qryUpsertValue.ParamByName('part_id').AsInteger := PartID;
      FDM.qryUpsertValue.ParamByName('attribute_id').AsInteger := AttrID;

      case ParseAttrType(FDM.qryGetAttribute.FieldByName('attr_type').AsString) of
        atString:
          begin
            FDM.qryUpsertValue.ParamByName('value_string').AsString := ValStr;
            FDM.qryUpsertValue.ParamByName('value_number').Clear;
            FDM.qryUpsertValue.ParamByName('value_date').Clear;
            FDM.qryUpsertValue.ParamByName('value_bool').Clear;
          end;
        atNumber:
          begin
            FDM.qryUpsertValue.ParamByName('value_string').Clear;
            FDM.qryUpsertValue.ParamByName('value_number').AsFloat := StrToFloat(ValStr);
            FDM.qryUpsertValue.ParamByName('value_date').Clear;
            FDM.qryUpsertValue.ParamByName('value_bool').Clear;
          end;
        atDate:
          begin
            FDM.qryUpsertValue.ParamByName('value_string').Clear;
            FDM.qryUpsertValue.ParamByName('value_number').Clear;
            FDM.qryUpsertValue.ParamByName('value_date').AsDate := StrToDate(ValStr); // Ожидает формат системы или настройте FormatSettings
            FDM.qryUpsertValue.ParamByName('value_bool').Clear;
          end;
        atBoolean:
          begin
            FDM.qryUpsertValue.ParamByName('value_string').Clear;
            FDM.qryUpsertValue.ParamByName('value_number').Clear;
            FDM.qryUpsertValue.ParamByName('value_date').Clear;
            FDM.qryUpsertValue.ParamByName('value_bool').AsBoolean := SameText(ValStr, 'true');
          end;
      end;

      FDM.qryUpsertValue.ExecSQL;
      FDM.qryGetAttribute.Close;
    end;
  end;
end;

procedure TXmlImporter.ImportFromFile(const AFileName: string);
var
  XmlDocument: IXMLDocument;
  RootNode: IXMLNode;
  i: Integer;
begin
  if not FileExists(AFileName) then
    raise EImportError.CreateFmt('Файл не найден: %s', [AFileName]);

  XmlDocument := LoadXMLDocument(AFileName);
  XmlDocument.Active := True;
  RootNode := XmlDocument.DocumentElement;

  if not SameText(RootNode.NodeName, 'catalog') then
    raise EImportError.Create('Неверный корневой элемент XML. Ожидается "catalog"');

  FDM.Connect;
  FDM.BeginTransaction;
  try
    for i := 0 to RootNode.ChildNodes.Count - 1 do
    begin
      if SameText(RootNode.ChildNodes[i].NodeName, 'category') then
        ProcessCategoryNode(RootNode.ChildNodes[i], 0);
    end;

    FDM.CommitTransaction;
  except
    on E: Exception do
    begin
      FDM.RollbackTransaction;
      raise EImportError.CreateFmt('Ошибка импорта (транзакция отменена): %s', [E.Message]);
    end;
  end;
end;

end.
