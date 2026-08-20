unit uMockCatalogRepository;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants,
  uCatalogRepositoryIntf;

type
  TMockCatalogRepository = class(TInterfacedObject, ICatalogRepository)
  private
    FCategories: TList<TDBCategory>;
    FAttributes: TList<TDBAttribute>;
    FParts: TList<TDBPartValue>;

    // Счетчики вызовов и параметры для проверок (Assertions)
    FBeginTransaction_CallCount: Integer;
    FCommitTransaction_CallCount: Integer;
    FRollbackTransaction_CallCount: Integer;

    FInsertCategory_CallCount: Integer;
    FLastInsertCategory_Name: string;
    FLastInsertCategory_ParentID: Integer;

    FUpdateCategory_CallCount: Integer;
    FLastUpdateCategory_ID: Integer;
    FLastUpdateCategory_Name: string;
    FLastUpdateCategory_ParentID: Integer;
    
    FInsertAttribute_CallCount: Integer;
    FLastInsertAttribute_Name: string;
    FLastInsertAttribute_TypeStr: string;

    FUpdateAttribute_CallCount: Integer;
    FLastUpdateAttribute_ID: Integer;
    FLastUpdateAttribute_Name: string;
    FLastUpdateAttribute_TypeStr: string;

    FUpsertPart_CallCount: Integer;
    FLastUpsertPart_CategoryID: Integer;
    FLastUpsertPart_PartID: Integer;
    FLastUpsertPart_Code: string;

    FUpsertValue_CallCount: Integer;
    FLastUpsertValue_PartID: Integer;
    FLastUpsertValue_AttrID: Integer;
    FLastUpsertValue_AttrTypeStr: string;
    FLastUpsertValue_ValStr: string;

    FFindAttribute_CallCount: Integer;
    FLastFindAttribute_CategoryID: Integer;
    FLastFindAttribute_Name: string;

    FDeleteAttribute_CallCount: Integer;
    FLastDeleteAttribute_ID: Integer;
    FDeletePart_CallCount: Integer;
    FLastDeletePart_ID: Integer;
    FDeleteCategory_CallCount: Integer;
    FLastDeleteCategory_ID: Integer;

    FSelectParts_CallCount: Integer;
    FLastSelectParts_CategoryID: Integer;
    FLastSelectParts_SearchTerm: string;

    // Инъекция ошибок (строка = текст исключения)
    FRaiseExceptionOnSelect: string;
    FRaiseExceptionOnInsertCategory: string;
    FRaiseExceptionOnUpdateCategory: string;
    FRaiseExceptionOnInsertAttribute: string;
    FRaiseExceptionOnUpdateAttribute: string;
    FRaiseExceptionOnUpsertPart: string;
    FRaiseExceptionOnUpsertValue: string;
    FRaiseExceptionOnDeleteAttribute: string;
    FRaiseExceptionOnDeletePart: string;
    FRaiseExceptionOnDeleteCategory: string;
    FRaiseExceptionOnFindAttribute: string;

    // Настройки возврата
    FFindAttribute_Result: Boolean;
    FFindAttribute_AttrID: Integer;
    FFindAttribute_TypeStr: string;
    
    FUpsertPart_ReturnValue: Integer;
    FInsertCategory_ReturnValue: Integer;
    FInsertAttribute_ReturnValue: Integer;

  public
    constructor Create;
    destructor Destroy; override;

    // ICatalogRepository
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;

    function SelectCategories: TArray<TDBCategory>;
    function SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
    function SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;
    function FindAttribute(ACategoryID: Integer; const AName: string; out AAttrID: Integer; out ATypeStr: string): Boolean;

    function InsertCategory(const AName: string; AParentID: Integer): Integer;
    function UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;
    function InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
    function UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;
    function UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer;
    procedure UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);

    procedure DeleteAttribute(AAttributeID: Integer);
    procedure DeletePart(APartID: Integer);
    procedure DeleteCategory(ACategoryID: Integer);

    // Методы для настройки мока из тестов
    procedure AddCategory(const ACategory: TDBCategory);
    procedure AddAttribute(const AAttr: TDBAttribute);
    procedure AddPartValue(const APart: TDBPartValue);

    // Свойства для Assertions
    property BeginTransaction_CallCount: Integer read FBeginTransaction_CallCount;
    property CommitTransaction_CallCount: Integer read FCommitTransaction_CallCount;
    property RollbackTransaction_CallCount: Integer read FRollbackTransaction_CallCount;

    property InsertCategory_CallCount: Integer read FInsertCategory_CallCount;
    property LastInsertCategory_Name: string read FLastInsertCategory_Name;
    property LastInsertCategory_ParentID: Integer read FLastInsertCategory_ParentID;
    
    property UpdateCategory_CallCount: Integer read FUpdateCategory_CallCount;
    property LastUpdateCategory_ID: Integer read FLastUpdateCategory_ID;
    property LastUpdateCategory_Name: string read FLastUpdateCategory_Name;
    property LastUpdateCategory_ParentID: Integer read FLastUpdateCategory_ParentID;

    property InsertAttribute_CallCount: Integer read FInsertAttribute_CallCount;
    property LastInsertAttribute_Name: string read FLastInsertAttribute_Name;
    property LastInsertAttribute_TypeStr: string read FLastInsertAttribute_TypeStr;
    
    property UpdateAttribute_CallCount: Integer read FUpdateAttribute_CallCount;
    property LastUpdateAttribute_ID: Integer read FLastUpdateAttribute_ID;
    property LastUpdateAttribute_Name: string read FLastUpdateAttribute_Name;
    property LastUpdateAttribute_TypeStr: string read FLastUpdateAttribute_TypeStr;

    property UpsertPart_CallCount: Integer read FUpsertPart_CallCount;
    property LastUpsertPart_CategoryID: Integer read FLastUpsertPart_CategoryID;
    property LastUpsertPart_PartID: Integer read FLastUpsertPart_PartID;
    property LastUpsertPart_Code: string read FLastUpsertPart_Code;

    property UpsertValue_CallCount: Integer read FUpsertValue_CallCount;
    property LastUpsertValue_PartID: Integer read FLastUpsertValue_PartID;
    property LastUpsertValue_AttrID: Integer read FLastUpsertValue_AttrID;
    property LastUpsertValue_AttrTypeStr: string read FLastUpsertValue_AttrTypeStr;
    property LastUpsertValue_ValStr: string read FLastUpsertValue_ValStr;

    property FindAttribute_CallCount: Integer read FFindAttribute_CallCount;
    property LastFindAttribute_CategoryID: Integer read FLastFindAttribute_CategoryID;
    property LastFindAttribute_Name: string read FLastFindAttribute_Name;

    property DeleteAttribute_CallCount: Integer read FDeleteAttribute_CallCount;
    property LastDeleteAttribute_ID: Integer read FLastDeleteAttribute_ID;
    property DeletePart_CallCount: Integer read FDeletePart_CallCount;
    property LastDeletePart_ID: Integer read FLastDeletePart_ID;
    property DeleteCategory_CallCount: Integer read FDeleteCategory_CallCount;
    property LastDeleteCategory_ID: Integer read FLastDeleteCategory_ID;

    property SelectParts_CallCount: Integer read FSelectParts_CallCount;
    property LastSelectParts_CategoryID: Integer read FLastSelectParts_CategoryID;
    property LastSelectParts_SearchTerm: string read FLastSelectParts_SearchTerm;

    // Инъекция исключений
    property RaiseExceptionOnSelect: string write FRaiseExceptionOnSelect;
    property RaiseExceptionOnInsertCategory: string write FRaiseExceptionOnInsertCategory;
    property RaiseExceptionOnUpdateCategory: string write FRaiseExceptionOnUpdateCategory;
    property RaiseExceptionOnInsertAttribute: string write FRaiseExceptionOnInsertAttribute;
    property RaiseExceptionOnUpdateAttribute: string write FRaiseExceptionOnUpdateAttribute;
    property RaiseExceptionOnUpsertPart: string write FRaiseExceptionOnUpsertPart;
    property RaiseExceptionOnUpsertValue: string write FRaiseExceptionOnUpsertValue;
    property RaiseExceptionOnDeleteAttribute: string write FRaiseExceptionOnDeleteAttribute;
    property RaiseExceptionOnDeletePart: string write FRaiseExceptionOnDeletePart;
    property RaiseExceptionOnDeleteCategory: string write FRaiseExceptionOnDeleteCategory;
    property RaiseExceptionOnFindAttribute: string write FRaiseExceptionOnFindAttribute;

    // Настройка возвратов
    property FindAttribute_Result: Boolean write FFindAttribute_Result;
    property FindAttribute_AttrID: Integer write FFindAttribute_AttrID;
    property FindAttribute_TypeStr: string write FFindAttribute_TypeStr;
    
    property UpsertPart_ReturnValue: Integer write FUpsertPart_ReturnValue;
    property InsertCategory_ReturnValue: Integer write FInsertCategory_ReturnValue;
    property InsertAttribute_ReturnValue: Integer write FInsertAttribute_ReturnValue;
  end;

