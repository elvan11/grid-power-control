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
  on conflict on constraint plant_runtime_pkey do nothing;

  return query
  with due as (
    select pr.plant_id
    from public.plant_runtime pr
    where pr.next_due_at is null
      or pr.next_due_at <= now() + interval '5 minutes'
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

revoke all on function public.claim_due_plants(integer, integer) from public;
grant execute on function public.claim_due_plants(integer, integer) to service_role;

commit;
