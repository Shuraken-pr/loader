unit fAttributeDelete;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, 
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, 
  Vcl.StdCtrls, Vcl.ExtCtrls, uCatalogService, uEntities, cxGraphics,
  cxControls, cxLookAndFeels, cxLookAndFeelPainters, dxLayoutControlAdapters,
  dxLayoutContainer, cxClasses, dxLayoutControl, dxLayoutcxEditAdapters,
  cxContainer, cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, dmDatabase,
  dxSkinsCore, dxSkinBasic, dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2010Silver, dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark, dxSkinVS2010;

type
  TfAttributeDelete = class(TForm)
    btnOK: TButton;
    btnCancel: TButton;
    lcAttributeDeleteGroup_Root: TdxLayoutGroup;
    lcAttributeDelete: TdxLayoutControl;
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
    function ValidateAndDelete: Boolean;
  public
    class function Execute(ACatalogService: TCatalogService; ACategoryID: Integer): Boolean;
  end;

implementation

{$R *.dfm}

class function TfAttributeDelete.Execute(ACatalogService: TCatalogService; ACategoryID: Integer): Boolean;
var
  frm: TfAttributeDelete;
begin
  frm := TfAttributeDelete.Create(nil);
  try
    frm.FCatalogService := ACatalogService;
    frm.FCategoryID := ACategoryID;

    frm.FillAttributes;
    Result := (frm.ShowModal = mrOk);
  finally
    frm.Free;
  end;
end;

procedure TfAttributeDelete.FillAttributes;
var
  i: Integer;
begin
  // Загружаем атрибуты текущей категории
  FAttributes := FCatalogService.GetCategoryAttributes(FCategoryID);
  cmbAttributes.Clear;

  for i := 0 to High(FAttributes) do
  begin
    // Сохраняем ID атрибута в Objects для последующего использования
    cmbAttributes.Properties.Items.AddObject(FAttributes[i].Name, TObject(FAttributes[i].ID));
  end;

  if cmbAttributes.Properties.Items.Count > 0 then
    cmbAttributes.ItemIndex := 0
  else
  begin
    cmbAttributes.Enabled := False;
    liAttributes.CaptionOptions.Text := 'В данной категории нет атрибутов для удаления.';
  end;
end;

function TfAttributeDelete.ValidateAndDelete: Boolean;
var
  AttrID: Integer;
  ErrMsg: string;
begin
  Result := False;
  if cmbAttributes.ItemIndex < 0 then Exit;

  AttrID := Integer(cmbAttributes.Properties.Items.Objects[cmbAttributes.ItemIndex]);
  
  // Вызываем метод сервиса, который уже содержит перехват ошибки 23503
  if FCatalogService.DeleteAttribute(AttrID, ErrMsg) then
  begin
    Result := True;
    ModalResult := mrOk;
  end
  else
  begin
    ShowMessage(ErrMsg);
  end;
end;

procedure TfAttributeDelete.btnOKClick(Sender: TObject);
begin
  ValidateAndDelete;
end;

end.