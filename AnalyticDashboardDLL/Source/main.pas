unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Phys, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.DataSet,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, dxCore,
  dxRibbonSkins, dxRibbonCustomizationForm,
  cxClasses,
  dxBar, dxRibbon, Threading, SyncObjs, cxContainer, cxEdit,
  cxProgressBar, FireDAC.DApt, System.Generics.Collections, Vcl.ComCtrls, RealTimePoller,
  dxLayoutContainer, dxLayoutControl, cxPC, dxDockControl, dxDockPanel,
  dxLayoutcxEditAdapters, cxTextEdit, cxMaskEdit, cxSpinEdit, Vcl.StdCtrls,
  dxLayoutControlAdapters, Vcl.Buttons, cxCalendar,
  dxDateTimeWheelPicker, cxBarEditItem, FDMoniCustomLoggerHelper,
  VirtualDataCache, uConnectionSemaphore, intf_dll_manager, frxDevDSIntf,
  uDBConnectionSettings, uMultiDBSettingsForm, dxRibbonGallery,
  System.ImageList, Vcl.ImgList, cxImageList, dmSkins, dxSkinsCore,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle, dxSkinOffice2007Blue,
  dxSkinOffice2010Silver, dxSkinOffice2013LightGray, dxSkinVS2010, uSkinHelper,
  cxFilter, cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL,
  cxTLdxBarBuiltInMenu, cxInplaceContainer, cxTLData, cxVirtualTreeListHelper,
  cxData, cxDataStorage, cxNavigator, dxDateRanges,
  cxGridCustomView, cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid;

{
id
Пользователь
Дата изменения
Тип события
Ip
Источник
Статус
Задержка (мс)
}

type
  /// <summary>
  /// Простой класс-контейнер для данных события.
  /// Используется в TVirtualDataCache и отображается через cxGrid OnGetCellDisplayText.
  /// </summary>
  TEventRecord = class
  private
    FId: Integer;
    FUserName: string;
    FOccured: TDateTime;
    FEventType: string;
    FIp: string;
    FSource: string;
    FStatus: string;
    FLatencyMS: string;
  public
    property Id: Integer read FId write FId;
    property UserName: string read FUserName write FUserName;
    property Occured: TDateTime read FOccured write FOccured;
    property EventType: string read FEventType write FEventType;
    property Ip: string read FIp write FIp;
    property Source: string read FSource write FSource;
    property Status: string read FStatus write FStatus;
    property LatencyMS: string read FLatencyMS write FLatencyMS;
  end;

  /// <summary>
  /// Запись статистики событий для TVTLoadAllDataSource<TEventStatsRecord>.
  /// Наследуется от TVTBaseRecord для интеграции с cxVirtualTreeList (vtlEventsStats).
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

