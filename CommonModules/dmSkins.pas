unit dmSkins;

interface

uses
  System.SysUtils, System.Classes, dxCore, cxClasses, dxLayoutLookAndFeels,
  cxLookAndFeels, dxSkinsForm, dxSkinsCore, dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle, dxSkinOffice2007Blue, dxSkinOffice2010Silver,
  dxSkinOffice2013LightGray, dxSkinVS2010;

type
  TdmSkin = class(TDataModule)
    dxSkinController: TdxSkinController;
    dxLayoutLookAndFeelList: TdxLayoutLookAndFeelList;
    dxLayoutSkinLookAndFeel: TdxLayoutSkinLookAndFeel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dmSkin: TdmSkin;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

end.
