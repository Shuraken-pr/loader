unit uCatalogService;

interface

uses
  System.SysUtils, System.Generics.Collections, uEntities, dmDatabase, FireDAC.Stan.Param, Data.DB;

type
  TCatalogService = class
  private
    FDM: TdmDB;
  public
    constructor Create(ADM: TdmDB);

    // Получить плоский список категорий (UI сам построит из него дерево)
    function GetCategories: TArray<TCategory>;

    // Получить атрибуты для построения колонок таблицы
    function GetCategoryAttributes(ACategoryID: Integer): TArray<TAttributeDef>;

    // Получить детали категории с возможностью текстового поиска
    function GetParts(ACategoryID: Integer; const ASearchTerm: string = ''): TArray<TPartRow>;

    function SavePart(ACategoryID: Integer; APartID: Integer; const ACode: string;
    const AValues: TArray<TPair<string, string>>): Boolean;
    // Сохранение категории (ACategoryID = 0 для создания новой)
    function SaveCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;

    // Сохранение атрибута (AAttributeID = 0 для создания нового)
    function SaveAttribute(ACategoryID: Integer; AAttributeID: Integer; const AName: string; AType: TAttrType): Boolean;

    // Удаление атрибута (возвращает True, если успешно, или False, если есть ограничения БД)
    function DeleteAttribute(AAttributeID: Integer; out AErrorMsg: string): Boolean;

    // Удаление детали (возвращает True при успехе)
    function DeletePart(APartID: Integer): Boolean;

    // Удаление категории (возвращает True при успехе, или False и причину в AErrorMsg)
    function DeleteCategory(ACategoryID: Integer; out AErrorMsg: string): Boolean;
  end;

implementation

{ TCatalogService }

constructor TCatalogService.Create(ADM: TdmDB);
begin
  inherited Create;
  FDM := ADM;
end;

function TCatalogService.DeleteAttribute(AAttributeID: Integer;
  out AErrorMsg: string): Boolean;
begin
  Result := False;
  AErrorMsg := '';
  FDM.BeginTransaction;
  try
    FDM.qryDeleteAttribute.Close;
    FDM.qryDeleteAttribute.ParamByName('id').AsInteger := AAttributeID;
    FDM.qryDeleteAttribute.ExecSQL;
    FDM.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FDM.RollbackTransaction;
      // Перехватываем ошибку внешнего ключа (23503) или триггера
      if Pos('23503', E.Message) > 0 then
        AErrorMsg := 'Невозможно удалить атрибут: он используется в существующих деталях.'
      else
        AErrorMsg := 'Ошибка удаления: ' + E.Message;
    end;
  end;
end;

function TCatalogService.DeletePart(APartID: Integer): Boolean;
begin
  FDM.BeginTransaction;
  try
    // Выполняем удаление.
    // Благодаря ON DELETE CASCADE в схеме БД, значения атрибутов (part_values)
    // удалятся автоматически вместе с деталью.
    FDM.qryDeletePart.Close;
    FDM.qryDeletePart.ParamByName('id').AsInteger := APartID;
    FDM.qryDeletePart.ExecSQL;

    FDM.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FDM.RollbackTransaction;
      // Для деталей критических ограничений обычно нет, но на всякий случай пробрасываем ошибку
      raise Exception.Create('Ошибка при удалении детали: ' + E.Message);
    end;
  end;
end;

function TCatalogService.DeleteCategory(ACategoryID: Integer; out AErrorMsg: string): Boolean;
begin
  Result := False;
  AErrorMsg := '';

  FDM.BeginTransaction;
  try
    FDM.qryDeleteCategory.Close;
    FDM.qryDeleteCategory.ParamByName('id').AsInteger := ACategoryID;
    FDM.qryDeleteCategory.ExecSQL;

    FDM.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FDM.RollbackTransaction;

      // FireDAC оборачивает ошибки PostgreSQL. Код нарушения внешнего ключа (foreign key violation)
      // всегда содержит '23503' в тексте сообщения.
      // Это срабатывает, если у категории есть дочерние категории, атрибуты или детали.
      if Pos('23503', E.Message) > 0 then
        AErrorMsg := 'Невозможно удалить категорию: в ней есть дочерние категории, атрибуты или детали. Сначала удалите их.'
      else
        AErrorMsg := 'Ошибка удаления категории: ' + E.Message;
    end;
  end;
end;

function TCatalogService.GetCategories: TArray<TCategory>;
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
    Result[Count].ParentID := FDM.qryCategories.FieldByName('parent_id').AsInteger; // AsInteger вернет 0 для NULL
    Result[Count].Name := FDM.qryCategories.FieldByName('name').AsString;
    Result[Count].ChildCount := FDM.qryCategories.FieldByName('child_count').AsInteger;
    Inc(Count);
    FDM.qryCategories.Next;
  end;
  FDM.qryCategories.Close;
end;

