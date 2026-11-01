begin;
create schema if not exists private;
revoke all on schema private from public;
alter table public.plants add column price_area text check (price_area in ('SE1','SE2','SE3','SE4','NO1','NO2','NO3','NO4','NO5','DK1','DK2','FI'));
alter table public.time_segments add column control_kind text not null default 'fixed' check (control_kind in ('fixed','spot_import')),
 add column import_energy_wh integer,
 add constraint spot_import_parameters check (
 (control_kind='fixed' and import_energy_wh is null) or
 (control_kind='spot_import' and peak_shaving_w > 0 and peak_shaving_w <= 10000 and not grid_charging_allowed
 and import_energy_wh > 0 and import_energy_wh is not null
 and import_energy_wh::bigint * 60 <= peak_shaving_w::bigint * (end_minute-start_minute)));
alter table public.plant_runtime add column lease_until timestamptz, add column last_control_source text;

create table public.spot_import_plans (
 plant_id uuid not null references public.plants(id) on delete cascade,
 segment_id uuid not null, -- deliberately no segment FK: retain elapsed allocations across replacement saves
 local_date date not null,
 revision_key text not null,
 price_area text not null,
 peak_shaving_w integer not null,
 target_wh integer not null,
 window_start timestamptz not null,
 window_end timestamptz not null,
 status text not null check (status in ('ready','pending_prices','insufficient_capacity')),
 slots jsonb not null check (jsonb_typeof(slots)='array'),
 prepared_at timestamptz not null default now(),
 refresh_after timestamptz,
 primary key(plant_id,segment_id,local_date)
);
alter table public.spot_import_plans enable row level security;
revoke all on public.spot_import_plans from anon, authenticated;
create policy spot_import_plans_member_read on public.spot_import_plans for select to authenticated using(public.is_plant_member(plant_id));
grant select on public.spot_import_plans to authenticated;
grant all on public.spot_import_plans to service_role;
create table public.spot_price_cache (
 area text not null, source_date date not null, entries jsonb not null check(jsonb_typeof(entries)='array'),
 fetched_at timestamptz not null default now(), primary key(area,source_date)
);
alter table public.spot_price_cache enable row level security;
revoke all on public.spot_price_cache from anon, authenticated;
grant all on public.spot_price_cache to service_role;

create or replace function private.spot_revision(p_plant uuid,p_segment uuid,p_date date) returns text
language sql stable set search_path=public as $$
 select md5(concat_ws('|',p.id, p.active_schedule_collection_id,p.time_zone,p.price_area,p.schedule_control_enabled,
 ts.id,ts.start_time,ts.end_time,ts.peak_shaving_w,ts.import_energy_wh,ts.control_kind,p_date,
 (select string_agg(concat_ws(':',a.daily_schedule_id,a.priority,a.day_of_week,a.updated_at),',' order by a.day_of_week,a.priority,a.id)
 from week_schedules w join week_schedule_day_assignments a on a.week_schedule_id=w.id where w.schedule_collection_id=p.active_schedule_collection_id),
 (select string_agg(concat_ws(':',t.id,t.start_time,t.end_time,t.control_kind),',' order by t.id)
 from week_schedules w join week_schedule_day_assignments a on a.week_schedule_id=w.id join time_segments t on t.daily_schedule_id=a.daily_schedule_id where w.schedule_collection_id=p.active_schedule_collection_id)))
 from plants p cross join time_segments ts where p.id=p_plant and ts.id=p_segment and ts.control_kind='spot_import'
 and exists(select 1 from daily_schedules d join schedule_collections c on c.id=d.schedule_collection_id
 where d.id=ts.daily_schedule_id and c.plant_id=p.id and c.id=p.active_schedule_collection_id)
$$;

create or replace function private.validate_spot_area() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.control_kind='spot_import' and not exists (
 select 1 from daily_schedules d join schedule_collections c on c.id=d.schedule_collection_id join plants p on p.id=c.plant_id
 where d.id=new.daily_schedule_id and p.price_area is not null) then raise exception 'Select an installation price area before saving spot import controls'; end if;
 return new;
