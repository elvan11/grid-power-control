begin;

create or replace function public.claim_due_plants(
  p_limit integer default 50,
  p_lease_seconds integer default 55
)
returns table (plant_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_lease integer := greatest(coalesce(p_lease_seconds, 55), 1);
begin
  insert into public.plant_runtime (plant_id)
  select p.id
  from public.plants p
  left join public.plant_runtime pr on pr.plant_id = p.id
  where pr.plant_id is null
  on conflict (plant_id) do nothing;

  return query
  with due as (
    select pr.plant_id
    from public.plant_runtime pr
    where pr.next_due_at is null or pr.next_due_at <= now()
    order by coalesce(pr.next_due_at, 'epoch'::timestamptz), pr.plant_id
    for update skip locked
    limit v_limit
  ),
  updated as (
    update public.plant_runtime pr
    set next_due_at = now() + make_interval(secs => v_lease)
    from due
    where pr.plant_id = due.plant_id
    returning pr.plant_id
  )
  select updated.plant_id
  from updated;
end;
$$;

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
  v_desired_peak integer;
  v_desired_grid boolean;
  v_source text := 'default';
  v_next_boundary timestamptz;
  v_next_today_minute integer;
  v_next_tomorrow_minute integer;
  v_override public.overrides%rowtype;
begin
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

  if v_plant.active_schedule_collection_id is not null then
    select ts.peak_shaving_w, ts.grid_charging_allowed
    into v_active_peak, v_active_grid
    from public.week_schedules ws
    join public.week_schedule_day_assignments wsda
      on wsda.week_schedule_id = ws.id
    join public.time_segments ts
      on ts.daily_schedule_id = wsda.daily_schedule_id
    where ws.schedule_collection_id = v_plant.active_schedule_collection_id
      and wsda.day_of_week = v_dow
      and ts.start_minute <= v_local_minute
      and ts.end_minute > v_local_minute
    order by wsda.priority desc, ts.start_minute asc
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
    if v_override.until_next_segment and v_override.ends_at is null and v_next_boundary <= p_at then
      update public.overrides
      set is_active = false,
          ends_at = p_at
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

      if v_override.ends_at is not null and v_override.ends_at < v_next_boundary then
        v_next_boundary := v_override.ends_at;
      end if;
    end if;
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

revoke all on function public.claim_due_plants(integer, integer) from public;
revoke all on function public.compute_plant_desired_control(uuid, timestamptz) from public;

grant execute on function public.claim_due_plants(integer, integer) to service_role;
grant execute on function public.compute_plant_desired_control(uuid, timestamptz) to service_role;

grant execute on function public.compute_plant_desired_control(uuid, timestamptz) to authenticated;

commit;