type
  TfrmMain = class(TForm)
    FDManager: TFDManager;
    rtMain: TdxRibbonTab;
    rbMain: TdxRibbon;
    bmMain: TdxBarManager;
    brEvents: TdxBar;
    btnRefreshEvents: TdxBarLargeButton;
    pbLoad: TProgressBar;
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    lgEventsInfo: TdxLayoutGroup;
    lgEventsStats: TdxLayoutGroup;
    brEventsStats: TdxBar;
    btnRefreshStatsEvents: TdxBarLargeButton;
    brFilterSettings: TdxBar;
    edStartTs: TcxBarEditItem;
    edEndTs: TcxBarEditItem;
    edFilterSource: TcxBarEditItem;
    bFastReport: TdxBar;
    rddFastReport: TdxRibbonDropDownGallery;
    btnFastReport: TdxBarLargeButton;
    ilBig: TcxImageList;
    ilSmall: TcxImageList;
    btnFRDesigner: TdxBarLargeButton;
    btnFRPreview: TdxBarLargeButton;
    vtlEventsStats: TcxVirtualTreeList;
    liEventsStats: TdxLayoutItem;
    vtlEventsStatsHour: TcxTreeListColumn;
    vtlEventsStatsSource: TcxTreeListColumn;
    vtlEventsStatsEventCount: TcxTreeListColumn;
    vtlEventsStatsAvg_latency: TcxTreeListColumn;
    vtlEventsStatslatencyTrend: TcxTreeListColumn;
    vtlEventsStatsGrouwthPct: TcxTreeListColumn;
    vtlEventsStatsAllEvents: TcxTreeListColumn;
    glEvents: TcxGridLevel;
    grEvents: TcxGrid;
    liEvents: TdxLayoutItem;
    tvEvents: TcxGridTableView;
    tvcId: TcxGridColumn;
    tvcUserName: TcxGridColumn;
    tvcDTChange: TcxGridColumn;
    tvcEventType: TcxGridColumn;
    tvcIp: TcxGridColumn;
    tvcSource: TcxGridColumn;
    tvcStatus: TcxGridColumn;
    tvcLatency: TcxGridColumn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRefreshEventsClick(Sender: TObject);
    procedure btnRefreshStatsEventsClick(Sender: TObject);
    procedure edStartTsKeyPress(Sender: TObject; var Key: Char);
    procedure edStartTsKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure edStartTsPropertiesEditValueChanged(Sender: TObject);
    procedure edEndTsPropertiesEditValueChanged(Sender: TObject);
    procedure edFilterSourceChange(Sender: TObject);
    procedure btnFRDesignerClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    FCallbackProc: TProc<WideString>;
    FDllManager: IDllManager;
    FIntfFR: IFrxDevDS;
    FRunningUpdateEvents: boolean;
    FRunningUpdateEventsStats: boolean;
    FCriticalSection: TCriticalSection;
    FEventCache: TVirtualDataCache<TEventRecord>;
    FEventsStatsDS: TVTLoadAllDataSource<TEventStatsRecord>;
    FLoadEventsStatsList: TObjectList<TEventStatsRecord>;
    FPoller: TRealTimePoller;
    procedure HandleNewPollerEvents(const AEvents: TArray<TEventPayload>);
    procedure HandlePageLoaded(Sender: TObject; PageIndex: Integer);
    procedure HandleCacheError(Sender: TObject; const ErrorMsg: string);
    procedure DoCallback(const AMsg: WideString);
    function FRCustomFunction(ANameFunc: WideString; ANameParam: WideString): variant;
    // Обработчики событий cxGrid для виртуального режима (unbound mode)
    procedure tvEventsTopRecordIndexChanged(Sender: TObject);
    procedure tvcGetDisplayText(Sender: TcxCustomGridTableItem;
      ARecord: TcxCustomGridRecord; var AText: string);
    procedure tvEventsCustomDrawCell(Sender: TcxCustomGridTableView;
      ACanvas: TcxCanvas; AViewInfo: TcxGridTableDataCellViewInfo;
      var ADone: Boolean);
  public
    { Public declarations }
    function InitConnectionPool: boolean;
    procedure RefreshEvents;
    procedure RefreshEventsStats;
    class function RunForm(ACallback: TProc<WideString>; var AMsg: WideString; ASkinName: WideString; ANativeStyle: boolean; ADllManager: IDllManager): boolean;
    procedure SetDllManager(AMgr: IDllManager);
  end;

var
  frmMain: TfrmMain;

implementation

uses math;

const
  SettingsFile = 'db_settings.xml';

{$R *.dfm}

{ TForm1 }

procedure TfrmMain.btnFRDesignerClick(Sender: TObject);
var
  conn: TFDConnection;
  ReportFile, connStr: string;
begin
  if Assigned(FIntfFR) then
  begin
    connStr := '';
    ReportFile := ExtractFilePath(ParamStr(0)) + 'FastReportTemplates\AnalyticDashboard.fr3';
    conn := TFDConnection.Create(Self);
    try
      conn.ConnectionDefName := 'PgPool';
      try
        connStr := format('DriverID=%s;Database=%s;User_name=%s;Password=%s;Server=%s;Port=%s',
                         [conn.Params.DriverID, conn.Params.Database, conn.Params.UserName,
                          conn.Params.Password, conn.Params.Values['Server'], conn.Params.Values['Port']]);
      except
      end;
    finally
      FreeAndNil(conn);
    end;
    if connStr <> '' then
    begin
      FIntfFR.SetCustomFunction(FRCustomFunction);
      if TdxBarLargeButton(Sender).Tag = 1 then
        FIntfFR.PreviewDBReport(
        connStr,
        ReportFile)
      else
        FIntfFR.DesignDBReport(
        ['Select * from public.get_hourly_agg(:start_ts, :end_ts, :source_filter) where source is not null'],
        ['EventsStats'],
        connStr,
        ReportFile);
    end;
  end;
