object dmDB: TdmDB
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 480
  Width = 640
  object PGConn: TFDConnection
    Params.Strings = (
      'Server=localhost'
      'Database=postgres'
      'User_Name=postgres'
      'DriverID=PG'
      'Port=5432'
      'MonitorBy=Custom')
    FetchOptions.AssignedValues = [evItems]
    FetchOptions.Items = [fiBlobs, fiDetails]
    UpdateOptions.AssignedValues = [uvEDelete, uvEInsert, uvEUpdate]
    UpdateOptions.EnableDelete = False
    UpdateOptions.EnableInsert = False
    UpdateOptions.EnableUpdate = False
    TxOptions.AutoStop = False
    LoginDialog = LDPg
    Left = 48
    Top = 12
  end
  object PGTrans: TFDTransaction
    Options.AutoStop = False
    Connection = PGConn
    Left = 152
    Top = 8
  end
  object qryGetCategory: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT id '
      '  FROM categories '
      ' WHERE name = :name '
      '    AND (parent_id = :parent_id '
      '             OR (parent_id IS NULL AND :parent_id IS NULL)'
      '            )')
    Left = 48
    Top = 68
    ParamData = <
      item
        Name = 'NAME'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'PARENT_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end>
  end
  object qryInsertCategory: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'INSERT INTO categories (name, parent_id) '
      ' VALUES (:name, :parent_id) RETURNING id')
    Left = 152
    Top = 68
    ParamData = <
      item
        Name = 'NAME'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
      end
      item
        Name = 'PARENT_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end>
  end
  object qryGetAttribute: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  id, '
      '  attr_type::text as attr_type '
      '  FROM attribute_defs '
      ' WHERE category_id = :category_id '
      '   AND name = :name')
    Left = 44
    Top = 136
    ParamData = <
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = 0
      end
      item
        Name = 'NAME'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryInsertAttribute: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'INSERT INTO attribute_defs (category_id, name, attr_type) '
      'VALUES (:category_id, :name, :attr_type::attr_type) '
      'RETURNING id')
    Left = 152
    Top = 136
    ParamData = <
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end
      item
        Name = 'NAME'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
      end
      item
        Name = 'ATTR_TYPE'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
      end>
  end
  object qryGetPart: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  id, '
      '  category_id '
      '  FROM parts '
      ' WHERE code = :code')
    Left = 44
    Top = 220
    ParamData = <
      item
        Name = 'CODE'
        DataType = ftString
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryUpsertPart: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'INSERT INTO parts (code, category_id) '
      'VALUES (:code, :category_id) '
      '  ON CONFLICT (code) DO '
      '  UPDATE SET category_id = :category_id '
      'RETURNING id')
    Left = 152
    Top = 220
    ParamData = <
      item
        Name = 'CODE'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end>
  end
  object qryUpsertValue: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      
        'INSERT INTO part_values (part_id, attribute_id, value_string, va' +
        'lue_number, value_date, value_bool)'
      
        'VALUES (:part_id, :attribute_id, :value_string, :value_number, :' +
        'value_date, :value_bool)'
      'ON CONFLICT (part_id, attribute_id) DO '
      'UPDATE SET'
      '  value_string = EXCLUDED.value_string,'
      '  value_number = EXCLUDED.value_number,'
      '  value_date = EXCLUDED.value_date,'
      '  value_bool = EXCLUDED.value_bool')
    Left = 44
    Top = 288
    ParamData = <
      item
        Name = 'PART_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end
      item
        Name = 'ATTRIBUTE_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end
      item
        Name = 'VALUE_STRING'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
      end
      item
        Name = 'VALUE_NUMBER'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end
      item
        Name = 'VALUE_DATE'
        DataType = ftDate
        FDDataType = dtDateTime
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'VALUE_BOOL'
        DataType = ftBoolean
        FDDataType = dtBoolean
        ParamType = ptInput
      end>
  end
  object LDPg: TFDGUIxLoginDialog
    Provider = 'Forms'
    Caption = 'PostGre'
    VisibleItems.Strings = (
      'Server'
      'Database'
      'Port'
      'User_Name'
      'Password')
    Left = 260
    Top = 8
  end
  object qryCategories: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  c.id, '
      '  c.parent_id, '
      '  c.name,'
      '  COALESCE(child_counts.child_count, 0) AS child_count'
      'FROM categories c'
      'LEFT JOIN ('
      '  SELECT parent_id, COUNT(*) AS child_count'
      '  FROM categories'
      '  GROUP BY parent_id'
      ') child_counts ON child_counts.parent_id = c.id'
      'ORDER BY '
      '  c.parent_id NULLS FIRST, '
      '  c.name;')
    Left = 44
    Top = 376
  end
  object qryAttributes: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  id, '
      '  name, '
      '  attr_type::text as attr_type '
      '  FROM attribute_defs '
      ' WHERE category_id = :category_id '
      ' ORDER BY id')
    Left = 136
    Top = 376
    ParamData = <
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryParts: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '    p.id AS part_id,'
      '    p.code,'
      '    a.name AS attr_name,'
      '    pv.value_string,'
      '    pv.value_number,'
      '    pv.value_date,'
      '    pv.value_bool'
      '  FROM parts p'
      '  JOIN attribute_defs a ON a.category_id = p.category_id'
      
        '  LEFT JOIN part_values pv ON pv.part_id = p.id AND pv.attribute' +
        '_id = a.id'
      ' WHERE p.category_id = :category_id'
      '  AND ('
      '    :search_term = '#39#39' OR'
      '    pv.value_string ILIKE '#39'%'#39' || :search_term || '#39'%'#39' OR'
      
        '    CAST(pv.value_number AS TEXT) ILIKE '#39'%'#39' || :search_term || '#39 +
        '%'#39' OR'
      
        '    CAST(pv.value_date AS TEXT) ILIKE '#39'%'#39' || :search_term || '#39'%'#39 +
        ' OR'
      '    CAST(pv.value_bool AS TEXT) ILIKE '#39'%'#39' || :search_term || '#39'%'#39
      '  )'
      ' ORDER BY p.code, a.id')
    Left = 232
    Top = 376
    ParamData = <
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'SEARCH_TERM'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
      end>
  end
  object qryGetCategoryName: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  name '
      '  FROM categories '
      'WHERE id = :id')
    Left = 356
    Top = 8
    ParamData = <
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
      end>
  end
  object qryExportParts: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  p.code, '
      '  a.name AS attr_name, '
      '  pv.value_string, '
      '  pv.value_number, '
      '  pv.value_date, '
      '  pv.value_bool'
      '  FROM parts p'
      '  JOIN attribute_defs a ON a.category_id = p.category_id'
      
        '  LEFT JOIN part_values pv ON pv.part_id = p.id AND pv.attribute' +
        '_id = a.id'
      '  WHERE p.category_id = :category_id'
      '  ORDER BY p.code, a.id')
    Left = 356
    Top = 72
    ParamData = <
      item
        Name = 'CATEGORY_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryChildCategories: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  count(*) as cnt'
      '  FROM categories '
      '  WHERE parent_id = :parent_id '
      '')
    Left = 356
    Top = 140
    ParamData = <
      item
        Name = 'PARENT_ID'
        ParamType = ptInput
      end>
  end
  object qryRootCategories: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'SELECT '
      '  id '
      '  FROM categories '
      ' WHERE parent_id IS NULL '
      ' ORDER BY name')
    Left = 356
    Top = 220
  end
  object qryUpdateCategory: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'UPDATE categories'
      'SET '
      '    name = :name,'
      '    parent_id = :parent_id'
      'WHERE '
      '    id = :id')
    Left = 356
    Top = 284
    ParamData = <
      item
        Name = 'NAME'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'PARENT_ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryUpdateAttribute: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'UPDATE attribute_defs'
      'SET '
      '    name = :name,'
      '    attr_type = :attr_type::attr_type'
      'WHERE '
      '    id = :id')
    Left = 356
    Top = 352
    ParamData = <
      item
        Name = 'NAME'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ATTR_TYPE'
        DataType = ftString
        FDDataType = dtWideString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryDeleteAttribute: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'DELETE FROM attribute_defs'
      'WHERE '
      '    id = :id')
    Left = 356
    Top = 416
    ParamData = <
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryDeletePart: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'DELETE FROM parts'
      'WHERE '
      '    id = :id')
    Left = 460
    Top = 416
    ParamData = <
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryDeleteCategory: TFDQuery
    Connection = PGConn
    SQL.Strings = (
      'DELETE FROM categories'
      'WHERE '
      '    id = :id')
    Left = 568
    Top = 416
    ParamData = <
      item
        Name = 'ID'
        DataType = ftInteger
        FDDataType = dtInt32
        ParamType = ptInput
        Value = Null
      end>
  end
  object dxSkinController: TdxSkinController
    NativeStyle = False
    SkinName = 'DevExpressStyle'
    Left = 476
    Top = 124
  end
  object dxLayoutLookAndFeelList1: TdxLayoutLookAndFeelList
    Left = 480
    Top = 212
    object dxLayoutSkinLookAndFeel1: TdxLayoutSkinLookAndFeel
      GroupOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      GroupOptions.CaptionOptions.Font.Color = clWindowText
      GroupOptions.CaptionOptions.Font.Height = -12
      GroupOptions.CaptionOptions.Font.Name = 'Segoe UI'
      GroupOptions.CaptionOptions.Font.Style = []
      GroupOptions.CaptionOptions.UseDefaultFont = False
      ItemOptions.CaptionOptions.Font.Charset = DEFAULT_CHARSET
      ItemOptions.CaptionOptions.Font.Color = clWindowText
      ItemOptions.CaptionOptions.Font.Height = -12
      ItemOptions.CaptionOptions.Font.Name = 'Segoe UI'
      ItemOptions.CaptionOptions.Font.Style = []
      ItemOptions.CaptionOptions.UseDefaultFont = False
      LookAndFeel.Kind = lfUltraFlat
      LookAndFeel.NativeStyle = False
      PixelsPerInch = 96
    end
  end
end
