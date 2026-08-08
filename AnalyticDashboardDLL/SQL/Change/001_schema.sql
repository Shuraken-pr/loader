-- 001_schema.sql
CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', COALESCE(event_type, '') || ' ' || COALESCE(metadata->>'description', ''))
    ) STORED
);

CREATE INDEX idx_events_user_time ON events (user_id, occurred_at DESC);
CREATE INDEX idx_events_type ON events (event_type);
CREATE INDEX idx_events_metadata ON events USING GIN (metadata);
CREATE INDEX idx_events_fts ON events USING GIN (search_vector);
CREATE INDEX idx_events_time_source ON events (occurred_at, (metadata->>'source'));
