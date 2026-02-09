begin;

create or replace function public.replace_daily_schedule_segments(
  p_daily_schedule_id uuid,
  p_segments jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plant_id uuid;
  v_segment jsonb;
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_daily_schedule_id is null then
    raise exception 'daily_schedule_id is required';
  end if;

  if p_segments is null or jsonb_typeof(p_segments) <> 'array' then
    raise exception 'segments must be a JSON array';
  end if;

  select sc.plant_id
    into v_plant_id
  from public.daily_schedules ds
  join public.schedule_collections sc
    on sc.id = ds.schedule_collection_id
  where ds.id = p_daily_schedule_id;

  if v_plant_id is null then
    raise exception 'daily_schedule_id % does not exist', p_daily_schedule_id;
  end if;

  if not public.has_plant_role(v_plant_id, array['owner', 'admin', 'member']) then
    raise exception 'Insufficient permissions for daily_schedule_id %', p_daily_schedule_id;
  end if;

  delete from public.time_segments
  where daily_schedule_id = p_daily_schedule_id;

  for v_segment in
    select value
    from jsonb_array_elements(p_segments)
  loop
    insert into public.time_segments (
      daily_schedule_id,
      start_time,
      end_time,
      peak_shaving_w,
      grid_charging_allowed,
      sort_order
    )
    values (
      p_daily_schedule_id,
      (v_segment ->> 'start_time')::time,
      (v_segment ->> 'end_time')::time,
      (v_segment ->> 'peak_shaving_w')::integer,
      coalesce((v_segment ->> 'grid_charging_allowed')::boolean, false),
      coalesce((v_segment ->> 'sort_order')::integer, v_count)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.delete_daily_schedule_with_unassign(
  p_daily_schedule_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plant_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_daily_schedule_id is null then
    raise exception 'daily_schedule_id is required';
  end if;

  select sc.plant_id
    into v_plant_id
  from public.daily_schedules ds
  join public.schedule_collections sc
    on sc.id = ds.schedule_collection_id
  where ds.id = p_daily_schedule_id;

  if v_plant_id is null then
    raise exception 'daily_schedule_id % does not exist', p_daily_schedule_id;
  end if;

  if not public.has_plant_role(v_plant_id, array['owner', 'admin', 'member']) then
    raise exception 'Insufficient permissions for daily_schedule_id %', p_daily_schedule_id;
  end if;

  delete from public.daily_schedules
  where id = p_daily_schedule_id;

  if not found then
    raise exception 'daily_schedule_id % does not exist', p_daily_schedule_id;
  end if;
end;
$$;

revoke all on function public.replace_daily_schedule_segments(uuid, jsonb) from public;
revoke all on function public.delete_daily_schedule_with_unassign(uuid) from public;

grant execute on function public.replace_daily_schedule_segments(uuid, jsonb) to authenticated;
grant execute on function public.delete_daily_schedule_with_unassign(uuid) to authenticated;

commit;
