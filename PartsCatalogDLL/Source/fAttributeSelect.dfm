object fAttributeSelect: TfAttributeSelect
  Left = 0
  Top = 0
  Caption = #1042#1099#1073#1086#1088' '#1072#1090#1088#1080#1073#1091#1090#1072' '#1076#1083#1103' '#1088#1077#1076#1072#1082#1090#1080#1088#1086#1074#1072#1085#1080#1103
  ClientHeight = 104
  ClientWidth = 362
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lcAttributeSelect: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 362
    Height = 104
    Align = alClient
    TabOrder = 0
    LayoutLookAndFeel = dmDB.dxLayoutSkinLookAndFeel1
    DesignSize = (
      362
      104)
    object btnOK: TButton
      Left = 175
      Top = 61
      Width = 93
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #1056#1077#1076#1072#1082#1090#1080#1088#1086#1074#1072#1090#1100
      TabOrder = 1
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 275
      Top = 61
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 2
    end
    object cmbAttributes: TcxComboBox
      Left = 12
      Top = 33
      Properties.DropDownListStyle = lsFixedList
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 0
      Width = 338
    end
    object lcAttributeSelectGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
      ShowBorder = False
      Index = -1
    end
    object lgActions: TdxLayoutGroup
      Parent = lcAttributeSelectGroup_Root
      CaptionOptions.Text = 'New Group'
      ItemIndex = 1
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 1
    end
    object liOk: TdxLayoutItem
      Parent = lgActions
      AlignHorz = ahRight
      AlignVert = avClient
      CaptionOptions.Text = 'New Item'
      CaptionOptions.Visible = False
      Control = btnOK
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 93
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liCancel: TdxLayoutItem
      Parent = lgActions
      AlignHorz = ahRight
      AlignVert = avClient
      CaptionOptions.Text = 'New Item'
      CaptionOptions.Visible = False
      Control = btnCancel
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 75
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liAttributes: TdxLayoutItem
      Parent = lcAttributeSelectGroup_Root
      CaptionOptions.Text = #1042#1099#1073#1077#1088#1080#1090#1077' '#1072#1090#1088#1080#1073#1091#1090' '#1090#1077#1082#1091#1097#1077#1081' '#1082#1072#1090#1077#1075#1086#1088#1080#1080
      CaptionOptions.Layout = clTop
      Control = cmbAttributes
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
end
