-- 002_seed.sql
INSERT INTO users (username)
SELECT 'user_' || i FROM generate_series(1, 1000) i;

INSERT INTO events (user_id, event_type, occurred_at, metadata)
SELECT 
    (random() * 999 + 1)::BIGINT,
    unnest(ARRAY['click', 'purchase', 'login', 'error', 'view']),
    NOW() - (random() * interval '30 days'),
    jsonb_build_object(
        'source', unnest(ARRAY['web', 'mobile', 'api']),
        'ip', '192.168.' || (random()*255)::int || '.' || (random()*255)::int,
        'description', md5(random()::text),
        'metrics', jsonb_build_object('latency_ms', (random()*500)::int, 'status', 200 + (random()*50)::int)
    )
FROM generate_series(1, 500000);
