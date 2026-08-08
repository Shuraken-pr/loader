create or replace function public.get_events(
  p_start_ts   timestamp,
  p_end_ts     timestamp,
  p_limit      int DEFAULT 1000,
  p_offset     int DEFAULT 0
)
returns table
(
  id bigint,
  username text,
  event_type text,
  occurred_at timestamp,
  ip text,
  source text,
  status text,
  latency_ms text
)
LANGUAGE plpgsql
AS $function$
begin
  return Query
  select
    e.id,
    u.username,
    e.event_type,
    e.occurred_at::timestamp as occurred_at,
    e.metadata ->> 'ip',
    coalesce(e.metadata ->> 'source', e.event_type) as source,
    e.metadata ->'metrics'->> 'status',
    e.metadata ->'metrics'->> 'latency_ms'
    from events e
    join users u on e.user_id = u.id
   WHERE (p_start_ts IS NULL OR e.occurred_at >= p_start_ts)
     AND (p_end_ts   IS NULL OR e.occurred_at < p_end_ts + INTERVAL '1 day')
   order by e.id
   LIMIT p_limit OFFSET p_offset;
end;
$function$;
