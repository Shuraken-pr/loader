SELECT
  t.owner                                 AS table_schema,
  t.table_name,
  c.column_name,
  c.data_type as col_type,
  -- формат размерности: VARCHAR2/CHAR -> (char_length) или (data_length);
  -- NUMBER -> (precision) или (precision,scale)
  CASE
    WHEN upper(c.data_type) IN ('VARCHAR2','CHAR','NCHAR','NVARCHAR2') THEN
      '(' ||
      NVL(TO_CHAR(c.char_length), TO_CHAR(c.data_length)) ||
      CASE WHEN c.char_used = 'C' THEN ' CHAR' ELSE '' END ||
      ')'
    WHEN upper(c.data_type) = 'NUMBER' THEN
      CASE
        WHEN c.data_precision IS NULL AND c.data_scale IS NULL THEN ''
        WHEN c.data_precision IS NOT NULL AND c.data_scale IS NULL THEN '(' || TO_CHAR(c.data_precision) || ')'
        ELSE '(' || TO_CHAR(c.data_precision) || ',' || TO_CHAR(c.data_scale) || ')'
      END
    WHEN upper(c.data_type) IN ('RAW','LONG','LONG RAW','BLOB') THEN
      '(' || TO_CHAR(c.data_length) || ')'
    ELSE
      NULL
  END AS col_length,
  CASE WHEN tl.table_name IS NOT NULL THEN 1 ELSE 0 END AS have_log,
  CASE WHEN EXISTS (
    SELECT 1
    FROM all_triggers trg
    WHERE trg.owner = t.owner
      AND trg.table_name = t.table_name
      AND trg.trigger_name = 'TRG_' || t.table_name || '_FILL_LOG'
  ) THEN 1 ELSE 0 END                            AS have_trg
FROM all_tables t
JOIN all_tab_columns c
  ON c.owner = t.owner
 AND c.table_name = t.table_name
LEFT JOIN all_tables tl
  ON tl.owner = t.owner
 AND tl.table_name = t.table_name || '_LOG'
LEFT JOIN all_tab_columns log_c
  ON log_c.owner = tl.owner
 AND log_c.table_name = tl.table_name
 AND log_c.column_name = c.column_name
WHERE
  t.owner NOT IN ('SYS','SYSTEM')
  AND (tl.table_name IS NULL OR log_c.column_name IS NOT NULL)
  -- исключаем бинарные типы (при необходимости скорректируйте список)
  AND upper(c.data_type) NOT IN ('BLOB','RAW','LONG RAW')
  -- исключаем сами лог-таблицы
  AND ( LENGTH(t.table_name) < 4 OR SUBSTR(t.table_name, LENGTH(t.table_name)-3, 4) <> '_LOG' )
ORDER BY
  t.table_name,
  c.column_id;