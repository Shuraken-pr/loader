unit uCatalogService;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants, uEntities, 
  uCatalogRepositoryIntf;

type
  TCatalogService = class
  private
    FRepo: ICatalogRepository;
    
    // Хелперы для маппинга
    function MapTypeStrToEnum(const ATypeStr: string): TAttrType;
    function MapTypeEnumToStr(AType: TAttrType): string;
    function FormatDBValueToStr(const AAttrType: string; 
      const AValStr, AValNum, AValDate, AValBool: Variant): string;
  public
    constructor Create(ARepo: ICatalogRepository);

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
    function SaveAttribute(ACategoryID: Integer; AAttributeID: Integer; 
      const AName: string; AType: TAttrType): Boolean;

    // Удаление атрибута (возвращает True, если успешно, или False, если есть ограничения БД)
    function DeleteAttribute(AAttributeID: Integer; out AErrorMsg: string): Boolean;

    // Удаление детали (возвращает True при успехе)
    function DeletePart(APartID: Integer): Boolean;

    // Удаление категории (возвращает True при успехе, или False и причину в AErrorMsg)
    function DeleteCategory(ACategoryID: Integer; out AErrorMsg: string): Boolean;
  end;

implementation

{ TCatalogService }

constructor TCatalogService.Create(ARepo: ICatalogRepository);
begin
  inherited Create;
  FRepo := ARepo;
end;

function TCatalogService.MapTypeStrToEnum(const ATypeStr: string): TAttrType;
begin
  if SameText(ATypeStr, 'string') then Result := atString
  else if SameText(ATypeStr, 'number') then Result := atNumber
  else if SameText(ATypeStr, 'date') then Result := atDate
  else if SameText(ATypeStr, 'boolean') then Result := atBoolean
  else Result := atString; // Default
end;

function TCatalogService.MapTypeEnumToStr(AType: TAttrType): string;
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

function TCatalogService.FormatDBValueToStr(const AAttrType: string; 
  const AValStr, AValNum, AValDate, AValBool: Variant): string;
begin
  // Формируем строковое представление значения в зависимости от того, какая колонка заполнена
  if not VarIsNull(AValStr) and not VarIsEmpty(AValStr) then
    Result := VarToStr(AValStr)
  else if not VarIsNull(AValNum) and not VarIsEmpty(AValNum) then
    Result := VarToStr(AValNum)
  else if not VarIsNull(AValDate) and not VarIsEmpty(AValDate) then
    Result := FormatDateTime('dd.mm.yyyy', VarToDateTime(AValDate))
  else if not VarIsNull(AValBool) and not VarIsEmpty(AValBool) then
  begin
    if VarIsType(AValBool, varBoolean) and boolean(AValBool) then
      Result := 'Да'
    else
      Result := 'Нет';
  end
  else
    Result := '';
end;

function TCatalogService.DeleteAttribute(AAttributeID: Integer;
  out AErrorMsg: string): Boolean;
begin
  Result := False;
  AErrorMsg := '';
  FRepo.BeginTransaction;
  try
    FRepo.DeleteAttribute(AAttributeID);
    FRepo.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FRepo.RollbackTransaction;
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
  FRepo.BeginTransaction;
  try
    // Выполняем удаление.
    // Благодаря ON DELETE CASCADE в схеме БД, значения атрибутов (part_values)
    // удалятся автоматически вместе с деталью.
    FRepo.DeletePart(APartID);
    FRepo.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FRepo.RollbackTransaction;
      // Для деталей критических ограничений обычно нет, но на всякий случай пробрасываем ошибку
      raise Exception.Create('Ошибка при удалении детали: ' + E.Message);
    end;
  end;
end;

function TCatalogService.DeleteCategory(ACategoryID: Integer; out AErrorMsg: string): Boolean;
begin
  Result := False;
  AErrorMsg := '';

  FRepo.BeginTransaction;
  try
    FRepo.DeleteCategory(ACategoryID);
    FRepo.CommitTransaction;
    Result := True;
  except
    on E: Exception do
    begin
      FRepo.RollbackTransaction;

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
  DBItems: TArray<TDBCategory>;
  i: Integer;
begin
  DBItems := FRepo.SelectCategories;
  SetLength(Result, Length(DBItems));
  for i := 0 to High(DBItems) do
  begin
    Result[i].ID := DBItems[i].ID;
    Result[i].ParentID := DBItems[i].ParentID;
    Result[i].Name := DBItems[i].Name;
    Result[i].ChildCount := DBItems[i].ChildCount;
  end;
end;