function TCatalogService.GetCategoryAttributes(ACategoryID: Integer): TArray<TAttributeDef>;
var
  Count: Integer;
  TypeStr: string;
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

    TypeStr := FDM.qryAttributes.FieldByName('attr_type').AsString;
    if SameText(TypeStr, 'string') then Result[Count].AttrType := atString
    else if SameText(TypeStr, 'number') then Result[Count].AttrType := atNumber
    else if SameText(TypeStr, 'date') then Result[Count].AttrType := atDate
    else if SameText(TypeStr, 'boolean') then Result[Count].AttrType := atBoolean;

    Inc(Count);
    FDM.qryAttributes.Next;
  end;
  FDM.qryAttributes.Close;
end;

function TCatalogService.GetParts(ACategoryID: Integer; const ASearchTerm: string = ''): TArray<TPartRow>;
var
  PartDict: TDictionary<Integer, TPartRow>;
  CurrentPartID: Integer;
  CurrentRow: TPartRow;
  AttrName, ValStr: string;
  Count: Integer;
  Keys: TArray<Integer>;
  Key: Integer;
begin
  FDM.qryParts.Close;
  FDM.qryParts.ParamByName('category_id').AsInteger := ACategoryID;
  FDM.qryParts.ParamByName('search_term').AsString := ASearchTerm;
  FDM.qryParts.Open;

  PartDict := TDictionary<Integer, TPartRow>.Create;
  try
    while not FDM.qryParts.Eof do
    begin
      CurrentPartID := FDM.qryParts.FieldByName('part_id').AsInteger;

      if not PartDict.TryGetValue(CurrentPartID, CurrentRow) then
      begin
        CurrentRow := TPartRow.Create;
        CurrentRow.PartID := CurrentPartID;
        CurrentRow.Code := FDM.qryParts.FieldByName('code').AsString;
        PartDict.Add(CurrentPartID, CurrentRow);
      end;

      AttrName := FDM.qryParts.FieldByName('attr_name').AsString;

      // Формируем строковое представление значения в зависимости от того, какая колонка заполнена
      if not FDM.qryParts.FieldByName('value_string').IsNull then
        ValStr := FDM.qryParts.FieldByName('value_string').AsString
      else if not FDM.qryParts.FieldByName('value_number').IsNull then
        ValStr := FDM.qryParts.FieldByName('value_number').AsString
      else if not FDM.qryParts.FieldByName('value_date').IsNull then
        ValStr := FormatDateTime('dd.mm.yyyy', FDM.qryParts.FieldByName('value_date').AsDateTime)
      else if not FDM.qryParts.FieldByName('value_bool').IsNull then
        ValStr := IfThen(FDM.qryParts.FieldByName('value_bool').AsBoolean, 'Да', 'Нет')
      else
        ValStr := '';

      CurrentRow.Values.AddOrSetValue(AttrName, ValStr);

      FDM.qryParts.Next;
    end;

    // Преобразуем словарь в массив для возврата
    Count := 0;
    SetLength(Result, PartDict.Count);
    Keys := PartDict.Keys.ToArray;
    for Key in Keys do
    begin
      Result[Count] := PartDict.Items[Key];
      Inc(Count);
    end;

  finally
    // Очищаем словарь, но не сами объекты TPartRow, так как мы их вернули в массив
    PartDict.Free;
  end;

  FDM.qryParts.Close;
end;

function TCatalogService.SaveAttribute(ACategoryID, AAttributeID: Integer;
  const AName: string; AType: TAttrType): Boolean;
var
  TypeStr: string;
begin
  case AType of
    atString: TypeStr := 'string';
    atNumber: TypeStr := 'number';
    atDate: TypeStr := 'date';
    atBoolean: TypeStr := 'boolean';
  end;

  FDM.BeginTransaction;
  try
    if AAttributeID = 0 then
    begin
      FDM.qryInsertAttribute.Close;
      FDM.qryInsertAttribute.ParamByName('category_id').AsInteger := ACategoryID;
      FDM.qryInsertAttribute.ParamByName('name').AsString := AName;
      FDM.qryInsertAttribute.ParamByName('attr_type').AsString := TypeStr;
      FDM.qryInsertAttribute.Open;
    end
    else
    begin
      FDM.qryUpdateAttribute.Close;
      FDM.qryUpdateAttribute.ParamByName('name').AsString := AName;
      FDM.qryUpdateAttribute.ParamByName('attr_type').AsString := TypeStr;
      FDM.qryUpdateAttribute.ParamByName('id').AsInteger := AAttributeID;
      FDM.qryUpdateAttribute.ExecSQL;
    end;
    FDM.CommitTransaction;
    Result := True;
  except
    FDM.RollbackTransaction;
    raise;
  end;
end;

function TCatalogService.SaveCategory(ACategoryID: Integer; const AName: string;
  AParentID: Integer): Boolean;
