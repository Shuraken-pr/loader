-- 002_test_notify_insert.sql
-- Вставка тестового события для проверки real-time

INSERT INTO events (user_id, event_type, metadata)
VALUES (
  (SELECT id FROM users ORDER BY random() LIMIT 1),
  'realtime_test',
  jsonb_build_object(
    'source', 'manual_test',
    'ip', '127.0.0.1',
    'description', 'Проверка LISTEN/NOTIFY в дашборде',
    'test_timestamp', NOW(),
    'metrics', jsonb_build_object('latency_ms', 42, 'status', 200)
  )
)
RETURNING id, user_id, occurred_at, metadata;
