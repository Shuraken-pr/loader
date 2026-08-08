unit uConnectionSemaphore;

interface

uses
  System.SysUtils, System.SyncObjs;

type
  TConnectionSemaphore = class
  private
    FSemaphore: TSemaphore;
    FMaxConnections: Integer;
    FCurrentCount: Integer;   // только для наблюдения, не для логики!
    FCS: TCriticalSection;
    class var FInstance: TConnectionSemaphore;
    class constructor CreateClass;
    class destructor DestroyClass;
    procedure SetMaxConnections(const Value: Integer);
  public
    constructor Create(AMaxConnections: Integer);
    destructor Destroy; override;

    /// <summary>Блокирует поток до получения слота или таймаута.</summary>
    function Acquire(Timeout: Cardinal = 5000): Boolean;
    procedure Release;

    /// <summary>
    /// Сбрасывает семафор. Опасно при наличии ожидающих потоков!
    /// Все ожидающие получат wrAbandoned.
    /// </summary>
    procedure Reset(AMaxConnections: Integer);

    property AvailableCount: Integer read FCurrentCount;
    property MaxConnections: Integer read FMaxConnections write SetMaxConnections;

    class function Instance: TConnectionSemaphore;
  end;

  /// <summary>RAII-обёртка. Гарантирует Release при выходе из scope.</summary>
  TSemaphoreGuard = class
  private
    FSemaphore: TConnectionSemaphore;
    FAcquired: Boolean;
  public
    constructor Create(Semaphore: TConnectionSemaphore; Timeout: Cardinal = 5000);
    destructor Destroy; override;
    property Acquired: Boolean read FAcquired;
  end;

implementation

{ TConnectionSemaphore }

class constructor TConnectionSemaphore.CreateClass;
begin
  FInstance := TConnectionSemaphore.Create(10);
end;

class destructor TConnectionSemaphore.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

class function TConnectionSemaphore.Instance: TConnectionSemaphore;
begin
  Result := FInstance;
  if not Assigned(Result) then
    FInstance := TConnectionSemaphore.Create(10);
end;

constructor TConnectionSemaphore.Create(AMaxConnections: Integer);
begin
  inherited Create;
  FMaxConnections := AMaxConnections;
  FCurrentCount := AMaxConnections;
  FCS := TCriticalSection.Create;
  FSemaphore := TSemaphore.Create(nil, AMaxConnections, AMaxConnections, '');
end;

destructor TConnectionSemaphore.Destroy;
begin
  FreeAndNil(FSemaphore);
  FreeAndNil(FCS);
  inherited;
end;

function TConnectionSemaphore.Acquire(Timeout: Cardinal): Boolean;
var
  Res: TWaitResult;
begin
  // Единственный источник истины — TSemaphore. Никаких "fast path".
  Res := FSemaphore.WaitFor(Timeout);

  FCS.Enter;
  try
    Result := (Res = wrSignaled);
    if Result then
      Dec(FCurrentCount);
  finally
    FCS.Leave;
  end;
end;

procedure TConnectionSemaphore.Release;
begin
  // Сначала отдаём семафор, потом обновляем счётчик наблюдения.
  // Порядок важен: если наоборот, Acquire увидит FCurrentCount > 0,
  // но семафор ещё не освободится.
  FSemaphore.Release;

  FCS.Enter;
  try
    if FCurrentCount < FMaxConnections then
      Inc(FCurrentCount);
  finally
    FCS.Leave;
  end;
end;

procedure TConnectionSemaphore.Reset(AMaxConnections: Integer);
begin
  FCS.Enter;
  try
    FreeAndNil(FSemaphore);
    FMaxConnections := AMaxConnections;
    FCurrentCount := AMaxConnections;
    FSemaphore := TSemaphore.Create(nil, AMaxConnections, AMaxConnections, '');
  finally
    FCS.Leave;
  end;
end;

procedure TConnectionSemaphore.SetMaxConnections(const Value: Integer);
begin
  if FMaxConnections <> Value then
  begin
    FMaxConnections := Value;
    Reset(FMaxConnections);
  end;
end;

{ TSemaphoreGuard }

constructor TSemaphoreGuard.Create(Semaphore: TConnectionSemaphore; Timeout: Cardinal);
begin
  inherited Create;
  FSemaphore := Semaphore;
  FAcquired := Assigned(FSemaphore) and FSemaphore.Acquire(Timeout);
end;

destructor TSemaphoreGuard.Destroy;
begin
  if FAcquired and Assigned(FSemaphore) then
    FSemaphore.Release;
  inherited;
end;

end.
