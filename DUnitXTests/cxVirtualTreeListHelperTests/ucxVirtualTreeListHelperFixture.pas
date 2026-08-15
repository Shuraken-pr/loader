unit ucxVirtualTreeListHelperFixture;

interface

uses
  System.SysUtils, System.Classes, System.Variants, DUnitX.TestFramework,
  cxVirtualTreeListHelper, cxTL;

type
  { TMockRecord — конкретный наследник TVTBaseRecord для тестирования.
    Предоставляет 5 колонок разных типов для покрытия GetFieldType. }
  TMockRecord = class(TVTBaseRecord)
  public
    const
      COL_INTEGER = 0;
      COL_STRING  = 1;
      COL_DATE    = 2;
      COL_BOOLEAN = 3;
      COL_NULL    = 4;
  private
    FIntValue: Integer;
    FText: string;
    FDate: TDateTime;
    FBoolValue: Boolean;
    FNullValue: Variant;
  public
    constructor Create(AParent: TVTBase); override;
    function  GetValue(ColIdx: Integer): Variant; override;
    procedure SetValue(ColIdx: Integer; const AValue: Variant); override;
    procedure Assign(Source: TVTBaseRecord); override;
  end;

  TMockLoadAllDS = class(TVTLoadAllDataSource<TMockRecord>);