implementation

{ TMockCatalogRepository }

constructor TMockCatalogRepository.Create;
begin
  inherited Create;
  FCategories := TList<TDBCategory>.Create;
  FAttributes := TList<TDBAttribute>.Create;
  FParts := TList<TDBPartValue>.Create;

  FFindAttribute_Result := True;
  FUpsertPart_ReturnValue := 1;
  FInsertCategory_ReturnValue := 1;
  FInsertAttribute_ReturnValue := 1;
end;

destructor TMockCatalogRepository.Destroy;
begin
  FCategories.Free;
  FAttributes.Free;
  FParts.Free;
  inherited;
end;

procedure TMockCatalogRepository.BeginTransaction;
begin
  Inc(FBeginTransaction_CallCount);
end;

procedure TMockCatalogRepository.CommitTransaction;
begin
  Inc(FCommitTransaction_CallCount);
end;

procedure TMockCatalogRepository.RollbackTransaction;
begin
  Inc(FRollbackTransaction_CallCount);
end;

procedure TMockCatalogRepository.AddCategory(const ACategory: TDBCategory);
begin
  FCategories.Add(ACategory);
end;

procedure TMockCatalogRepository.AddAttribute(const AAttr: TDBAttribute);
begin
  FAttributes.Add(AAttr);
