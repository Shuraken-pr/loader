unit cxVirtualTreeListHelper;

{$I cxVer.inc}

{
  Дженерик-фреймворк виртуального источника данных для DevExpress cxTreeList.

  Обзор архитектуры
  =================

  TVTBase
    Базовый узел дерева.  Управляет связями «родитель–потомок» и
    безопасным удалением (флаг FDeletion).  Конструктор виртуальный;
    Add / AddChild используют TVTBaseClass(ClassType).Create(...),
    поэтому наследники всегда получают экземпляры своего фактического
    класса.  Флаг DataLoaded используется стратегией SmartLoad для
    отслеживания состояния ленивой инициализации.

  TVTBaseRecord  (абстрактный)
    Добавляет GetValue / SetValue для отдельных ячеек и Assign
    (используется методом NodeMoveTo при IsCopy = True).  Создайте
    наследника со своими полями и перекройте три этих метода.

  TVTBaseDataSource<T: TVTBaseRecord>  (абстрактный)
    Общая CRUD-логика для обеих стратегий: GetValue, SetValue,
    AppendRecord, InsertRecord, DeleteRecord, NodeMoveTo.  Создаёт
    и владеет невидимым корневым дескриптором и привязывает себя
    к TreeList.  InsertRecordHandle объявлен в public — внешние
    модули создают записи исключительно через эту точку входа.

  TVTSmartDataSource<T: TVTBaseRecord>
    Стратегия SmartLoad — использует GetRootRecordHandle /
    GetChildCount / GetChildRecordHandle.  Потомки НЕ создаются
    автоматически; приложение должно вызвать InitChildren(parent,
    proc) до того, как TreeList их запросит (например, из OnExpanding /
    OnExpanded).  InitChildren вызывает переданный AProc, который
    позволяет приложению создать детей через InsertRecordHandle.

  TVTLoadAllDataSource<T: TVTBaseRecord>
    Стратегия LoadAll — использует GetRecordCount /
    GetRecordHandle(index) / GetParentRecordHandle.  Дерево НЕ
    строится в конструкторе; приложение заполняет его через
    InsertRecordHandle.  Поддерживает плоский TObjectList<T> с
    OwnsObjects = False (корневой дескриптор владеет всеми записями;
    список используется только для доступа по индексу).

  Пример использования
  ====================

    type
      TMyRecord = class(TVTBaseRecord)
      private
        FIntValue: Integer;
        FText: string;
        FDate: TDateTime;
      public
        function  GetValue(ColIdx: Integer): Variant; override;
        procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
        procedure Assign(Source: TVTBaseRecord); override;
      end;

    // Создание источника данных:
    FDS := TVTSmartDataSource<TMyRecord>.Create(cxVirtualTreeList1);

    // Заполнение детей корня:
    FDS.InitChildren(FDS.RootHandle,
      procedure(AParent: TVTBaseRecord)
      var I: Integer;
      begin
        for I := 1 to 10 do
          with TMyRecord(FDS.InsertRecordHandle(AParent, True)) do
          begin
            FIntValue := I;
            FText     := 'Item ' + IntToStr(I);
            FDate     := Now + I * 0.001;
          end;
      end);

    // Обработчик OnExpanding — подгрузка детей раскрываемого узла:
    procedure TForm1.cxVirtualTreeList1Expanding(...);
    var
      AParent: TVTBaseRecord;
    begin
      AParent := TMyRecord(cxVirtualTreeList1.FocusedNode.RecordHandle);
      FDS.InitChildren(AParent, ...);
    end;
}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  cxTL, cxTLData, cxCustomData;