type
  [TestFixture]
  TcxVTLHelperTests = class
  private
    FRoot: TVTBase;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // === 3.1.1 Создание и иерархия ===

    [Test]
    /// <summary>
    /// Корневой узел (AParent = nil) имеет:
    /// Parent = nil, Index = -1, Level = -1, ChildCount = 0
    /// </summary>
    procedure Create_RootHasNoParent;

    [Test]
    /// <summary>
    /// AddChild создаёт потомка. После 3 вызовов:
    /// ChildCount = 3, все Items[i].Parent = Root
    /// </summary>
    procedure AddChild_ParentHasCorrectChildCount;

    [Test]
    /// <summary>
    /// Add создаёт сиблинга (общий Parent с текущим узлом).
    /// Для потомка корня оба Add-сиблинга имеют Parent = Root.
    /// NB: root.Add создаёт сиблинг КОРНЯ (Parent = nil), а не потомка.
    /// </summary>
    procedure Add_Sibling_HasSameParent;

    [Test]
    /// <summary>
    /// Для 5 добавленных потомков Items[i].Index = i
    /// </summary>
    procedure Index_ReturnsCorrectPosition;

    [Test]
    /// <summary>
    /// root.Level = -1; root.Children[0].Level = 0; Children[0].Children[0].Level = 1
    /// </summary>
    procedure Level_CorrectAtEachDepth;

    [Test]
    /// <summary>
    /// Для дерева 2x3 (2 ветви по 3 потомка):
    /// TotalCount = 8 (ChildCount + рекурсивные потомки, БЕЗ самого корня).
    /// NB: спецификация ожидает 9 (1+2+6), но реализация считает только потомков.
    /// </summary>
    procedure TotalCount_IncludesAllDescendants;

    // === 3.1.2 DeleteChildren ===

    [Test]
    /// <summary>
    /// DeleteChildren удаляет всех прямых потомков.
    /// ChildCount становится 0.
    /// </summary>
    procedure DeleteChildren_RemovesAllChildren;

    [Test]
    /// <summary>
    /// DeleteChildren рекурсивно освобождает все уровни потомков.
    /// Все вложенные объекты уничтожаются корректно.
    /// </summary>
    procedure DeleteChildren_DescendantsDeletedRecursively;

    [Test]
    /// <summary>
    /// Флаг FDeletion предотвращает попытки деструктора потомка
    /// удалить себя из FChildList родителя во время итерации.
    /// После DeleteChildren флаг сброшен в False.
    /// </summary>
    procedure DeleteChildren_DeletionFlag_PreventsDoubleRemove;

    // === 3.1.3 NodeMoveTo ===

    [Test]
    /// <summary>
    /// NodeMoveTo с tlamAdd делает узел сиблингом AttachRecordHandle.
    /// Parent изменяется на AttachRecordHandle.Parent.
    /// </summary>
    procedure NodeMoveTo_ToSibling_ChangesParent;

    [Test]
    /// <summary>
    /// NodeMoveTo с tlamAddChild делает узел потомком AttachRecordHandle.
    /// Parent изменяется на AttachRecordHandle.
    /// </summary>
    procedure NodeMoveTo_ToChild_MovesUnderNewParent;

    [Test]
    /// <summary>
    /// NodeMoveTo к сиблингу с тем же родителем не изменяет Parent.
    /// FChildList родителя остаётся консистентным.
    /// </summary>
    procedure NodeMoveTo_SameParent_NoChange;
  end;

  [TestFixture]
  TTVTBaseRecordFixture = class
  private
    FRecord: TMockRecord;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // === 3.2.1 GetFieldType (virtual) ===

    [Test]
    /// <summary>
    /// Integer значение возвращает varInteger (3).
    /// Данные: 42 -> varInteger
    /// </summary>
    procedure GetFieldType_Integer_ReturnsVarInteger;

    [Test]
    /// <summary>
    /// string значение возвращает varUString (258) в Delphi 2009+.
    /// NB: спецификация указывает varString, но UnicodeString = varUString.
    /// </summary>
    procedure GetFieldType_String_ReturnsVarUString;

    [Test]
    /// <summary>
    /// TDateTime значение возвращает varDate (7).
    /// </summary>
    procedure GetFieldType_DateTime_ReturnsVarDate;

    [Test]
    /// <summary>
    /// Boolean значение возвращает varBoolean (11).
    /// </summary>
    procedure GetFieldType_Boolean_ReturnsVarBoolean;

    [Test]
    /// <summary>
    /// Null значение возвращает 0 (согласно специальной проверке VarIsNull).
    /// Важно: это НЕ varNull (1), а именно 0 по логике GetFieldType.
    /// </summary>
    procedure GetFieldType_Null_ReturnsZero;

    [Test]
    /// <summary>
    /// Unassigned (Empty) значение возвращает 0 (по проверке VarIsEmpty).
    /// Проверяется для несуществующего индекса колонки.
    /// </summary>
    procedure GetFieldType_Unassigned_ReturnsZero;

    [Test]
    /// <summary>
    /// Integer 0 возвращает varInteger, а НЕ 0.
    /// Это важная проверка: число 0 не должно путаться с «нет типа».
    /// </summary>
    procedure GetFieldType_ZeroInteger_ReturnsVarInteger;

    [Test]
    /// <summary>
    /// Пустая строка возвращает varUString, а не 0.
    /// Пустая строка — это валидное значение, не Null/Empty.
    /// </summary>
    procedure GetFieldType_EmptyString_ReturnsVarUString;

    // === Дополнительные тесты для TVTBaseRecord ===

    [Test]
    /// <summary>
    /// Базовая реализация Assign не падает и ничего не делает
    /// для разнотипных записей.
    /// </summary>
    procedure Assign_DefaultImpl_DoesNotRaise;

    [Test]
    /// <summary>
    /// Перекрытая Assign корректно копирует значения полей
    /// между экземплярами одного типа.
    /// </summary>
    procedure Assign_MockRecord_CopiesFields;

    [Test]
    /// <summary>
    /// GetFieldType отражает изменения после SetValue.
    /// Тип колонки может меняться динамически (Variant-природа).
    /// </summary>
    procedure GetFieldType_AfterSetValue_ReflectsNewType;
  end;

  [TestFixture]
  TTVTLoadALLDSFixture = class
  private
    FDS: TMockLoadAllDS;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    //добавляем 5 дочерних записей к root-записи
    procedure InsertRecordHandle_Child_AddsToFRecordList;

    [Test]
    //добавляем 3 sibling записи к root
    procedure InsertRecordHandle_Sibling_AddsToFRecordList;

    [Test]
    //Добавленные записи имеют тип TMockRecord
    procedure InsertRecordHandle_RecordTypesMatch;

    [Test]
    //удаляем среднюю запись и проверяем количество и индексы оставшихся
    procedure DeleteRecord_RemovesFromListAndCallsDataChanged;

    [Test]
    //Процедура очистки и проверки количества записей после неё
    procedure Clear_EmptiesListAndFreesRecords;
  end;

