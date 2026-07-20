unit fAttributeSelect;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, 
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, 
  Vcl.StdCtrls, Vcl.ExtCtrls, uCatalogService, uEntities, cxGraphics,
  cxControls, cxLookAndFeels, cxLookAndFeelPainters, dxLayoutControlAdapters,
  dxLayoutContainer, cxClasses, dxLayoutControl, dxLayoutcxEditAdapters,
  cxContainer, cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, dmDatabase,
  dxSkinsCore, dmSkins;

type
  TfAttributeSelect = class(TForm)
    btnOK: TButton;
    btnCancel: TButton;
    lcAttributeSelectGroup_Root: TdxLayoutGroup;
    lcAttributeSelect: TdxLayoutControl;
    lgActions: TdxLayoutGroup;
    liOk: TdxLayoutItem;
    liCancel: TdxLayoutItem;
    cmbAttributes: TcxComboBox;
    liAttributes: TdxLayoutItem;
    procedure btnOKClick(Sender: TObject);
  private
    FCatalogService: TCatalogService;
    FCategoryID: Integer;
    FAttributes: TArray<TAttributeDef>;

    procedure FillAttributes;
    function ValidateAndSelect: Boolean;
  public
    // Возвращает True, если выбран атрибут, и заполняет выходные параметры
    class function Execute(ACatalogService: TCatalogService; ACategoryID: Integer; 
      out AAttributeID: Integer; out AAttributeName: string; out AAttrType: TAttrType): Boolean;
  end;

implementation

{$R *.dfm}

class function TfAttributeSelect.Execute(ACatalogService: TCatalogService; ACategoryID: Integer; 
  out AAttributeID: Integer; out AAttributeName: string; out AAttrType: TAttrType): Boolean;
var
  frm: TfAttributeSelect;
begin
  AAttributeID := 0;
  AAttributeName := '';
  AAttrType := atString;
  
  frm := TfAttributeSelect.Create(nil);
  try
    frm.FCatalogService := ACatalogService;
    frm.FCategoryID := ACategoryID;
    frm.FillAttributes;
    Result := (frm.ShowModal = mrOk);
    
    if Result then
    begin
      AAttributeID := Integer(frm.cmbAttributes.Properties.Items.Objects[frm.cmbAttributes.ItemIndex]);
      AAttributeName := frm.cmbAttributes.Properties.Items[frm.cmbAttributes.ItemIndex];
      
      // Находим тип атрибута в массиве
      for var i := 0 to High(frm.FAttributes) do
        if frm.FAttributes[i].ID = AAttributeID then
        begin
          AAttrType := frm.FAttributes[i].AttrType;
          Break;
        end;
    end;
  finally
    frm.Free;
  end;
end;

procedure TfAttributeSelect.FillAttributes;
var
  i: Integer;
begin
  FAttributes := FCatalogService.GetCategoryAttributes(FCategoryID);
  cmbAttributes.Clear;

  for i := 0 to High(FAttributes) do
    cmbAttributes.Properties.Items.AddObject(FAttributes[i].Name, TObject(FAttributes[i].ID));

  if cmbAttributes.Properties.Items.Count > 0 then
    cmbAttributes.ItemIndex := 0
  else
  begin
    cmbAttributes.Enabled := False;
    liAttributes.CaptionOptions.Text := 'В данной категории нет атрибутов.';
    btnOK.Enabled := False;
  end;
end;

function TfAttributeSelect.ValidateAndSelect: Boolean;
begin
  Result := cmbAttributes.ItemIndex >= 0;
  if Result then
    ModalResult := mrOk;
end;

procedure TfAttributeSelect.btnOKClick(Sender: TObject);
begin
  ValidateAndSelect;
end;

end.