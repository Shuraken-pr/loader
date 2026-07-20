object fAttributeDelete: TfAttributeDelete
  Left = 0
  Top = 0
  Caption = #1059#1076#1072#1083#1077#1085#1080#1077' '#1072#1090#1088#1080#1073#1091#1090#1072
  ClientHeight = 105
  ClientWidth = 356
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lcAttributeDelete: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 356
    Height = 105
    Align = alClient
    TabOrder = 0
    LayoutLookAndFeel = dmSkin.dxLayoutSkinLookAndFeel
    object btnOK: TButton
      Left = 187
      Top = 68
      Width = 75
      Height = 25
      Caption = #1059#1076#1072#1083#1080#1090#1100
      TabOrder = 1
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 269
      Top = 68
      Width = 75
      Height = 25
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
      Width = 332
    end
    object lcAttributeDeleteGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
      ShowBorder = False
      Index = -1
    end
    object lgActions: TdxLayoutGroup
      Parent = lcAttributeDeleteGroup_Root
      AlignHorz = ahClient
      AlignVert = avBottom
      CaptionOptions.Text = 'New Group'
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
      ControlOptions.OriginalWidth = 75
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
      Parent = lcAttributeDeleteGroup_Root
      CaptionOptions.Text = #1042#1099#1073#1077#1088#1080#1090#1077' '#1072#1090#1088#1080#1073#1091#1090' '#1076#1083#1103' '#1091#1076#1072#1083#1077#1085#1080#1103':'
      CaptionOptions.Layout = clTop
      Control = cmbAttributes
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
end