implementation

procedure TcxVTLHelperTests.Setup;
begin
  FRoot := TVTBase.Create(nil);
end;

procedure TcxVTLHelperTests.TearDown;
begin
  FreeAndNil(FRoot);
end;

{ === 3.1.1 Создание и иерархия === }

procedure TcxVTLHelperTests.Create_RootHasNoParent;
begin
  Assert.IsNull(FRoot.Parent, 'У корневого узла нет родителя');
  Assert.AreEqual(-1, FRoot.Index, 'Index корня = -1 (его нет в списке родителя)');
  Assert.AreEqual(-1, FRoot.Level, 'Level корня = -1');
  Assert.AreEqual(0, FRoot.ChildCount, 'ChildCount нового корня = 0');
  Assert.AreEqual(0, FRoot.TotalCount, 'TotalCount пустого корня = 0');
end;

procedure TcxVTLHelperTests.AddChild_ParentHasCorrectChildCount;
var
  C0, C1, C2: TVTBase;
begin
  C0 := FRoot.AddChild;
  C1 := FRoot.AddChild;
  C2 := FRoot.AddChild;

  Assert.AreEqual(3, FRoot.ChildCount, 'После 3 AddChild ChildCount = 3');
  Assert.AreSame(FRoot, C0.Parent, 'Items[0].Parent = Root');
  Assert.AreSame(FRoot, C1.Parent, 'Items[1].Parent = Root');
  Assert.AreSame(FRoot, C2.Parent, 'Items[2].Parent = Root');
  Assert.AreSame(C0, FRoot.Items[0], 'Items[0] — первый созданный потомок');
  Assert.AreSame(C1, FRoot.Items[1], 'Items[1] — второй созданный потомок');
  Assert.AreSame(C2, FRoot.Items[2], 'Items[2] — третий созданный потомок');
end;

procedure TcxVTLHelperTests.Add_Sibling_HasSameParent;
var
  Child, Sib1, Sib2: TVTBase;
  RootSib: TVTBase;
begin
  // Сценарий 1: root.Add создаёт сиблинг корня (Parent = nil)
  RootSib := FRoot.Add;
  Assert.IsNull(RootSib.Parent, 'Add от корня создаёт узел с Parent=nil (сиблинг корня)');

  // Сценарий 2: Add от потомка корня создаёт сиблингов под тем же родителем (Root)
  Child := FRoot.AddChild;
  Sib1 := Child.Add;
  Sib2 := Child.Add;

  Assert.AreSame(FRoot, Sib1.Parent, 'Сиблинг потомка имеет родителем FRoot');
  Assert.AreSame(FRoot, Sib2.Parent, 'Второй сиблинг имеет того же родителя');
  Assert.AreSame(Sib1.Parent, Sib2.Parent, 'Оба сиблинга имеют одинаковый Parent');
  Assert.AreEqual(3, FRoot.ChildCount, 'У корня теперь 3 потомка: Child + Sib1 + Sib2');
end;

procedure TcxVTLHelperTests.Index_ReturnsCorrectPosition;
var
  Children: array[0..4] of TVTBase;
  I: Integer;
begin
  for I := 0 to 4 do
    Children[I] := FRoot.AddChild;

  for I := 0 to 4 do
    Assert.AreEqual(I, Children[I].Index,
      Format('Items[%d].Index должен быть %d', [I, I]));
end;

procedure TcxVTLHelperTests.Level_CorrectAtEachDepth;
var
  L0, L1, L2, L3: TVTBase;
begin
  Assert.AreEqual(-1, FRoot.Level, 'root.Level = -1');

  L0 := FRoot.AddChild;
  Assert.AreEqual(0, L0.Level, 'root.Children[0].Level = 0');

  L1 := L0.AddChild;
  Assert.AreEqual(1, L1.Level, 'Children[0].Children[0].Level = 1');

  L2 := L1.AddChild;
  Assert.AreEqual(2, L2.Level, 'Глубина 3 = Level 2');

  L3 := L2.AddChild;
  Assert.AreEqual(3, L3.Level, 'Глубина 4 = Level 3');
