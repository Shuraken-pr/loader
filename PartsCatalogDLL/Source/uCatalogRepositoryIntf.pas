unit uCatalogRepositoryIntf;

interface

uses
  System.SysUtils, System.Variants;

type
  // Сырые записи, возвращаемые из БД (DTO)
  TDBCategory = record
    ID: Integer;
    ParentID: Integer; // 0, если в БД был NULL
    Name: string;
    ChildCount: Integer;
  end;

  TDBAttribute = record
    ID: Integer;
    Name: string;
    TypeStr: string; // 'string', 'number', 'date', 'boolean'
  end;

  TDBPartValue = record
    PartID: Integer;
    Code: string;
    AttrName: string;
    // Используем Variant для поддержки SQL NULL
    ValStr: Variant;
    ValNum: Variant;
    ValDate: Variant;
    ValBool: Variant;
  end;

  ICatalogRepository = interface
    ['{B5E3D2A1-1234-5678-9ABC-DEF012345678}']
    // Транзакции
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;

    // Чтение
    function SelectCategories: TArray<TDBCategory>;
    function SelectAttributes(ACategoryID: Integer): TArray<TDBAttribute>;
    function SelectParts(ACategoryID: Integer; const ASearchTerm: string): TArray<TDBPartValue>;

    // Поиск атрибута по имени (необходимо для SavePart)
    function FindAttribute(ACategoryID: Integer; const AName: string; out AAttrID: Integer; out ATypeStr: string): Boolean;

    // Запись (CRUD)
    function InsertCategory(const AName: string; AParentID: Integer): Integer;
    function UpdateCategory(ACategoryID: Integer; const AName: string; AParentID: Integer): Boolean;

    function InsertAttribute(ACategoryID: Integer; const AName: string; const ATypeStr: string): Integer;
    function UpdateAttribute(AAttributeID: Integer; const AName: string; const ATypeStr: string): Boolean;

    function UpsertPart(ACategoryID: Integer; APartID: Integer; const ACode: string): Integer; // Возвращает PartID
    
    // Запись значения атрибута.
    // Парсинг строк (TryStrToInt, StrToDate) происходит внутри реализации этого метода.
    procedure UpsertValue(APartID, AAttrID: Integer; const ATypeStr: string; const AValStr: string);

    // Удаление. При ошибке БД (в т.ч. FK violation) пробрасывает Exception
    procedure DeleteAttribute(AAttributeID: Integer);
    procedure DeletePart(APartID: Integer);
    procedure DeleteCategory(ACategoryID: Integer);
  end;

implementation

end.
