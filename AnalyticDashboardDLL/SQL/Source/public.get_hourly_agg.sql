-- DROP FUNCTION public.get_hourly_agg();
CREATE OR REPLACE FUNCTION public.get_hourly_agg(
  start_ts timestamp,
  end_ts timestamp,
  source_filter varchar
  )
RETURNS TABLE (
  hour timestamp,
  source text,
  event_count bigint,
  avg_latency numeric,
  latency_trend numeric,
  growth_pct numeric,
  all_events bigint
)
LANGUAGE plpgsql
AS $function$
declare
  sf varchar(100);
BEGIN
  sf := nullif(source_filter, '');
  RETURN QUERY
  with hourly_agg as 
  (select 
     date_trunc('hour', e.occurred_at)::timestamp as h_hour,
     e.metadata ->> 'source' as h_source,
     count(*) as h_event_count,
     avg((e.metadata ->'metrics'->>'latency_ms')::numeric) as h_avg_latency
     from public.events e 
    where e.occurred_at between start_ts and end_ts
      and (sf is null or e.metadata ->> 'source' = source_filter)
    group by 1, 2
  )
  select 
    h_hour as hour, 
    h_source as source,
    h_event_count as event_count,
    h_avg_latency as avg_latency,
    avg(h_avg_latency) over 
       (partition by source 
        order by hour
        rows between 2 preceding and current row
       ) as latency_trend,
    round(100.0*(h_event_count - lag(h_event_count) over (partition by h_source order by h_hour))/
                 nullif(lag(h_event_count) over (partition by h_source order by h_hour), 0), 1
         ) as growth_pct,
    sum(h_event_count) over (partition by h_source)::bigint as all_events
     from hourly_agg
    order by h_hour desc, h_source;
END;
$function$;

