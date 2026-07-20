unit fAttributeEdit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, Vcl.Menus, cxContainer, cxEdit,
  dxLayoutControlAdapters, dxLayoutcxEditAdapters, dxLayoutContainer, cxClasses,
  cxMaskEdit, cxDropDownEdit, cxTextEdit, Vcl.StdCtrls, cxButtons, dmDatabase,
  dxLayoutControl, uCatalogService, uEntities, dxSkinsCore, dmSkins;

type
  TfrmAttributeEdit = class(TForm)
    lcAttributeEdit: TdxLayoutControl;
    btnOk: TcxButton;
    btnCancel: TcxButton;
    edName: TcxTextEdit;
    cmbType: TcxComboBox;
    lcAttributeEditGroup_Root: TdxLayoutGroup;
    lgModalResul: TdxLayoutGroup;
    lgCategoryEdit: TdxLayoutGroup;
    liOk: TdxLayoutItem;
    liCancel: TdxLayoutItem;
    liCategoryName: TdxLayoutItem;
    liType: TdxLayoutItem;
    procedure FormCreate(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    { Private declarations }
    FCatalogService: TCatalogService;
    FCategoryID: Integer;
    FAttributeID: Integer;
    FCurrentName: string;
    FCurrentType: TAttrType;

    function GetAttrTypeFromCombo: TAttrType;
    procedure SetComboToAttrType(AType: TAttrType);
    function ValidateAndSave: Boolean;
  public
    { Public declarations }
    class function Execute(ACatalogService: TCatalogService; ACategoryID: Integer;
      AAttributeID: Integer = 0; const ACurrentName: string = ''; ACurrentType: TAttrType = atString): Boolean;
  end;

var
  frmAttributeEdit: TfrmAttributeEdit;

implementation

{$R *.dfm}

{ TfrmAttributeEdit }

procedure TfrmAttributeEdit.btnOkClick(Sender: TObject);
begin
  if ValidateAndSave then
    ModalResult := mrOk;
end;

class function TfrmAttributeEdit.Execute(ACatalogService: TCatalogService;
  ACategoryID, AAttributeID: Integer; const ACurrentName: string;
  ACurrentType: TAttrType): Boolean;
var
  frm: TfrmAttributeEdit;
begin
  frm := TfrmAttributeEdit.Create(nil);
  try
    frm.FCatalogService := ACatalogService;
    frm.FCategoryID := ACategoryID;
    frm.FAttributeID := AAttributeID;
    frm.FCurrentName := ACurrentName;
    frm.FCurrentType := ACurrentType;

    frm.edName.Text := ACurrentName;
    frm.SetComboToAttrType(ACurrentType);

    Result := (frm.ShowModal = mrOk);
  finally
    frm.Free;
  end;
end;

procedure TfrmAttributeEdit.FormCreate(Sender: TObject);
begin
  cmbType.Clear;
  cmbType.Properties.Items.AddObject('Строка', TObject(Ord(atString)));
  cmbType.Properties.Items.AddObject('Число', TObject(Ord(atNumber)));
  cmbType.Properties.Items.AddObject('Дата', TObject(Ord(atDate)));
  cmbType.Properties.Items.AddObject('Логическое (Да/Нет)', TObject(Ord(atBoolean)));
end;

function TfrmAttributeEdit.GetAttrTypeFromCombo: TAttrType;
begin
  Result := TAttrType(Integer(cmbType.Properties.Items.Objects[cmbType.ItemIndex]));
end;

procedure TfrmAttributeEdit.SetComboToAttrType(AType: TAttrType);
var
  i: Integer;
begin
  for i := 0 to cmbType.Properties.Items.Count - 1 do
  begin
    if TAttrType(Integer(cmbType.Properties.Items.Objects[i])) = AType then
    begin
      cmbType.ItemIndex := i;
      Break;
    end;
  end;
end;

function TfrmAttributeEdit.ValidateAndSave: Boolean;
var
  NameStr: string;
  AttrType: TAttrType;
begin
  Result := False;
  NameStr := Trim(edName.Text);
  if NameStr = '' then
  begin
    ShowMessage('Наименование атрибута не может быть пустым.');
    Exit;
  end;

  AttrType := GetAttrTypeFromCombo;

  try
    if FAttributeID = 0 then
    begin
      Result := FCatalogService.SaveAttribute(FCategoryID, 0, NameStr, AttrType);
    end
    else
    begin
      // При редактировании существующего атрибута
      Result := FCatalogService.SaveAttribute(FCategoryID, FAttributeID, NameStr, AttrType);
    end;

    if not Result then
      ShowMessage('Не удалось сохранить атрибут.');

  except
    on E: Exception do
    begin
      if Pos('23505', E.Message) > 0 then
        ShowMessage('Атрибут с таким именем уже существует в этой категории.')
      else if Pos('23514', E.Message) > 0 then // Наш кастомный код из триггера при смене типа
        ShowMessage('Невозможно изменить тип атрибута, так как он уже содержит данные несоответствующего типа.')
      else
        ShowMessage('Ошибка сохранения: ' + E.Message);
    end;
  end;
end;

end.
