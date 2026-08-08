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
  dxLayoutControlAdapters, Vcl.Buttons, settings, cxCalendar,
  dxDateTimeWheelPicker, cxBarEditItem, FDMoniCustomLoggerHelper,
  VirtualDataCache, uConnectionSemaphore, intf_dll_manager, frxDevDSIntf,
  uDBConnectionSettings, uMultiDBSettingsForm, dxRibbonGallery,
  System.ImageList, Vcl.ImgList, cxImageList, dmSkins, dxSkinsCore,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle, dxSkinOffice2007Blue,
  dxSkinOffice2010Silver, dxSkinOffice2013LightGray, dxSkinVS2010, uSkinHelper,
  cxFilter, cxCustomData, cxStyles, dxScrollbarAnnotations, cxTL,
  cxTLdxBarBuiltInMenu, cxInplaceContainer, cxTLData, cxVirtualTreeListHelper,
  VirtualEventsDataSource;

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
    vtlEvents: TcxVirtualTreeList;
    liEvents: TdxLayoutItem;
    vtlEventsStats: TcxVirtualTreeList;
    liEventsStats: TdxLayoutItem;
    vtlEventsID: TcxTreeListColumn;
    vtlEventsUserName: TcxTreeListColumn;
    vtlEventsDTChange: TcxTreeListColumn;
    vtlEventsEventType: TcxTreeListColumn;
    vtlEventsIp: TcxTreeListColumn;
    vtlEventsSource: TcxTreeListColumn;
    vtlEventsStatus: TcxTreeListColumn;
    vtlEventsLatency: TcxTreeListColumn;
    vtlEventsStatsHour: TcxTreeListColumn;
    vtlEventsStatsSource: TcxTreeListColumn;
    vtlEventsStatsEventCount: TcxTreeListColumn;
    vtlEventsStatsAvg_latency: TcxTreeListColumn;
    vtlEventsStatslatencyTrend: TcxTreeListColumn;
    vtlEventsStatsGrouwthPct: TcxTreeListColumn;
    vtlEventsStatsAllEvents: TcxTreeListColumn;
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
    FEventsDS: TEventsCacheDataSource;
    FEventsStatsDS: TVTLoadAllDataSource<TEventStatsRecord>;
    FLoadEventsStatsList: TObjectList<TEventStatsRecord>;
    FPoller: TRealTimePoller;
    procedure HandleNewPollerEvents(const AEvents: TArray<TEventPayload>);
    procedure HandlePageLoaded(Sender: TObject; PageIndex: Integer);
    procedure HandleCacheError(Sender: TObject; const ErrorMsg: string);
    procedure DoCallback(const AMsg: WideString);
    function FRCustomFunction(ANameFunc: WideString; ANameParam: WideString): variant;
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
  FreeAndNil(FEventsDS);
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
begin
  if Length(AEvents) = 0 then
    Exit;

  if not Assigned(FEventsDS) then
    Exit;

  vtlEvents.BeginUpdate;
  try
    for i := Low(AEvents) to High(AEvents) do
      FEventsDS.PrependRecord(AEvents[i]);
  finally
    vtlEvents.EndUpdate;
  end;
end;

procedure TfrmMain.HandlePageLoaded(Sender: TObject; PageIndex: Integer);
begin
  if Assigned(FEventsDS) then
    FEventsDS.NotifyDataChanged;
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

        // Шаг 2: Переход в UI-поток — создание кэша и настройка DataSource
        TThread.Synchronize(nil, procedure
        begin
          // Освобождаем предыдущий DataSource и кэш
          FreeAndNil(FEventsDS);
          FreeAndNil(FEventCache);

          // Создаём новый кэш с маппер-функцией
          FEventCache := TVirtualDataCache<TEventRecord>.Create('PgPool', 1000,
            function(qr: TFDQuery): TEventRecord
            begin
              Result := TEventRecord.Create(nil);
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

          // Создаём DataSource для vtlEvents
          FEventsDS := TEventsCacheDataSource.Create(vtlEvents, FEventCache);
          vtlEvents.OptionsData.SmartLoad := False;

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

end.
