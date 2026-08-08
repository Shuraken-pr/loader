unit VirtualEventsDataSource;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  cxTL, cxTLData, cxCustomData,
  VirtualDataCache, RealTimePoller, cxVirtualTreeListHelper;

type
  /// <summary>
  /// Обёртка для данных события, наследуется от TVTBaseRecord для интеграции
  /// с cxTreeList через DataSource.
  /// </summary>
  TEventRecord = class(TVTBaseRecord)
  private
    FId: Integer;
    FUserName: string;
    FOccured: TDateTime;
    FEventType: string;
    FIp: string;
    FSource: string;
    FStatus: string;
    FLatencyMS: string;
    FIsPlaceholder: Boolean;
    FNodeIndex: Int64;
  public
    constructor Create(AParent: TVTBase); override;
    function GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;

    property Id: Integer read FId write FId;
    property UserName: string read FUserName write FUserName;
    property Occured: TDateTime read FOccured write FOccured;
    property EventType: string read FEventType write FEventType;
    property Ip: string read FIp write FIp;
    property Source: string read FSource write FSource;
    property Status: string read FStatus write FStatus;
    property LatencyMS: string read FLatencyMS write FLatencyMS;
    property IsPlaceholder: Boolean read FIsPlaceholder write FIsPlaceholder;
    property NodeIndex: Int64 read FNodeIndex write FNodeIndex;
  end;

  /// <summary>
  /// Запись статистики событий для TVTLoadAllDataSource<TEventStatsRecord>.
  /// </summary>
  TEventStatsRecord = class(TVTBaseRecord)
  private
    FHour: TDateTime;
    FSource: string;
    FEventCount: Integer;
    FAvgLatency: Extended;
    FLatencyTrend: Extended;
    FGrowthPct: Extended;
    FAllEvents: Integer;
  public
    function GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;

    property Hour: TDateTime read FHour write FHour;
    property Source: string read FSource write FSource;
    property EventCount: Integer read FEventCount write FEventCount;
    property AvgLatency: Extended read FAvgLatency write FAvgLatency;
    property LatencyTrend: Extended read FLatencyTrend write FLatencyTrend;
    property GrowthPct: Extended read FGrowthPct write FGrowthPct;
    property AllEvents: Integer read FAllEvents write FAllEvents;
  end;

  /// <summary>
  /// Специализированный DataSource для работы с TVirtualDataCache<TEventRecord>.
  /// Наследуется напрямую от TcxTreeListCustomDataSource.
  /// </summary>
  TEventsCacheDataSource = class(TcxTreeListCustomDataSource)
  private
    FTreeList: TcxVirtualTreeList;
    FCache: TVirtualDataCache<TEventRecord>;
    FPlaceholderRecords: TObjectList<TEventRecord>;
  protected
    function GetValue(ARecordHandle: TcxDataRecordHandle;
      AItemHandle: TcxDataItemHandle): Variant; override;
    procedure SetValue(ARecordHandle: TcxDataRecordHandle;
      AItemHandle: TcxDataItemHandle; const AValue: Variant); override;
    function GetRecordCount: Integer; override;
    function GetRecordHandle(ARecordIndex: Integer): TcxDataRecordHandle; override;
    function GetParentRecordHandle(ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle; override;
  public
    constructor Create(ATreeList: TcxVirtualTreeList; ACache: TVirtualDataCache<TEventRecord>);
    destructor Destroy; override;

    /// <summary>
    /// Добавить новую запись в начало списка (для RealTimePoller).
    /// </summary>
    procedure PrependRecord(const AEvent: TEventPayload);

    /// <summary>
    /// Вызвать DataChanged (после загрузки страницы кэшем).
    /// </summary>
    procedure NotifyDataChanged;

    /// <summary>
    /// Очистить все данные.
    /// </summary>
    procedure Clear;

    property Cache: TVirtualDataCache<TEventRecord> read FCache;
  end;

implementation

uses System.Math;

{ TEventRecord }

constructor TEventRecord.Create(AParent: TVTBase);
begin
  inherited;
  FIsPlaceholder := False;
  FNodeIndex := -1;
end;

function TEventRecord.GetValue(ColIdx: Integer): Variant;
begin
  if FIsPlaceholder then
  begin
    // Плейсхолдер для незагруженной страницы
    if ColIdx = 0 then
      Result := '⌛ ...'
    else
      Result := '';
    Exit;
  end;

  case ColIdx of
    0: Result := IntToStr(FId);
    1: Result := FUserName;
    2: Result := FormatDateTime('dd.mm.yyyy hh:nn:ss', FOccured);
    3: Result := FEventType;
    4: Result := FIp;
    5: Result := FSource;
    6: Result := FStatus;
    7: Result := FLatencyMS;
  else
    Result := '';
  end;
end;

procedure TEventRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  // Только для чтения
end;

procedure TEventRecord.Assign(Source: TVTBaseRecord);
var
  Src: TEventRecord;
begin
  if Source is TEventRecord then
  begin
    Src := TEventRecord(Source);
    FId := Src.FId;
    FUserName := Src.FUserName;
    FOccured := Src.FOccured;
    FEventType := Src.FEventType;
    FIp := Src.FIp;
    FSource := Src.FSource;
    FStatus := Src.FStatus;
    FLatencyMS := Src.FLatencyMS;
    FIsPlaceholder := Src.FIsPlaceholder;
    FNodeIndex := Src.FNodeIndex;
  end;
end;

{ TEventStatsRecord }

function TEventStatsRecord.GetValue(ColIdx: Integer): Variant;
begin
  case ColIdx of
    0: Result := FormatDateTime('dd.mm.yyyy hh:nn', FHour);
    1: Result := FSource;
    2: Result := IntToStr(FEventCount);
    3: if not IsZero(FAvgLatency) then
         Result := FormatFloat('0.00 ms', FAvgLatency)
       else
         Result := '';
    4: if not IsZero(FLatencyTrend) then
         Result := FormatFloat('0.00 ms', FLatencyTrend)
       else
         Result := '';
    5: if IsZero(FGrowthPct) then
         Result := '-'
       else if FGrowthPct > 0 then
         Result := '+' + FormatFloat('0.0', FGrowthPct) + '%'
       else
         Result := FormatFloat('0.0', FGrowthPct) + '%';
    6: Result := IntToStr(FAllEvents);
  else
    Result := '';
  end;
end;

procedure TEventStatsRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  // Только для чтения
end;

procedure TEventStatsRecord.Assign(Source: TVTBaseRecord);
var
  Src: TEventStatsRecord;
begin
  if Source is TEventStatsRecord then
  begin
    Src := TEventStatsRecord(Source);
    FHour := Src.FHour;
    FSource := Src.FSource;
    FEventCount := Src.FEventCount;
    FAvgLatency := Src.FAvgLatency;
    FLatencyTrend := Src.FLatencyTrend;
    FGrowthPct := Src.FGrowthPct;
    FAllEvents := Src.FAllEvents;
  end;
end;

{ TEventsCacheDataSource }

constructor TEventsCacheDataSource.Create(ATreeList: TcxVirtualTreeList;
  ACache: TVirtualDataCache<TEventRecord>);
begin
  inherited Create;
  FTreeList := ATreeList;
  FCache := ACache;
  FPlaceholderRecords := TObjectList<TEventRecord>.Create(True);

  if ATreeList <> nil then
  begin
    ATreeList.CustomDataSource := Self;
    ATreeList.OptionsData.SmartLoad := False;
    ATreeList.OptionsData.Editing := False;
    ATreeList.OptionsData.Inserting := False;
  end;
end;

destructor TEventsCacheDataSource.Destroy;
begin
  if FTreeList <> nil then
    FTreeList.CustomDataSource := nil;
  FPlaceholderRecords.Free;
  inherited;
end;

function TEventsCacheDataSource.GetValue(ARecordHandle: TcxDataRecordHandle;
  AItemHandle: TcxDataItemHandle): Variant;
var
  Rec: TEventRecord;
begin
  Rec := TEventRecord(ARecordHandle);
  Result := Rec.GetValue(Integer(AItemHandle));
end;

procedure TEventsCacheDataSource.SetValue(ARecordHandle: TcxDataRecordHandle;
  AItemHandle: TcxDataItemHandle; const AValue: Variant);
begin
  // Только для чтения
end;

function TEventsCacheDataSource.GetRecordCount: Integer;
begin
  Result := FCache.TotalCount;
end;

function TEventsCacheDataSource.GetRecordHandle(ARecordIndex: Integer): TcxDataRecordHandle;
var
  Rec: TEventRecord;
  PageIdx: Integer;
begin
  // Пробуем получить запись из кэша
  if FCache.GetRecord(ARecordIndex, Rec) then
    Result := TcxDataRecordHandle(Rec)
  else
  begin
    // Создаём плейсхолдер
    Rec := TEventRecord.Create(nil);
    Rec.IsPlaceholder := True;
    Rec.NodeIndex := ARecordIndex;
    FPlaceholderRecords.Add(Rec);

    // Запрашиваем загрузку страницы
    PageIdx := ARecordIndex div FCache.PageSize;
    FCache.RequestPage(PageIdx);
    FCache.RequestPage(PageIdx + 1);

    Result := TcxDataRecordHandle(Rec);
  end;
end;

function TEventsCacheDataSource.GetParentRecordHandle(
  ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle;
begin
  Result := nil; // Плоский список - все записи на верхнем уровне
end;

procedure TEventsCacheDataSource.PrependRecord(const AEvent: TEventPayload);
var
  NewRec: TEventRecord;
begin
  NewRec := TEventRecord.Create(nil);
  NewRec.Id := AEvent.Id;
  NewRec.UserName := AEvent.UserName;
  NewRec.Occured := AEvent.Occured;
  NewRec.EventType := AEvent.EventType;
  NewRec.Ip := AEvent.Ip;
  NewRec.Source := AEvent.Source;
  NewRec.Status := AEvent.Status;
  NewRec.LatencyMS := AEvent.LatencyMS;

  FCache.PrependRecord(NewRec);
  NotifyDataChanged;
end;

procedure TEventsCacheDataSource.NotifyDataChanged;
begin
  FPlaceholderRecords.Clear;
  DataChanged;
end;

procedure TEventsCacheDataSource.Clear;
begin
  FPlaceholderRecords.Clear;
  FCache.Clear;
  DataChanged;
end;

end.
