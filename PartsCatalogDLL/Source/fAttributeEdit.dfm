object frmAttributeEdit: TfrmAttributeEdit
  Left = 0
  Top = 0
  Caption = #1056#1077#1076#1072#1082#1090#1080#1088#1086#1074#1072#1085#1080#1077' '#1072#1090#1088#1080#1073#1091#1090#1086#1074
  ClientHeight = 159
  ClientWidth = 377
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object lcAttributeEdit: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 377
    Height = 159
    Align = alClient
    TabOrder = 0
    LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel
    object btnOk: TcxButton
      Left = 208
      Top = 122
      Width = 75
      Height = 25
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      ModalResult = 1
      TabOrder = 2
      OnClick = btnOkClick
    end
    object btnCancel: TcxButton
      Left = 290
      Top = 122
      Width = 75
      Height = 25
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 3
    end
    object edName: TcxTextEdit
      Left = 110
      Top = 46
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 0
      Width = 246
    end
    object cmbType: TcxComboBox
      Left = 110
      Top = 74
      Properties.DropDownListStyle = lsFixedList
      Properties.ImmediatePost = True
      Properties.ImmediateUpdateText = True
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 1
      Width = 246
    end
    object lcAttributeEditGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
      ShowBorder = False
      Index = -1
    end
    object lgModalResul: TdxLayoutGroup
      Parent = lcAttributeEditGroup_Root
      AlignHorz = ahClient
      AlignVert = avBottom
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 1
    end
    object lgCategoryEdit: TdxLayoutGroup
      Parent = lcAttributeEditGroup_Root
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = #1055#1072#1088#1072#1084#1077#1090#1088#1099' '#1088#1077#1076#1072#1082#1090#1080#1088#1086#1074#1072#1085#1080#1103
      Index = 0
    end
    object liOk: TdxLayoutItem
      Parent = lgModalResul
      AlignHorz = ahRight
      AlignVert = avClient
      CaptionOptions.Text = 'cxButton1'
      CaptionOptions.Visible = False
      Control = btnOk
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 75
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liCancel: TdxLayoutItem
      Parent = lgModalResul
      AlignHorz = ahRight
      AlignVert = avClient
      CaptionOptions.Visible = False
      Control = btnCancel
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 75
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liCategoryName: TdxLayoutItem
      Parent = lgCategoryEdit
      CaptionOptions.Text = #1053#1072#1080#1084#1077#1085#1086#1074#1072#1085#1080#1077
      Control = edName
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liType: TdxLayoutItem
      Parent = lgCategoryEdit
      CaptionOptions.Text = #1058#1080#1087' '#1072#1090#1088#1080#1073#1091#1090#1072
      CaptionOptions.WordWrap = True
      Control = cmbType
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 1
    end
  end
end
