unit fCategoryEdit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxClasses, dxLayoutContainer, dxLayoutControl,
  dxLayoutControlAdapters, dxLayoutcxEditAdapters, Vcl.Menus, cxContainer, dmDatabase,
  cxEdit, cxMaskEdit, cxDropDownEdit, cxTextEdit, Vcl.StdCtrls, cxButtons, uCatalogService, uEntities,
  dxSkinsCore, dmSkins;

type
  TfrmCategoryEdit = class(TForm)
    lcCategoryEditGroup_Root: TdxLayoutGroup;
    lcCategoryEdit: TdxLayoutControl;
    lgModalResul: TdxLayoutGroup;
    lgCategoryEdit: TdxLayoutGroup;
    btnOk: TcxButton;
    liOk: TdxLayoutItem;
    btnCancel: TcxButton;
    liCancel: TdxLayoutItem;
    edName: TcxTextEdit;
    liCategoryName: TdxLayoutItem;
    cmbParent: TcxComboBox;
    liParent: TdxLayoutItem;
    procedure btnOkClick(Sender: TObject);
  private
    { Private declarations }
    FCatalogService: TCatalogService;
    FCategoryID: Integer;
    FCurrentName: string;
    FCurrentParentID: Integer;

    procedure PopulateParents;
    function ValidateAndSave: Boolean;
  public
    class function Execute(ACatalogService: TCatalogService; ACategoryID: Integer = 0;
      const ACurrentName: string = ''; ACurrentParentID: Integer = 0): Boolean;
    { Public declarations }
  end;

var
  frmCategoryEdit: TfrmCategoryEdit;

implementation

{$R *.dfm}

{ TfrmCategoryEdit }

class function TfrmCategoryEdit.Execute(ACatalogService: TCatalogService; ACategoryID: Integer;
  const ACurrentName: string; ACurrentParentID: Integer): Boolean;
var
  frm: TfrmCategoryEdit;
begin
  frm := TfrmCategoryEdit.Create(nil);
  try
    frm.FCatalogService := ACatalogService;
    frm.FCategoryID := ACategoryID;
    frm.FCurrentName := ACurrentName;
    frm.FCurrentParentID := ACurrentParentID;

    frm.edName.Text := ACurrentName;
    frm.PopulateParents;

    Result := (frm.ShowModal = mrOk);
  finally
    frm.Free;
  end;
end;

procedure TfrmCategoryEdit.PopulateParents;
var
  Cats: TArray<TCategory>;
  i: Integer;
begin
  cmbParent.Clear;
  cmbParent.Properties.Items.AddObject('(Корневая категория)', TObject(0));

  Cats := FCatalogService.GetCategories;
  for i := 0 to High(Cats) do
  begin
    // Исключаем текущую категорию, чтобы она не могла стать своим же родителем (защита от циклов)
    if Cats[i].ID <> FCategoryID then
      cmbParent.Properties.Items.AddObject(Cats[i].Name, TObject(Cats[i].ID));
  end;

  // Выбираем текущий родительский элемент
  for i := 0 to cmbParent.Properties.Items.Count - 1 do
  begin
    if Integer(cmbParent.Properties.Items.Objects[i]) = FCurrentParentID then
    begin
      cmbParent.ItemIndex := i;
      Break;
    end;
  end;
end;

function TfrmCategoryEdit.ValidateAndSave: Boolean;
var
  NameStr: string;
  ParentID: Integer;
begin
  Result := False;
  NameStr := Trim(edName.Text);
  if NameStr = '' then
  begin
    ShowMessage('Наименование категории не может быть пустым.');
    Exit;
  end;

  ParentID := Integer(cmbParent.Properties.Items.Objects[cmbParent.ItemIndex]);

  try
    Result := FCatalogService.SaveCategory(FCategoryID, NameStr, ParentID);
    if not Result then
      ShowMessage('Не удалось сохранить категорию.');
  except
    on E: Exception do
    begin
      if Pos('23505', E.Message) > 0 then // Unique violation
        ShowMessage('Категория с таким именем уже существует на этом уровне иерархии.')
      else
        ShowMessage('Ошибка сохранения: ' + E.Message);
    end;
  end;
end;

procedure TfrmCategoryEdit.btnOKClick(Sender: TObject);
begin
  if ValidateAndSave then
    ModalResult := mrOk;
end;

end.
