unit ConnectionSemaphore;

interface

uses
  System.SysUtils, System.SyncObjs;

type
  TConnectionSemaphore = class
  private
    FSemaphore: TSemaphore;
    FMaxConnections: Integer;
    FCurrentCount: Integer;
    FCS: TCriticalSection;
    class var FInstance: TConnectionSemaphore;
    class constructor CreateClass;
    class destructor DestroyClass;
  public
    constructor Create(AMaxConnections: Integer);
    destructor Destroy; override;

    function Acquire(Timeout: Cardinal = 5000): Boolean;
    procedure Release;
    procedure Reset(AMaxConnections: Integer);

    property AvailableCount: Integer read FCurrentCount;
    property MaxConnections: Integer read FMaxConnections;
  end;

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

var
  FSemaInstance: TConnectionSemaphore;

{ TConnectionSemaphore }

class constructor TConnectionSemaphore.CreateClass;
begin
  FSemaInstance := nil;
end;

class destructor TConnectionSemaphore.DestroyClass;
begin
  FreeAndNil(FSemaInstance);
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
  FCS.Enter;
  try
    if FCurrentCount <= 0 then
    begin
      Result := False;
      Exit;
    end;
  finally
    FCS.Leave;
  end;

  Res := FSemaphore.WaitFor(Timeout);

  FCS.Enter;
  try
    case Res of
      wrSignaled:
        begin
          Dec(FCurrentCount);
          Result := True;
        end;
      wrTimeout:
        Result := False;
      wrAbandoned, wrError:
        Result := False;
    end;
  finally
    FCS.Leave;
  end;
end;

procedure TConnectionSemaphore.Release;
begin
  FCS.Enter;
  try
    if FCurrentCount < FMaxConnections then
      Inc(FCurrentCount);
  finally
    FCS.Leave;
  end;
  FSemaphore.Release;
end;

procedure TConnectionSemaphore.Reset(AMaxConnections: Integer);
begin
  FCS.Enter;
  try
    FMaxConnections := AMaxConnections;
    FCurrentCount := AMaxConnections;
  finally
    FCS.Leave;
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

finalization
  FreeAndNil(FSemaInstance);

end.