end;

procedure TfrmMain.btnRefreshEventsClick(Sender: TObject);
begin
  RefreshEvents;
  lcMainGroup_Root.ItemIndex := 0;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FRunningUpdateEvents := false;
  FRunningUpdateEventsStats := false;
  FCriticalSection := TCriticalSection.Create;
  FLoadEventsStatsList := TObjectList<TEventStatsRecord>.Create(true);

  // Создаём DataSource для статистики
  FEventsStatsDS := TVTLoadAllDataSource<TEventStatsRecord>.Create(vtlEventsStats);

  // Подключаем обработчики событий cxGrid для виртуального режима
  for var i := 0 to tvEvents.ColumnCount - 1 do
    tvEvents.Columns[i].OnGetDisplayText := tvcGetDisplayText;
  tvEvents.OnTopRecordIndexChanged := tvEventsTopRecordIndexChanged;
  tvEvents.OnCustomDrawCell := tvEventsCustomDrawCell;

  edFilterSource.Properties.ImmediatePost := true;
  if InitConnectionPool then
  begin
    DoCallback('Соединение успешно установлено');
    FPoller := TRealTimePoller.Create('PgPool');
    FPoller.OnNewEvents := HandleNewPollerEvents;
    FPoller.Start;
  end
    else
  begin
    DoCallback('Ошибка при установке соединения');
    Application.Terminate;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
var
  Settings: TDBConnectionSettings;
begin
  if Assigned(FPoller) then
  begin
    FPoller.Free;
    FPoller := nil;
  end;

  FreeAndNil(FLoadEventsStatsList);
  FreeAndNil(FEventsStatsDS);
  FreeAndNil(FEventCache);
  FreeAndNil(FCriticalSection);

  Settings := TDBConnectionSettings.Create;
  try
    if FileExists(SettingsFile) then
    begin
      Settings.LoadFromFile(SettingsFile, ['start_ts', 'end_ts', 'filter_source']);
      Settings.Values['start_ts'] := varToStr(edStartTs.EditValue);
      Settings.Values['end_ts'] := varToStr(edEndTs.EditValue);
      Settings.Values['filter_source'] := varToStr(edFilterSource.EditValue);
      Settings.SaveToFile(SettingsFile, ['start_ts', 'end_ts', 'filter_source']);
    end;
  finally
    FreeAndNil(Settings)
  end;
end;

procedure TfrmMain.FormShow(Sender: TObject);
var
  intf: IInterface;
begin
  if Assigned(FDllManager) then
  begin
    intf := FDllManager.GetIntf(IFrxDevDS);
    if Supports(intf, IFrxDevDS, FIntfFR) then
      bFastReport.Visible := Assigned(FIntfFR);
  end;
end;

function TfrmMain.FRCustomFunction(ANameFunc, ANameParam: WideString): variant;
begin
  Result := '';
  if ANameFunc = 'FormParam' then
  begin
    if ANameParam = 'start_ts' then
      Result := edStartTs.EditValue
    else if ANameParam = 'end_ts' then
      Result := edEndTs.EditValue
    else if ANameParam = 'filter_source' then
      Result := edFilterSource.EditValue;
  end;
end;

procedure TfrmMain.HandleNewPollerEvents(const AEvents: TArray<TEventPayload>);
var
  i: Integer;
  Rec: TEventRecord;
begin
  if Length(AEvents) = 0 then
    Exit;

  if not Assigned(FEventCache) then
    Exit;

  tvEvents.BeginUpdate;
  try
    for i := Low(AEvents) to High(AEvents) do
    begin
      Rec := TEventRecord.Create;
      Rec.Id := AEvents[i].Id;
      Rec.UserName := AEvents[i].UserName;
      Rec.Occured := AEvents[i].Occured;
      Rec.EventType := AEvents[i].EventType;
      Rec.Ip := AEvents[i].Ip;
      Rec.Source := AEvents[i].Source;
      Rec.Status := AEvents[i].Status;
      Rec.LatencyMS := AEvents[i].LatencyMS;
      FEventCache.PrependRecord(Rec);
    end;
    // Обновляем количество записей в гриде
    tvEvents.DataController.RecordCount := FEventCache.TotalCount;
  finally
    tvEvents.EndUpdate;
  end;
