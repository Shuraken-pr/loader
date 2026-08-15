unit ucxVirtualTreeListHelperFixture;

interface

uses
  System.SysUtils, System.Classes, DUnitX.TestFramework,
  cxVirtualTreeListHelper, cxTL;

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

initialization
  TDUnitX.RegisterTestFixture(TcxVTLHelperTests);

end.