end $$;
create trigger time_segments_spot_area before insert or update on public.time_segments for each row execute function private.validate_spot_area();
create or replace function private.prevent_missing_spot_area() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.price_area is null and exists(select 1 from schedule_collections c join daily_schedules d on d.schedule_collection_id=c.id join time_segments t on t.daily_schedule_id=d.id where c.plant_id=new.id and t.control_kind='spot_import') then raise exception 'Price area is required while spot import controls exist'; end if;
 return new;
end $$;
create trigger plants_spot_area before update of price_area on public.plants for each row execute function private.prevent_missing_spot_area();

create or replace function public.replace_daily_schedule_segments(p_daily_schedule_id uuid,p_segments jsonb) returns integer
language plpgsql security definer set search_path=public as $$
declare v_plant uuid; v_segment jsonb; v_count integer:=0; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_segments is null or jsonb_typeof(p_segments)<>'array' then raise exception 'segments must be a JSON array'; end if;
 select c.plant_id into v_plant from daily_schedules d join schedule_collections c on c.id=d.schedule_collection_id where d.id=p_daily_schedule_id for update of d;
 if v_plant is null or not public.has_plant_role(v_plant,array['owner','admin','member']) then raise exception 'Insufficient permissions for schedule'; end if;
 if exists(select 1 from time_segments where daily_schedule_id=p_daily_schedule_id and control_kind='spot_import') and
 (jsonb_array_length(p_segments)=0 or exists(select 1 from jsonb_array_elements(p_segments) x where not(x ? 'control_kind')))
 then raise exception 'Update the app before editing a schedule containing spot import controls'; end if;
 for v_segment in select value from jsonb_array_elements(p_segments) loop
  if v_segment->>'id' is not null and not exists(select 1 from time_segments where id=(v_segment->>'id')::uuid and daily_schedule_id=p_daily_schedule_id)
  then raise exception 'Segment identity does not belong to this schedule'; end if;
 end loop;
 delete from time_segments where daily_schedule_id=p_daily_schedule_id;
 for v_segment in select value from jsonb_array_elements(p_segments) loop
  v_id:=coalesce((v_segment->>'id')::uuid,gen_random_uuid());
  insert into time_segments(id,daily_schedule_id,start_time,end_time,peak_shaving_w,grid_charging_allowed,sort_order,control_kind,import_energy_wh)
  values(v_id,p_daily_schedule_id,(v_segment->>'start_time')::time,(v_segment->>'end_time')::time,(v_segment->>'peak_shaving_w')::integer,
  coalesce((v_segment->>'grid_charging_allowed')::boolean,false),coalesce((v_segment->>'sort_order')::integer,v_count),coalesce(v_segment->>'control_kind','fixed'),(v_segment->>'import_energy_wh')::integer);
  v_count:=v_count+1;
 end loop;
 insert into plant_runtime(plant_id,next_due_at) values(v_plant,now()) on conflict(plant_id) do update set next_due_at=excluded.next_due_at;
 return v_count;
end $$;

create or replace function public.get_spot_import_work(p_at timestamptz default now())
returns table(plant_id uuid,segment_id uuid,local_date date,revision_key text,price_area text,time_zone text,peak_shaving_w integer,target_wh integer,
 window_start timestamptz,window_end timestamptz,slots jsonb,previous_plan jsonb)
