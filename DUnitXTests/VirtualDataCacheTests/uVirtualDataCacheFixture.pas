unit uVirtualDataCacheFixture;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, Winapi.Windows, FireDAC.Stan.Def, FireDAC.Stan.Intf,
  FireDAC.Comp.Client, Variants,
  DUnitX.TestFramework,
  VirtualDataCache;

type
  /// <summary>
  /// Простой mock-класс для тестов кэша.
  /// Содержит минимум полей (ID и Name) для идентификации записей.
  /// </summary>
  TMockRecord = class
  private
    FID: Integer;
    FName: string;
  public
    constructor Create; overload;
    constructor Create(AID: Integer; const AName: string); overload;
    property ID: Integer read FID;
    property Name: string read FName;
  end;

  /// <summary>
  /// Тестовый наследник TVirtualDataCache с реэкспортом protected-членов
  /// как public. Позволяет тестировать внутреннее состояние БЕЗ RTTI.
  ///
  /// Применяется стандартный Delphi-паттерн:
  ///   class(TParent) public property SomeProperty; end;
  /// который превращает protected-свойство в public без изменения кода.
  /// </summary>
  TTestVirtualDataCache = class(TVirtualDataCache<TMockRecord>)
  public
    // Реэкспорт protected-свойств как public
    property Pages;            // → FPages: TObjectDictionary<Integer, TObjectList<T>>
    property LoadingPages;     // → FLoadingPages: TDictionary<Integer, Boolean>
    property PageAccessOrder;  // → FPageAccessOrder: TList<Integer>
    property FailedPages;      // → FFailedPages: TDictionary<Integer, string>
    property SQLParams;        // → FSQLParams: TDictionary<string, Variant>
    property SQLTemplate;      // → FSQLTemplate: string

    /// <summary>
    /// Обёртка для вызова protected-метода EnforceCacheLimit из теста.
    /// Прямой вызов без RTTI.
    /// </summary>
    procedure ExposedEnforceCacheLimit;
  end;

  [TestFixture]
  TVirtualDataCacheFixture = class
  private
    FCache: TTestVirtualDataCache;

    /// <summary>
    /// Mock-функция маппинга TFDQuery → TMockRecord.
    /// В unit-тестах без БД не вызывается — передаётся только для
    /// удовлетворения сигнатуры конструктора TVirtualDataCache.Create.
    /// </summary>
    function MockMapFunc(qr: TFDQuery): TMockRecord;

    /// <summary>
    /// Helper для прямого добавления страницы в FPages (минуя DoLoadPage).
    /// Используется для тестов GetRecord / EnforceCacheLimit без БД.
    /// Автоматически обновляет PageAccessOrder (LRU-семантика).
    /// </summary>
    procedure InjectPage(APageIndex: Integer; const ARecords: array of Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // ============================================================
    // 5.1.1 Конструктор и инициализация
    // ============================================================

    /// <summary>
    /// Конструктор инициализирует все коллекции пустыми и устанавливает
    /// дефолтные значения (MaxCachedPages=50, TotalCount=0).
    /// Проверяется и состояние FCache (с переопределёнными значениями из Setup),
    /// и состояние отдельного экземпляра с дефолтными параметрами.
    /// </summary>
    [Test]
    procedure Create_InitializesCollectionsAndDefaults;

    // ============================================================
    // 5.1.2 SQL / параметры
    // ============================================================

    /// <summary>
    /// SetSQL сохраняет переданный SQL-шаблон в поле FSQLTemplate,
    /// доступное через protected-свойство SQLTemplate.
    /// </summary>
    [Test]
    procedure SetSQL_StoresTemplate;

    /// <summary>
    /// SetParam реализует семантику AddOrSetValue: первый вызов добавляет
    /// параметр, повторный — обновляет значение существующего, новый ключ
    /// добавляет ещё один параметр.
    /// </summary>
    [Test]
    procedure SetParam_AddsOrUpdatesParam;

    /// <summary>
    /// ClearParams полностью очищает словарь SQLParams, не затрагивая
    /// другие коллекции кэша (страницы, счётчики).
    /// </summary>
    [Test]
    procedure ClearParams_RemovesAllParams;

    /// <summary>
    /// SetTotalCount сохраняет переданное значение в FTotalCount,
    /// доступное через public-свойство TotalCount (Int64).
    /// </summary>
    [Test]
    procedure SetTotalCount_StoresTotal;

    /// <summary>
    /// GetTotalCount (метод-геттер) возвращает то же значение, что и
    /// свойство TotalCount — оба читают FTotalCount.
    /// </summary>
    [Test]
    procedure GetTotalCount_ReturnsStoredValue;

    // ============================================================
    // 5.1.3 Clear
    // ============================================================

    /// <summary>
    /// Clear полностью очищает состояние кэша:
    ///   - FPages (страницы данных)
    ///   - FPageAccessOrder (LRU-очередь)
    ///   - FLoadingPages (страницы в процессе загрузки)
    ///   - FFailedPages (страницы с ошибками)
    ///   - FTotalCount → 0
    /// Тест не проверяет очистку SQLParams/SQLTemplate — это отдельная
    /// ответственность (ClearParams), и Clear их не трогает.
    /// </summary>
    [Test]
    procedure Clear_EmptiesAllPagesAndResetsCount;

    // ============================================================
    // 5.1.4 GetRecord — попадание в кэш
    // ============================================================

    /// <summary>
    /// GetRecord с индексом, попадающим в загруженную страницу,
    /// возвращает True и заполняет out-параметр Rec.
    /// Страница добавлена напрямую через InjectPage (минуя DoLoadPage).
    /// </summary>
    [Test]
    procedure GetRecord_CacheHit_ReturnsTrue;

    // ============================================================
    // 5.1.5 GetRecord — промах кэша
    // ============================================================

    /// <summary>
    /// GetRecord с индексом, для которого страница не загружена,
    /// возвращает False и Rec = nil.
    /// </summary>
    [Test]
    procedure GetRecord_CacheMiss_ReturnsFalse;

    // ============================================================
    // 5.1.6 GetRecord — LRU переупорядочивание
    // ============================================================

    /// <summary>
    /// GetRecord обновляет LRU-очередь: страница, к которой обратились,
    /// перемещается в конец FPageAccessOrder.
    /// </summary>
    [Test]
    procedure GetRecord_LRU_MovesPageToEnd;

    // ============================================================
    // 5.1.7 RequestPage — защита от дубликатов
    // ============================================================

    /// <summary>
    /// RequestPage для уже загруженной страницы — no-op:
    /// не добавляет в LoadingPages и не запускает TTask.Run.
    /// </summary>
    [Test]
    procedure RequestPage_AlreadyLoaded_Noop;

    /// <summary>
    /// RequestPage для страницы, уже находящейся в LoadingPages — no-op:
    /// не создаёт повторную загрузку.
    /// </summary>
    [Test]
    procedure RequestPage_AlreadyLoading_Noop;

    // ============================================================
    // 5.1.8 EnforceCacheLimit — LRU eviction
    // ============================================================

    /// <summary>
    /// EnforceCacheLimit вытесняет самые старые страницы (в начале
    /// FPageAccessOrder), когда количество страниц превышает MaxCachedPages.
    /// </summary>
    [Test]
    procedure EnforceCacheLimit_EvictsOldestPages;

    // ============================================================
    // 5.1.9 PrependRecord
    // ============================================================

    /// <summary>
    /// PrependRecord инкрементирует TotalCount после каждой вставки.
    /// </summary>
    [Test]
    procedure PrependRecord_IncrementsTotalCount;

    /// <summary>
    /// PrependRecord сохраняет запись в специальную страницу -1
    /// (в начало списка, FPages[-1][0]).
    /// </summary>
    [Test]
    procedure PrependRecord_AddsToSpecialPageMinusOne;

    // ============================================================
    // 5.2 Дополнительные тесты
    // ============================================================

    /// <summary>
    /// GetRecord с отрицательным NodeIndex сразу возвращает False
    /// без обращения к коллекциям.
    /// </summary>
    [Test]
    procedure GetRecord_NegativeIndex_ReturnsFalse;

    /// <summary>
    /// RequestPage с отрицательным PageIndex — no-op,
    /// не добавляет в LoadingPages.
    /// </summary>
    [Test]
    procedure RequestPage_NegativeIndex_Noop;

    /// <summary>
    /// PrependRecord + GetRecord: добавленная в начало запись
    /// НЕ доступна через GetRecord по индексу 0 (страница -1
    /// не участвует в делении PageIndex = NodeIndex div PageSize).
    /// Это специфическая семантика PrependRecord.
    /// </summary>
    [Test]
    procedure PrependRecord_GetRecord_OnlyThroughSpecialPage;

    /// <summary>
    /// GetRecord для индекса за пределами страницы (Offset >= List.Count)
    /// возвращает False.
    /// </summary>
    [Test]
    procedure GetRecord_OffsetOutOfRange_ReturnsFalse;

    /// <summary>
    /// Потокобезопасность: 4 потока параллельно читают/пишут кэш.
    /// Нет AV, deadlock, состояние после всех операций консистентно.
    /// </summary>
    [Test]
    procedure ThreadSafety_ConcurrentAccess_NoAV;

    /// <summary>
    /// EnforceCacheLimit при MaxCachedPages=1 оставляет только последнюю
    /// добавленную страницу (самую свежую в LRU).
    /// </summary>
    [Test]
    procedure EnforceCacheLimit_MaxOne_KeepsOnlyNewest;

    /// <summary>
    /// После ClearParams словарь SQLParams пуст, но можно добавить
    /// новые параметры — словарь функционален.
    /// </summary>
    [Test]
    procedure ClearParams_ThenSetParam_WorksCorrectly;

    /// <summary>
    /// CreatePlaceholderRecord создаёт пустую запись T.Create
    /// и инициирует загрузку PageIndex и PageIndex+1 через RequestPage.
    /// </summary>
    [Test]
    procedure CreatePlaceholderRecord_CreatesRecordAndRequestsNextPage;

    /// <summary>
    /// FailedPages — функциональная коллекция: можно добавлять,
    /// читать и очищать значения.
    /// </summary>
    [Test]
    procedure FailedPages_CanBeSetManually;
  end;

implementation

{ TMockRecord }

constructor TMockRecord.Create;
begin
  inherited Create;
  FID := 0;
  FName := '';
end;

constructor TMockRecord.Create(AID: Integer; const AName: string);
begin
  inherited Create;
  FID := AID;
  FName := AName;
end;

{ TTestVirtualDataCache }

procedure TTestVirtualDataCache.ExposedEnforceCacheLimit;
begin
  // Прямой вызов protected-метода (без RTTI)
  EnforceCacheLimit;
end;

{ TVirtualDataCacheFixture }

function TVirtualDataCacheFixture.MockMapFunc(qr: TFDQuery): TMockRecord;
begin
  // В unit-тестах без БД эта функция не вызывается.
  // Возвращаем плейсхолдер для удовлетворения сигнатуры конструктора.
  Result := TMockRecord.Create(0, '');
end;

procedure TVirtualDataCacheFixture.Setup;
begin
  // Создаём кэш сPageSize=100 (стандартный для тестов).
  // MaxCachedPages переопределяем в 3 — малый лимит для тестов LRU.
  FCache := TTestVirtualDataCache.Create('TestConnDef', 100, MockMapFunc);
  FCache.MaxCachedPages := 3;
end;

procedure TVirtualDataCacheFixture.TearDown;
begin
  FreeAndNil(FCache);
end;

procedure TVirtualDataCacheFixture.InjectPage(APageIndex: Integer;
  const ARecords: array of Integer);
var
  List: TObjectList<TMockRecord>;
  ID: Integer;
begin
  // Создаём список записей (OwnsObjects = True)
  List := TObjectList<TMockRecord>.Create(True);
  for ID in ARecords do
    List.Add(TMockRecord.Create(ID, 'Rec_' + IntToStr(ID)));

  // Добавляем или заменяем страницу в Pages
  FCache.Pages.AddOrSetValue(APageIndex, List);

  // Обновляем LRU-очередь: удаляем возможный дубликат и добавляем в конец
  FCache.PageAccessOrder.Remove(APageIndex);
  FCache.PageAccessOrder.Add(APageIndex);
end;

{ --- 5.1.1.1 Create_InitializesCollectionsAndDefaults --- }

procedure TVirtualDataCacheFixture.Create_InitializesCollectionsAndDefaults;
var
  DefaultCache: TTestVirtualDataCache;
begin
  // === Assert: FCache после Setup (переопределённые значения) ===
  // Все коллекции должны быть пусты сразу после создания
  Assert.AreEqual(0, FCache.Pages.Count,
    'Pages должен быть пуст сразу после создания');
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'LoadingPages должен быть пуст (нет активных загрузок)');
  Assert.AreEqual(0, FCache.FailedPages.Count,
    'FailedPages должен быть пуст (нет ошибок загрузки)');
  Assert.AreEqual(0, FCache.PageAccessOrder.Count,
    'PageAccessOrder должен быть пуст (LRU-очередь не инициализирована)');

  // Счётчики и дефолты
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'TotalCount = 0 после создания');
  Assert.AreEqual(3, FCache.MaxCachedPages,
    'MaxCachedPages = 3 (переопределено в Setup)');
  Assert.AreEqual(100, FCache.PageSize,
    'PageSize = 100 (передано в конструктор в Setup)');

  // === Assert: проверка дефолтного MaxCachedPages = 50 на отдельном экземпляре ===
  // Создаём новый кэш с PageSize=50 и НЕ переопределяем MaxCachedPages,
  // чтобы проверить исходное значение из конструктора (50).
  DefaultCache := TTestVirtualDataCache.Create('DefaultConn', 50, MockMapFunc);
  try
    Assert.AreEqual(50, DefaultCache.MaxCachedPages,
      'MaxCachedPages = 50 (дефолт из конструктора: "50 тыс. записей в памяти макс.")');
    Assert.AreEqual(50, DefaultCache.PageSize,
      'PageSize = 50 (передано в конструктор)');

    // Все коллекции пусты и в дефолтном экземпляре
    Assert.AreEqual(0, DefaultCache.Pages.Count,
      'Pages пуст в дефолтном экземпляре');
    Assert.AreEqual(0, DefaultCache.LoadingPages.Count,
      'LoadingPages пуст в дефолтном экземпляре');
    Assert.AreEqual(0, DefaultCache.FailedPages.Count,
      'FailedPages пуст в дефолтном экземпляре');
    Assert.AreEqual(0, DefaultCache.PageAccessOrder.Count,
      'PageAccessOrder пуст в дефолтном экземпляре');
    Assert.AreEqual<Int64>(0, DefaultCache.TotalCount,
      'TotalCount = 0 в дефолтном экземпляре');
  finally
    FreeAndNil(DefaultCache);
  end;