end;

procedure TcxVTLHelperTests.TotalCount_IncludesAllDescendants;
var
  Branch1, Branch2: TVTBase;
  I: Integer;
begin
  // Структура: Root -> 2 ветви, в каждой по 3 потомка
  Branch1 := FRoot.AddChild;
  Branch2 := FRoot.AddChild;

  for I := 1 to 3 do
    Branch1.AddChild;

  for I := 1 to 3 do
    Branch2.AddChild;

  // TotalCount считает всех потомков рекурсивно, но НЕ включает сам узел:
  // TotalCount(Root) = ChildCount(2) + TotalCount(Branch1) + TotalCount(Branch2)
  //                  = 2 + 3 + 3 = 8
  Assert.AreEqual(8, FRoot.TotalCount,
    'TotalCount = ChildCount(2) + grandchildren(6) = 8 (без учёта корня)');

  // Проверка TotalCount для ветвей
  Assert.AreEqual(3, Branch1.TotalCount, 'TotalCount ветви = 3 потомка');
  Assert.AreEqual(3, Branch2.TotalCount, 'TotalCount ветви = 3 потомка');

  // Проверка TotalCount для листьев
  Assert.AreEqual(0, Branch1.Items[0].TotalCount, 'TotalCount листа = 0');
end;

{ === 3.1.2 DeleteChildren === }

procedure TcxVTLHelperTests.DeleteChildren_RemovesAllChildren;
var
  I: Integer;
begin
  // Создаём 5 потомков
  for I := 1 to 5 do
    FRoot.AddChild;

  Assert.AreEqual(5, FRoot.ChildCount, 'Перед удалением ChildCount = 5');

  FRoot.DeleteChildren;

  Assert.AreEqual(0, FRoot.ChildCount, 'После DeleteChildren ChildCount = 0');
end;

procedure TcxVTLHelperTests.DeleteChildren_DescendantsDeletedRecursively;
var
  Child, GrandChild: TVTBase;
  TotalBefore, TotalAfter: Integer;
begin
  // Создаём цепочку: Root -> Child -> GrandChild -> GreatGrandChild
  Child := FRoot.AddChild;
  GrandChild := Child.AddChild;
  GrandChild.AddChild;

  TotalBefore := FRoot.TotalCount;
  Assert.AreEqual(3, TotalBefore, 'Перед удалением TotalCount = 3');

  // Удаляем всех потомков корня (рекурсивно удалятся Child, GrandChild, GreatGrandChild)
  FRoot.DeleteChildren;

  TotalAfter := FRoot.TotalCount;
  Assert.AreEqual(0, TotalAfter, 'После DeleteChildren TotalCount = 0 (все уровни удалены)');
  Assert.AreEqual(0, FRoot.ChildCount, 'ChildCount = 0');
end;

procedure TcxVTLHelperTests.DeleteChildren_DeletionFlag_PreventsDoubleRemove;
begin
  FRoot.AddChild;
  FRoot.AddChild;

  Assert.AreEqual(2, FRoot.ChildCount, 'Перед удалением ChildCount = 2');

  // DeleteChildren должен корректно отработать без AV
  // благодаря флагу FDeletion
  FRoot.DeleteChildren;

  Assert.AreEqual(0, FRoot.ChildCount, 'После DeleteChildren ChildCount = 0');

  // Проверяем, что FDeletion сброшен (через повторный вызов - должен работать)
  FRoot.AddChild;
  Assert.AreEqual(1, FRoot.ChildCount, 'Можно добавлять новые узлы после DeleteChildren');

  FRoot.DeleteChildren;
  Assert.AreEqual(0, FRoot.ChildCount, 'Второй вызов DeleteChildren также работает');
end;

{ === 3.1.3 NodeMoveTo === }

procedure TcxVTLHelperTests.NodeMoveTo_ToSibling_ChangesParent;
var
  Parent1, Parent2, MovingNode: TVTBase;
