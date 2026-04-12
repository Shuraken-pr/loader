unit uConnectionParams;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, uDMConn, dxCore, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxLayoutcxEditAdapters, cxContainer,
  cxEdit, dxLayoutContainer, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxClasses,
  dxLayoutControl, FireDAC.Phys.PGDef, FireDAC.Phys.MSSQLDef, FireDAC.Phys.OracleDef,
  dxLayoutControlAdapters, Vcl.Menus, Vcl.StdCtrls, cxButtons;

type
 TfrmConnections = class(TForm)
    lcConnectionParamsGroup_Root: TdxLayoutGroup;
    lcConnectionParams: TdxLayoutControl;
    cbTypeDB: TcxComboBox;
    liTypeBD: TdxLayoutItem;
    edNameDB: TcxTextEdit;
    liNameDB: TdxLayoutItem;
    edServer: TcxTextEdit;
    liServer: TdxLayoutItem;
    edPort: TcxTextEdit;
    liPort: TdxLayoutItem;
    edLogin: TcxTextEdit;
    liLogin: TdxLayoutItem;
    edPassword: TcxTextEdit;
    liPassword: TdxLayoutItem;
    btnOk: TcxButton;
    liOk: TdxLayoutItem;
    procedure cbTypeDBPropertiesChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    class function RunForm(FDM: TdmConn; var AMsg: WideString): boolean;
  end;

var
  frmConnections: TfrmConnections;

implementation

{$R *.dfm}

{ TfrmConnections }

procedure TfrmConnections.cbTypeDBPropertiesChange(Sender: TObject);
begin
  liPort.Visible := TcxComboBox(Sender).ItemIndex = 0;
  liServer.Visible := TcxComboBox(Sender).ItemIndex <> 2;
  if not liServer.Visible then
    liNameDB.CaptionOptions.Text := 'Сервер'
  else
    liNameDB.CaptionOptions.Text := 'База Данных';
end;

class function TfrmConnections.RunForm(FDM: TdmConn; var AMsg: WideString): boolean;
var
  curConn: TAvailiableConnection;
begin
  Result := Assigned(FDM);
  if not Result then
  begin
    AMsg := 'Не задан dmConn';
    exit;
  end;
  try
    if not Assigned(frmConnections) then
      frmConnections := TfrmConnections.Create(nil);
    try
      Result := false;
      if frmConnections.ShowModal = mrOk then
      begin
        with frmConnections do
        begin
          if FDM.ConnLogData.Connected then
            FDM.ConnLogData.Connected := false;
          if cbTypeDB.ItemIndex <= 2 then
            curConn := TAvailiableConnection(cbTypeDB.ItemIndex)
          else
            curConn := tacNone;
          if curConn <> tacNone then
          begin
            case curConn of
              tacPostGre: FDM.ConnLogData.DriverName := 'PG';
              tacMSSql: FDM.ConnLogData.DriverName := 'MSSQL';
              tacOracle: FDM.ConnLogData.DriverName := 'Ora';
            end;

            with FDM.ConnLogData.Params do
            begin
              DriverID := FDM.ConnLogData.DriverName;
              Database := edNameDB.Text;
              UserName := edLogin.Text;
              Password := edPassword.Text;
              case curConn of
                tacPostGre:
                  begin
                    TFDPhysPGConnectionDefParams(FDM.ConnLogData.Params).port := StrToInt(edPort.Text);
                    TFDPhysPGConnectionDefParams(FDM.ConnLogData.Params).server := edServer.Text;
                  end;
                tacMSSql:
                  begin
                    TFDPhysMSSQLConnectionDefParams(FDM.ConnLogData.Params).server := edServer.Text;
                  end;
                tacOracle:
                  begin
                    // Oracle использует Database как TNS-имя или Easy Connect string
                  end;
              end;
            end;
            try
              FDM.ConnLogData.Connected := true;
              AMsg := 'Соединение успешно установлено';
              Result := true;
            except
              on E: Exception do
              begin
                AMsg := E.Message;
                Result := false;
              end;
            end;
          end
            else
          begin
            AMsg := 'Неизвестный вид соединения';
            Result := false;
          end;
        end;
      end;
    finally
      FreeAndNil(frmConnections);
    end;
  except
    on E: Exception do
    begin
      Result := false;
      AMsg := E.Message;
    end;
  end;
end;

end.