end;

{ --- 5.1.2.1 SetSQL_StoresTemplate --- }

procedure TVirtualDataCacheFixture.SetSQL_StoresTemplate;
const
  SQL_TEMPLATE = 'SELECT id, name FROM parts WHERE category_id = :cat_id ORDER BY id LIMIT :lim OFFSET :off';
begin
  // === Arrange: до вызова SQLTemplate пуст ===
  Assert.AreEqual('', FCache.SQLTemplate,
    'SQLTemplate должен быть пуст сразу после создания кэша');

  // === Act ===
  FCache.SetSQL(SQL_TEMPLATE);

  // === Assert: SQLTemplate содержит переданную строку (прямое сравнение) ===
  Assert.AreEqual(SQL_TEMPLATE, FCache.SQLTemplate,
    'SetSQL должен сохранить шаблон в FSQLTemplate без изменений');

  // === Дополнительно: повторный вызов SetSQL перезаписывает значение ===
  FCache.SetSQL('SELECT * FROM t LIMIT :lim OFFSET :off');
  Assert.AreEqual('SELECT * FROM t LIMIT :lim OFFSET :off', FCache.SQLTemplate,
    'Повторный SetSQL должен перезаписать предыдущий шаблон');
end;

{ --- 5.1.2.2 SetParam_AddsOrUpdatesParam --- }