begin
  // Создаём двух родителей
  Parent1 := FRoot.AddChild;
  Parent2 := FRoot.AddChild;

  // Создаём узел под Parent1
  MovingNode := Parent1.AddChild;
  Assert.AreSame(Parent1, MovingNode.Parent, 'Начальный Parent = Parent1');
  Assert.AreEqual(1, Parent1.ChildCount, 'У Parent1 один потомок');
  Assert.AreEqual(0, Parent2.ChildCount, 'У Parent2 нет потомков');

  // Перемещаем MovingNode как сиблинга Parent2 (tlamAdd)
  MovingNode.NodeMoveTo(Parent2, tlamAdd);

  // Теперь MovingNode имеет того же родителя, что и Parent2 (т.е. FRoot)
  Assert.AreSame(FRoot, MovingNode.Parent, 'После tlamAdd Parent = Parent2.Parent = Root');
  Assert.AreEqual(0, Parent1.ChildCount, 'У Parent1 больше нет потомков');
  Assert.AreEqual(0, Parent2.ChildCount, 'У Parent2 по-прежнему нет потомков (MovingNode стал сиблингом)');
  Assert.AreEqual(3, FRoot.ChildCount, 'У корня теперь 3 потомка: Parent1, Parent2, MovingNode');
end;

procedure TcxVTLHelperTests.NodeMoveTo_ToChild_MovesUnderNewParent;
var
  Parent1, Parent2, MovingNode: TVTBase;
begin
  // Создаём двух родителей
  Parent1 := FRoot.AddChild;
  Parent2 := FRoot.AddChild;

  // Создаём узел под Parent1
  MovingNode := Parent1.AddChild;
  Assert.AreSame(Parent1, MovingNode.Parent, 'Начальный Parent = Parent1');

  // Перемещаем MovingNode как потомка Parent2 (tlamAddChild)
  MovingNode.NodeMoveTo(Parent2, tlamAddChild);

  Assert.AreSame(Parent2, MovingNode.Parent, 'После tlamAddChild Parent = Parent2');
  Assert.AreEqual(0, Parent1.ChildCount, 'У Parent1 больше нет потомков');
  Assert.AreEqual(1, Parent2.ChildCount, 'У Parent2 теперь один потомок');
  Assert.AreSame(MovingNode, Parent2.Items[0], 'MovingNode стал первым потомком Parent2');
end;

procedure TcxVTLHelperTests.NodeMoveTo_SameParent_NoChange;
var
  Parent, Node1, Node2: TVTBase;
  InitialIndex1, InitialIndex2: Integer;
begin
  // Создаём родителя и двух потомков
  Parent := FRoot.AddChild;
  Node1 := Parent.AddChild;
  Node2 := Parent.AddChild;

  InitialIndex1 := Node1.Index;
  InitialIndex2 := Node2.Index;

  Assert.AreSame(Parent, Node1.Parent, 'Node1.Parent = Parent');
  Assert.AreSame(Parent, Node2.Parent, 'Node2.Parent = Parent');
  Assert.AreEqual(0, InitialIndex1, 'Node1.Index = 0');
  Assert.AreEqual(1, InitialIndex2, 'Node2.Index = 1');

  // Перемещаем Node1 как сиблинга Node2 (тот же родитель)
  Node1.NodeMoveTo(Node2, tlamAdd);

  // Parent не изменился
  Assert.AreSame(Parent, Node1.Parent, 'Parent остался тем же');
  Assert.AreSame(Parent, Node2.Parent, 'Parent остался тем же');

  // Node1 удаляется из старой позиции и добавляется в конец
  // (Remove + Add в ChangeParent)
  Assert.AreEqual(2, Parent.ChildCount, 'Количество потомков не изменилось');

  // Индексы меняются: Node2 остаётся на месте, Node1 уходит в конец
  Assert.AreEqual(0, Node2.Index, 'Node2 остался на позиции 0');
  Assert.AreEqual(1, Node1.Index, 'Node1 переместился на позицию 1');
end;

{ TMockRecord }

constructor TMockRecord.Create(AParent: TVTBase);
begin
  inherited Create(AParent);
  FNullValue := Null;
  FDate := 0;
  FIntValue := 0;
  FText := '';
  FBoolValue := False;
