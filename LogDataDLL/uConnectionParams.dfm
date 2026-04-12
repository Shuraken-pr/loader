object frmConnections: TfrmConnections
  Left = 0
  Top = 0
  Caption = #1055#1072#1088#1072#1084#1077#1090#1088#1099' '#1089#1086#1077#1076#1080#1085#1077#1085#1080#1103
  ClientHeight = 267
  ClientWidth = 342
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Icon.Data = {
    0000010001001010000001000800680500001600000028000000100000002000
    0000010008000000000000000000000000000000000000000000000000000C0C
    0C00330000000033000033330000000033003300330000333300323232006600
    0000663300006600330066333300006600003366000000663300336633006666
    00006666330076643E0000006600330066000D29700036356F00660066006633
    66000066660033666600505050007C6A4600746658006C6C6C008C0000009933
    00009900330099333300CC000000FF000000CC330000FF330000CC003300FF00
    3300CC333300FF3333009966000099663300CC660000FF660000CC663300FF66
    33009900660099336600CC006600FF006600CC336600FF33660083714D008876
    5400907E5E0099666600CC666600FF666600008C000033990000009933003399
    3300669900006699330000CC000033CC000000FF000033FF000000CC330033CC
    330000FF330033FF330066CC000066FF000066CC330066FF3300009966003399
    66006699660000CC660033CC660000FF660033FF660066CC660066FF66008C8C
    000099993300CC990000FF990000CC993300FF99330099CC000099FF000099CC
    330099FF3300CCCC0000FFCC0000CCFF0000FFFF0000CCCC3300FFCC3300CCFF
    3300FFFF330092805F009987680099996600A5947800CC996600FF99660099CC
    660099FF6600CCCC6600FFCC6600CCFF6600FFFF660000008C00330099001425
    95002E309B001B23AF002C30B10066009900663399001F408F00224598000066
    9900336699002B51AC00326FAB004D4F980066669900567ABB000000CC003300
    CC001229CB003333CC000000FF003300FF000033FF003333FF006600CC006633
    CC006600FF006633FF001B5DC0001971CF003366CC000066FF003366FF006666
    CC006666FF008C008C0099339900CC009900FF009900CC339900FF3399009966
    9900CC669900FF6699009900CC009933CC009900FF009933FF00CC00CC00FF00
    CC00CC33CC00FF33CC00CC00FF00FF00FF00CC33FF00FF33FF009966CC009966
    FF00CC66CC00FF66CC00CC66FF00FF66FF00008C8C0033999900669999006989
    B50000CC990033CC990000FF990033FF990066CC990066FF99001587D900298E
    D3001790E9002589E7002093E6003397ED003399FF0033A3E9003BA2F0005897
    DC006699CC006699FF0044B3F00000CCCC0033CCCC0000FFCC0033FFCC0000CC
    FF0033CCFF0000FFFF0033FFFF0066CCCC0066FFCC0052CFF80066CCFF0066FF
    FF008F8D8A00A89B8600B4A38900ACA29300B6AB9A00BEB19F008C8CBA00B4B0
    AA00CC999900FF999900C0B39E00C4BAAD0099CC990099FF9900CCCC9900FFCC
    9900CCFF9900FFFF9900CEC6BB009999CC009EB8D4009999FF00CC99CC00FF99
    CC00CC99FF00FF99FF0099CCCC0099FFCC0099CCFF0099FFFF00D3CFC900FFCC
    CC00CCFFCC00FFFFCC00CCCCFF00FFCCFF00CCFFFF00E6E6E600FEFEFE000000
    0000000000DEE0DDDDDCDA0000000000000000E4E4E4EBF7EBEBDDDA00000000
    F7F7F7F7F7F7F7EDC886E0E3DADAEBF7F7F7F7F7DF84B8C2C29393E0E3DAF7F7
    F7DE6D827A787EC4C49393E0E3DDF7F76A6A1C797A787FC7C79493B8000000DD
    6B6B1C797A7A82CBCB9494940000006B6B6B377B897A82CBCBC294940000006D
    6D6D387B897A82D6D6C2BFBF0000006D6D6D397B7A7882D6D6C1C1BF000000DA
    DADA6A1D161583D6D6C3C1C2000000DBDBDB6A381D00CBCBC694BFBF000000DB
    DBDB6B383800C6C3BF949394000000DBDBDB6B383800000000000000000000DA
    DB6D393837000000000000000000006D39381C121C000000000000000000FE07
    0000F8030000C000000000000000000000000003000080030000800300008003
    00008003000080030000810300008103000081FF000081FF000081FF0000}
  TextHeight = 15
  object lcConnectionParams: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 342
    Height = 267
    Align = alClient
    TabOrder = 0
    object cbTypeDB: TcxComboBox
      Left = 87
      Top = 12
      Properties.DropDownListStyle = lsFixedList
      Properties.ImmediatePost = True
      Properties.Items.Strings = (
        'Postgre'
        'MS SQL'
        'Oracle')
      Properties.OnChange = cbTypeDBPropertiesChange
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      Style.ButtonStyle = bts3D
      Style.PopupBorderStyle = epbsFrame3D
      TabOrder = 0
      Text = 'Postgre'
      Width = 243
    end
    object edNameDB: TcxTextEdit
      Left = 87
      Top = 42
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 1
      Text = 'postgres'
      Width = 243
    end
    object edServer: TcxTextEdit
      Left = 87
      Top = 72
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 2
      Text = 'localhost'
      Width = 243
    end
    object edPort: TcxTextEdit
      Left = 87
      Top = 102
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 3
      Text = '5432'
      Width = 243
    end
    object edLogin: TcxTextEdit
      Left = 87
      Top = 132
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 4
      Text = 'postgres'
      Width = 243
    end
    object edPassword: TcxTextEdit
      Left = 87
      Top = 162
      Properties.EchoMode = eemPassword
      Style.BorderColor = clWindowFrame
      Style.BorderStyle = ebs3D
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 5
      Text = 'PGAdmin'
      Width = 243
    end
    object btnOk: TcxButton
      Left = 12
      Top = 192
      Width = 318
      Height = 25
      Caption = #1059#1089#1090#1072#1085#1086#1074#1080#1090#1100' '#1089#1086#1077#1076#1080#1085#1077#1085#1080#1077
      ModalResult = 1
      TabOrder = 6
    end
    object lcConnectionParamsGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ShowBorder = False
      Index = -1
    end
    object liTypeBD: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1058#1080#1087' '#1041#1044
      Control = cbTypeDB
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liNameDB: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1041#1072#1079#1072' '#1044#1072#1085#1085#1099#1093
      Control = edNameDB
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liServer: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1057#1077#1088#1074#1077#1088
      Control = edServer
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 2
    end
    object liPort: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1055#1086#1088#1090
      Control = edPort
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 3
    end
    object liLogin: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1051#1086#1075#1080#1085
      Control = edLogin
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 4
    end
    object liPassword: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = #1055#1072#1088#1086#1083#1100
      Control = edPassword
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 5
    end
    object liOk: TdxLayoutItem
      Parent = lcConnectionParamsGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = 'cxButton1'
      CaptionOptions.Visible = False
      Control = btnOk
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 75
      ControlOptions.ShowBorder = False
      Index = 6
    end
  end
end