procedure TVirtualDataCacheFixture.SetParam_AddsOrUpdatesParam;
begin
  // === Шаг 1: добавление нового параметра ===
  FCache.SetParam('p', 42);

  Assert.AreEqual(1, FCache.SQLParams.Count,
    'После первого SetParam SQLParams.Count = 1');
  Assert.AreEqual(42, Integer(FCache.SQLParams['p']),
    'Значение параметра "p" = 42');

  // === Шаг 2: обновление значения существующего параметра ===
  FCache.SetParam('p', 99);

  Assert.AreEqual(1, FCache.SQLParams.Count,
    'Повторный SetParam с тем же ключом НЕ должен увеличивать Count');
  Assert.AreEqual(99, Integer(FCache.SQLParams['p']),
    'Значение параметра "p" должно быть обновлено до 99');

  // === Шаг 3: добавление второго параметра ===
  FCache.SetParam('q', 'test');

  Assert.AreEqual(2, FCache.SQLParams.Count,
    'Новый ключ должен увеличить Count до 2');
  Assert.AreEqual(99, Integer(FCache.SQLParams['p']),
    'Параметр "p" не должен измениться при добавлении "q"');
  Assert.AreEqual('test', string(FCache.SQLParams['q']),
    'Значение параметра "q" = "test"');

  // === Шаг 4: разные типы значений (Variant) ===
  FCache.SetParam('dt', EncodeDate(2026, 8, 19));
  Assert.AreEqual(3, FCache.SQLParams.Count);
  Assert.AreEqual(varDate, VarType(FCache.SQLParams['dt']),
    'Параметр типа TDateTime должен сохранить varDate');

  FCache.SetParam('flag', True);
  Assert.AreEqual(4, FCache.SQLParams.Count);
  Assert.AreEqual(varBoolean, VarType(FCache.SQLParams['flag']),
    'Параметр типа Boolean должен сохранить varBoolean');
  Assert.AreEqual(True, Boolean(FCache.SQLParams['flag']),
    'Значение булевого параметра = True');
end;

{ --- 5.1.2.3 ClearParams_RemovesAllParams --- }

procedure TVirtualDataCacheFixture.ClearParams_RemovesAllParams;
begin
  // === Arrange: добавляем несколько параметров разных типов ===
  FCache.SetParam('a', 1);
  FCache.SetParam('b', 'two');
  FCache.SetParam('c', 3.14);

  Assert.AreEqual(3, FCache.SQLParams.Count,
    'Перед ClearParams словарь содержит 3 параметра');

  // === Act ===
  FCache.ClearParams;

  // === Assert: словарь параметров пуст ===
  Assert.AreEqual(0, FCache.SQLParams.Count,
    'После ClearParams SQLParams должен быть полностью очищен');

  // === Дополнительно: повторный ClearParams на пустом словаре не падает ===
  Assert.WillNotRaise(
    procedure
    begin
      FCache.ClearParams;
    end,
    Exception,
    'Повторный ClearParams на пустом словаре не должен вызывать исключение');
  Assert.AreEqual(0, FCache.SQLParams.Count,
    'Словарь остаётся пустым после повторного ClearParams');

  // === Дополнительно: добавление параметра после ClearParams работает ===
  FCache.SetParam('new', 100);
  Assert.AreEqual(1, FCache.SQLParams.Count,
    'После ClearParams можно добавлять новые параметры');
  Assert.AreEqual(100, Integer(FCache.SQLParams['new']),
    'Новый параметр корректно добавлен');
end;

{ --- 5.1.2.4 SetTotalCount_StoresTotal --- }

procedure TVirtualDataCacheFixture.SetTotalCount_StoresTotal;
begin
  // === Предусловие: TotalCount = 0 после создания (проверено в 5.1.1.1) ===
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'TotalCount = 0 сразу после создания');

  // === Act: устанавливаем TotalCount ===
  FCache.SetTotalCount(12345);

  // === Assert: значение сохранено ===
  Assert.AreEqual<Int64>(12345, FCache.TotalCount,
    'SetTotalCount должен сохранить значение в FTotalCount');

  // === Дополнительно: повторный вызов перезаписывает значение ===
  FCache.SetTotalCount(99999);
  Assert.AreEqual<Int64>(99999, FCache.TotalCount,
    'Повторный SetTotalCount должен перезаписать значение');

  // === Дополнительно: граничные значения Int64 ===
  FCache.SetTotalCount(0);
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'SetTotalCount(0) должен обнулить TotalCount');

  FCache.SetTotalCount(High(Int64));
  Assert.AreEqual<Int64>(High(Int64), FCache.TotalCount,
    'SetTotalCount должен поддерживать максимальное значение Int64');

  FCache.SetTotalCount(Low(Int64));
  Assert.AreEqual<Int64>(Low(Int64), FCache.TotalCount,
    'SetTotalCount должен поддерживать минимальное значение Int64 (отрицательные не типичны, но возможны)');
end;

{ --- 5.1.2.5 GetTotalCount_ReturnsStoredValue --- }