end;

procedure TfrmMain.HandlePageLoaded(Sender: TObject; PageIndex: Integer);
begin
  // После загрузки страницы перерисовываем видимые ячейки
  if Assigned(tvEvents) then
  begin
    tvEvents.BeginUpdate;
    try
      // Обновляем количество записей (на случай PrependRecord)
      if tvEvents.DataController.RecordCount <> FEventCache.TotalCount then
        tvEvents.DataController.RecordCount := FEventCache.TotalCount
      else
        tvEvents.DataController.Refresh;
    finally
      tvEvents.EndUpdate;
    end;
  end;
end;

procedure TfrmMain.HandleCacheError(Sender: TObject; const ErrorMsg: string);
begin
  // Вызывается при ошибке загрузки страницы
  TThread.Queue(nil, procedure
  begin
    ShowMessage('Ошибка загрузки данных: ' + ErrorMsg);
  end);
end;

function TfrmMain.InitConnectionPool: boolean;
var
  NeedConfig: Boolean;
  Settings: TDBConnectionSettings;
  ErrMsg: string;
  curDate: TDateTime;
  ConnDef: IFDStanConnectionDef;
begin
  Result := false;
  Settings := TDBConnectionSettings.Create;
  try
    if FileExists(SettingsFile) then
      Settings.LoadFromFile(SettingsFile, ['start_ts', 'end_ts', 'filter_source']);
    NeedConfig := not (Settings.IsValid(ErrMsg) and Settings.TestConnection(ErrMsg));
    if NeedConfig then
    begin
      Settings.DBType := dbPostgreSQL;
      Settings.ShowDBTypeSelector := false;
      Settings.ShowPoolMaxItems := true;
      Settings.ShowPoolTimeout := true;
      if TfrmMultiDBSettings.Execute(Settings) then
        Settings.SaveToFile(SettingsFile, ['start_ts', 'end_ts', 'filter_source'])
      else
        Exit;
    end;
    if FDManager.ConnectionDefs.Count > 0 then
      FDManager.ConnectionDefs.Clear;
    Settings.RegisterInManager(FDManager, 'PgPool');
    ConnDef := FDManager.ConnectionDefs.FindConnectionDef('PgPool');
    if Assigned(ConnDef) then
      ConnDef.Params.MonitorBy := mbCustom;
    TConnectionSemaphore.Instance.MaxConnections := Settings.PoolMaxItems - 1;
    if TryStrToDate(Settings.Values['start_ts'], curDate) then
      edStartTs.EditValue := curDate
    else
      edStartTs.EditValue := Date;
    if TryStrToDate(Settings.Values['end_ts'], curDate) then
      edEndTs.EditValue := curDate
    else
      edEndTs.EditValue := Date;
    edFilterSource.EditValue := Settings.Values['filter_source'];
    Result := true;
  finally
    FreeAndNil(Settings);
  end;
  edStartTs.Properties.OnEditValueChanged := edStartTsPropertiesEditValueChanged;
  edEndTs.Properties.OnEditValueChanged := edEndTsPropertiesEditValueChanged;
  FDManager.Active := True; // Активируем пул соединений с параметрами выше
end;

procedure TfrmMain.btnRefreshStatsEventsClick(Sender: TObject);
begin
  RefreshEventsStats;
  lcMainGroup_Root.ItemIndex := 1;
end;

procedure TfrmMain.DoCallback(const AMsg: WideString);
begin
  if Assigned(FCallbackProc) then
    FCallbackProc(AMsg);
end;

procedure TfrmMain.edEndTsPropertiesEditValueChanged(Sender: TObject);
begin
  if edEndTs.curEditValue < edStartTs.EditValue then
    edStartTs.EditValue := edEndTs.curEditValue;
end;

procedure TfrmMain.edFilterSourceChange(Sender: TObject);
begin
  edFilterSource.EditValue := edFilterSource.CurEditValue;
end;

procedure TfrmMain.edStartTsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  key := 0;
end;

