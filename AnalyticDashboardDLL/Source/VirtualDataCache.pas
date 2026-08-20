unit VirtualDataCache;

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  System.SyncObjs, System.Threading,
  FireDAC.Comp.Client, FireDAC.Stan.Param, FDMoniCustomLoggerHelper,
  uConnectionSemaphore;

type
  /// <summary>
  /// Функция маппинга текущей строки TFDQuery в объект записи.
  /// Вызывается в фоновом потоке — не обращайтесь к UI.
  /// </summary>
  TMapRecordFunc<T: class> = reference to function(qr: TFDQuery): T;

  TPageLoadedEvent = procedure(Sender: TObject; PageIndex: Integer) of object;
  TCacheErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;

  /// <summary>
  /// Потокобезопасный кэш данных с постраничной (оконной) ленивой загрузкой.
  /// Хранит в памяти только ограниченное число страниц (LRU-вытеснение).
  /// </summary>
  TVirtualDataCache<T: class, constructor> = class
  private
    FPageSize: Integer;
    FTotalCount: Int64;
    FPages: TObjectDictionary<Integer, TObjectList<T>>;
    FLoadingPages: TDictionary<Integer, Boolean>;
    FFailedPages: TDictionary<Integer, string>;
    FCriticalSection: TCriticalSection;
    FConnDefName: string;
    FSQLTemplate: string;
    FSQLParams: TDictionary<string, Variant>;
    FMapFunc: TMapRecordFunc<T>;
    FOnPageLoaded: TPageLoadedEvent;
    FOnError: TCacheErrorEvent;
    FMaxCachedPages: Integer;
    FPageAccessOrder: TList<Integer>;
    FLastError: string;

    procedure DoLoadPage(PageIndex: Integer);
    procedure InternalClearPages;
  protected
    property Pages: TObjectDictionary<Integer, TObjectList<T>> read FPages;
    property LoadingPages: TDictionary<Integer, Boolean> read FLoadingPages;
    property PageAccessOrder: TList<Integer> read FPageAccessOrder;
    property FailedPages: TDictionary<Integer, string> read FFailedPages;
    property SQLParams: TDictionary<string, Variant> read FSQLParams;
    property SQLTemplate: string read FSQLTemplate;
    procedure EnforceCacheLimit;
  public
    constructor Create(const AConnDefName: string; APageSize: Integer;
      AMapFunc: TMapRecordFunc<T>);
    destructor Destroy; override;

    /// <summary>SQL-шаблон. Должен содержать параметры :lim и :off.</summary>
    procedure SetSQL(const ASQL: string);
    procedure SetParam(const AName: string; const AValue: Variant);
    procedure ClearParams;

    /// <summary>Установить общее количество записей (получено отдельным COUNT).</summary>
    procedure SetTotalCount(ATotal: Int64);
    function GetTotalCount: Int64;

    /// <summary>
    /// Получить запись по индексу узла.
    /// Возвращает False, если страница ещё не загружена — в этом случае
    /// вызовите RequestPage для инициации фоновой загрузки.
    /// </summary>
    function GetRecord(NodeIndex: Int64; out Rec: T): Boolean;

    /// <summary>Запросить загрузку страницы асинхронно (если ещё не загружена).</summary>
    procedure RequestPage(PageIndex: Integer);

    /// <summary>Предзагрузить несколько страниц (например, текущую ±1).</summary>
    procedure PreloadPages(const PageIndices: array of Integer);

    /// <summary>Сбросить кэш и счётчики.</summary>
    procedure Clear;

    /// <summary>
    /// Создать запись-плейсхолдер для незагруженной страницы.
    /// Инициирует загрузку страницы.
    /// </summary>
    function CreatePlaceholderRecord(NodeIndex: Int64): T;

    /// <summary>
    /// Добавить запись в начало списка (для real-time обновлений).
    /// </summary>
    procedure PrependRecord(ARec: T);

    property TotalCount: Int64 read FTotalCount;
    property PageSize: Integer read FPageSize;
    property LastError: string read FLastError;
    property MaxCachedPages: Integer read FMaxCachedPages write FMaxCachedPages;

    property OnPageLoaded: TPageLoadedEvent read FOnPageLoaded write FOnPageLoaded;
    property OnError: TCacheErrorEvent read FOnError write FOnError;
  end;