procedure TVirtualDataCacheFixture.GetTotalCount_ReturnsStoredValue;
begin
  // === Шаг 1: проверка на начальном состоянии (0) ===
  Assert.AreEqual<Int64>(0, FCache.GetTotalCount,
    'GetTotalCount должен вернуть 0 для нового кэша');

  // === Шаг 2: GetTotalCount возвращает то же, что и свойство TotalCount ===
  FCache.SetTotalCount(500);

  Assert.AreEqual<Int64>(FCache.TotalCount, FCache.GetTotalCount,
    'GetTotalCount и свойство TotalCount должны возвращать одинаковое значение');
  Assert.AreEqual<Int64>(500, FCache.GetTotalCount,
    'GetTotalCount должен вернуть сохранённое значение 500');

  // === Шаг 3: после изменения TotalCount GetTotalCount отражает новое значение ===
  FCache.SetTotalCount(777);
  Assert.AreEqual<Int64>(777, FCache.GetTotalCount,
    'GetTotalCount должен динамически отражать изменения FTotalCount');

  // === Дополнительно: Clear сбрасывает TotalCount (тест-пересечение с 5.1.3.1) ===
  FCache.Clear;
  Assert.AreEqual<Int64>(0, FCache.GetTotalCount,
    'После Clear GetTotalCount должен вернуть 0');
end;

{ --- 5.1.3.1 Clear_EmptiesAllPagesAndResetsCount --- }

procedure TVirtualDataCacheFixture.Clear_EmptiesAllPagesAndResetsCount;
begin
  // === Arrange: заполняем кэш через InjectPage ===
  // Добавляем 3 страницы (с автоматическим обновлением LRU-очереди)
  InjectPage(0, [1, 2, 3]);
  InjectPage(1, [4, 5, 6]);
  InjectPage(2, [7, 8, 9]);

  // Устанавливаем TotalCount через публичный метод
  FCache.SetTotalCount(300);

  // Имитируем состояние "страница в процессе загрузки" и "ошибка загрузки"
  // Эти коллекции тоже должны очиститься после Clear
  FCache.LoadingPages.Add(99, True);
  FCache.FailedPages.Add(77, 'Connection timeout');

  // Также устанавливаем SQLParams для проверки того, что Clear их НЕ очищает
  // (это зона ответственности ClearParams, не Clear)
  FCache.SetParam('category_id', 42);
  FCache.SetSQL('SELECT * FROM parts WHERE cat_id = :category_id LIMIT :lim OFFSET :off');

  // === Проверка предусловий: все коллекции заполнены ===
  Assert.AreEqual(3, FCache.Pages.Count,
    'Перед Clear кэш содержит 3 страницы');
  Assert.AreEqual(3, FCache.PageAccessOrder.Count,
    'LRU-очередь содержит 3 индекса страниц');
  Assert.AreEqual(1, FCache.LoadingPages.Count,
    'LoadingPages содержит 1 имитируемую загрузку');
  Assert.AreEqual(1, FCache.FailedPages.Count,
    'FailedPages содержит 1 имитируемую ошибку');
  Assert.AreEqual<Int64>(300, FCache.TotalCount,
    'TotalCount установлен в 300');
  Assert.AreEqual(1, FCache.SQLParams.Count,
    'SQLParams содержит 1 параметр');
  Assert.AreNotEqual('', FCache.SQLTemplate,
    'SQLTemplate не пуст');

  // === Act: вызываем Clear ===
  FCache.Clear;

  // === Assert: все коллекции, связанные с данными, пусты ===
  Assert.AreEqual(0, FCache.Pages.Count,
    'Clear должен полностью очистить FPages');
  Assert.AreEqual(0, FCache.PageAccessOrder.Count,
    'Clear должен очистить LRU-очередь FPageAccessOrder');
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'Clear должен очистить FLoadingPages');
  Assert.AreEqual(0, FCache.FailedPages.Count,
    'Clear должен очистить FFailedPages');
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'Clear должен сбросить FTotalCount в 0');

  // === Дополнительно: SQLParams и SQLTemplate НЕ очищаются Clear ===
  // Это отдельная ответственность (ClearParams). Если реализация Clear
  // всё-таки очищает и их, этот assert упадёт — и это будет сигналом
  // обсудить семантику Clear с автором компонента.
  Assert.AreEqual(1, FCache.SQLParams.Count,
    'Clear НЕ должен очищать SQLParams (зона ответственности ClearParams)');
  Assert.AreNotEqual('', FCache.SQLTemplate,
    'Clear НЕ должен очищать SQLTemplate');

  // === Дополнительно: повторный Clear не падает и идемпотентен ===
  Assert.WillNotRaise(
    procedure
    begin
      FCache.Clear;
    end,
    Exception,
    'Повторный Clear на пустом кэше не должен вызывать исключение');
  Assert.AreEqual(0, FCache.Pages.Count,
    'Кэш остаётся пустым после повторного Clear');
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'TotalCount остаётся 0 после повторного Clear');

  // === Дополнительно: кэш остаётся функциональным после Clear ===
  InjectPage(0, [100, 200]);
  FCache.SetTotalCount(500);

  Assert.AreEqual(1, FCache.Pages.Count,
    'После Clear кэш должен принимать новые страницы');
  Assert.AreEqual<Int64>(500, FCache.TotalCount,
    'После Clear TotalCount должен устанавливаться заново');
  Assert.AreEqual(1, FCache.PageAccessOrder.Count,
    'LRU-очередь работает после Clear');
end;

{ --- 5.1.4.1 GetRecord_CacheHit_ReturnsTrue --- }

procedure TVirtualDataCacheFixture.GetRecord_CacheHit_ReturnsTrue;
var
  Rec: TMockRecord;
begin
  // === Arrange: добавляем страницу 0 с записями ID=10..19 (10 записей) ===
  // PageSize=100, но страница содержит только 10 записей — это нормально
  InjectPage(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);

  Assert.AreEqual(1, FCache.Pages.Count,
    'Кэш содержит 1 страницу');

  // === Act: запрашиваем запись с NodeIndex=5 (PageIndex=0, Offset=5) ===
  Assert.IsTrue(FCache.GetRecord(5, Rec),
    'GetRecord(5) должен вернуть True (страница 0 загружена, Offset=5 существует)');

  // === Assert: запись получена корректно ===
  Assert.IsNotNull(Rec, 'Rec не должен быть nil при hit');
  Assert.AreEqual(15, Rec.ID,
    'Запись с Offset=5 должна иметь ID=15 (шестая по счёту в массиве)');
  Assert.AreEqual('Rec_15', Rec.Name,
    'Name должен соответствовать ID');

  // === Дополнительно: запрашиваем первую и последнюю записи страницы ===
  Assert.IsTrue(FCache.GetRecord(0, Rec),
    'GetRecord(0) — первая запись страницы');
  Assert.AreEqual(10, Rec.ID, 'Первая запись имеет ID=10');

  Assert.IsTrue(FCache.GetRecord(9, Rec),
    'GetRecord(9) — последняя существующая запись страницы');
  Assert.AreEqual(19, Rec.ID, 'Последняя запись имеет ID=19');
end;