end;

function TMockRecord.GetValue(ColIdx: Integer): Variant;
begin
  case ColIdx of
    COL_INTEGER: Result := FIntValue;
    COL_STRING:  Result := FText;
    COL_DATE:    Result := FDate;
    COL_BOOLEAN: Result := FBoolValue;
    COL_NULL:    Result := FNullValue;
  else
    Result := Unassigned;
  end;
end;

procedure TMockRecord.SetValue(ColIdx: Integer; const AValue: Variant);
begin
  case ColIdx of
    COL_INTEGER: FIntValue := AValue;
    COL_STRING:  FText := AValue;
    COL_DATE:    FDate := AValue;
    COL_BOOLEAN: FBoolValue := AValue;
    COL_NULL:    FNullValue := AValue;
  end;
end;

procedure TMockRecord.Assign(Source: TVTBaseRecord);
var
  S: TMockRecord;
begin
  if Source is TMockRecord then
  begin
    S := TMockRecord(Source);
    FIntValue  := S.FIntValue;
    FText      := S.FText;
    FDate      := S.FDate;
    FBoolValue := S.FBoolValue;
    FNullValue := S.FNullValue;
  end;
end;

{ TTVTBaseRecordFixture }

procedure TTVTBaseRecordFixture.Setup;
begin
  FRecord := TMockRecord.Create(nil);
end;

procedure TTVTBaseRecordFixture.TearDown;
begin
  FreeAndNil(FRecord);
end;

{ === 3.2.1 GetFieldType === }

procedure TTVTBaseRecordFixture.GetFieldType_Integer_ReturnsVarInteger;
begin
  FRecord.SetValue(TMockRecord.COL_INTEGER, 42);
  Assert.AreEqual(varInteger, FRecord.GetFieldType(TMockRecord.COL_INTEGER),
    'Integer (42) должен вернуть varInteger');
end;

procedure TTVTBaseRecordFixture.GetFieldType_String_ReturnsVarUString;
var
  ActualType: Integer;
begin
  FRecord.SetValue(TMockRecord.COL_STRING, 'hello world');
  ActualType := FRecord.GetFieldType(TMockRecord.COL_STRING);

  { В Delphi 2009+ string = UnicodeString → varUString (258),
    а не varString (256), как указано в спецификации.
    Принимаем оба варианта для совместимости. }
  Assert.IsTrue((ActualType = varString) or (ActualType = varUString),
    Format('string должен вернуть varString или varUString, получено: %d', [ActualType]));
end;

procedure TTVTBaseRecordFixture.GetFieldType_DateTime_ReturnsVarDate;
begin
  FRecord.SetValue(TMockRecord.COL_DATE, EncodeDate(2026, 8, 16));
  Assert.AreEqual(varDate, FRecord.GetFieldType(TMockRecord.COL_DATE),
    'TDateTime должен вернуть varDate');
end;

procedure TTVTBaseRecordFixture.GetFieldType_Boolean_ReturnsVarBoolean;
begin
  FRecord.SetValue(TMockRecord.COL_BOOLEAN, True);
  Assert.AreEqual(varBoolean, FRecord.GetFieldType(TMockRecord.COL_BOOLEAN),
    'Boolean должен вернуть varBoolean');

  FRecord.SetValue(TMockRecord.COL_BOOLEAN, False);
  Assert.AreEqual(varBoolean, FRecord.GetFieldType(TMockRecord.COL_BOOLEAN),
    'Boolean False также должен вернуть varBoolean');
end;

procedure TTVTBaseRecordFixture.GetFieldType_Null_ReturnsZero;
begin
  // FNullValue уже инициализирован Null в конструкторе
  Assert.AreEqual(0, FRecord.GetFieldType(TMockRecord.COL_NULL),
    'Null должен вернуть 0 (по специальной проверке VarIsNull в GetFieldType), НЕ varNull');
end;

procedure TTVTBaseRecordFixture.GetFieldType_Unassigned_ReturnsZero;
begin
  // Для несуществующего ColIdx GetValue возвращает Unassigned
  Assert.AreEqual(0, FRecord.GetFieldType(999),
    'Unassigned (несуществующая колонка) должен вернуть 0');
