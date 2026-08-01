unit dmFastReport;

interface

uses
  System.SysUtils, System.Variants, System.Generics.Collections, System.Classes, fs_iFDRTTI, fs_igraphicsrtti,
  fs_iclassesrtti, fs_ipascal, fs_iinterpreter, frxExportRTF, frxExportPDF,
  frxExportXLSX, frxExportDOCX, frxExportMail, frxExportXLS, frxExportImage,
  frxClass, frxExportBaseDialog, frxDesgn, frCoreClasses;

type
  TdmFR = class(TDataModule)
    report: TfrxReport;
    designer: TfrxDesigner;
    BMPExport: TfrxBMPExport;
    JPEGExport: TfrxJPEGExport;
    XLSExport: TfrxXLSExport;
    MailExport: TfrxMailExport;
    DOCXExport: TfrxDOCXExport;
    XLSXExport: TfrxXLSXExport;
    PDFExport: TfrxPDFExport;
    RTFExport: TfrxRTFExport;
    fsScript: TfsScript;
    fsPascal: TfsPascal;
    fsClassesRTTI: TfsClassesRTTI;
    fsGraphicsRTTI: TfsGraphicsRTTI;
    fsFDRTTI: TfsFDRTTI;
  private
    FCustomFunc: TFunc<WideString, WideString, variant>;
    { Private declarations }
  public
    { Public declarations }
    property CustomFunc: TFunc<WideString, WideString, variant> read FCustomFunc write FCustomFunc;
  end;

var
  dmFR: TdmFR;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

end.