{ --- 5.1.5.1 GetRecord_CacheMiss_ReturnsFalse --- }

procedure TVirtualDataCacheFixture.GetRecord_CacheMiss_ReturnsFalse;
var
  Rec: TMockRecord;
begin
  // === Предусловие: кэш пуст (из Setup) ===
  Assert.AreEqual(0, FCache.Pages.Count,
    'Кэш должен быть пуст сразу после создания');

  // === Act: запрашиваем запись при отсутствии страницы ===
  Assert.IsFalse(FCache.GetRecord(50, Rec),
    'GetRecord(50) должен вернуть False (страница 0 не загружена)');

  // === Assert: Rec = nil ===
  Assert.IsNull(Rec, 'Rec должен быть nil при промахе кэша');

  // === Дополнительно: запрашиваем запись при загрузке других страниц ===
  InjectPage(2, [200, 201, 202]); // страница 2 (NodeIndex 200..299 при PageSize=100)
  InjectPage(5, [500, 501, 502]); // страница 5 (NodeIndex 500..599)

  // Запрос к незагруженной странице 0
  Assert.IsFalse(FCache.GetRecord(0, Rec),
    'GetRecord(0) должен вернуть False (страница 0 не загружена)');
  Assert.IsNull(Rec, 'Rec должен быть nil');

  // Запрос к незагруженной странице 1
  Assert.IsFalse(FCache.GetRecord(150, Rec),
    'GetRecord(150) должен вернуть False (страница 1 не загружена)');
  Assert.IsNull(Rec, 'Rec должен быть nil');

  // Запрос к загруженной странице 2
  Assert.IsTrue(FCache.GetRecord(200, Rec),
    'GetRecord(200) должен вернуть True (страница 2 загружена)');
  Assert.AreEqual(200, Rec.ID, 'Запись из страницы 2');
end;

{ --- 5.1.6.1 GetRecord_LRU_MovesPageToEnd --- }

procedure TVirtualDataCacheFixture.GetRecord_LRU_MovesPageToEnd;
var
  Rec: TMockRecord;
begin
  // === Arrange: добавляем 3 страницы ===
  // Порядок в LRU-очереди после InjectPage: [0, 1, 2]
  InjectPage(0, [0, 1, 2]);
  InjectPage(1, [100, 101, 102]);
  InjectPage(2, [200, 201, 202]);

  Assert.AreEqual(3, FCache.PageAccessOrder.Count,
    'LRU-очередь содержит 3 страницы');
  Assert.AreEqual(0, FCache.PageAccessOrder[0], 'Самая старая: страница 0');
  Assert.AreEqual(1, FCache.PageAccessOrder[1], 'Средняя: страница 1');
  Assert.AreEqual(2, FCache.PageAccessOrder[2], 'Самая свежая: страница 2');

  // === Act: обращаемся к странице 0 (самая старая) ===
  Assert.IsTrue(FCache.GetRecord(0, Rec), 'GetRecord(0) возвращает True');
  Assert.IsNotNull(Rec, 'Запись получена');

  // === Assert: страница 0 переместилась в конец LRU-очереди ===
  Assert.AreEqual(3, FCache.PageAccessOrder.Count,
    'Размер LRU-очереди не изменился');
  Assert.AreEqual(1, FCache.PageAccessOrder[0],
    'Самая старая теперь: страница 1');
  Assert.AreEqual(2, FCache.PageAccessOrder[1],
    'Средняя: страница 2');
  Assert.AreEqual(0, FCache.PageAccessOrder[2],
    'Самая свежая теперь: страница 0 (только что обращались)');

  // === Дополнительно: повторное обращение к той же странице не создаёт дубликатов ===
  Assert.IsTrue(FCache.GetRecord(1, Rec), 'GetRecord(1) — страница 0');
  Assert.AreEqual(3, FCache.PageAccessOrder.Count,
    'Повторное обращение НЕ увеличивает размер очереди');
  Assert.AreEqual(0, FCache.PageAccessOrder[2],
    'Страница 0 остаётся свежей (единственный экземпляр)');

  // === Дополнительно: обращение к странице 1 ===
  Assert.IsTrue(FCache.GetRecord(100, Rec), 'GetRecord(100) — страница 1');
  Assert.AreEqual(2, FCache.PageAccessOrder[0], 'Самая старая: страница 2');
  Assert.AreEqual(0, FCache.PageAccessOrder[1], 'Средняя: страница 0');
  Assert.AreEqual(1, FCache.PageAccessOrder[2], 'Самая свежая: страница 1');
end;

{ --- 5.1.7.1 RequestPage_AlreadyLoaded_Noop --- }

procedure TVirtualDataCacheFixture.RequestPage_AlreadyLoaded_Noop;
begin
  // === Arrange: добавляем страницу 0 напрямую ===
  InjectPage(0, [1, 2, 3]);

  Assert.IsTrue(FCache.Pages.ContainsKey(0), 'Страница 0 загружена');
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'LoadingPages пуст (нет активных загрузок)');

  // === Act: запрашиваем уже загруженную страницу ===
  FCache.RequestPage(0);

  // === Assert: RequestPage — no-op, ничего не изменилось ===
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'RequestPage для загруженной страницы НЕ должен добавлять в LoadingPages');
  // Не проверяем TTask.Run — он не должен был запуститься

  // === Дополнительно: состояние Pages не изменилось ===
  Assert.IsTrue(FCache.Pages.ContainsKey(0),
    'Страница 0 остаётся в кэше');
end;

{ --- 5.1.7.2 RequestPage_AlreadyLoading_Noop --- }

procedure TVirtualDataCacheFixture.RequestPage_AlreadyLoading_Noop;
begin
  // === Arrange: имитируем состояние "страница в процессе загрузки" ===
  FCache.LoadingPages.Add(5, True);

  Assert.AreEqual(1, FCache.LoadingPages.Count,
    'LoadingPages содержит имитируемую загрузку страницы 5');
  Assert.IsFalse(FCache.Pages.ContainsKey(5),
    'Страница 5 ещё не загружена (в процессе)');

  // === Act: запрашиваем страницу, которая уже загружается ===
  FCache.RequestPage(5);

  // === Assert: RequestPage — no-op, не запускает вторую загрузку ===
  Assert.AreEqual(1, FCache.LoadingPages.Count,
    'RequestPage НЕ должен запускать повторную загрузку для страницы, уже находящейся в процессе');
  Assert.IsTrue(FCache.LoadingPages.ContainsKey(5),
    'Страница 5 остаётся в LoadingPages');

  // === Дополнительно: первая загрузка новой страницы работает ===
  // LoadingPages должен увеличиться на 1 (TTask.Run запустится и упадёт на БД,
  // но синхронная часть RequestPage добавит страницу в LoadingPages).
  // Т.к. TTask.Run не дождёмся, проверяем только синхронную часть.
  FCache.RequestPage(7);
  Assert.IsTrue(FCache.LoadingPages.ContainsKey(7),
    'RequestPage для новой страницы добавляет её в LoadingPages');
  Assert.AreEqual(2, FCache.LoadingPages.Count,
    'LoadingPages увеличился на 1');

  // Ждём завершения асинхронного TTask.Run (он попытается подключиться к БД,
  // не найдет соединение и завершится с ошибкой — это нормально для теста).
  Sleep(200);
