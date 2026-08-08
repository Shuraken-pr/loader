unit RealTimePoller;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Option,
  FireDAC.Stan.Param, Data.DB, FDMoniCustomLoggerHelper;

type
  TEventPayload = record
    Occured: TDateTime;
    Source: string;
    Id: integer;
    Status: string;
    LatencyMS: string;
    Ip: string;
    UserName: string;
    EventType: string;
  end;

  TOnNewEvents = procedure(const AEvents: TArray<TEventPayload>) of object;

  TRealTimePoller = class(TThread)
  private
    FConn: TFDConnection;
    FQryMaxId: TFDQuery;
    FQryNew: TFDQuery;
    FConnDefName: string;
    FLastMaxId: Integer;
    FOnNewEvents: TOnNewEvents;
    FFDMonitor: TFDMoniCustomLogger;
    procedure DoNewEvents(const AEvents: TArray<TEventPayload>);
    procedure SafeCloseConn;
  protected
    procedure Execute; override;
  public
    constructor Create(const AConnectionDefName: string);
    destructor Destroy; override;

    property OnNewEvents: TOnNewEvents read FOnNewEvents write FOnNewEvents;
  end;

implementation

{ TRealTimePoller }

constructor TRealTimePoller.Create(const AConnectionDefName: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FConnDefName := AConnectionDefName;
  FLastMaxId := 0;

  FConn := TFDConnection.Create(nil);
  FConn.ConnectionDefName := AConnectionDefName;
  FConn.Params.Pooled := False; // Пулеру не нужен пул
  FConn.LoginPrompt := False;
  FConn.ResourceOptions.AutoReconnect := True; // Встроенная обработка обрывов
  FFDMonitor := TFDMoniCustomLogger.Create(nil);
  FFDMonitor.SetConnection(FConn);

  FQryMaxId := TFDQuery.Create(nil);
  FQryMaxId.Connection := FConn;
  FQryMaxId.FetchOptions.Mode := fmAll;

  FQryNew := TFDQuery.Create(nil);
  FQryNew.Connection := FConn;
  FQryNew.FetchOptions.Mode := fmAll;
end;

destructor TRealTimePoller.Destroy;
begin
  Terminate;
  WaitFor;
  SafeCloseConn;
  FQryNew.Free;
  FQryMaxId.Free;
  FreeAndNil(FFDMonitor);
  FConn.Free;
  inherited;
end;

procedure TRealTimePoller.SafeCloseConn;
begin
  if FConn.Connected then
    try FConn.Close; except end;
end;

procedure TRealTimePoller.DoNewEvents(const AEvents: TArray<TEventPayload>);
begin
  if Assigned(FOnNewEvents) then
    FOnNewEvents(AEvents);
end;

procedure TRealTimePoller.Execute;
var
  NewMaxId: Integer;
  Payloads: TArray<TEventPayload>;
  i: Integer;
begin
  try
    FConn.Open;

    // 1. Инициализация: узнаём текущий максимум
    FQryMaxId.SQL.Text := 'SELECT COALESCE(MAX(id), 0) AS max_id FROM events';
    FQryMaxId.Open;
    FLastMaxId := FQryMaxId.FieldByName('max_id').AsInteger;
    FQryMaxId.Close;

    // 2. Цикл опроса
    while not Terminated do
    begin
      Sleep(1000); // 1 сек интервал
      if Terminated then Break;

      try
        // Проверяем, появились ли новые записи
        FQryMaxId.SQL.Text := 'SELECT MAX(id) AS max_id FROM events';
        FQryMaxId.Open;
        NewMaxId := FQryMaxId.FieldByName('max_id').AsInteger;
        FQryMaxId.Close;

        if (NewMaxId > FLastMaxId) then
        begin
          // Дельта-загрузка только новых записей
          FQryNew.SQL.Text :=
            'SELECT * FROM public.get_events(:start_ts, :end_ts) WHERE id > :last_id ORDER BY id';
          FQryNew.ParamByName('start_ts').DataType := ftDate;
          FQryNew.ParamByName('end_ts').DataType := ftDate;
          FQryNew.ParamByName('last_id').AsInteger := FLastMaxId;
          FQryNew.Open;

          SetLength(Payloads, FQryNew.RecordCount);
          i := 0;
          while not FQryNew.Eof do
          begin
            Payloads[i].Id := FQryNew.FieldByName('id').AsInteger;
            Payloads[i].UserName := FQryNew.FieldByName('username').AsString;
            Payloads[i].EventType := FQryNew.FieldByName('event_type').AsString;
            Payloads[i].Occured := FQryNew.FieldByName('occurred_at').AsDateTime;
            Payloads[i].ip := FQryNew.FieldByName('ip').AsString;
            Payloads[i].Source := FQryNew.FieldByName('source').AsString;
            Payloads[i].Status := FQryNew.FieldByName('status').AsString;
            Payloads[i].LatencyMS := FQryNew.FieldByName('latency_ms').AsString;
            Inc(i);
            FQryNew.Next;
          end;
          FQryNew.Close;

          FLastMaxId := NewMaxId;

          // Передаём в UI-поток
          TThread.Queue(nil,
            procedure
            begin
              DoNewEvents(Payloads);
            end);
        end;
      except
        on E: Exception do
        begin
          // При ошибке сети/БД закрываем соединение и ждём
          SafeCloseConn;
          Sleep(3000); // Backoff перед повторной попыткой
          try FConn.Open; except end; // Реконнект
        end;
      end;
    end;
  except
    // Фатальная ошибка -> поток завершается
  end;
  SafeCloseConn;
end;

end.