end;

procedure TMockCatalogRepository.AddPartValue(const APart: TDBPartValue);
begin
  FParts.Add(APart);
end;

function TMockCatalogRepository.SelectCategories: TArray<TDBCategory>;
begin
  if FRaiseExceptionOnSelect <> '' then
    raise Exception.Create(FRaiseExceptionOnSelect);
  Result := FCategories.ToArray;
end;

function TMockCatalogRepository.SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
begin
  if FRaiseExceptionOnSelect <> '' then
    raise Exception.Create(FRaiseExceptionOnSelect);
  Result := FAttributes.ToArray;
end;

function TMockCatalogRepository.SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;
begin
  if FRaiseExceptionOnSelect <> '' then
    raise Exception.Create(FRaiseExceptionOnSelect);
  Inc(FSelectParts_CallCount);
  FLastSelectParts_CategoryID := ACategoryID;
  FLastSelectParts_SearchTerm := ASearchTerm;
  Result := FParts.ToArray;
end;

function TMockCatalogRepository.FindAttribute(ACategoryID: Integer; const AName: string;
  out AAttrID: Integer; out ATypeStr: string): Boolean;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FFindAttribute_CallCount);
  FLastFindAttribute_CategoryID := ACategoryID;
  FLastFindAttribute_Name := AName;

  if FRaiseExceptionOnFindAttribute <> '' then
    raise Exception.Create(FRaiseExceptionOnFindAttribute);
    
  Result := FFindAttribute_Result;
  AAttrID := FFindAttribute_AttrID;
  ATypeStr := FFindAttribute_TypeStr;