end;

{ --- 5.1.8.1 EnforceCacheLimit_EvictsOldestPages --- }

procedure TVirtualDataCacheFixture.EnforceCacheLimit_EvictsOldestPages;
begin
  // === Arrange: устанавливаем MaxCachedPages=2, но загружаем 3 страницы ===
  FCache.MaxCachedPages := 2;

  // InjectPage добавляет страницы и обновляет LRU-очередь
  InjectPage(0, [0, 1]);     // LRU: [0]
  InjectPage(1, [100, 101]); // LRU: [0, 1]
  InjectPage(2, [200, 201]); // LRU: [0, 1, 2] — превышение лимита!

  Assert.AreEqual(3, FCache.Pages.Count,
    'Перед EnforceCacheLimit кэш содержит 3 страницы');
  Assert.AreEqual(3, FCache.PageAccessOrder.Count,
    'LRU-очередь содержит 3 элемента');
  Assert.AreEqual(0, FCache.PageAccessOrder[0],
    'Самая старая (кандидат на вытеснение): страница 0');

  // === Act: вызываем protected-метод EnforceCacheLimit ===
  FCache.ExposedEnforceCacheLimit;

  // === Assert: самая старая страница (0) вытеснена ===
  Assert.AreEqual(2, FCache.Pages.Count,
    'После EnforceCacheLimit должно остаться 2 страницы (MaxCachedPages)');
  Assert.AreEqual(2, FCache.PageAccessOrder.Count,
    'LRU-очередь уменьшилась до 2');
  Assert.IsFalse(FCache.Pages.ContainsKey(0),
    'Страница 0 (самая старая) должна быть вытеснена');
  Assert.IsTrue(FCache.Pages.ContainsKey(1),
    'Страница 1 должна остаться');
  Assert.IsTrue(FCache.Pages.ContainsKey(2),
    'Страница 2 должна остаться');

  // === Assert: LRU-очередь корректна после вытеснения ===
  Assert.AreEqual(1, FCache.PageAccessOrder[0], 'Самая старая теперь: 1');
  Assert.AreEqual(2, FCache.PageAccessOrder[1], 'Самая свежая: 2');
end;

{ --- 5.1.9.1 PrependRecord_IncrementsTotalCount --- }

procedure TVirtualDataCacheFixture.PrependRecord_IncrementsTotalCount;
var
  Rec1, Rec2, Rec3: TMockRecord;
begin
  // === Предусловие: TotalCount = 0 ===
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'TotalCount должен быть 0 сразу после создания');

  // === Act: 3 последовательных PrependRecord ===
  Rec1 := TMockRecord.Create(1000, 'First');
  FCache.PrependRecord(Rec1);
  Assert.AreEqual<Int64>(1, FCache.TotalCount,
    'После 1-го PrependRecord TotalCount = 1');

  Rec2 := TMockRecord.Create(1001, 'Second');
  FCache.PrependRecord(Rec2);
  Assert.AreEqual<Int64>(2, FCache.TotalCount,
    'После 2-го PrependRecord TotalCount = 2');

  Rec3 := TMockRecord.Create(1002, 'Third');
  FCache.PrependRecord(Rec3);
  Assert.AreEqual<Int64>(3, FCache.TotalCount,
    'После 3-го PrependRecord TotalCount = 3');

  // === Дополнительно: Clear сбрасывает TotalCount ===
  FCache.Clear;
  Assert.AreEqual<Int64>(0, FCache.TotalCount,
    'Clear сбрасывает TotalCount в 0');
end;

{ --- 5.1.9.2 PrependRecord_AddsToSpecialPageMinusOne --- }

procedure TVirtualDataCacheFixture.PrependRecord_AddsToSpecialPageMinusOne;
var
  Rec1, Rec2: TMockRecord;
  List: TObjectList<TMockRecord>;
begin
  // === Предусловие: страница -1 не существует ===
  Assert.IsFalse(FCache.Pages.ContainsKey(-1),
    'Специальная страница -1 не должна существовать сразу после создания');

  // === Act 1: первый PrependRecord создаёт страницу -1 ===
  Rec1 := TMockRecord.Create(100, 'First');
  FCache.PrependRecord(Rec1);

  // === Assert: страница -1 создана ===
  Assert.IsTrue(FCache.Pages.ContainsKey(-1),
    'После первого PrependRecord страница -1 должна быть создана');

  List := FCache.Pages[-1];
  Assert.IsNotNull(List, 'Список страницы -1 не должен быть nil');
  Assert.AreEqual(1, List.Count, 'В странице -1 ровно 1 запись');
  Assert.AreSame(Rec1, List[0],
    'Первая запись в странице -1 = Rec1');
  Assert.AreEqual(100, List[0].ID, 'ID записи = 100');

  // === Act 2: второй PrependRecord добавляет запись в НАЧАЛО списка ===
  Rec2 := TMockRecord.Create(200, 'Second');
  FCache.PrependRecord(Rec2);

  // === Assert: Rec2 в начале (Insert(0, ...)) ===
  Assert.AreEqual(2, List.Count, 'В странице -1 теперь 2 записи');
  Assert.AreSame(Rec2, List[0],
    'Вторая добавленная запись становится в начало (Insert(0))');
  Assert.AreSame(Rec1, List[1],
    'Первая запись сдвигается на позицию 1');
  Assert.AreEqual(200, List[0].ID, 'Новейшая запись имеет ID=200');
  Assert.AreEqual(100, List[1].ID, 'Старейшая запись имеет ID=100');
end;

{ --- 5.2.1 GetRecord_NegativeIndex_ReturnsFalse --- }

procedure TVirtualDataCacheFixture.GetRecord_NegativeIndex_ReturnsFalse;
var
  Rec: TMockRecord;
begin
  // === Arrange: загружаем страницу 0 для чистоты эксперимента ===
  InjectPage(0, [1, 2, 3]);

  // === Act: GetRecord с отрицательным NodeIndex ===
  Assert.IsFalse(FCache.GetRecord(-1, Rec),
    'GetRecord(-1) должен вернуть False');
  Assert.IsNull(Rec, 'Rec должен быть nil при отрицательном индексе');

  Assert.IsFalse(FCache.GetRecord(-100, Rec),
    'GetRecord(-100) должен вернуть False');
  Assert.IsNull(Rec, 'Rec должен быть nil');

  Assert.IsFalse(FCache.GetRecord(Low(Int64), Rec),
    'GetRecord(Low(Int64)) должен вернуть False');
  Assert.IsNull(Rec, 'Rec должен быть nil');

  // === Assert: отрицательный NodeIndex не затрагивает LRU-очередь ===
  // В InjectPage мы обращались к странице 0, LRU=[0].
  // Отрицательные индексы не должны менять LRU.
  Assert.AreEqual(1, FCache.PageAccessOrder.Count,
    'Отрицательные индексы не должны менять LRU-очередь');
end;

{ --- 5.2.2 RequestPage_NegativeIndex_Noop --- }

