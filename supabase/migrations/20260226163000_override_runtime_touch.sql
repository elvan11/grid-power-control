begin;

create or replace function public.touch_plant_runtime_on_override_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plant_id uuid;
  v_candidate_due timestamptz;
begin
  v_plant_id := coalesce(new.plant_id, old.plant_id);
  if v_plant_id is null then
    return coalesce(new, old);
  end if;

  -- Force an executor recomputation after override changes and ensure
  -- upcoming override boundaries (start/end) are not missed.
  v_candidate_due := least(
    now(),
    coalesce(new.starts_at, old.starts_at, 'infinity'::timestamptz),
    coalesce(new.ends_at, old.ends_at, 'infinity'::timestamptz)
  );

  insert into public.plant_runtime (plant_id, next_due_at)
  values (v_plant_id, v_candidate_due)
  on conflict (plant_id)
  do update
    set next_due_at = least(
      coalesce(public.plant_runtime.next_due_at, 'infinity'::timestamptz),
      excluded.next_due_at
    );

  return coalesce(new, old);
end;
$$;

drop trigger if exists overrides_touch_runtime_trg on public.overrides;

create trigger overrides_touch_runtime_trg
after insert or update or delete
on public.overrides
for each row
execute function public.touch_plant_runtime_on_override_change();

commit;