language sql stable security definer set search_path=public as $$
 with contexts as (
 select p.id as pid,t.id as sid,dt.d::date as d,p.price_area as area,p.time_zone as zone,t.peak_shaving_w as power,t.import_energy_wh as energy,
 t.start_minute,t.end_minute,p.active_schedule_collection_id as collection_id
 from plants p cross join lateral (select (p_at at time zone p.time_zone)::date + n as d from generate_series(0,1) n) dt
 join schedule_collections c on c.id=p.active_schedule_collection_id
 join week_schedules w on w.schedule_collection_id=c.id
 join week_schedule_day_assignments a on a.week_schedule_id=w.id and a.day_of_week=extract(isodow from dt.d)
 join time_segments t on t.daily_schedule_id=a.daily_schedule_id and t.control_kind='spot_import'
 where p.schedule_control_enabled and p.price_area is not null
 ), quarters as (
 select c.*,q.qstart, q.qstart+interval '15 minutes' as qend,
 (select t.id from week_schedules w join week_schedule_day_assignments a on a.week_schedule_id=w.id
 join time_segments t on t.daily_schedule_id=a.daily_schedule_id
 where w.schedule_collection_id=c.collection_id and a.day_of_week=extract(isodow from c.d)
 and t.start_minute<=extract(hour from(q.qstart at time zone c.zone))*60+extract(minute from(q.qstart at time zone c.zone))
 and t.end_minute>extract(hour from(q.qstart at time zone c.zone))*60+extract(minute from(q.qstart at time zone c.zone))
 order by a.priority desc,t.start_minute,t.id limit 1)=c.sid as eligible
 from contexts c cross join lateral generate_series(c.d::timestamp at time zone c.zone,((c.d+1)::timestamp at time zone c.zone)-interval '15 minutes',interval '15 minutes') q(qstart)
 where extract(hour from(q.qstart at time zone c.zone))*60+extract(minute from(q.qstart at time zone c.zone))>=c.start_minute
 and extract(hour from(q.qstart at time zone c.zone))*60+extract(minute from(q.qstart at time zone c.zone))<c.end_minute
 ), grouped as (
 select pid,sid,d,area,zone,power,energy,min(qstart) as ws,max(qend) as we,
 jsonb_agg(jsonb_build_object('start',qstart,'end',qend,'eligible',eligible) order by qstart) as ss
 from quarters group by pid,sid,d,area,zone,power,energy)
 select g.pid,g.sid,g.d,private.spot_revision(g.pid,g.sid,g.d),g.area,g.zone,g.power,g.energy,g.ws,g.we,g.ss,to_jsonb(plan)
 from grouped g left join spot_import_plans plan on plan.plant_id=g.pid and plan.segment_id=g.sid and plan.local_date=g.d
$$;
revoke all on function public.get_spot_import_work(timestamptz) from public,anon,authenticated;
grant execute on function public.get_spot_import_work(timestamptz) to service_role;

create or replace function public.save_spot_import_plan(p_plan jsonb) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_plant uuid:=(p_plan->>'plant_id')::uuid; v_segment uuid:=(p_plan->>'segment_id')::uuid; v_date date:=(p_plan->>'local_date')::date; v_previous spot_import_plans%rowtype;
begin
 perform 1 from plants where id=v_plant for update;
 if (p_plan->>'revision_key') is distinct from private.spot_revision(v_plant,v_segment,v_date) then return false; end if;
 select * into v_previous from spot_import_plans where plant_id=v_plant and segment_id=v_segment and local_date=v_date;
 if found and v_previous.revision_key=p_plan->>'revision_key' and v_previous.window_start<=now() and v_previous.status<>'pending_prices' then return false; end if;
 insert into spot_import_plans(plant_id,segment_id,local_date,revision_key,price_area,peak_shaving_w,target_wh,window_start,window_end,status,slots,prepared_at,refresh_after)
 values(v_plant,v_segment,v_date,p_plan->>'revision_key',p_plan->>'price_area',(p_plan->>'peak_shaving_w')::int,(p_plan->>'target_wh')::int,(p_plan->>'window_start')::timestamptz,(p_plan->>'window_end')::timestamptz,p_plan->>'status',p_plan->'slots',coalesce((p_plan->>'prepared_at')::timestamptz,now()),(p_plan->>'refresh_after')::timestamptz)
 on conflict(plant_id,segment_id,local_date) do update set revision_key=excluded.revision_key,price_area=excluded.price_area,peak_shaving_w=excluded.peak_shaving_w,target_wh=excluded.target_wh,
 window_start=excluded.window_start,window_end=excluded.window_end,status=excluded.status,slots=excluded.slots,prepared_at=excluded.prepared_at,refresh_after=excluded.refresh_after;
 insert into plant_runtime(plant_id,next_due_at) values(v_plant,now()) on conflict(plant_id) do update set next_due_at=least(plant_runtime.next_due_at,excluded.next_due_at);
 return true;
end $$;
revoke all on function public.save_spot_import_plan(jsonb) from public,anon,authenticated;
grant execute on function public.save_spot_import_plan(jsonb) to service_role;

