unit uXmlExporter;

interface

uses
  System.SysUtils, System.Classes, Xml.XmlDoc, Xml.XmlIntf,
  dmDatabase, System.Generics.Collections, FireDac.Stan.Param;

type
  // Вспомогательная запись для хранения категорий в памяти
  TExportCat = record
    ID: Integer;
    ParentID: Integer;
    Name: string;
  end;

  TXmlExporter = class
  private
    FDM: TdmDb;
    FAllCategories: TArray<TExportCat>; // Массив всех категорий

    procedure ExportCategory(ANode: IXMLNode; ACategoryID: Integer);
  public
    constructor Create(ADM: TdmDb);
    procedure ExportToFile(const AFileName: string);
  end;

implementation

{ TXmlExporter }

constructor TXmlExporter.Create(ADM: TdmDb);
begin
  inherited Create;
  FDM := ADM;
end;

procedure TXmlExporter.ExportToFile(const AFileName: string);
var
  XmlDocument: IXMLDocument;
  RootNode: IXMLNode;
  i: Integer;
begin
  // 1. ОДНОКРАТНО загружаем все категории в память перед началом экспорта
  // Мы используем существующий qryCategories из dmDatabase
  FDM.qryCategories.Close;
  FDM.qryCategories.Open;

  SetLength(FAllCategories, FDM.qryCategories.RecordCount);
  i := 0;
  while not FDM.qryCategories.Eof do
  begin
    FAllCategories[i].ID := FDM.qryCategories.FieldByName('id').AsInteger;
    // AsInteger автоматически вернет 0, если parent_id IS NULL
    FAllCategories[i].ParentID := FDM.qryCategories.FieldByName('parent_id').AsInteger;
    FAllCategories[i].Name := FDM.qryCategories.FieldByName('name').AsString;
    Inc(i);
    FDM.qryCategories.Next;
  end;
  FDM.qryCategories.Close;

  // 2. Инициализация XML
  XmlDocument := NewXMLDocument;
  XmlDocument.Encoding := 'UTF-8';
  XmlDocument.Options := [doNodeAutoIndent];

  RootNode := XmlDocument.AddChild('catalog');
  RootNode.Attributes['version'] := '1.0';

  // 3. Запускаем рекурсию только для корневых категорий (ParentID = 0)
  for i := 0 to High(FAllCategories) do
  begin
    if FAllCategories[i].ParentID = 0 then
      ExportCategory(RootNode, FAllCategories[i].ID);
  end;

  XmlDocument.SaveToFile(AFileName);
end;

procedure TXmlExporter.ExportCategory(ANode: IXMLNode; ACategoryID: Integer);
var
  CatNode, AttrNode, PartNode, ValNode: IXMLNode;
  CatName, CurrentPartCode, ValStr: string;
  i: Integer;
begin
  // 1. Имя категории (берем из памяти, запросов к БД нет!)
  CatName := '';
  for i := 0 to High(FAllCategories) do
  begin
    if FAllCategories[i].ID = ACategoryID then
    begin
      CatName := FAllCategories[i].Name;
      Break;
    end;
  end;

  CatNode := ANode.AddChild('category');
  CatNode.Attributes['name'] := CatName;

  // 2. Атрибуты категории (запрос к БД)
  FDM.qryAttributes.Close;
  FDM.qryAttributes.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryAttributes.Open;
  while not FDM.qryAttributes.Eof do
  begin
    AttrNode := CatNode.AddChild('attribute');
    AttrNode.Attributes['name'] := FDM.qryAttributes.FieldByName('name').AsString;
    AttrNode.Attributes['type'] := FDM.qryAttributes.FieldByName('attr_type').AsString;
    FDM.qryAttributes.Next;
  end;
  FDM.qryAttributes.Close;

  // 3. Детали категории (запрос к БД)
  FDM.qryExportParts.Close;
  FDM.qryExportParts.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryExportParts.Open;

  CurrentPartCode := '';
  PartNode := nil;

  while not FDM.qryExportParts.Eof do
  begin
    var PartCode := FDM.qryExportParts.FieldByName('code').AsString;
    if PartCode <> CurrentPartCode then
    begin
      CurrentPartCode := PartCode;
      PartNode := CatNode.AddChild('part');
      PartNode.Attributes['code'] := CurrentPartCode;
    end;

    ValNode := PartNode.AddChild('value');
    ValNode.Attributes['attribute'] := FDM.qryExportParts.FieldByName('attr_name').AsString;

    if not FDM.qryExportParts.FieldByName('value_string').IsNull then
      ValStr := FDM.qryExportParts.FieldByName('value_string').AsString
    else if not FDM.qryExportParts.FieldByName('value_number').IsNull then
      ValStr := FDM.qryExportParts.FieldByName('value_number').AsString
    else if not FDM.qryExportParts.FieldByName('value_date').IsNull then
      ValStr := FormatDateTime('dd.mm.yyyy', FDM.qryExportParts.FieldByName('value_date').AsDateTime)
    else if not FDM.qryExportParts.FieldByName('value_bool').IsNull then
      ValStr := IfThen(FDM.qryExportParts.FieldByName('value_bool').AsBoolean, 'true', 'false')
    else
      ValStr := '';

    ValNode.Text := ValStr;
    FDM.qryExportParts.Next;
  end;
  FDM.qryExportParts.Close;

  // 4. Рекурсия: дочерние категории (ИЩЕМ В ПАМЯТИ, а не через TFDQuery!)
  for i := 0 to High(FAllCategories) do
  begin
    if FAllCategories[i].ParentID = ACategoryID then
      ExportCategory(CatNode, FAllCategories[i].ID);
  end;
end;

end.