procedure TVirtualDataCacheFixture.RequestPage_NegativeIndex_Noop;
begin
  // === Предусловие: LoadingPages пуст ===
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'LoadingPages должен быть пуст сразу после создания');

  // === Act: RequestPage с отрицательным индексом ===
  FCache.RequestPage(-1);
  FCache.RequestPage(-100);

  // === Assert: ничего не изменилось ===
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'RequestPage с отрицательным индексом не должен добавлять в LoadingPages');
end;

{ --- 5.2.3 PrependRecord_GetRecord_OnlyThroughSpecialPage --- }

procedure TVirtualDataCacheFixture.PrependRecord_GetRecord_OnlyThroughSpecialPage;
var
  Rec: TMockRecord;
  Found: TMockRecord;
begin
  // === Arrange: добавляем запись через PrependRecord ===
  Rec := TMockRecord.Create(999, 'Prepended');
  FCache.PrependRecord(Rec);

  // Проверка: запись в странице -1
  Assert.IsTrue(FCache.Pages.ContainsKey(-1),
    'Запись добавлена в страницу -1');
  Assert.AreSame(Rec, FCache.Pages[-1][0],
    'Запись находится в FPages[-1][0]');

  // === Act: пытаемся получить её через GetRecord(0, ...) ===
  // NodeIndex=0 → PageIndex = 0 div 100 = 0, Offset = 0
  // Страница 0 не существует → GetRecord возвращает False
  Assert.IsFalse(FCache.GetRecord(0, Found),
    'GetRecord(0) не находит PrependRecord, т.к. PrependRecord добавляет в страницу -1, а не в страницу 0');
  Assert.IsNull(Found, 'Found должен быть nil');

  // === Assert: единственный способ получить PrependRecord — прямое обращение к Pages[-1] ===
  Assert.IsNotNull(FCache.Pages[-1],
    'Страница -1 доступна напрямую через Pages[-1]');
  Assert.AreSame(Rec, FCache.Pages[-1][0],
    'PrependRecord доступна только через FPages[-1][0]');
end;

{ --- 5.2.4 GetRecord_OffsetOutOfRange_ReturnsFalse --- }

procedure TVirtualDataCacheFixture.GetRecord_OffsetOutOfRange_ReturnsFalse;
var
  Rec: TMockRecord;
begin
  // === Arrange: страница 0 с 3 записями (индексы 0, 1, 2 валидны) ===
  InjectPage(0, [10, 20, 30]);

  // === Act: запрашиваем запись с Offset >= List.Count ===
  // NodeIndex=3 → PageIndex=0, Offset=3, но в странице только 3 записи
  Assert.IsFalse(FCache.GetRecord(3, Rec),
    'GetRecord(3) должен вернуть False (Offset=3 >= List.Count=3)');
  Assert.IsNull(Rec, 'Rec должен быть nil при Offset >= List.Count');

  Assert.IsFalse(FCache.GetRecord(99, Rec),
    'GetRecord(99) должен вернуть False (Offset=99 >> List.Count)');
  Assert.IsNull(Rec, 'Rec должен быть nil');

  // === Assert: валидные индексы всё ещё работают ===
  Assert.IsTrue(FCache.GetRecord(0, Rec), 'GetRecord(0) — валиден');
  Assert.AreEqual(10, Rec.ID);
  Assert.IsTrue(FCache.GetRecord(2, Rec), 'GetRecord(2) — валиден');
  Assert.AreEqual(30, Rec.ID);

  // === Дополнительно: LRU-очередь не обновляется при Offset out of range ===
  // После всех операций страница 0 остаётся единственной в LRU,
  // но её порядок мог измениться из-за валидных запросов
  Assert.AreEqual(1, FCache.PageAccessOrder.Count,
    'LRU-очередь содержит 1 элемент');
  Assert.AreEqual(0, FCache.PageAccessOrder[0],
    'Страница 0 остаётся в LRU');
end;

{ --- 5.2.5 ThreadSafety_ConcurrentAccess_NoAV --- }

procedure TVirtualDataCacheFixture.ThreadSafety_ConcurrentAccess_NoAV;
const
  THREAD_COUNT = 4;
  CYCLES = 20;
var
  Threads: array[0..THREAD_COUNT-1] of TThread;
  Handles: array[0..THREAD_COUNT-1] of THandle;
  I: Integer;
  WaitResult: Cardinal;

  function CreateWorkerThread(AThreadId: Integer): TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      var
        C: Integer;
        Rec: TMockRecord;
      begin
        for C := 1 to CYCLES do
        begin
          case AThreadId of // Используем параметр функции, а не переменную цикла
            0: FCache.GetRecord(C mod 10, Rec);
            1: FCache.GetRecord(100 + (C mod 5), Rec);
            2: FCache.GetRecord(999, Rec);
            3: begin
                 var NewRec := TMockRecord.Create(5000 + C, 'T' + IntToStr(C));
                 FCache.PrependRecord(NewRec);
                 FCache.GetTotalCount;
               end;
          end;
          TThread.Sleep(1);
        end;
      end
    );
  end;
begin
  // === Arrange: подготавливаем кэш с 2 страницами ===
  InjectPage(0, [1, 2, 3, 4, 5]);
  InjectPage(1, [100, 101, 102, 103, 104]);
  FCache.SetTotalCount(1000);

  // === Act: создаём 4 потока с разной нагрузкой ===
  for I := 0 to THREAD_COUNT - 1 do
  begin
    Threads[I] := CreateWorkerThread(I); // Передаем I по значению
    Threads[I].FreeOnTerminate := False;
    Handles[I] := Threads[I].Handle;
    Threads[I].Start;
  end;

  // === Assert: ждём завершения всех потоков с таймаутом 60 сек ===
  WaitResult := WaitForMultipleObjects(THREAD_COUNT, @Handles, True, 60000);
  Assert.AreEqual(WAIT_OBJECT_0, WaitResult,
    'Все потоки должны завершиться в течение 60 секунд (нет deadlock)');

  // === Assert: проверяем отсутствие исключений в потоках ===
  for I := 0 to THREAD_COUNT - 1 do
  begin
    if Assigned(Threads[I].FatalException) then
      Assert.Fail(Format('Поток %d завершился с ошибкой: %s',
        [I, Exception(Threads[I].FatalException).Message]));
    FreeAndNil(Threads[I]);
  end;

  // === Assert: состояние кэша консистентно ===
  Assert.AreEqual(3, FCache.Pages.Count,
    'Количество страниц в кэше равно 3 (страницы 0, 1 и специальная страница -1 от PrependRecord)');
  // Страница -1 создана PrependRecord
  Assert.IsTrue(FCache.Pages.ContainsKey(-1),
    'Страница -1 создана потоком с PrependRecord');
  // TotalCount увеличен на THREAD_COUNT * CYCLES (только поток 3 делал PrependRecord)
  // Фактически: только поток 3 делал CYCLES PrependRecord
  Assert.AreEqual<Int64>(1000 + CYCLES, FCache.TotalCount,
    'TotalCount увеличен на количество PrependRecord (только поток 3)');
end;