implementation

{ TVirtualDataCache<T> }

constructor TVirtualDataCache<T>.Create(const AConnDefName: string;
  APageSize: Integer; AMapFunc: TMapRecordFunc<T>);
begin
  inherited Create;
  FConnDefName := AConnDefName;
  FPageSize := APageSize;
  FMapFunc := AMapFunc;
  FMaxCachedPages := 50; // ~50 тыс. записей в памяти макс.

  FCriticalSection := TCriticalSection.Create;
  FPages := TObjectDictionary<Integer, TObjectList<T>>.Create([doOwnsValues]);
  FLoadingPages := TDictionary<Integer, Boolean>.Create;
  FFailedPages := TDictionary<Integer, string>.Create;
  FSQLParams := TDictionary<string, Variant>.Create;
  FPageAccessOrder := TList<Integer>.Create;

  FTotalCount := 0;
end;

destructor TVirtualDataCache<T>.Destroy;
begin
  Clear;
  FCriticalSection.Free;
  FPages.Free;
  FLoadingPages.Free;
  FFailedPages.Free;
  FSQLParams.Free;
  FPageAccessOrder.Free;
  inherited;
end;

procedure TVirtualDataCache<T>.Clear;
begin
  FCriticalSection.Enter;
  try
    InternalClearPages;
    FTotalCount := 0;
    FLastError := '';
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVirtualDataCache<T>.InternalClearPages;
begin
  FPages.Clear;
  FLoadingPages.Clear;
  FFailedPages.Clear;
  FPageAccessOrder.Clear;
end;

procedure TVirtualDataCache<T>.SetSQL(const ASQL: string);
begin
  FSQLTemplate := ASQL;
end;

procedure TVirtualDataCache<T>.SetParam(const AName: string; const AValue: Variant);
begin
  FSQLParams.AddOrSetValue(AName, AValue);
end;

procedure TVirtualDataCache<T>.ClearParams;
begin
  FSQLParams.Clear;
end;

procedure TVirtualDataCache<T>.SetTotalCount(ATotal: Int64);
begin
  FTotalCount := ATotal;
end;

function TVirtualDataCache<T>.GetTotalCount: Int64;
begin
  Result := FTotalCount;
end;

procedure TVirtualDataCache<T>.EnforceCacheLimit;
var
  OldPage: Integer;
begin
  while FPageAccessOrder.Count > FMaxCachedPages do
  begin
    OldPage := FPageAccessOrder[0];
    FPageAccessOrder.Delete(0);
    FPages.Remove(OldPage);
    FLoadingPages.Remove(OldPage);
    FFailedPages.Remove(OldPage);
  end;
end;

procedure TVirtualDataCache<T>.DoLoadPage(PageIndex: Integer);
var
  conn: TFDConnection;
  qr: TFDQuery;
  List: TObjectList<T>;
  Rec: T;
  Pair: TPair<string, Variant>;
  ErrorMsg: string;
  mon: TFDMoniCustomLogger;
  SemaGuard: TSemaphoreGuard;