procedure TfrmMain.edStartTsKeyPress(Sender: TObject; var Key: Char);
begin
  key := #0;
end;

procedure TfrmMain.edStartTsPropertiesEditValueChanged(Sender: TObject);
begin
  if edStartTs.curEditValue > edEndTs.EditValue then
    edEndTs.EditValue := edStartTs.curEditValue;
end;

procedure TfrmMain.RefreshEvents;
var
  task: ITask;
  StartTS, EndTS: TDateTime;
  SourceFilter: string;
begin
  FCriticalSection.Enter;
  try
    if FRunningUpdateEvents then
      exit;
  finally
    FCriticalSection.Leave;
  end;

  // Захватываем параметры фильтрации в UI-потоке
  StartTS := edStartTs.EditValue;
  EndTS := edEndTs.EditValue;
  SourceFilter := edFilterSource.EditValue;

  task := TTask.Run(procedure
  var
    qr: TFDQuery;
    conn: TFDConnection;
    Total: Int64;
    SemaGuard: TSemaphoreGuard;
  begin
    // Захват семафора для защиты пула соединений
    SemaGuard := TSemaphoreGuard.Create(TConnectionSemaphore.Instance, 10000);
    if not SemaGuard.Acquired then
    begin
      TThread.Queue(nil, procedure
      begin
        ShowMessage('Превышено время ожидания соединения с БД');
      end);
      Exit;
    end;

    try
      FCriticalSection.Enter;
      try
        FRunningUpdateEvents := true;
      finally
        FCriticalSection.Leave;
      end;

      // Шаг 1: Быстрый COUNT(*) в фоновом потоке
      try
        conn := TFDConnection.Create(nil);
        try
          conn.ConnectionDefName := 'PgPool';
          conn.Open;

          qr := TFDQuery.Create(nil);
          try
            qr.Connection := conn;
            qr.SQL.Text := 'SELECT COUNT(*) AS cnt FROM events e ' +
              'WHERE (:start_ts IS NULL OR e.occurred_at >= :start_ts) ' +
              'AND (:end_ts IS NULL OR e.occurred_at < :end_ts + INTERVAL ''1 day'')';
            qr.ParamByName('start_ts').AsDateTime := StartTS;
            qr.ParamByName('end_ts').AsDateTime := EndTS;
            qr.Open;
            Total := qr.FieldByName('cnt').AsLargeInt;
          finally
            FreeAndNil(qr);
          end;
        finally
          FreeAndNil(conn);
        end;

        // Шаг 2: Переход в UI-поток — создание кэша и настройка грида
        TThread.Synchronize(nil, procedure
        begin
          // Освобождаем предыдущий кэш
          FreeAndNil(FEventCache);

          // Создаём новый кэш с маппер-функцией
          FEventCache := TVirtualDataCache<TEventRecord>.Create('PgPool', 10000,
            function(qr: TFDQuery): TEventRecord
            begin
              Result := TEventRecord.Create;
              Result.Id := qr.FieldByName('id').AsInteger;
              Result.UserName := qr.FieldByName('username').AsString;
              Result.EventType := qr.FieldByName('event_type').AsString;
              Result.Occured := qr.FieldByName('occurred_at').AsDateTime;
              Result.Ip := qr.FieldByName('ip').AsString;
              Result.Source := qr.FieldByName('source').AsString;
              Result.Status := qr.FieldByName('status').AsString;
              Result.LatencyMS := qr.FieldByName('latency_ms').AsString;
            end);

          // Настраиваем SQL и параметры
          FEventCache.SetSQL('SELECT * FROM public.get_events(:start_ts, :end_ts, :lim, :off)');
          FEventCache.SetParam('start_ts', StartTS);
          FEventCache.SetParam('end_ts', EndTS);
          FEventCache.SetTotalCount(Total);

          // Подписываемся на события кэша
          FEventCache.OnPageLoaded := HandlePageLoaded;
          FEventCache.OnError := HandleCacheError;

          // Настраиваем грид: устанавливаем количество записей (без создания объектов)
          tvEvents.BeginUpdate;
          try
            tvEvents.DataController.RecordCount := Total;
          finally
            tvEvents.EndUpdate;
          end;

          // Скрываем прогресс-бар
          pbLoad.Visible := False;
        end);

        // Шаг 3: Предзагрузка первых 2 страниц в фоновом потоке
        FEventCache.PreloadPages([0, 1]);

      except
        on E: Exception do
        begin
          var ErrMsg: string;
          ErrMsg := E.Message;
          TThread.Queue(nil, procedure
          begin
            if Assigned(pbLoad) then pbLoad.Visible := False;
            ShowMessage('Ошибка: ' + ErrMsg);
          end);
        end;
      end;
    finally
      FCriticalSection.Enter;
      try
        FRunningUpdateEvents := false;
      finally
        FCriticalSection.Leave;
      end;
      SemaGuard.Free;
    end;
  end);