begin
  FDM.BeginTransaction;
  try
    if ACategoryID = 0 then
    begin
      // Создание новой
      FDM.qryInsertCategory.Close;
      FDM.qryInsertCategory.ParamByName('name').AsString := AName;
      if AParentID = 0 then
        FDM.qryInsertCategory.ParamByName('parent_id').Clear
      else
        FDM.qryInsertCategory.ParamByName('parent_id').AsInteger := AParentID;
      FDM.qryInsertCategory.Open;
    end
    else
    begin
      // Обновление существующей
      FDM.qryUpdateCategory.Close;
      FDM.qryUpdateCategory.ParamByName('name').AsString := AName;
      if AParentID = 0 then
        FDM.qryUpdateCategory.ParamByName('parent_id').Clear
      else
        FDM.qryUpdateCategory.ParamByName('parent_id').AsInteger := AParentID;
      FDM.qryUpdateCategory.ParamByName('id').AsInteger := ACategoryID;
      FDM.qryUpdateCategory.ExecSQL;
    end;
    FDM.CommitTransaction;
    Result := True;
  except
    FDM.RollbackTransaction;
    raise; // Пробрасываем исключение дальше, чтобы UI мог его перехватить
  end;
end;

function TCatalogService.SavePart(ACategoryID, APartID: Integer;
  const ACode: string; const AValues: TArray<TPair<string, string>>): Boolean;
var
  i: Integer;
  PartID: Integer;
  AttrID: Integer;
  ValStr: string;
  ValInt: integer;
begin
  FDM.BeginTransaction;
  try
    // 1. Upsert детали
    FDM.qryUpsertPart.Close;
    FDM.qryUpsertPart.ParamByName('code').AsString := ACode;
    FDM.qryUpsertPart.ParamByName('category_id').AsInteger := ACategoryID;
    FDM.qryUpsertPart.Open;
    PartID := FDM.qryUpsertPart.Fields[0].AsInteger;
    FDM.qryUpsertPart.Close;

    // 2. Сохранение значений
    for i := 0 to High(AValues) do
    begin
      // Находим ID атрибута по имени
      FDM.qryGetAttribute.Close;
      FDM.qryGetAttribute.ParamByName('category_id').AsInteger := ACategoryID;
      FDM.qryGetAttribute.ParamByName('name').AsString := AValues[i].Key;
      FDM.qryGetAttribute.Open;

      if FDM.qryGetAttribute.IsEmpty then
        raise Exception.CreateFmt('Атрибут "%s" не найден в категории', [AValues[i].Key]);

      AttrID := FDM.qryGetAttribute.FieldByName('id').AsInteger;
      ValStr := AValues[i].Value;

      FDM.qryUpsertValue.Close;
      FDM.qryUpsertValue.ParamByName('part_id').AsInteger := PartID;
      FDM.qryUpsertValue.ParamByName('attribute_id').AsInteger := AttrID;

      var AttrType := FDM.qryGetAttribute.FieldByName('attr_type').AsString;
      if SameText(AttrType, 'string') then
      begin
        FDM.qryUpsertValue.ParamByName('value_string').AsString := ValStr;
        FDM.qryUpsertValue.ParamByName('value_number').Clear;
        FDM.qryUpsertValue.ParamByName('value_date').Clear;
        FDM.qryUpsertValue.ParamByName('value_bool').Clear;
      end
      else if SameText(AttrType, 'number') then
      begin
        FDM.qryUpsertValue.ParamByName('value_string').Clear;
        if TryStrToInt(ValStr, ValInt) then
          FDM.qryUpsertValue.ParamByName('value_number').AsInteger := ValInt
        else
          FDM.qryUpsertValue.ParamByName('value_number').AsInteger := 0;
        FDM.qryUpsertValue.ParamByName('value_date').Clear;
        FDM.qryUpsertValue.ParamByName('value_bool').Clear;
      end
      else if SameText(AttrType, 'date') then
      begin
        FDM.qryUpsertValue.ParamByName('value_string').Clear;
        FDM.qryUpsertValue.ParamByName('value_number').Clear;
        FDM.qryUpsertValue.ParamByName('value_date').AsDate := StrToDate(ValStr);
        FDM.qryUpsertValue.ParamByName('value_bool').Clear;
      end
      else if SameText(AttrType, 'boolean') then
      begin
        FDM.qryUpsertValue.ParamByName('value_string').Clear;
        FDM.qryUpsertValue.ParamByName('value_number').Clear;
        FDM.qryUpsertValue.ParamByName('value_date').Clear;
        FDM.qryUpsertValue.ParamByName('value_bool').AsBoolean := SameText(ValStr, 'true') or SameText(ValStr, 'Да');
      end;

      FDM.qryUpsertValue.ExecSQL;
      FDM.qryGetAttribute.Close;
    end;

    FDM.CommitTransaction;
    Result := True;
  except
    FDM.RollbackTransaction;
    raise;
  end;
end;

end.