end;

function TMockCatalogRepository.InsertCategory(const AName: string; AParentID: Integer): Integer;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FInsertCategory_CallCount);
  FLastInsertCategory_Name := AName;
  FLastInsertCategory_ParentID := AParentID;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnInsertCategory <> '' then
    raise Exception.Create(FRaiseExceptionOnInsertCategory);
    
  Result := FInsertCategory_ReturnValue;
end;

function TMockCatalogRepository.UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FUpdateCategory_CallCount);
  FLastUpdateCategory_ID := ACategoryID;
  FLastUpdateCategory_Name := AName;
  FLastUpdateCategory_ParentID := AParentID;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnUpdateCategory <> '' then
    raise Exception.Create(FRaiseExceptionOnUpdateCategory);
    
  Result := True;
end;

function TMockCatalogRepository.InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FInsertAttribute_CallCount);
  FLastInsertAttribute_Name := AName;
  FLastInsertAttribute_TypeStr := ATypeStr;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnInsertAttribute <> '' then
    raise Exception.Create(FRaiseExceptionOnInsertAttribute);
    
  Result := FInsertAttribute_ReturnValue;
end;

function TMockCatalogRepository.UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FUpdateAttribute_CallCount);
  FLastUpdateAttribute_ID := AAttributeID;
  FLastUpdateAttribute_Name := AName;
  FLastUpdateAttribute_TypeStr := ATypeStr;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnUpdateAttribute <> '' then
    raise Exception.Create(FRaiseExceptionOnUpdateAttribute);
    
  Result := True;
end;

function TMockCatalogRepository.UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer;
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FUpsertPart_CallCount);
  FLastUpsertPart_CategoryID := ACategoryID;
  FLastUpsertPart_PartID := APartID;
  FLastUpsertPart_Code := ACode;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnUpsertPart <> '' then
    raise Exception.Create(FRaiseExceptionOnUpsertPart);
    
  Result := FUpsertPart_ReturnValue;
end;

procedure TMockCatalogRepository.UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FUpsertValue_CallCount);
  FLastUpsertValue_PartID := APartID;
  FLastUpsertValue_AttrID := AAttrID;
  FLastUpsertValue_AttrTypeStr := ATypeStr;
  FLastUpsertValue_ValStr := AValStr;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnUpsertValue <> '' then
    raise Exception.Create(FRaiseExceptionOnUpsertValue);
end;

procedure TMockCatalogRepository.DeleteAttribute(AAttributeID: Integer);
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FDeleteAttribute_CallCount);
  FLastDeleteAttribute_ID := AAttributeID;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnDeleteAttribute <> '' then
    raise Exception.Create(FRaiseExceptionOnDeleteAttribute);
end;

procedure TMockCatalogRepository.DeletePart(APartID: Integer);
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FDeletePart_CallCount);
  FLastDeletePart_ID := APartID;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnDeletePart <> '' then
    raise Exception.Create(FRaiseExceptionOnDeletePart);
end;

procedure TMockCatalogRepository.DeleteCategory(ACategoryID: Integer);
begin
  // Сначала увеличиваем счетчик и сохраняем параметры (метод был вызван)
  Inc(FDeleteCategory_CallCount);
  FLastDeleteCategory_ID := ACategoryID;
  
  // Затем проверяем, нужно ли выбросить исключение
  if FRaiseExceptionOnDeleteCategory <> '' then
    raise Exception.Create(FRaiseExceptionOnDeleteCategory);
end;

end.
