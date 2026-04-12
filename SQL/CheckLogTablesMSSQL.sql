select
  log_data.schema_name,
  log_data.table_name,
  log_data.column_name,
  log_data.col_type,
  log_data.col_length,
  log_data.have_log,
  log_data.have_trg
  from
(SELECT 
  SCHEMA_NAME(t.schema_id) as schema_name,
  t.object_id,
  t.name AS table_name,
  c.name AS column_name,
  CASE WHEN EXISTS (SELECT 1 FROM sys.tables WHERE name = t.name + '_log') 
       THEN 1 
       ELSE 0 
  END AS have_log,
  CASE WHEN EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_' + t.name + '_fill_log') 
       THEN 1 
       ELSE 0 
  END AS have_trg,
  c.column_id,
  st.name as col_type,
  case when st.name like '%char' then 
       case when c.max_length < 0 then '100' 
	        when c.max_length > 4000 then 'max' 
			else cast(c.max_length as varchar) 
	   end 
	   else '' 
  end as col_length
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
join sys.types st on st.system_type_id = c.system_type_id
WHERE t.is_ms_shipped = 0 -- Исключаем системные таблицы
  AND t.name NOT LIKE '#%' -- Исключаем временные таблицы
  AND t.name NOT LIKE '%tmp%' -- Исключаем таблицы с 'tmp' в названии
  and t.name not like '%_log'
  AND c.system_type_id NOT IN (
	select system_type_id
      from sys.types st
     where st.name in ('image', 'text', 'binary', 'varbinary', 'ntext'))
  AND EXISTS ( -- Проверяем наличие поля id
    SELECT 1 
      FROM sys.columns c2 
     WHERE c2.object_id = t.object_id 
       AND c2.name = 'id'
    )
--ORDER BY SCHEMA_NAME(t.schema_id), t.name, c.column_id
)log_data
order by log_data.schema_name, log_data.table_name, log_data.column_id