{ --- 5.2.6 EnforceCacheLimit_MaxOne_KeepsOnlyNewest --- }

procedure TVirtualDataCacheFixture.EnforceCacheLimit_MaxOne_KeepsOnlyNewest;
begin
  // === Arrange: MaxCachedPages=1, загружаем 3 страницы ===
  FCache.MaxCachedPages := 1;

  InjectPage(0, [0, 1]);     // LRU: [0]
  InjectPage(1, [100, 101]); // LRU: [0, 1]
  InjectPage(2, [200, 201]); // LRU: [0, 1, 2]

  Assert.AreEqual(3, FCache.Pages.Count,
    'Перед EnforceCacheLimit кэш содержит 3 страницы');

  // === Act ===
  FCache.ExposedEnforceCacheLimit;

  // === Assert: только самая свежая страница (2) осталась ===
  Assert.AreEqual(1, FCache.Pages.Count,
    'После EnforceCacheLimit должна остаться 1 страница (MaxCachedPages=1)');
  Assert.IsFalse(FCache.Pages.ContainsKey(0),
    'Страница 0 (самая старая) вытеснена');
  Assert.IsFalse(FCache.Pages.ContainsKey(1),
    'Страница 1 (средняя) вытеснена');
  Assert.IsTrue(FCache.Pages.ContainsKey(2),
    'Только самая свежая страница 2 осталась');

  Assert.AreEqual(1, FCache.PageAccessOrder.Count,
    'LRU-очередь содержит 1 элемент');
  Assert.AreEqual(2, FCache.PageAccessOrder[0],
    'Единственный элемент в LRU: страница 2 (самая свежая)');
end;

{ --- 5.2.7 ClearParams_ThenSetParam_WorksCorrectly --- }

procedure TVirtualDataCacheFixture.ClearParams_ThenSetParam_WorksCorrectly;
begin
  // === Arrange: добавляем параметры ===
  FCache.SetParam('a', 1);
  FCache.SetParam('b', 2);
  FCache.SetParam('c', 3);

  Assert.AreEqual(3, FCache.SQLParams.Count,
    'Перед ClearParams словарь содержит 3 параметра');

  // === Act: очищаем и добавляем новые ===
  FCache.ClearParams;
  Assert.AreEqual(0, FCache.SQLParams.Count,
    'ClearParams очистил словарь');

  FCache.SetParam('x', 100);
  FCache.SetParam('y', 'new');

  // === Assert: словарь работает корректно с новыми параметрами ===
  Assert.AreEqual(2, FCache.SQLParams.Count,
    'После ClearParams можно добавить новые параметры');
  Assert.AreEqual(100, Integer(FCache.SQLParams['x']),
    'Параметр "x" = 100');
  Assert.AreEqual('new', string(FCache.SQLParams['y']),
    'Параметр "y" = "new"');

  // === Assert: старые параметры действительно отсутствуют ===
  Assert.IsFalse(FCache.SQLParams.ContainsKey('a'),
    'Старый параметр "a" должен отсутствовать');
  Assert.IsFalse(FCache.SQLParams.ContainsKey('b'),
    'Старый параметр "b" должен отсутствовать');
end;

{ --- 5.2.8 CreatePlaceholderRecord_CreatesRecordAndRequestsNextPage --- }

procedure TVirtualDataCacheFixture.CreatePlaceholderRecord_CreatesRecordAndRequestsNextPage;
var
  Rec: TMockRecord;
begin
  // === Предусловие: кэш пуст ===
  Assert.AreEqual(0, FCache.Pages.Count,
    'Кэш должен быть пуст');
  Assert.AreEqual(0, FCache.LoadingPages.Count,
    'LoadingPages должен быть пуст');

  // === Act: CreatePlaceholderRecord для NodeIndex=150 ===
  // PageIndex = 150 div 100 = 1
  // Должен вызвать RequestPage(1) и RequestPage(2)
  Rec := FCache.CreatePlaceholderRecord(150);

  try
    // === Assert: запись создана (T.Create) ===
    Assert.IsNotNull(Rec,
      'CreatePlaceholderRecord должен вернуть ненулевую запись');
    Assert.IsTrue(Rec is TMockRecord,
      'Тип записи = TMockRecord');

    // === Assert: RequestPage(1) и RequestPage(2) добавили страницы в LoadingPages ===
    // (или уже успели загрузиться, но это маловероятно за время теста)
    // Проверяем через LoadingPages.ContainsKey или Pages.ContainsKey
    Assert.IsTrue(
      FCache.LoadingPages.ContainsKey(1) or FCache.Pages.ContainsKey(1),
      'Страница 1 должна быть запрошена (в LoadingPages) или уже загружена');
    Assert.IsTrue(
      FCache.LoadingPages.ContainsKey(2) or FCache.Pages.ContainsKey(2),
      'Страница 2 (PageIndex+1) должна быть запрошена для предзагрузки');
  finally
    // CreatePlaceholderRecord НЕ добавляет запись в кэш — освобождаем вручную
    FreeAndNil(Rec);
  end;

  // Ждём завершения асинхронных задач (могут упасть на БД — это нормально)
  Sleep(200);
end;

{ --- 5.2.9 FailedPages_CanBeSetManually --- }

procedure TVirtualDataCacheFixture.FailedPages_CanBeSetManually;
begin
  // === Предусловие: FailedPages пуст ===
  Assert.AreEqual(0, FCache.FailedPages.Count,
    'FailedPages должен быть пуст сразу после создания');

  // === Act: добавляем информацию об ошибках ===
  FCache.FailedPages.Add(5, 'Connection timeout');
  FCache.FailedPages.Add(10, 'SQL syntax error');
  FCache.FailedPages.Add(15, 'Permission denied');

  // === Assert: коллекция работает корректно ===
  Assert.AreEqual(3, FCache.FailedPages.Count,
    'FailedPages содержит 3 ошибки');
  Assert.IsTrue(FCache.FailedPages.ContainsKey(5),
    'FailedPages содержит страницу 5');
  Assert.AreEqual('Connection timeout', FCache.FailedPages[5],
    'Текст ошибки для страницы 5');
  Assert.AreEqual('SQL syntax error', FCache.FailedPages[10],
    'Текст ошибки для страницы 10');
  Assert.AreEqual('Permission denied', FCache.FailedPages[15],
    'Текст ошибки для страницы 15');

  // === Дополнительно: обновление существующей ошибки через AddOrSetValue ===
  FCache.FailedPages.AddOrSetValue(5, 'Retry succeeded');
  Assert.AreEqual('Retry succeeded', FCache.FailedPages[5],
    'Ошибка для страницы 5 обновлена');
  Assert.AreEqual(3, FCache.FailedPages.Count,
    'Count не изменился при обновлении');

  // === Дополнительно: Remove работает ===
  FCache.FailedPages.Remove(10);
  Assert.IsFalse(FCache.FailedPages.ContainsKey(10),
    'Страница 10 удалена из FailedPages');
  Assert.AreEqual(2, FCache.FailedPages.Count,
    'Count уменьшился после Remove');
end;

initialization
  TDUnitX.RegisterTestFixture(TVirtualDataCacheFixture);

end.
