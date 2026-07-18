unit fPartEdit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, System.Generics.Collections,
  uEntities, uCatalogService, dmDatabase, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, cxClasses, dxLayoutContainer,
  dxLayoutControl, cxContainer, cxEdit, cxTextEdit, cxCheckBox, dxCore,
  cxDateUtils, cxMaskEdit, cxDropDownEdit, cxCalendar, dxSkinsCore, dxSkinBasic,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle,
  dxSkinOffice2007Blue, dxSkinOffice2010Silver, dxSkinOffice2013LightGray,
  dxSkinOffice2016Dark, dxSkinVS2010, dxLayoutControlAdapters, Vcl.Menus, cxButtons;

type
  TfPartEdit = class(TForm)
    lcMainGroup_Root: TdxLayoutGroup;
    lcMain: TdxLayoutControl;
    lgButtons: TdxLayoutGroup;
    btnOK: TcxButton;
    liOk: TdxLayoutItem;
    btnCancel: TcxButton;
    liCancel: TdxLayoutItem;
    lgMain: TdxLayoutGroup;
    procedure cxDateEdit1KeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure cxDateEdit1KeyPress(Sender: TObject; var Key: Char);
    procedure btnOKClick(Sender: TObject);
  private
    FCatalogService: TCatalogService;
    FCategoryID: Integer;
    FPartID: Integer;
    FCode: string;

    edtCode: TcxTextEdit;
    // Используем TComponent, так как и TLabel, и TEdit/TPicker наследуются от него
    FAttributes: TArray<TAttributeDef>;

    procedure BuildControls;
    function ValidateAndSave: Boolean;
  public
    // Классовый метод для удобного вызова формы
    class function Execute(ACatalogService: TCatalogService; ACategoryID: Integer; APartID: Integer = 0; const ACode: string = ''): Boolean;
  end;

implementation

{$R *.dfm}

class function TfPartEdit.Execute(ACatalogService: TCatalogService; ACategoryID: Integer; APartID: Integer = 0; const ACode: string = ''): Boolean;
var
  frm: TfPartEdit;
begin
  // 1. Создаем форму (вызывается FormCreate, но параметры еще не заданы)
  frm := TfPartEdit.Create(nil);
  try
    // 2. Задаем параметры
    frm.FCatalogService := ACatalogService;
    frm.FCategoryID := ACategoryID;
    frm.FPartID := APartID;
    frm.FCode := ACode;

    // 3. И только теперь строим контролы, когда все данные уже есть!
    frm.BuildControls;

    // 4. Показываем форму
    Result := (frm.ShowModal = mrOk);
  finally
    frm.Free; // Вызовет FormDestroy, который очистит память
  end;
end;

procedure TfPartEdit.BuildControls;
var
  i, YPos: Integer;
  li: TdxLayoutItem;
  ctrl: TControl;
  Parts: TArray<TPartRow>;
  PartValues: TDictionary<string, string>;
  ValStr: string;
