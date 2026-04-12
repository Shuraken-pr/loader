object dmConn: TdmConn
  Height = 480
  Width = 640
  object ConnLogData: TFDConnection
    Params.Strings = (
      'DriverID=PG'
      'Password=PGAdmin'
      'Server=localhost'
      'User_Name=postgres'
      'Database=postgres')
    Left = 252
    Top = 100
  end
  object qrLogData: TFDQuery
    Connection = ConnLogData
    Left = 324
    Top = 252
  end
end