begin
  // Захват семафора для защиты пула соединений
  SemaGuard := TSemaphoreGuard.Create(TConnectionSemaphore.Instance, 10000);
  if not SemaGuard.Acquired then
  begin
    // Возвращаем страницу в очередь загрузки для повторной попытки
    FCriticalSection.Enter;
    try
      FLoadingPages.Remove(PageIndex);
    finally
      FCriticalSection.Leave;
    end;
    Exit;
  end;

  conn := TFDConnection.Create(nil);
  try
    try
      mon := TFDMoniCustomLogger.Create(nil);
      try
        conn.ConnectionDefName := FConnDefName;
        conn.Open;
        mon.SetConnection(conn);

        qr := TFDQuery.Create(nil);
        try
          qr.Connection := conn;
          qr.SQL.Text := FSQLTemplate;

          for Pair in FSQLParams do
            qr.ParamByName(Pair.Key).Value := Pair.Value;

          qr.ParamByName('lim').AsInteger := FPageSize;
          qr.ParamByName('off').AsInteger := PageIndex * FPageSize;

          qr.Open;

          List := TObjectList<T>.Create(True);
          try
            while not qr.Eof do
            begin
              Rec := FMapFunc(qr);
              if Assigned(Rec) then
                List.Add(Rec);
              qr.Next;
            end;

            FCriticalSection.Enter;
            try
              FPages.AddOrSetValue(PageIndex, List);
              FLoadingPages.Remove(PageIndex);
              FFailedPages.Remove(PageIndex);
              FPageAccessOrder.Remove(PageIndex);
              FPageAccessOrder.Add(PageIndex);
              EnforceCacheLimit;
            finally
              FCriticalSection.Leave;
            end;

            TThread.Queue(nil, procedure
            begin
              if Assigned(Self) and Assigned(FOnPageLoaded) then
                FOnPageLoaded(Self, PageIndex);
            end);
          except
            List.Free;
            raise;
          end;
        finally
          qr.Free;
        end;
      finally
        FreeAndNil(mon);
      end;
    except
      on E: Exception do
      begin
        ErrorMsg := E.Message;
        FCriticalSection.Enter;
        try
          FLoadingPages.Remove(PageIndex);
          FFailedPages.AddOrSetValue(PageIndex, ErrorMsg);
          FLastError := ErrorMsg;
        finally
          FCriticalSection.Leave;
        end;

        TThread.Queue(nil, procedure
        begin
          if Assigned(Self) and Assigned(FOnError) then
            FOnError(Self, ErrorMsg);
        end);
      end;
    end;
  finally
    conn.Close;
    FreeAndNil(conn);
    SemaGuard.Free;
  end;
end;

function TVirtualDataCache<T>.GetRecord(NodeIndex: Int64; out Rec: T): Boolean;
var
  PageIndex: Integer;
  Offset: Integer;
  List: TObjectList<T>;
begin
  Result := False;
  Rec := nil;

  if NodeIndex < 0 then Exit;

  PageIndex := NodeIndex div FPageSize;
  Offset := NodeIndex mod FPageSize;

  FCriticalSection.Enter;
  try
    if FPages.TryGetValue(PageIndex, List) then
    begin
      if Offset < List.Count then
      begin
        Rec := List[Offset];
        Result := True;
        // Поднимаем страницу в LRU
        FPageAccessOrder.Remove(PageIndex);
        FPageAccessOrder.Add(PageIndex);
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVirtualDataCache<T>.RequestPage(PageIndex: Integer);
var
  AlreadyLoading: Boolean;
begin
  if PageIndex < 0 then Exit;

  FCriticalSection.Enter;
  try
    if FPages.ContainsKey(PageIndex) then Exit;
    if FLoadingPages.TryGetValue(PageIndex, AlreadyLoading) and AlreadyLoading then Exit;
    FLoadingPages.Add(PageIndex, True);
  finally
    FCriticalSection.Leave;
  end;

  TTask.Run(procedure
  begin
    DoLoadPage(PageIndex);
  end);
end;

procedure TVirtualDataCache<T>.PreloadPages(const PageIndices: array of Integer);
var
  Idx: Integer;
begin
  for Idx in PageIndices do
    RequestPage(Idx);
end;

function TVirtualDataCache<T>.CreatePlaceholderRecord(NodeIndex: Int64): T;
var
  PageIdx: Integer;
begin
  // Создаём пустую запись-плейсхолдер для незагруженных страниц
  Result := T.Create;

  // Инициируем загрузку страницы
  PageIdx := NodeIndex div FPageSize;
  RequestPage(PageIdx);
  RequestPage(PageIdx + 1);
end;

procedure TVirtualDataCache<T>.PrependRecord(ARec: T);
begin
  FCriticalSection.Enter;
  try
    // Добавляем запись в начало (специальная страница с индексом -1)
    if not FPages.ContainsKey(-1) then
      FPages.Add(-1, TObjectList<T>.Create(True));
    FPages[-1].Insert(0, ARec);

    // Увеличиваем общий счётчик
    Inc(FTotalCount);
  finally
    FCriticalSection.Leave;
  end;
end;

end.