end;

procedure TfrmMain.RefreshEventsStats;
var
  task: ITask;
begin
  FCriticalSection.Enter;
  try
    if FRunningUpdateEventsStats then
      exit;
  finally
    FCriticalSection.Leave;
  end;

  task := TTask.Run(procedure
  var
    qr: TFDQuery;
    conn: TFDConnection;
    mon: TFDMoniCustomLogger;
    SemaGuard: TSemaphoreGuard;
    Rec: TEventStatsRecord;
  begin
    // Захват семафора для защиты пула соединений
    SemaGuard := TSemaphoreGuard.Create(TConnectionSemaphore.Instance, 10000);
    if not SemaGuard.Acquired then
    begin
      TThread.Queue(nil, procedure
      begin
        ShowMessage('Превышено время ожидания соединения с БД');
      end);
      Exit;
    end;

    try
      FCriticalSection.Enter;
      try
        FRunningUpdateEventsStats := true;
      finally
        FCriticalSection.Leave;
      end;

      try
        conn := TFDConnection.Create(nil);
        try
          mon := TFDMoniCustomLogger.Create(nil);
          try
            conn.ConnectionDefName := 'PgPool';
            conn.Open;
            mon.SetConnection(conn);

            qr := TFDQuery.Create(nil);
            try
              qr.Connection := conn;
              qr.FetchOptions.Mode := fmAll;
              FLoadEventsStatsList.Clear;
              qr.SQL.Text := 'Select * from public.get_hourly_agg(:start_ts, :end_ts, :source_filter) where source is not null';
              qr.ParamByName('start_ts').DataType := ftDate;
              qr.ParamByName('end_ts').DataType := ftDate;
              qr.ParamByName('start_ts').Value := edStartTs.EditValue;
              qr.ParamByName('end_ts').Value := edEndTs.EditValue;
              qr.ParamByName('source_filter').DataType := ftString;
              qr.ParamByName('source_filter').Value := edFilterSource.EditValue;
              qr.Open;
              qr.First;
              while not qr.Eof do
              begin
                Rec := TEventStatsRecord.Create(nil); ;

                Rec.Hour := qr.FieldByName('hour').AsDateTime;
                Rec.Source := qr.FieldByName('source').AsString;
                Rec.EventCount := qr.FieldByName('event_count').AsInteger;
                Rec.AvgLatency := qr.FieldByName('avg_latency').AsExtended;
                Rec.LatencyTrend := qr.FieldByName('latency_trend').AsExtended;
                Rec.GrowthPct := qr.FieldByName('growth_pct').AsExtended;
                Rec.AllEvents := qr.FieldByName('all_events').AsInteger;
                FLoadEventsStatsList.Add(rec);
                qr.Next;
              end;

              TThread.Queue(nil, procedure
              var
                Rec: TEventStatsRecord;
              begin
                vtlEventsStats.BeginUpdate;
                try
                  FEventsStatsDS.Clear;
                  for var i := 0 to FLoadEventsStatsList.Count - 1 do
                  begin
                    rec := FEventsStatsDS.InsertRecordHandle(FEventsStatsDS.RootHandle, True);
                    rec.Assign(FLoadEventsStatsList[i]);
                  end;
                finally
                  vtlEventsStats.EndUpdate;
                  FEventsStatsDS.DataChanged;
                end;
              end);
            finally
              qr.Close;
              FreeAndNil(qr);
            end;
          finally
            FreeAndNil(mon);
          end;
        finally
          conn.Close;
          FreeAndNil(conn);
        end;
      except
        on E: Exception do
        begin
          var ErrMsg: string;
          ErrMsg := E.Message;
          TThread.Queue(nil,
            procedure
            begin
              ShowMessage('Ошибка получения статистики: ' + ErrMsg);
            end);
        end;
      end;
    finally
      FCriticalSection.Enter;
      try
        FRunningUpdateEventsStats := false;
      finally
        FCriticalSection.Leave;
      end;
      SemaGuard.Free;
    end;
  end);
