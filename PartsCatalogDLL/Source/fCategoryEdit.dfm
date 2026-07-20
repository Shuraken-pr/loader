object frmCategoryEdit: TfrmCategoryEdit
  Left = 0
  Top = 0
  Caption = #1056#1077#1076#1072#1082#1090#1080#1088#1086#1074#1072#1085#1080#1077' '#1082#1072#1090#1077#1075#1086#1088#1080#1081
  ClientHeight = 167
  ClientWidth = 343
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object lcCategoryEdit: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 343
    Height = 167
    Align = alClient
    TabOrder = 0
    LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel
    object btnOk: TcxButton
      Left = 174
      Top = 130
      Width = 75
      Height = 25
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      ModalResult = 1
      TabOrder = 2
      OnClick = btnOkClick
    end
    object btnCancel: TcxButton
      Left = 256
      Top = 130
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
      Width = 212
    end
    object cmbParent: TcxComboBox
      Left = 110
      Top = 74
      Properties.DropDownListStyle = lsFixedList
      Properties.ImmediatePost = True
      Properties.ImmediateUpdateText = True
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 1
      Width = 212
    end
    object lcCategoryEditGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
      ShowBorder = False
      Index = -1
    end
    object lgModalResul: TdxLayoutGroup
      Parent = lcCategoryEditGroup_Root
      AlignHorz = ahClient
      AlignVert = avBottom
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 1
    end
    object lgCategoryEdit: TdxLayoutGroup
      Parent = lcCategoryEditGroup_Root
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
    object liParent: TdxLayoutItem
      Parent = lgCategoryEdit
      CaptionOptions.Text = #1056#1086#1076#1080#1090#1077#1083#1100#1089#1082#1072#1103#13#10#1082#1072#1090#1077#1075#1086#1088#1080#1103
      CaptionOptions.WordWrap = True
      Control = cmbParent
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 1
    end
  end
end