type
  { TVTBase }

  TVTBase = class
  private
    FParent: TVTBase;
    FChildList: TList;
    FDataLoaded: Boolean;
    FDeletion: Boolean;
  protected
    function GetChildCount: Integer; virtual;
    procedure SetChildCount(const Value: Integer); virtual;
    function GetItem(Index: Integer): TVTBase; virtual;
    function GetIndex: Integer;
    function GetLevel: Integer;
    function GetTotalCount: Integer;
    property Deletion: Boolean read FDeletion;
  public
    constructor Create(AParent: TVTBase); virtual;
    destructor Destroy; override;
    function Add: TVTBase;
    function AddChild: TVTBase;
    procedure DeleteChildren;
    procedure NodeMoveTo(AttachRecordHandle: TVTBase;
      AttachMode: TcxTreeListNodeAttachMode); virtual;
    property ChildCount: Integer read GetChildCount write SetChildCount;
    property Items[Index: Integer]: TVTBase read GetItem; default;
    property Index: Integer read GetIndex;
    property Level: Integer read GetLevel;
    property Parent: TVTBase read FParent;
    property TotalCount: Integer read GetTotalCount;
    { DataLoaded используется TVTSmartDataSource для отслеживания,
      были ли материализованы дети этого узла через InitChildren.
      Приложение также может читать это свойство, чтобы решить,
      нужно ли вызывать InitChildren при раскрытии узла. }
    property DataLoaded: Boolean read FDataLoaded write FDataLoaded;
  end;

  TVTBaseClass = class of TVTBase;

  { TVTBaseRecord }

  TVTBaseRecord = class abstract(TVTBase)
  public
    { Возвращает значение для указанного индекса колонки. }
    function  GetValue(ColIdx: Integer): Variant; virtual; abstract;
    { Сохраняет значение для указанного индекса колонки. }
    procedure SetValue(ColIdx: Integer; const AValue: Variant); virtual; abstract;
    { Копирует значения полей из Source в Self.  Перекройте в наследниках;
      реализация по умолчанию — пустая.  Используется методом
      NodeMoveTo(IsCopy). }
    procedure Assign(Source: TVTBaseRecord); virtual;
  end;

  { TVTBaseDataSource<T> }

  TVTBaseDataSource<T: TVTBaseRecord> = class abstract(TcxTreeListCustomDataSource)
  private
    FRootHandle: T;
    FTreeList: TcxVirtualTreeList;
  protected
    { — Перекрытия TcxTreeListCustomDataSource — }
    function  GetValue(ARecordHandle: TcxDataRecordHandle;
      AItemHandle: TcxDataItemHandle): Variant; override;
    procedure SetValue(ARecordHandle: TcxDataRecordHandle;
      AItemHandle: TcxDataItemHandle; const AValue: Variant); override;
    procedure DeleteRecord(ARecordHandle: TcxDataRecordHandle); override;
    function  AppendRecord: TcxDataRecordHandle; override;
    function  InsertRecord(ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle; override;
    procedure NodeMoveTo(ARecordHandle, AttachRecordHandle: TcxDataRecordHandle;
      AttachMode: TcxTreeListNodeAttachMode; IsCopy: Boolean); override;

    property RootHandle: T read FRootHandle;
    property TreeList: TcxVirtualTreeList read FTreeList;
  public
    constructor Create(const ATreeList: TcxVirtualTreeList); virtual;
    destructor Destroy; override;
    { Публичная точка входа для создания записей.  Внешние модули
      ДОЛЖНЫ использовать этот метод для добавления записей — обе
      стратегии маршрутизируются через него, а TVTLoadAllDataSource
      перекрывает его для синхронизации FRecordList.  Передайте
      AIsChild = True, чтобы добавить как потомка AParentHandle,
      AIsChild = False — как сиблинга. }
    function  InsertRecordHandle(AParentHandle: TVTBaseRecord;
      AIsChild: Boolean): T; virtual;
    function CurrentObj: T;
    function Obj(ANode: TcxTreeListNode): T;
    procedure Clear; virtual;
  end;

  { TVTSmartDataSource<T> — SmartLoad (ленивая, навигационный API) }

  TVTSmartDataSource<T: TVTBaseRecord> = class(TVTBaseDataSource<T>)
  protected
    function GetRootRecordHandle: TcxDataRecordHandle; override;
    function GetChildCount(AParentHandle: TcxDataRecordHandle): Integer; override;
    function GetChildRecordHandle(AParentHandle: TcxDataRecordHandle;
      AChildIndex: Integer): TcxDataRecordHandle; override;
    function AppendRecord: TcxDataRecordHandle; override;
  public
    constructor Create(const ATreeList: TcxVirtualTreeList); override;

    { Материализует детей AParentHandle через AProc.
      AProc получает родительскую запись и должен вызывать
      InsertRecordHandle(AParentHandle, True) для каждого ребёнка,
      которого нужно создать, заполняя поля ребёнка по мере
      необходимости.

      InitChildren идемпотентен: если AParentHandle.DataLoaded уже
      равен True, вызов немедленно завершается без выполнения AProc.
      После возврата из AProc устанавливается DataLoaded := True и
      вызывается DataChanged, чтобы TreeList обновился.

      Типичное использование — вызывать из OnExpanding / OnExpanded:

        procedure TForm1.TreeListExpanding(...);
        var
          AParent: TVTBaseRecord;
        begin
          AParent := TVTBaseRecord(ATreeList.FocusedNode.RecordHandle);
          FDS.InitChildren(AParent,
            procedure(P: TVTBaseRecord)
            begin
              // создание детей P через FDS.InsertRecordHandle(P, True)
            end);
        end; }
    procedure InitChildren(AParentHandle: TVTBaseRecord;
      AProc: TProc<TVTBaseRecord>);
  end;

  { TVTLoadAllDataSource<T> — LoadAll (жадная, индексный API) }

  TVTLoadAllDataSource<T: TVTBaseRecord> = class(TVTBaseDataSource<T>)
  private
    FRecordList: TObjectList<T>;
  protected
    procedure DeleteRecord(ARecordHandle: TcxDataRecordHandle); override;
    function  GetRecordCount: Integer; override;
    function  GetRecordHandle(ARecordIndex: Integer): TcxDataRecordHandle; override;
    function  GetParentRecordHandle(
      ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle; override;
  public
    constructor Create(const ATreeList: TcxVirtualTreeList); override;
    destructor Destroy; override;
    function  InsertRecordHandle(AParentHandle: TVTBaseRecord;
      AIsChild: Boolean): T; override;
    procedure Clear; override;
  end;

implementation

{ TVTBase }

constructor TVTBase.Create(AParent: TVTBase);
begin
  inherited Create;
  FParent := AParent;
  FChildList := TList.Create;
  if AParent <> nil then
    AParent.FChildList.Add(Self);
end;

destructor TVTBase.Destroy;
begin
  try
    DeleteChildren;
  finally
    FChildList.Free;
    if (FParent <> nil) and not FParent.FDeletion then
      FParent.FChildList.Remove(Self);
    inherited Destroy;
  end;
end;

function TVTBase.Add: TVTBase;
begin
  { Создаёт сиблинга — использует фактический runtime-класс, чтобы
    наследники получали экземпляры собственного типа. }
  Result := TVTBaseClass(ClassType).Create(FParent);
end;

function TVTBase.AddChild: TVTBase;
begin
  { Создаёт потомка — аналогично Add. }
  Result := TVTBaseClass(ClassType).Create(Self);
end;

procedure TVTBase.DeleteChildren;
var
  I: Integer;
begin
  { FDeletion предотвращает попытки деструктора каждого ребёнка
    удалить себя из FChildList во время итерации по нему.
    Прямой доступ к FChildList.List исключает O(n)-вызов Remove
    для каждого элемента. }
  FDeletion := True;
  try
    for I := 0 to FChildList.Count - 1 do
      TObject(FChildList.List[I]).Free;
  finally
    FChildList.Clear;
    FDeletion := False;
  end;
end;

procedure TVTBase.NodeMoveTo(AttachRecordHandle: TVTBase;
  AttachMode: TcxTreeListNodeAttachMode);

  procedure ChangeParent(ANewParent: TVTBase);
  begin
    if FParent <> ANewParent then
    begin
      FParent.FChildList.Remove(Self);
      ANewParent.FChildList.Add(Self);
      FParent := ANewParent;
    end;
  end;

begin
  case AttachMode of
    tlamAdd, tlamAddFirst, tlamInsert:
      { Прикрепление как сиблинга AttachRecordHandle. }
      ChangeParent(AttachRecordHandle.Parent);
    tlamAddChild, tlamAddChildFirst:
      { Прикрепление как потомка AttachRecordHandle. }
      ChangeParent(AttachRecordHandle);
  end;
end;

procedure TVTBase.SetChildCount(const Value: Integer);
begin
; //заполняем в наследниках.
end;

function TVTBase.GetChildCount: Integer;
begin
  Result := FChildList.Count;
end;

function TVTBase.GetItem(Index: Integer): TVTBase;
begin
  Result := TVTBase(FChildList[Index]);
end;

function TVTBase.GetIndex: Integer;
begin
  if FParent <> nil then
    Result := FParent.FChildList.IndexOf(Self)
  else
    Result := -1;
end;

function TVTBase.GetLevel: Integer;
var
  AParent: TVTBase;
begin
  { Корень имеет уровень -1; его непосредственные дети — уровень 0 и т.д. }
  Result := -1;
  AParent := FParent;
  while AParent <> nil do
  begin
    AParent := AParent.FParent;
    Inc(Result);
  end;
end;

function TVTBase.GetTotalCount: Integer;
var
  I: Integer;
begin
  Result := ChildCount;
  for I := 0 to ChildCount - 1 do
    Inc(Result, Items[I].TotalCount);
end;

{ TVTBaseRecord }

procedure TVTBaseRecord.Assign(Source: TVTBaseRecord);
begin
  { По умолчанию — пустая реализация.  Перекройте, чтобы копировать
    конкретные поля, например:
      FIntValue := TMyRecord(Source).FIntValue;
      FText     := TMyRecord(Source).FText;
      FDate     := TMyRecord(Source).FDate; }
end;

{ TVTBaseDataSource<T> }

procedure TVTBaseDataSource<T>.Clear;
begin
  //очистим все записи
  FRootHandle.Free;
  //создадим заново
  FRootHandle := T.Create(nil);
end;

constructor TVTBaseDataSource<T>.Create(const ATreeList: TcxVirtualTreeList);
begin
  inherited Create;
  FTreeList := ATreeList;
  { T ограничен типом TVTBaseRecord, который наследует виртуальный
    конструктор Create(AParent) от TVTBase — поэтому T.Create(nil)
    вызывает корректный runtime-конструктор. }
  FRootHandle := T.Create(nil);
  if ATreeList <> nil then
    ATreeList.CustomDataSource := Self;
end;

destructor TVTBaseDataSource<T>.Destroy;
begin
  if FTreeList <> nil then
    FTreeList.CustomDataSource := nil;
  { Освобождение корня каскадно освобождает все записи через DeleteChildren. }
  FRootHandle.Free;
  inherited Destroy;
end;

function TVTBaseDataSource<T>.CurrentObj: T;
begin
  Result := nil;
  if Assigned(FTreeList) and Assigned(FTreeList.FocusedNode) then
    Result := T(TcxVirtualTreeListNode(FTreeList.FocusedNode).RecordHandle);
end;

function TVTBaseDataSource<T>.Obj(ANode: TcxTreeListNode): T;
begin
  Result := nil;
  if Assigned(FTreeList) and Assigned(ANode) then
    Result := T(TcxVirtualTreeListNode(ANode).RecordHandle);
end;

function TVTBaseDataSource<T>.GetValue(
  ARecordHandle: TcxDataRecordHandle;
  AItemHandle: TcxDataItemHandle): Variant;
var
  ARec: TVTBaseRecord;
begin
  { ARecordHandle — непрозрачный указатель на объект нашей записи.
    Приводим к TVTBaseRecord и делегируем вызов его GetValue. }
  ARec := TVTBaseRecord(ARecordHandle);
  Result := ARec.GetValue(Integer(AItemHandle));
end;

procedure TVTBaseDataSource<T>.SetValue(
  ARecordHandle: TcxDataRecordHandle;
  AItemHandle: TcxDataItemHandle; const AValue: Variant);
var
  ARec: TVTBaseRecord;
begin
  ARec := TVTBaseRecord(ARecordHandle);
  ARec.SetValue(Integer(AItemHandle), AValue);
  DataChanged;
end;

procedure TVTBaseDataSource<T>.DeleteRecord(
  ARecordHandle: TcxDataRecordHandle);
begin
  { Освобождение записи каскадно освобождает её детей (через
    DeleteChildren в деструкторе).  Запись автоматически удаляет
    себя из дочернего списка родителя. }
  TVTBaseRecord(ARecordHandle).Free;
  DataChanged;
end;

function TVTBaseDataSource<T>.AppendRecord: TcxDataRecordHandle;
var
  ANewRec: TVTBaseRecord;
begin
  { По умолчанию — добавление как потомка корня.  SmartLoad
    перекрывает это, чтобы добавлять под родителем сфокусированного
    узла. }
  ANewRec := InsertRecordHandle(RootHandle, True);
  ANewRec.DataLoaded := True;   { не выполнять ленивую загрузку пустого нового узла }
  Result := TcxDataRecordHandle(ANewRec);
  DataChanged;
end;

function TVTBaseDataSource<T>.InsertRecord(
  ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle;
var
  ANewRec: TVTBaseRecord;
begin
  { Вставка как сиблинга ARecordHandle. }
  ANewRec := InsertRecordHandle(TVTBaseRecord(ARecordHandle), False);
  ANewRec.DataLoaded := True;
  Result := TcxDataRecordHandle(ANewRec);
  DataChanged;
end;

procedure TVTBaseDataSource<T>.NodeMoveTo(
  ARecordHandle, AttachRecordHandle: TcxDataRecordHandle;
  AttachMode: TcxTreeListNodeAttachMode; IsCopy: Boolean);
var
  ASourceRec, AAttachRec, ANewRec: TVTBaseRecord;
begin
  ASourceRec := TVTBaseRecord(ARecordHandle);
  AAttachRec := TVTBaseRecord(AttachRecordHandle);

  if IsCopy then
  begin
    { Создаём новую запись (потомка или сиблинга Attach в зависимости
      от AttachMode) и копируем значения полей из источника. }
    ANewRec := InsertRecordHandle(AAttachRec,
      AttachMode in [tlamAddChild, tlamAddChildFirst]);
    ANewRec.Assign(ASourceRec);
  end
  else
    { Перемещаем исходную запись к новому родителю.  Наследникам
      LoadAll не нужно обновлять FRecordList, поскольку перемещаемый
      объект уже находится в списке — меняется только его позиция
      в дереве. }
    ASourceRec.NodeMoveTo(AAttachRec, AttachMode);

  DataChanged;
end;

function TVTBaseDataSource<T>.InsertRecordHandle(
  AParentHandle: TVTBaseRecord; AIsChild: Boolean): T;
begin
  { AddChild / Add используют ClassType, поэтому новый экземпляр
    имеет тот же runtime-тип, что и AParentHandle.  Приведение к T
    корректно, поскольку T ограничен типом TVTBaseRecord, а
    AParentHandle имеет тип T. }
  if AIsChild then
    Result := T(AParentHandle.AddChild)
  else
    Result := T(AParentHandle.Add);
end;

{ TVTSmartDataSource<T> }

constructor TVTSmartDataSource<T>.Create(const ATreeList: TcxVirtualTreeList);
begin
  inherited Create(ATreeList);
  if ATreeList <> nil then
  begin
    ATreeList.OptionsData.SmartLoad := True;
    ATreeList.CustomDataSource := Self;
  end;
  { Дети корня здесь НЕ создаются — приложение должно явно
    вызвать InitChildren(RootHandle, ...). }
end;

function TVTSmartDataSource<T>.GetRootRecordHandle: TcxDataRecordHandle;
begin
  Result := TcxDataRecordHandle(RootHandle);
end;

function TVTSmartDataSource<T>.GetChildCount(
  AParentHandle: TcxDataRecordHandle): Integer;
begin
  { Возвращаем реальное количество детей.  Если приложение ещё
    не вызвало InitChildren для этого родителя, ChildCount будет 0,
    и TreeList не покажет кнопку раскрытия — вызовите InitChildren
    заранее (например, из OnExpanding), чтобы заполнить детей. }
  Result := TVTBaseRecord(AParentHandle).ChildCount;
end;

function TVTSmartDataSource<T>.GetChildRecordHandle(
  AParentHandle: TcxDataRecordHandle; AChildIndex: Integer): TcxDataRecordHandle;
begin
  { Дети должны быть созданы предыдущим вызовом InitChildren. }
  Result := TcxDataRecordHandle(TVTBaseRecord(AParentHandle).Items[AChildIndex]);
end;

function TVTSmartDataSource<T>.AppendRecord: TcxDataRecordHandle;
var
  AIndex: Integer;
  AParent, ANewRec: TVTBaseRecord;
begin
  { Добавление под родителем текущей сфокусированной записи (или
    под корнем, если фокуса нет).  Это даёт более естественный UX,
    чем базовая реализация, всегда добавляющая к корню. }
  AIndex := DataController.FocusedRecordIndex;
  if AIndex = -1 then
    AParent := RootHandle
  else
    AParent := T(TVTBaseRecord(GetRecordHandleByIndex(AIndex)).Parent);

  ANewRec := InsertRecordHandle(AParent, True);
  ANewRec.DataLoaded := True;
  Result := TcxDataRecordHandle(ANewRec);
  DataChanged;
end;

procedure TVTSmartDataSource<T>.InitChildren(
  AParentHandle: TVTBaseRecord; AProc: TProc<TVTBaseRecord>);
begin
  if AParentHandle = nil then
    Exit;
  { Идемпотентно: пропускаем, если дети уже материализованы. }
  if AParentHandle.DataLoaded then
    Exit;

  { Позволяем приложению создать детей.  Внутри AProc приложение
    вызывает InsertRecordHandle(AParentHandle, True) для каждого
    ребёнка и заполняет его поля. }
  AProc(AParentHandle);

  AParentHandle.DataLoaded := True;
  DataChanged;
end;

{ TVTLoadAllDataSource<T> }

procedure TVTLoadAllDataSource<T>.Clear;
begin
  inherited;
  FRecordList.Clear;
end;

constructor TVTLoadAllDataSource<T>.Create(const ATreeList: TcxVirtualTreeList);
begin
  inherited Create(ATreeList);
  { OwnsObjects = False — корневой дескриптор владеет всеми
    записями через древовидную структуру; FRecordList используется
    только для доступа по индексу. }
  FRecordList := TObjectList<T>.Create(False);
  if ATreeList <> nil then
    ATreeList.OptionsData.SmartLoad := False;
  { Дерево здесь НЕ строится — приложение заполняет его через
    InsertRecordHandle. }
end;

destructor TVTLoadAllDataSource<T>.Destroy;
begin
  { Освобождаем только контейнер списка; записи освобождаются
    корневым дескриптором в унаследованном деструкторе. }
  FRecordList.Free;
  inherited Destroy;
end;

function TVTLoadAllDataSource<T>.InsertRecordHandle(
  AParentHandle: TVTBaseRecord; AIsChild: Boolean): T;
begin
  { Вызываем унаследованный метод для создания записи в дереве,
    затем регистрируем её в плоском списке для доступа по индексу. }
  Result := inherited InsertRecordHandle(AParentHandle, AIsChild);
  FRecordList.Add(Result);
end;

procedure TVTLoadAllDataSource<T>.DeleteRecord(
  ARecordHandle: TcxDataRecordHandle);
begin
  { Сначала удаляем из плоского списка, затем освобождаем через
    унаследованный метод (который также вызывает DataChanged). }
  FRecordList.Remove(T(ARecordHandle));
  inherited DeleteRecord(ARecordHandle);
end;

function TVTLoadAllDataSource<T>.GetRecordCount: Integer;
begin
  if Assigned(FRecordList) then
    Result := FRecordList.Count
  else
    Result := 0;
end;

function TVTLoadAllDataSource<T>.GetRecordHandle(
  ARecordIndex: Integer): TcxDataRecordHandle;
begin
  Result := TcxDataRecordHandle(FRecordList[ARecordIndex]);
end;

function TVTLoadAllDataSource<T>.GetParentRecordHandle(
  ARecordHandle: TcxDataRecordHandle): TcxDataRecordHandle;
begin
  Result := TcxDataRecordHandle(TVTBaseRecord(ARecordHandle).Parent);
end;

end.