end;

class function TfrmMain.RunForm(ACallback: TProc<WideString>;
  var AMsg: WideString; ASkinName: WideString; ANativeStyle: boolean;
  ADllManager: IDllManager): boolean;
begin
  frmMain := TfrmMain.Create(nil);
  try
    ApplySkinToForm(frmMain, ASkinName, ANativeStyle, frmMain.rbMain);
    frmMain.FCallbackProc := ACallback;
    frmMain.SetDllManager(ADllManager);
    Result := true;
    frmMain.ShowModal;
  finally
    FreeAndNil(frmMain);
  end;
end;

procedure TfrmMain.SetDllManager(AMgr: IDllManager);
begin
  FDllManager := AMgr;
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

procedure TfrmMain.tvcGetDisplayText(Sender: TcxCustomGridTableItem;
  ARecord: TcxCustomGridRecord; var AText: string);
var
  Rec: TEventRecord;
  PageIdx: Integer;
begin
  // Пробуем получить запись из кэша
  if Assigned(FEventCache) and FEventCache.GetRecord(ARecord.Index, Rec) then
  begin
    // Данные загружены — отображаем значение
    case Sender.Index of
      0: AText := IntToStr(Rec.Id);
      1: AText := Rec.UserName;
      2: AText := FormatDateTime('dd.mm.yyyy hh:nn:ss', Rec.Occured);
      3: AText := Rec.EventType;
      4: AText := Rec.Ip;
      5: AText := Rec.Source;
      6: AText := Rec.Status;
      7: AText := Rec.LatencyMS;
    else
      AText := '';
    end;
  end
  else
  begin
    // Данные не загружены — показываем плейсхолдер
    AText := '⌛ ...';

    // Запрашиваем загрузку нужной страницы асинхронно
    if Assigned(FEventCache) then
    begin
      PageIdx := ARecord.Index div FEventCache.PageSize;
      FEventCache.RequestPage(PageIdx);
      // Предзагружаем следующую страницу
      FEventCache.RequestPage(PageIdx + 1);
    end;
  end;
end;

{ Обработчики событий cxGrid для виртуального режима (unbound mode) }

procedure TfrmMain.tvEventsTopRecordIndexChanged(Sender: TObject);
var
  TopIdx, LastVisibleIdx, NextPageIdx: Integer;
  tv: TcxCustomGridTableView;
begin
  if sender is TcxCustomGridTableView then
  begin
    if not Assigned(FEventCache) then
      Exit;
    tv := TcxCustomGridTableView(Sender);

    TopIdx := tv.Controller.TopRecordIndex;
    if TopIdx < 0 then Exit;

    // Определяем индекс последней видимой записи + буфер предзагрузки
    LastVisibleIdx := TopIdx + tv.ViewData.RecordCount + FEventCache.PageSize;

    // Загружаем страницу для буфера предзагрузки
    NextPageIdx := LastVisibleIdx div FEventCache.PageSize;
    FEventCache.RequestPage(NextPageIdx);
    FEventCache.RequestPage(NextPageIdx + 1);
  end;
end;

procedure TfrmMain.tvEventsCustomDrawCell(Sender: TcxCustomGridTableView;
  ACanvas: TcxCanvas; AViewInfo: TcxGridTableDataCellViewInfo;
  var ADone: Boolean);
var
  Rec: TEventRecord;
begin
  if not Assigned(FEventCache) then Exit;

  // Если данные ещё не загружены — рисуем серым курсивом
  if not FEventCache.GetRecord(AViewInfo.RecordViewInfo.GridRecord.Index, Rec) then
  begin
    ACanvas.Font.Color := clGray;
    ACanvas.Font.Style := [fsItalic];
  end;
  ADone := False; // Позволяем стандартную отрисовку после наших настроек
end;

end.
