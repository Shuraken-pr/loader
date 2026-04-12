SELECT
  t.table_schema,
  t.table_name,
  cols.column_name,
  cols.udt_name as col_type,
  null as col_length,
  (tl.table_name IS NOT NULL) AS have_log,
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM information_schema.triggers trg
      WHERE trg.trigger_schema = t.table_schema
        AND trg.event_object_table = t.table_name
        AND trg.trigger_name = 'trg_' || t.table_name || '_fill_log'
    ) THEN TRUE
    ELSE FALSE
  END AS have_trg
FROM information_schema.tables AS t
JOIN information_schema.columns AS cols
  ON cols.table_schema = t.table_schema
 AND cols.table_name = t.table_name
LEFT JOIN information_schema.tables AS tl
  ON tl.table_schema = t.table_schema
 AND tl.table_name = t.table_name || '_log'
LEFT JOIN information_schema.columns AS log_cols
  ON log_cols.table_schema = tl.table_schema
 AND log_cols.table_name = tl.table_name
 AND log_cols.column_name = cols.column_name
WHERE
  t.table_schema NOT IN ('information_schema', 'pg_catalog', 'pgagent')
  AND t.table_type = 'BASE TABLE'
  -- если лог-таблица есть, выводим только совпадающие колонки
  AND (tl.table_name IS NULL OR log_cols.column_name IS NOT NULL)
  and cols.data_type not in ('bytea')
  and RIGHT(t.table_name, 4) <> '_log'
ORDER BY
  t.table_name,
  cols.ordinal_position;