create or replace function public.get_plant_import_plan(p_plant_id uuid,p_date date default null)
returns setof public.spot_import_plans language plpgsql stable security definer set search_path=public as $$
begin
 if not public.is_plant_member(p_plant_id) then raise exception 'Insufficient permissions'; end if;
 return query select sp.* from spot_import_plans sp join time_segments t on t.id=sp.segment_id
 where sp.plant_id=p_plant_id and sp.local_date=coalesce(p_date,(now() at time zone (select p.time_zone from plants p where p.id=p_plant_id))::date)
 and t.control_kind='spot_import' and sp.revision_key=private.spot_revision(p_plant_id,t.id,sp.local_date) order by sp.window_start,sp.segment_id;
end $$;
revoke all on function public.get_plant_import_plan(uuid,date) from public,anon;
grant execute on function public.get_plant_import_plan(uuid,date) to authenticated;

create or replace function public.compute_plant_desired_control(
  p_plant_id uuid,
  p_at timestamptz default now()
)
returns table (
  desired_peak_shaving_w integer,
  desired_grid_charging_allowed boolean,
  next_due_at timestamptz,
  source text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plant public.plants%rowtype;
  v_local_ts timestamp;
  v_local_date date;
  v_local_minute integer;
  v_dow integer;
  v_tomorrow_dow integer;
  v_active_peak integer;
  v_active_grid boolean;
  v_segment_id uuid;
  v_control_kind text;
  v_plan public.spot_import_plans%rowtype;
  v_slot jsonb;
  v_desired_peak integer;
  v_desired_grid boolean;
  v_source text := 'default';
  v_next_boundary timestamptz;
  v_next_today_minute integer;
  v_next_tomorrow_minute integer;
  v_override public.overrides%rowtype;
  v_override_boundary timestamptz;
  v_override_local_ts timestamp;
  v_override_local_date date;
  v_override_local_minute integer;
  v_override_dow integer;
  v_override_tomorrow_dow integer;
  v_override_next_today_minute integer;
  v_override_next_tomorrow_minute integer;
begin
  if auth.role() <> 'service_role' and not public.is_plant_member(p_plant_id) then raise exception 'Insufficient permissions'; end if;
  select *
  into v_plant
  from public.plants p
  where p.id = p_plant_id;

  if not found then
    raise exception 'plant_id % not found', p_plant_id;
  end if;

  v_local_ts := p_at at time zone v_plant.time_zone;
  v_local_date := v_local_ts::date;
  v_local_minute := extract(hour from v_local_ts)::integer * 60 + extract(minute from v_local_ts)::integer;
  v_dow := extract(isodow from v_local_ts)::integer;
  v_tomorrow_dow := extract(isodow from (v_local_ts + interval '1 day'))::integer;

  v_desired_peak := v_plant.default_peak_shaving_w;
  v_desired_grid := v_plant.default_grid_charging_allowed;

  if not v_plant.schedule_control_enabled then
    v_source := 'disabled';
    v_next_boundary := p_at + interval '1 day';
  else
    if v_plant.active_schedule_collection_id is not null then
      select ts.peak_shaving_w, ts.grid_charging_allowed,ts.id,ts.control_kind
      into v_active_peak, v_active_grid,v_segment_id,v_control_kind
      from public.week_schedules ws
      join public.week_schedule_day_assignments wsda
        on wsda.week_schedule_id = ws.id
      join public.time_segments ts
        on ts.daily_schedule_id = wsda.daily_schedule_id
      where ws.schedule_collection_id = v_plant.active_schedule_collection_id
        and wsda.day_of_week = v_dow
        and ts.start_minute <= v_local_minute
        and ts.end_minute > v_local_minute
      order by wsda.priority desc, ts.start_minute asc,ts.id
      limit 1;

      if found then
        v_desired_peak := v_active_peak;
        v_desired_grid := v_active_grid;
        v_source := 'schedule';
      end if;

      select min(boundary_minute)
      into v_next_today_minute
      from (
        select ts.start_minute as boundary_minute
        from public.week_schedules ws
        join public.week_schedule_day_assignments wsda
          on wsda.week_schedule_id = ws.id
        join public.time_segments ts
          on ts.daily_schedule_id = wsda.daily_schedule_id
        where ws.schedule_collection_id = v_plant.active_schedule_collection_id
          and wsda.day_of_week = v_dow
          and ts.start_minute > v_local_minute
        union all
        select ts.end_minute as boundary_minute
        from public.week_schedules ws
        join public.week_schedule_day_assignments wsda
          on wsda.week_schedule_id = ws.id
        join public.time_segments ts
          on ts.daily_schedule_id = wsda.daily_schedule_id
        where ws.schedule_collection_id = v_plant.active_schedule_collection_id
          and wsda.day_of_week = v_dow
          and ts.end_minute > v_local_minute
      ) as today_boundaries;

      if v_next_today_minute is not null then
        v_next_boundary := ((v_local_date + make_interval(mins => v_next_today_minute)) at time zone v_plant.time_zone);
      else
        select min(boundary_minute)
        into v_next_tomorrow_minute
        from (
          select ts.start_minute as boundary_minute
          from public.week_schedules ws
          join public.week_schedule_day_assignments wsda
            on wsda.week_schedule_id = ws.id
          join public.time_segments ts
            on ts.daily_schedule_id = wsda.daily_schedule_id
          where ws.schedule_collection_id = v_plant.active_schedule_collection_id
            and wsda.day_of_week = v_tomorrow_dow
          union all
          select ts.end_minute as boundary_minute
          from public.week_schedules ws
          join public.week_schedule_day_assignments wsda
            on wsda.week_schedule_id = ws.id
          join public.time_segments ts
            on ts.daily_schedule_id = wsda.daily_schedule_id
          where ws.schedule_collection_id = v_plant.active_schedule_collection_id
            and wsda.day_of_week = v_tomorrow_dow
        ) as tomorrow_boundaries;

        if v_next_tomorrow_minute is not null then
          v_next_boundary := (((v_local_date + 1) + make_interval(mins => v_next_tomorrow_minute)) at time zone v_plant.time_zone);
        end if;
      end if;
    end if;

    if v_next_boundary is null then
      v_next_boundary := p_at + interval '5 minutes';
    end if;

    -- Resolve generated controls BEFORE applying a possibly partial manual override.
    if v_control_kind='spot_import' then
      v_desired_grid:=false;
      v_source:='spot_waiting_prices';
      select * into v_plan from public.spot_import_plans sp
      where sp.plant_id=p_plant_id and sp.segment_id=v_segment_id and sp.local_date=v_local_date
      and sp.revision_key=private.spot_revision(p_plant_id,v_segment_id,v_local_date);
      if found then
        v_source:=case when v_plan.status='pending_prices' then 'spot_waiting_prices'
          when v_plan.status='insufficient_capacity' then 'spot_insufficient_capacity' else 'spot_peak_shave' end;
        select value into v_slot from jsonb_array_elements(v_plan.slots)
        where (value->>'start')::timestamptz<=p_at and (value->>'end')::timestamptz>p_at limit 1;
        if found and coalesce((v_slot->>'selected')::boolean,false) then v_desired_grid:=true; v_source:='spot_import'; end if;
      end if;
      v_next_boundary:=least(v_next_boundary,date_bin(interval '15 minutes',p_at,'2000-01-01'::timestamptz)+interval '15 minutes');
      if v_source='spot_waiting_prices' then v_next_boundary:=least(v_next_boundary,p_at+interval '5 minutes'); end if;
    end if;

    select *
    into v_override
    from public.overrides o
    where o.plant_id = p_plant_id
      and o.is_active = true
      and o.starts_at <= p_at
      and (o.ends_at is null or o.ends_at > p_at)
    order by o.created_at desc
    limit 1;

    if found then
      v_override_boundary := null;

      if v_override.until_next_segment and v_override.ends_at is null then
        -- Compute the "next segment boundary" relative to override start time,
        -- not relative to p_at (which may be after the boundary already).
        v_override_local_ts := v_override.starts_at at time zone v_plant.time_zone;
        v_override_local_date := v_override_local_ts::date;
        v_override_local_minute := extract(hour from v_override_local_ts)::integer * 60 +
          extract(minute from v_override_local_ts)::integer;
        v_override_dow := extract(isodow from v_override_local_ts)::integer;
        v_override_tomorrow_dow := extract(isodow from (v_override_local_ts + interval '1 day'))::integer;

        if v_plant.active_schedule_collection_id is not null then
          select min(boundary_minute)
          into v_override_next_today_minute
          from (
            select ts.start_minute as boundary_minute
            from public.week_schedules ws
            join public.week_schedule_day_assignments wsda
              on wsda.week_schedule_id = ws.id
            join public.time_segments ts
              on ts.daily_schedule_id = wsda.daily_schedule_id
            where ws.schedule_collection_id = v_plant.active_schedule_collection_id
              and wsda.day_of_week = v_override_dow
              and ts.start_minute > v_override_local_minute
            union all
            select ts.end_minute as boundary_minute
            from public.week_schedules ws
            join public.week_schedule_day_assignments wsda
              on wsda.week_schedule_id = ws.id
            join public.time_segments ts
              on ts.daily_schedule_id = wsda.daily_schedule_id
            where ws.schedule_collection_id = v_plant.active_schedule_collection_id
              and wsda.day_of_week = v_override_dow
              and ts.end_minute > v_override_local_minute
          ) as override_today_boundaries;

          if v_override_next_today_minute is not null then
            v_override_boundary :=
              ((v_override_local_date + make_interval(mins => v_override_next_today_minute)) at time zone v_plant.time_zone);
          else
            select min(boundary_minute)
            into v_override_next_tomorrow_minute
            from (
              select ts.start_minute as boundary_minute
              from public.week_schedules ws
              join public.week_schedule_day_assignments wsda
                on wsda.week_schedule_id = ws.id
              join public.time_segments ts
                on ts.daily_schedule_id = wsda.daily_schedule_id
              where ws.schedule_collection_id = v_plant.active_schedule_collection_id
                and wsda.day_of_week = v_override_tomorrow_dow
              union all
              select ts.end_minute as boundary_minute
              from public.week_schedules ws
              join public.week_schedule_day_assignments wsda
                on wsda.week_schedule_id = ws.id
              join public.time_segments ts
                on ts.daily_schedule_id = wsda.daily_schedule_id
              where ws.schedule_collection_id = v_plant.active_schedule_collection_id
                and wsda.day_of_week = v_override_tomorrow_dow
            ) as override_tomorrow_boundaries;

            if v_override_next_tomorrow_minute is not null then
              v_override_boundary :=
                (((v_override_local_date + 1) + make_interval(mins => v_override_next_tomorrow_minute)) at time zone v_plant.time_zone);
            end if;
          end if;
        end if;

        if v_override_boundary is null then
          v_override_boundary := v_override.starts_at + interval '15 minutes';
        end if;

        if v_override_boundary <= p_at then
          update public.overrides
          set is_active = false,
              ends_at = v_override_boundary
          where id = v_override.id
            and is_active = true;
        else
          if v_override.peak_shaving_w is not null then
            v_desired_peak := v_override.peak_shaving_w;
          end if;

          if v_override.grid_charging_allowed is not null then
            v_desired_grid := v_override.grid_charging_allowed;
          end if;

          v_source := 'override';
          v_next_boundary := least(v_next_boundary, v_override_boundary);
        end if;
      else
        if v_override.peak_shaving_w is not null then
          v_desired_peak := v_override.peak_shaving_w;
        end if;

        if v_override.grid_charging_allowed is not null then
          v_desired_grid := v_override.grid_charging_allowed;
        end if;

        v_source := 'override';

        if v_override.ends_at is not null and v_override.ends_at < v_next_boundary then
          v_next_boundary := v_override.ends_at;
        end if;
      end if;
    end if;
  end if;

  -- On DST fall-back a local window can become active a second time after a gap.
  -- Keep a real UTC-quarter wake-up even while a different/default control wins.
  if v_plant.schedule_control_enabled and exists (
    select 1 from public.week_schedules ws
    join public.week_schedule_day_assignments a on a.week_schedule_id=ws.id
    join public.time_segments t on t.daily_schedule_id=a.daily_schedule_id
    where ws.schedule_collection_id=v_plant.active_schedule_collection_id
    and a.day_of_week=v_dow and t.control_kind='spot_import'
  ) then
    v_next_boundary:=least(v_next_boundary,date_bin(interval '15 minutes',p_at,'2000-01-01'::timestamptz)+interval '15 minutes');
  end if;

  if v_next_boundary <= p_at then
    v_next_boundary := p_at + interval '30 seconds';
  end if;

  return query
  select
    v_desired_peak,
    v_desired_grid,
    v_next_boundary,
    v_source;
end;
$$;


drop function public.claim_due_plants(integer,integer);
create function public.claim_due_plants(p_limit integer default 50,p_lease_seconds integer default 55)
returns table(plant_id uuid,lease_until timestamptz) language plpgsql security definer set search_path=public as $$
begin
 insert into plant_runtime(plant_id) select p.id from plants p on conflict on constraint plant_runtime_pkey do nothing;
 return query with due as (
 select pr.plant_id from plant_runtime pr
 where (pr.next_due_at is null or pr.next_due_at<=now()) and (pr.lease_until is null or pr.lease_until<=now())
 order by coalesce(pr.next_due_at,'epoch'::timestamptz),pr.plant_id for update skip locked limit greatest(coalesce(p_limit,50),1)
 ), updated as (
 update plant_runtime pr set lease_until=now()+make_interval(secs=>greatest(coalesce(p_lease_seconds,55),1))
 from due where pr.plant_id=due.plant_id returning pr.plant_id,pr.lease_until)
 select updated.plant_id,updated.lease_until from updated;
end $$;
revoke all on function public.claim_due_plants(integer,integer) from public,anon,authenticated;
grant execute on function public.claim_due_plants(integer,integer) to service_role;

create or replace function public.configure_executor_tick_cron(
  p_cron text default '* * * * *',
  p_job_name text default 'executor-tick-15m',
  p_limit integer default 30
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
  v_job_id bigint;
  v_command text;
begin
  select decrypted_secret
    into v_url
  from vault.decrypted_secrets
  where name = 'executor_tick_url'
  limit 1;

  select decrypted_secret
    into v_secret
  from vault.decrypted_secrets
  where name = 'executor_secret'
  limit 1;

  if v_url is null or length(trim(v_url)) = 0 then
    raise exception
      'Missing vault secret: executor_tick_url. Set it with vault.create_secret(...) first.';
  end if;

  if v_secret is null or length(trim(v_secret)) = 0 then
    raise exception
      'Missing vault secret: executor_secret. Set it with vault.create_secret(...) first.';
  end if;

  perform cron.unschedule(jobid)
  from cron.job
  where jobname = p_job_name;

  v_command := format(
    $cmd$
      select net.http_post(
        url := %L,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || %L
        ),
        body := jsonb_build_object('limit', %s)
      ) as request_id;
    $cmd$,
    v_url,
    v_secret,
    greatest(p_limit, 1)
  );

  select cron.schedule(
    p_job_name,
    p_cron,
    v_command
  )
  into v_job_id;

  return v_job_id;
end;
$$;


-- Editing/removing an assignment or segment must wake current controls as well as planning.
create or replace function private.touch_schedule_runtime() returns trigger language plpgsql security definer set search_path=public as $$
declare v_plant uuid; v_schedule uuid;
begin
 if tg_table_name='time_segments' then
   if tg_op='DELETE' then v_schedule:=old.daily_schedule_id; else v_schedule:=new.daily_schedule_id; end if;
   select c.plant_id into v_plant from daily_schedules d join schedule_collections c on c.id=d.schedule_collection_id where d.id=v_schedule;
 elsif tg_table_name='week_schedule_day_assignments' then
   select c.plant_id into v_plant from week_schedules w join schedule_collections c on c.id=w.schedule_collection_id
   where w.id=case when tg_op='DELETE' then old.week_schedule_id else new.week_schedule_id end;
 elsif tg_table_name='daily_schedules' then
   select c.plant_id into v_plant from schedule_collections c where c.id=old.schedule_collection_id;
 else v_plant:=new.id;
 end if;
 if v_plant is not null then insert into plant_runtime(plant_id,next_due_at) values(v_plant,now()) on conflict(plant_id) do update set next_due_at=excluded.next_due_at; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger time_segments_touch_runtime after insert or update or delete on public.time_segments for each row execute function private.touch_schedule_runtime();
create trigger assignments_touch_runtime after insert or update or delete on public.week_schedule_day_assignments for each row execute function private.touch_schedule_runtime();
create trigger daily_schedules_delete_touch_runtime before delete on public.daily_schedules for each row execute function private.touch_schedule_runtime();
create trigger plants_spot_settings_touch_runtime after update of price_area,time_zone,active_schedule_collection_id on public.plants for each row execute function private.touch_schedule_runtime();
-- Audit metadata is fetched separately to preserve the desired-control RPC contract.
create or replace function public.get_spot_import_context(p_plant_id uuid,p_at timestamptz default now())
returns table(segment_id uuid,local_date date,revision_key text,status text,slot_start timestamptz,slot_end timestamptz)
language sql stable security definer set search_path=public as $$
 with active as (
 select t.id,p.time_zone,p.price_area,t.control_kind,(p_at at time zone p.time_zone)::date as d
 from plants p join week_schedules w on w.schedule_collection_id=p.active_schedule_collection_id
 join week_schedule_day_assignments a on a.week_schedule_id=w.id
 join time_segments t on t.daily_schedule_id=a.daily_schedule_id
 where p.id=p_plant_id and p.schedule_control_enabled
 and a.day_of_week=extract(isodow from(p_at at time zone p.time_zone))
 and t.start_minute<=extract(hour from(p_at at time zone p.time_zone))*60+extract(minute from(p_at at time zone p.time_zone))
 and t.end_minute>extract(hour from(p_at at time zone p.time_zone))*60+extract(minute from(p_at at time zone p.time_zone))
 order by a.priority desc,t.start_minute,t.id limit 1
 )
 select a.id,a.d,private.spot_revision(p_plant_id,a.id,a.d),coalesce(sp.status,'pending_prices'),
 date_bin(interval '15 minutes',p_at,'2000-01-01'::timestamptz),date_bin(interval '15 minutes',p_at,'2000-01-01'::timestamptz)+interval '15 minutes'
 from active a left join spot_import_plans sp on sp.plant_id=p_plant_id and sp.segment_id=a.id and sp.local_date=a.d
 and sp.revision_key=private.spot_revision(p_plant_id,a.id,a.d)
 where a.control_kind='spot_import'
$$;
revoke all on function public.get_spot_import_context(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.get_spot_import_context(uuid,timestamptz) to service_role;
create or replace function public.release_plant_lease(p_plant_id uuid,p_lease_until timestamptz)
returns boolean language plpgsql security definer set search_path=public as $$
declare released integer;
begin
 update plant_runtime set lease_until=null where plant_id=p_plant_id and lease_until=p_lease_until;
 get diagnostics released=row_count;
 return released=1;
end $$;
revoke all on function public.release_plant_lease(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.release_plant_lease(uuid,timestamptz) to service_role;
-- A date-changing timezone edit could otherwise create a fresh occurrence budget.
create or replace function private.guard_active_spot_timezone_change() returns trigger
language plpgsql security definer set search_path=public as $$
declare state record; local_now timestamp; minute_now integer;
begin
 if new.time_zone is not distinct from old.time_zone then return new; end if;
 for state in select old.time_zone as zone,old.active_schedule_collection_id as collection_id
 union all select new.time_zone,new.active_schedule_collection_id loop
   local_now:=now() at time zone state.zone;
   minute_now:=extract(hour from local_now)::integer*60+extract(minute from local_now)::integer;
   if exists(select 1 from week_schedules w join week_schedule_day_assignments a on a.week_schedule_id=w.id
    join time_segments t on t.daily_schedule_id=a.daily_schedule_id
    where w.schedule_collection_id=state.collection_id and a.day_of_week=extract(isodow from local_now)
    and t.control_kind='spot_import' and t.start_minute<=minute_now and t.end_minute>minute_now)
   then raise exception 'Change time zone outside active spot-import windows'; end if;
 end loop;
 return new;
end $$;
create trigger plants_guard_spot_timezone_change before update of time_zone on public.plants
for each row execute function private.guard_active_spot_timezone_change();
commit;