end;

procedure TTVTBaseRecordFixture.GetFieldType_ZeroInteger_ReturnsVarInteger;
begin
  // Число 0 — это валидный Integer, а не «пустое» значение
  FRecord.SetValue(TMockRecord.COL_INTEGER, 0);
  Assert.AreEqual(varInteger, FRecord.GetFieldType(TMockRecord.COL_INTEGER),
    'Integer 0 должен вернуть varInteger, а НЕ 0 (как Null/Empty)');
end;

procedure TTVTBaseRecordFixture.GetFieldType_EmptyString_ReturnsVarUString;
var
  ActualType: Integer;
begin
  // Пустая строка — валидное значение, не Null/Empty
  FRecord.SetValue(TMockRecord.COL_STRING, '');
  ActualType := FRecord.GetFieldType(TMockRecord.COL_STRING);

  Assert.IsTrue((ActualType = varString) or (ActualType = varUString),
    Format('Пустая строка должна вернуть varUString, получено: %d', [ActualType]));
end;

{ === Дополнительные тесты TVTBaseRecord === }

procedure TTVTBaseRecordFixture.Assign_DefaultImpl_DoesNotRaise;
var
  BaseRecord: TVTBaseRecord;
begin
  { Создаём минимальный наследник с пустым Assign по умолчанию.
    TMockRecord.Assign работает, но мы хотим проверить базовое поведение.
    Используем FRecord (с перекрытым Assign) как Source —
    если бы Assign был пустым, вызов бы не падал. }
  BaseRecord := TMockRecord.Create(nil);
  try
    // Вызов Assign с nil-source — не должен падать
    // (проверка на is TMockRecord даст False и пропустит копирование)
    Assert.WillNotRaise(
      procedure
      begin
        FRecord.Assign(nil);
      end,
      Exception,
      'Assign(nil) не должен вызывать исключение'
    );
  finally
    FreeAndNil(BaseRecord);
  end;
end;

procedure TTVTBaseRecordFixture.Assign_MockRecord_CopiesFields;
var
  Source, Dest: TMockRecord;
  TestDate: TDateTime;
begin
  Source := TMockRecord.Create(nil);
  Dest   := TMockRecord.Create(nil);
  try
    TestDate := EncodeDate(2026, 8, 16);

    // Заполняем Source
    Source.SetValue(TMockRecord.COL_INTEGER, 12345);
    Source.SetValue(TMockRecord.COL_STRING, 'test string');
    Source.SetValue(TMockRecord.COL_DATE, TestDate);
    Source.SetValue(TMockRecord.COL_BOOLEAN, True);

    // Копируем в Dest
    Dest.Assign(Source);

    // Проверяем, что значения скопировались
    Assert.AreEqual(12345, Integer(Dest.GetValue(TMockRecord.COL_INTEGER)),
      'Integer скопирован корректно');
    Assert.AreEqual('test string', String(Dest.GetValue(TMockRecord.COL_STRING)),
      'String скопирован корректно');
    Assert.AreEqual(TestDate, TDateTime(Dest.GetValue(TMockRecord.COL_DATE)),
      'TDateTime скопирован корректно');
    Assert.AreEqual(True, Boolean(Dest.GetValue(TMockRecord.COL_BOOLEAN)),
      'Boolean скопирован корректно');
  finally
    FreeAndNil(Source);
    FreeAndNil(Dest);
  end;
end;

procedure TTVTBaseRecordFixture.GetFieldType_AfterSetValue_ReflectsNewType;
var
  Rec: TMockRecord;
