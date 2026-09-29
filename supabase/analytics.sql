-- Run this in the Supabase SQL editor. The game only inserts through the RPC.
-- anon cannot read, update, or delete these rows.

create table if not exists public.analytics_events (
	id bigint generated always as identity primary key,
	received_at timestamptz not null default now(),
	kind text not null check (kind in ('run', 'error')),
	run_id uuid not null,
	player_id text not null,
	build text not null,
	payload jsonb not null
);

create index if not exists analytics_events_kind_received_idx
	on public.analytics_events (kind, received_at desc);

create index if not exists analytics_events_run_id_idx
	on public.analytics_events (run_id, received_at desc);

alter table public.analytics_events enable row level security;

revoke all on table public.analytics_events from public, anon, authenticated;

create or replace function public.record_analytics_event(
	p_kind text,
	p_run_id uuid,
	p_player_id text,
	p_build text,
	p_payload jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
	if p_kind is null or p_kind not in ('run', 'error') then
		raise exception 'bad kind';
	end if;
	if p_run_id is null
		or p_player_id is null
		or length(btrim(p_player_id)) = 0
		or length(p_player_id) > 128 then
		raise exception 'bad identity';
	end if;
	if p_build is null or length(btrim(p_build)) = 0 or length(p_build) > 32 then
		raise exception 'bad build';
	end if;
	if p_payload is null or octet_length(p_payload::text) > 16000 then
		raise exception 'payload too large';
	end if;
	insert into public.analytics_events (kind, run_id, player_id, build, payload)
	values (p_kind, p_run_id, p_player_id, p_build, p_payload);
end;
$$;

revoke all on function public.record_analytics_event(text, uuid, text, text, jsonb) from public;
grant execute on function public.record_analytics_event(text, uuid, text, text, jsonb) to anon, authenticated;

-- Balance queries use the latest snapshot for each run_id.
-- Set the build and mode filters before reading the results.
-- map_size: 0 small, 1 medium, 2 large.
-- rules / counts are jsonb objects of id -> number.

-- with latest as (
-- 	select distinct on (run_id)
-- 		run_id,
-- 		build,
-- 		payload,
-- 		received_at
-- 	from public.analytics_events
-- 	where kind = 'run'
-- 		and build = '0.1.0'
-- 		and payload->>'mode' = 'endless'
-- 	order by run_id, received_at desc
-- )
-- select * from latest;

-- Animals: bought divided by offered is the pick rate.
-- with latest as (
-- 	select distinct on (run_id) payload
-- 	from public.analytics_events
-- 	where kind = 'run' and build = '0.1.0' and payload->>'mode' = 'endless'
-- 	order by run_id, received_at desc
-- ),
-- offered as (
-- 	select key as animal_id, sum(value::int) as offered
-- 	from latest, jsonb_each_text(payload->'animals_offered')
-- 	group by key
-- ),
-- bought as (
-- 	select key as animal_id, sum(value::int) as bought
-- 	from latest, jsonb_each_text(payload->'animals_bought')
-- 	group by key
-- ),
-- placed as (
-- 	select key as animal_id, sum(value::int) as placed
-- 	from latest, jsonb_each_text(payload->'animals_placed')
-- 	group by key
-- )
-- select
-- 	coalesce(o.animal_id, b.animal_id, p.animal_id) as animal_id,
-- 	coalesce(o.offered, 0) as offered,
-- 	coalesce(b.bought, 0) as bought,
-- 	coalesce(p.placed, 0) as placed
-- from offered o
-- full join bought b using (animal_id)
-- full join placed p using (animal_id)
-- order by animal_id;

-- Animals linked to high scores. Lift above 1 means the animal shows up in the top 10%
-- more often than in all runs of that mode.
-- with latest as (
-- 	select distinct on (run_id)
-- 		payload,
-- 		(payload->>'score_total')::int as score_total
-- 	from public.analytics_events
-- 	where kind = 'run' and build = '0.1.0' and payload->>'mode' = 'endless'
-- 	order by run_id, received_at desc
-- ),
-- ranked as (
-- 	select *, percent_rank() over (order by score_total desc) as pct
-- 	from latest
-- ),
-- base as (
-- 	select key as animal_id, count(*) as runs
-- 	from ranked, jsonb_each_text(payload->'animals_placed')
-- 	where value::int > 0
-- 	group by key
-- ),
-- top as (
-- 	select key as animal_id, count(*) as runs
-- 	from ranked, jsonb_each_text(payload->'animals_placed')
-- 	where pct <= 0.10 and value::int > 0
-- 	group by key
-- )
-- select
-- 	b.animal_id,
-- 	b.runs as runs_with_animal,
-- 	coalesce(t.runs, 0) as top_runs_with_animal,
-- 	(coalesce(t.runs, 0)::float / nullif((select count(*) from ranked where pct <= 0.10), 0))
-- 		/ nullif(b.runs::float / nullif((select count(*) from ranked), 0), 0) as lift
-- from base b
-- left join top t using (animal_id)
-- order by lift desc nulls last;

-- Scoring rules. rules is { element_type: rule_id }.
-- element_points is { element_type: points }.
-- with latest as (
-- 	select distinct on (run_id) payload
-- 	from public.analytics_events
-- 	where kind = 'run' and build = '0.1.0' and payload->>'mode' = 'normal'
-- 	order by run_id, received_at desc
-- ),
-- rules as (
-- 	select
-- 		key as element_type,
-- 		value as rule_id,
-- 		(payload->>'score_total')::int as score_total,
-- 		coalesce((payload->'element_points'->>key)::int, 0) as element_points
-- 	from latest, jsonb_each_text(payload->'rules')
-- )
-- select
-- 	element_type,
-- 	rule_id,
-- 	count(*) as runs,
-- 	avg(element_points) as avg_element_points,
-- 	avg(score_total) as avg_score_total
-- from rules
-- group by element_type, rule_id
-- order by element_type, rule_id;

-- Tiles offered versus placed, and points earned per element.
-- with latest as (
-- 	select distinct on (run_id) payload
-- 	from public.analytics_events
-- 	where kind = 'run' and build = '0.1.0' and payload->>'mode' = 'endless'
-- 	order by run_id, received_at desc
-- ),
-- offered as (
-- 	select key as element_id, sum(value::int) as offered
-- 	from latest, jsonb_each_text(payload->'tiles_offered')
-- 	group by key
-- ),
-- placed as (
-- 	select key as element_id, sum(value::int) as placed
-- 	from latest, jsonb_each_text(payload->'tiles_placed')
-- 	group by key
-- ),
-- points as (
-- 	select key as element_id, sum(value::int) as points
-- 	from latest, jsonb_each_text(payload->'element_points')
-- 	group by key
-- )
-- select
-- 	coalesce(o.element_id, p.element_id, s.element_id) as element_id,
-- 	coalesce(o.offered, 0) as offered,
-- 	coalesce(p.placed, 0) as placed,
-- 	coalesce(s.points, 0) as points
-- from offered o
-- full join placed p using (element_id)
-- full join points s using (element_id)
-- order by element_id;

-- Quests offered, taken, and completed.
-- with latest as (
-- 	select distinct on (run_id) payload
-- 	from public.analytics_events
-- 	where kind = 'run' and build = '0.1.0' and payload->>'mode' = 'endless'
-- 	order by run_id, received_at desc
-- ),
-- offered as (
-- 	select key as quest_id, sum(value::int) as offered
-- 	from latest, jsonb_each_text(payload->'quests_offered')
-- 	group by key
-- ),
-- taken as (
-- 	select key as quest_id, sum(value::int) as taken
-- 	from latest, jsonb_each_text(payload->'quests_taken')
-- 	group by key
-- ),
-- completed as (
-- 	select key as quest_id, sum(value::int) as completed
-- 	from latest, jsonb_each_text(payload->'quests_completed')
-- 	group by key
-- )
-- select
-- 	coalesce(o.quest_id, t.quest_id, c.quest_id) as quest_id,
-- 	coalesce(o.offered, 0) as offered,
-- 	coalesce(t.taken, 0) as taken,
-- 	coalesce(c.completed, 0) as completed
-- from offered o
-- full join taken t using (quest_id)
-- full join completed c using (quest_id)
-- order by quest_id;
