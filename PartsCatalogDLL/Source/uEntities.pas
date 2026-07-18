unit uEntities;

interface

uses
  System.SysUtils, System.Generics.Collections, cxVirtualTreeListHelper, Variants;

type
  TAttrType = (atString, atNumber, atDate, atBoolean);

  TCategory = record
    ID: Integer;
    ParentID: Integer;
    Name: string;
    ChildCount: Integer;
  end;

  TAttributeDef = record
    ID: Integer;
    Name: string;
    AttrType: TAttrType;
  end;

  TPartRow = class
  private
    FPartID: Integer;
    FCode: string;
    FValues: TDictionary<string, string>;
  public
    property PartID: Integer read FPartID write FPartID;
    property Code: string read FCode write FCode;
    property Values: TDictionary<string, string> read FValues;

    constructor Create;
    destructor Destroy; override;
  end;

  TCategoryNodeData = class(TVTBaseRecord)
  private
    FName: string;
    FCategoryID: Integer;
    FParentID: Integer;
    FExpectedChildCount: integer;
  protected
    function GetChildCount: Integer; override;
    procedure SetChildCount(const Value: Integer); override;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;

    property CategoryID: Integer read FCategoryID write FCategoryID;
    property ParentID: Integer read FParentID write FParentID;
    property Name: string read FName write FName;
  end;

  TPartNodeData = class(TVTBaseRecord)
  private
    FPartID: Integer;
    FCode: string;
    FValues: TDictionary<string, string>;
    FAttributes: TArray<TAttributeDef>; // Нужно для маппинга ColIdx -> AttrName
  public
    constructor Create(AParent: TVTBase); override;
    destructor Destroy; override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;

    property PartID: Integer read FPartID write FPartID;
    property Code: string read FCode write FCode;
    property Attributes: TArray<TAttributeDef> read FAttributes write FAttributes;
    property Values: TDictionary<string, string> read FValues;
  end;

implementation

{ TPartRow }

constructor TPartRow.Create;
begin
  FValues := TDictionary<string, string>.Create;
end;

destructor TPartRow.Destroy;
begin
  FValues.Free;
  inherited;
end;

{ TCategoryNodeData }

constructor TCategoryNodeData.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FName := '';
  FCategoryID := 0;
  FParentID := 0;
  FExpectedChildCount := 0;
end;

function TCategoryNodeData.GetChildCount: Integer;
begin
  if DataLoaded then
    Result := inherited GetChildCount
  else
    Result := FExpectedChildCount;
end;

function TCategoryNodeData.GetValue(ColIdx: Integer): Variant;
begin
  Result := null;
  case ColIdx of
    0: Result := FName; // Колонка 0 = Имя категории
  end;
end;

procedure TCategoryNodeData.SetChildCount(const Value: Integer);
begin
  FExpectedChildCount := Value;
end;

procedure TCategoryNodeData.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  case ColIdx of
    0: FName := AValue;
  end;
end;

procedure TCategoryNodeData.Assign(Source: TVTBaseRecord);
begin
  inherited;
  Self.Name := TCategoryNodeData(Source).Name;
  Self.CategoryID := TCategoryNodeData(Source).CategoryID;
  Self.ParentID := TCategoryNodeData(Source).ParentID;
end;

{ TPartNodeData }

constructor TPartNodeData.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FPartID := 0;
  FCode := '';
  FValues := TDictionary<string, string>.Create;
end;

destructor TPartNodeData.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TPartNodeData.GetValue(ColIdx: Integer): Variant;
var
  AttrName, Res: string;
begin
  Result := null;
  if ColIdx = 0 then
    Result := FCode
  else if (ColIdx - 1) < Length(FAttributes) then
  begin
    AttrName := FAttributes[ColIdx - 1].Name;
    if not FValues.TryGetValue(AttrName, Res) then
      Result := ''  // Пустая строка, если значения нет
    else
      Result := Res;
  end;
end;

procedure TPartNodeData.SetValue(ColIdx: Integer; const AValue: Variant);
var
  AttrName: string;
begin
  if ColIdx = 0 then
    FCode := AValue
  else if (ColIdx - 1) < Length(FAttributes) then
  begin
    AttrName := FAttributes[ColIdx - 1].Name;
    if VarIsNull(AValue) or VarIsEmpty(AValue) then
      FValues.Remove(AttrName)
    else
      FValues.AddOrSetValue(AttrName, VarToStr(AValue));
  end;
end;

procedure TPartNodeData.Assign(Source: TVTBaseRecord);
var
  Src: TPartNodeData;
  Pair: TPair<string, string>;
begin
  inherited;
  Src := TPartNodeData(Source);
  Self.PartID := Src.PartID;
  Self.Code := Src.Code;
  Self.Attributes := Copy(Src.Attributes);
  Self.FValues.Clear;
  for Pair in Src.FValues do
    Self.FValues.Add(Pair.Key, Pair.Value);
end;

end.