function TCatalogService.GetCategoryAttributes(ACategoryID: Integer): TArray<TAttributeDef>;
var
  DBItems: TArray<TDBAttribute>;
  i: Integer;
begin
  DBItems := FRepo.SelectAttributes(ACategoryID);
  SetLength(Result, Length(DBItems));
  for i := 0 to High(DBItems) do
  begin
    Result[i].ID := DBItems[i].ID;
    Result[i].Name := DBItems[i].Name;
    Result[i].AttrType := MapTypeStrToEnum(DBItems[i].TypeStr);
  end;
end;

function TCatalogService.GetParts(ACategoryID: Integer; const ASearchTerm: string = ''): TArray<TPartRow>;
var
  PartDict: TDictionary<Integer, TPartRow>;
  DBItems: TArray<TDBPartValue>;
  i: Integer;
  CurrentPartID: Integer;
  CurrentRow: TPartRow;
  AttrName, ValStr: string;
  Count: Integer;
  Keys: TArray<Integer>;
  Key: Integer;
  AttrTypeStr: string;
begin
  DBItems := FRepo.SelectParts(ACategoryID, ASearchTerm);

  PartDict := TDictionary<Integer, TPartRow>.Create;
  try
    for i := 0 to High(DBItems) do
    begin
      CurrentPartID := DBItems[i].PartID;

      if not PartDict.TryGetValue(CurrentPartID, CurrentRow) then
      begin
        CurrentRow := TPartRow.Create;
        CurrentRow.PartID := CurrentPartID;
        CurrentRow.Code := DBItems[i].Code;
        PartDict.Add(CurrentPartID, CurrentRow);
      end;

      AttrName := DBItems[i].AttrName;
      
      // Определяем тип атрибута (название типа не приходит из SelectParts, 
      // но мы можем его восстановить по заполненному варианту, либо упростить,
      // так как в оригинале он использовался только для форматирования даты)
      if not VarIsNull(DBItems[i].ValDate) and not VarIsEmpty(DBItems[i].ValDate) then
        AttrTypeStr := 'date'
      else if not VarIsNull(DBItems[i].ValBool) and not VarIsEmpty(DBItems[i].ValBool) then
        AttrTypeStr := 'boolean'
      else if not VarIsNull(DBItems[i].ValNum) and not VarIsEmpty(DBItems[i].ValNum) then
        AttrTypeStr := 'number'
      else
        AttrTypeStr := 'string';

      ValStr := FormatDBValueToStr(AttrTypeStr, DBItems[i].ValStr, DBItems[i].ValNum, DBItems[i].ValDate, DBItems[i].ValBool);
      CurrentRow.Values.AddOrSetValue(AttrName, ValStr);
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
end;

function TCatalogService.SaveAttribute(ACategoryID, AAttributeID: Integer;
  const AName: string; AType: TAttrType): Boolean;
var
  TypeStr: string;
begin
  TypeStr := MapTypeEnumToStr(AType);

  FRepo.BeginTransaction;
  try
    if AAttributeID = 0 then
      FRepo.InsertAttribute(ACategoryID, AName, TypeStr)
    else
      FRepo.UpdateAttribute(AAttributeID, AName, TypeStr);
      
    FRepo.CommitTransaction;
    Result := True;
  except
    FRepo.RollbackTransaction;
    raise;
  end;
end;

function TCatalogService.SaveCategory(ACategoryID: Integer; const AName: string;
  AParentID: Integer): Boolean;
begin
  FRepo.BeginTransaction;
  try
    if ACategoryID = 0 then
      FRepo.InsertCategory(AName, AParentID)
    else
      FRepo.UpdateCategory(ACategoryID, AName, AParentID);
      
    FRepo.CommitTransaction;
    Result := True;
  except
    FRepo.RollbackTransaction;
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
  AttrTypeStr: string;
begin
  FRepo.BeginTransaction;
  try
    // 1. Upsert детали
    PartID := FRepo.UpsertPart(ACategoryID, APartID, ACode);

    // 2. Сохранение значений
    for i := 0 to High(AValues) do
    begin
      // Находим ID атрибута по имени
      if not FRepo.FindAttribute(ACategoryID, AValues[i].Key, AttrID, AttrTypeStr) then
        raise Exception.CreateFmt('Атрибут "%s" не найден в категории', [AValues[i].Key]);

      ValStr := AValues[i].Value;

      // Делегируем сохранение значения и его парсинг репозиторию
      FRepo.UpsertValue(PartID, AttrID, AttrTypeStr, ValStr);
    end;

    FRepo.CommitTransaction;
    Result := True;
  except
    FRepo.RollbackTransaction;
    raise;
  end;
end;

end.
