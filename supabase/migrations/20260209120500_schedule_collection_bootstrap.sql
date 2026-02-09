begin;

create or replace function public.create_plant_with_defaults(
  p_name text,
  p_time_zone text,
  p_default_peak_shaving_w integer default 0,
  p_default_grid_charging_allowed boolean default false,
  p_collection_name text default 'Default',
  p_week_schedule_name text default 'Week'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_plant_id uuid;
  v_collection_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Plant name is required';
  end if;

  if p_time_zone is null or length(trim(p_time_zone)) = 0 then
    raise exception 'Plant time_zone is required';
  end if;

  if p_default_peak_shaving_w < 0 or p_default_peak_shaving_w % 100 <> 0 then
    raise exception 'default_peak_shaving_w must be >= 0 and divisible by 100';
  end if;

  insert into public.plants (
    name,
    time_zone,
    default_peak_shaving_w,
    default_grid_charging_allowed
  )
  values (
    trim(p_name),
    trim(p_time_zone),
    p_default_peak_shaving_w,
    p_default_grid_charging_allowed
  )
  returning id into v_plant_id;

  insert into public.plant_members (plant_id, auth_user_id, role)
  values (v_plant_id, v_user_id, 'owner');

  insert into public.schedule_collections (plant_id, name)
  values (v_plant_id, coalesce(nullif(trim(p_collection_name), ''), 'Default'))
  returning id into v_collection_id;

  insert into public.week_schedules (schedule_collection_id, name)
  values (v_collection_id, coalesce(nullif(trim(p_week_schedule_name), ''), 'Week'));

  update public.plants
  set active_schedule_collection_id = v_collection_id
  where id = v_plant_id;

  insert into public.plant_runtime (plant_id)
  values (v_plant_id)
  on conflict (plant_id) do nothing;

  return v_plant_id;
end;
$$;

create or replace function public.switch_active_schedule_collection(
  p_plant_id uuid,
  p_schedule_collection_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_plant_id is null or p_schedule_collection_id is null then
    raise exception 'plant_id and schedule_collection_id are required';
  end if;

  if not public.has_plant_role(p_plant_id, array['owner', 'admin']) then
    raise exception 'Insufficient permissions for plant %', p_plant_id;
  end if;

  if not exists (
    select 1
    from public.schedule_collections sc
    where sc.id = p_schedule_collection_id
      and sc.plant_id = p_plant_id
  ) then
    raise exception 'schedule_collection_id % does not belong to plant %', p_schedule_collection_id, p_plant_id;
  end if;

  update public.plants
  set active_schedule_collection_id = p_schedule_collection_id
  where id = p_plant_id;

  if not found then
    raise exception 'plant_id % does not exist', p_plant_id;
  end if;

  insert into public.plant_runtime (plant_id, next_due_at)
  values (p_plant_id, now())
  on conflict (plant_id)
  do update set next_due_at = excluded.next_due_at;
end;
$$;

revoke all on function public.create_plant_with_defaults(text, text, integer, boolean, text, text) from public;
revoke all on function public.switch_active_schedule_collection(uuid, uuid) from public;

grant execute on function public.create_plant_with_defaults(text, text, integer, boolean, text, text) to authenticated;
grant execute on function public.switch_active_schedule_collection(uuid, uuid) to authenticated;

commit;