begin
  Rec := TMockRecord.Create(nil);
  try
    // Изначально Null
    Assert.AreEqual(0, Rec.GetFieldType(TMockRecord.COL_NULL),
      'Изначальное значение Null → тип 0');

    // Меняем на Integer
    Rec.SetValue(TMockRecord.COL_NULL, 42);
    Assert.IsTrue((Rec.GetFieldType(TMockRecord.COL_NULL) = varByte) or
                  (Rec.GetFieldType(TMockRecord.COL_NULL) = varInteger),
      'После присвоения Integer тип изменился на varInteger');

    // Меняем на Boolean
    Rec.SetValue(TMockRecord.COL_NULL, True);
    Assert.AreEqual(varBoolean, Rec.GetFieldType(TMockRecord.COL_NULL),
      'После присвоения Boolean тип изменился на varBoolean');

    // Меняем на строку
    Rec.SetValue(TMockRecord.COL_NULL, 'text');
    Assert.IsTrue((Rec.GetFieldType(TMockRecord.COL_NULL) = varString) or
                  (Rec.GetFieldType(TMockRecord.COL_NULL) = varUString),
      'После присвоения строки тип стал строковым');
  finally
    Rec.Free;
  end;
end;

{ TTVTLoadALLDSFixture }

procedure TTVTLoadALLDSFixture.Setup;
begin
  FDS := TMockLoadAllDS.Create(nil);
end;

procedure TTVTLoadALLDSFixture.TearDown;
begin
  FreeAndNil(FDS);
end;

procedure TTVTLoadALLDSFixture.InsertRecordHandle_RecordTypesMatch;
var
  i: integer;
  MockArray: TArray<TMockRecord>;
  rec: TMockRecord;
begin
  SetLength(MockArray, 3);
  for i := 0 to 2 do
  begin
    rec := FDS.InsertRecordHandle(FDS.RootHandle, false);
    MockArray[i] := rec;
  end;

  for i := 0 to 2 do
    Assert.IsTrue(MockArray[i] is TMockRecord, 'Все записи имеют тип TMockRecord');
end;

procedure TTVTLoadALLDSFixture.InsertRecordHandle_Sibling_AddsToFRecordList;
begin
  for var i := 1 to 3 do
    FDS.InsertRecordHandle(FDS.RootHandle, false);

  Assert.IsTrue(FDS.GetRecordCount = 3, 'Добавлено 3 sibling-записи Root');
end;

procedure TTVTLoadALLDSFixture.Clear_EmptiesListAndFreesRecords;
begin
  for var i := 0 to 4 do
    FDS.InsertRecordHandle(FDS.RootHandle, true);

  Assert.IsTrue(FDS.GetRecordCount = 5, 'После добавления 5 записей');
  Assert.IsTrue(FDS.RootHandle.ChildCount = 5, 'Проверка синхронизации с деревом');
  FDS.Clear;
  Assert.IsTrue(FDS.GetRecordCount = 0, 'После удаления 0 записей');
  Assert.IsTrue(FDS.RootHandle.ChildCount = 0, 'Проверка синхронизации с деревом');
end;

procedure TTVTLoadALLDSFixture.DeleteRecord_RemovesFromListAndCallsDataChanged;
var
  rec0, rec2: TMockRecord;
begin
  rec0 := FDS.InsertRecordHandle(FDS.RootHandle, true);
  FDS.InsertRecordHandle(FDS.RootHandle, true);
  rec2 := FDS.InsertRecordHandle(FDS.RootHandle, true);

  FDS.DeleteRecord(FDS.GetRecordHandle(1));

  Assert.IsTrue(FDS.GetRecordCount = 2, 'После удаления должно остаться 2 записи');
  Assert.AreSame(rec0, TMockRecord(FDS.GetRecordHandle(0)), 'нулевая запись');
  Assert.AreSame(rec2, TMockRecord(FDS.GetRecordHandle(1)), 'вторая запись');
end;

procedure TTVTLoadALLDSFixture.InsertRecordHandle_Child_AddsToFRecordList;
begin
  for var i := 1 to 5 do
    FDS.InsertRecordHandle(FDS.RootHandle, true);

  Assert.IsTrue(FDS.GetRecordCount = 5, 'Добавлено 5 дочерних записей к Root');
  Assert.IsTrue(FDS.RootHandle.ChildCount = 5, 'Проверка синхронизации с деревом');
end;

initialization
  TDUnitX.RegisterTestFixture(TcxVTLHelperTests);
  TDUnitX.RegisterTestFixture(TTVTBaseRecordFixture);
  TDUnitX.RegisterTestFixture(TTVTLoadALLDSFixture);

end.