begin
  edtCode := TcxTextEdit.Create(Self);
  li := lcMain.CreateItemForControl(edtCode, lgMain);
  li.CaptionOptions.Text := 'Код детали:';
  edtCode.Text := FCode;
  edtCode.Tag := -1;

  YPos := 50;

  // --- 2. Загрузка текущих значений (если это редактирование, а не создание) ---
  PartValues := nil;
  if FPartID > 0 then
  begin
    Parts := FCatalogService.GetParts(FCategoryID, '');
    for i := 0 to High(Parts) do
    begin
      if Parts[i].PartID = FPartID then
      begin
        PartValues := Parts[i].Values;
        Break;
      end;
    end;
  end;

  // --- 3. Динамическое создание полей для атрибутов ---
  FAttributes := FCatalogService.GetCategoryAttributes(FCategoryID);

  for i := 0 to High(FAttributes) do
  begin
    case FAttributes[i].AttrType of
      atString, atNumber:
        begin
          ctrl := TcxTextEdit.Create(Self);
          ctrl.Tag := i;
          li := lcMain.CreateItemForControl(ctrl, lgMain);
          li.CaptionOptions.Text := FAttributes[i].Name + ':';
          if Assigned(PartValues) and PartValues.TryGetValue(FAttributes[i].Name, ValStr) then
            TcxTextEdit(ctrl).Text := ValStr;
        end;
      atDate:
        begin
          ctrl := TcxDateEdit.Create(Self);
          ctrl.Tag := i;
          TcxDateEdit(ctrl).OnKeyDown := cxDateEdit1KeyDown;
          TcxDateEdit(ctrl).OnKeyPress := cxDateEdit1KeyPress;
          li := lcMain.CreateItemForControl(ctrl, lgMain);
          li.CaptionOptions.Text := FAttributes[i].Name + ':';
          if Assigned(PartValues) and PartValues.TryGetValue(FAttributes[i].Name, ValStr) and (ValStr <> '') then
          begin
            try
              TcxDateEdit(ctrl).Date := StrToDate(ValStr);
            except
              // Игнорируем ошибки формата даты при загрузке, оставляем пустым
            end;
          end;
        end;
      atBoolean:
        begin
          ctrl := TcxCheckBox.Create(Self);
          ctrl.Tag := i;
          li := lcMain.CreateItemForControl(ctrl, lgMain);
          li.CaptionOptions.Text := FAttributes[i].Name + ':';
          TcxCheckBox(ctrl).Caption := 'Да';
          if Assigned(PartValues) and PartValues.TryGetValue(FAttributes[i].Name, ValStr) then
            TcxCheckBox(ctrl).Checked := SameText(ValStr, 'Да') or SameText(ValStr, 'true');
        end;
    end;
    YPos := YPos + 35;
  end;

  // Автоматическая подгонка высоты формы под количество полей
  ClientHeight := YPos + 60;
end;

procedure TfPartEdit.cxDateEdit1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  key := 0;
end;

procedure TfPartEdit.cxDateEdit1KeyPress(Sender: TObject; var Key: Char);
begin
  key := #0;
end;

function TfPartEdit.ValidateAndSave: Boolean;
var
  i: Integer;
  CodeStr: string;
  ValuesArray: TArray<TPair<string, string>>;
  ValCount: Integer;
  Ctrl: TComponent;
  AttrIdx: Integer;
  ValStr: string;
begin
  Result := False;
  CodeStr := Trim(edtCode.Text);
  if CodeStr = '' then
  begin
    ShowMessage('Код детали не может быть пустым.');
    Exit;
  end;


  // Выделяем память под массив пар (максимум = количество атрибутов)
  SetLength(ValuesArray, Length(FAttributes));
  ValCount := 0;

  // Считываем значения из динамически созданных контролов
  for i := 0 to lcMain.ControlCount - 1 do
  begin
    Ctrl := lcMain.Controls[i];

    // Нас интересуют только поля ввода, у которых мы сохранили индекс в Tag
    if (Ctrl is TWinControl) and (Ctrl.Tag >= 0) then
    begin
      AttrIdx := TWinControl(Ctrl).Tag;
      if AttrIdx < Length(FAttributes) then
      begin
        if Ctrl is TcxTextEdit then
          ValStr := Trim(TcxTextEdit(Ctrl).Text)
        else if Ctrl is TcxDateEdit then
          ValStr := FormatDateTime('dd.mm.yyyy', TcxDateEdit(Ctrl).Date)
        else if Ctrl is TcxCheckBox then
          ValStr := IfThen(TcxCheckBox(Ctrl).Checked, 'true', 'false')
        else
          ValStr := '';

        ValuesArray[ValCount] := TPair<string, string>.Create(FAttributes[AttrIdx].Name, ValStr);
        Inc(ValCount);
      end;
    end;
  end;

  // Обрезаем массив до реального количества считанных полей
  SetLength(ValuesArray, ValCount);

  try
    // Вызываем метод сохранения в сервисе
    Result := FCatalogService.SavePart(FCategoryID, FPartID, CodeStr, ValuesArray);
    if Result then
      ModalResult := mrOk
    else
      ShowMessage('Не удалось сохранить деталь. Проверьте данные.');
  except
    on E: Exception do
      ShowMessage('Ошибка сохранения: ' + E.Message);
  end;
end;

procedure TfPartEdit.btnOKClick(Sender: TObject);
begin
  ValidateAndSave; // Если успешно, ModalResult уже установлен в mrOk внутри функции
end;

end.
