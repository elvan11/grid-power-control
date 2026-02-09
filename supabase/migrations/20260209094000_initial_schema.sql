-- Grid Power Control initial schema
-- Scope: baseline schema, constraints, triggers, and RLS policies.

begin;

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'vault') then
    execute 'create extension if not exists vault';
  elsif exists (select 1 from pg_available_extensions where name = 'supabase_vault') then
    execute 'create extension if not exists supabase_vault';
  end if;
end;
$$;

create type public.plant_role as enum ('owner', 'admin', 'member', 'viewer');
create type public.invite_status as enum ('pending', 'accepted', 'revoked', 'expired');
create type public.provider_type as enum ('soliscloud');
create type public.provider_result as enum ('success', 'skipped', 'failed');
create type public.theme_mode as enum ('system', 'light', 'dark');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.normalize_invite_email()
returns trigger
language plpgsql
as $$
begin
  new.invited_email = lower(trim(new.invited_email));
  return new;
end;
$$;

create table public.plants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  time_zone text not null check (length(trim(time_zone)) > 0),
  active_schedule_collection_id uuid null,
  default_peak_shaving_w integer not null default 0 check (default_peak_shaving_w >= 0 and default_peak_shaving_w % 100 = 0),
  default_grid_charging_allowed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.plant_members (
  plant_id uuid not null references public.plants(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  role public.plant_role not null,
  created_at timestamptz not null default now(),
  primary key (plant_id, auth_user_id)
);

create table public.plant_invites (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  invited_email text not null check (length(trim(invited_email)) > 0),
  invited_by_auth_user_id uuid not null references auth.users(id) on delete restrict,
  role public.plant_role not null check (role in ('admin', 'member', 'viewer')),
  token_hash text not null,
  status public.invite_status not null default 'pending',
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz null,
  accepted_by_auth_user_id uuid null references auth.users(id) on delete set null
);

create unique index plant_invites_pending_unique_idx
  on public.plant_invites(plant_id, invited_email)
  where status = 'pending';

create table public.schedule_collections (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.plants
  add constraint plants_active_schedule_collection_id_fkey
  foreign key (active_schedule_collection_id)
  references public.schedule_collections(id)
  on delete set null
  deferrable initially deferred;

create table public.daily_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_collection_id uuid not null references public.schedule_collections(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.time_segments (
  id uuid primary key default gen_random_uuid(),
  daily_schedule_id uuid not null references public.daily_schedules(id) on delete cascade,
  start_time time not null,
  end_time time not null,
  start_minute integer generated always as (((extract(hour from start_time)::integer * 60) + extract(minute from start_time)::integer)) stored,
  end_minute integer generated always as (((extract(hour from end_time)::integer * 60) + extract(minute from end_time)::integer)) stored,
  peak_shaving_w integer not null check (peak_shaving_w >= 0 and peak_shaving_w % 100 = 0),
  grid_charging_allowed boolean not null,
  sort_order integer not null default 0 check (sort_order >= 0),
  constraint time_segments_valid_range check (start_time < end_time),
  constraint time_segments_15m_alignment check (start_minute % 15 = 0 and end_minute % 15 = 0)
);

alter table public.time_segments
  add constraint time_segments_no_overlap_excl
  exclude using gist (
    daily_schedule_id with =,
    int4range(start_minute, end_minute, '[)') with &&
  );

create index time_segments_daily_schedule_sort_idx
  on public.time_segments(daily_schedule_id, sort_order, start_time);

create table public.week_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_collection_id uuid not null references public.schedule_collections(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (schedule_collection_id)
);

create table public.week_schedule_day_assignments (
  id uuid primary key default gen_random_uuid(),
  week_schedule_id uuid not null references public.week_schedules(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7),
  daily_schedule_id uuid not null references public.daily_schedules(id) on delete cascade,
  priority integer not null check (priority >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index week_schedule_day_assignments_unique_priority_idx
  on public.week_schedule_day_assignments(week_schedule_id, day_of_week, priority);

create unique index week_schedule_day_assignments_unique_schedule_idx
  on public.week_schedule_day_assignments(week_schedule_id, day_of_week, daily_schedule_id);

create table public.overrides (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  created_by_auth_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  starts_at timestamptz not null,
  ends_at timestamptz null,
  until_next_segment boolean not null default false,
  peak_shaving_w integer null check (peak_shaving_w is null or (peak_shaving_w >= 0 and peak_shaving_w % 100 = 0)),
  grid_charging_allowed boolean null,
  is_active boolean not null default true,
  constraint overrides_end_after_start check (ends_at is null or ends_at > starts_at),
  constraint overrides_has_effect check (peak_shaving_w is not null or grid_charging_allowed is not null)
);

create index overrides_active_window_idx
  on public.overrides(plant_id, is_active, starts_at, ends_at);

create table public.plant_runtime (
  plant_id uuid primary key references public.plants(id) on delete cascade,
  next_due_at timestamptz null,
  last_applied_at timestamptz null,
  last_applied_peak_shaving_w integer null check (last_applied_peak_shaving_w is null or (last_applied_peak_shaving_w >= 0 and last_applied_peak_shaving_w % 100 = 0)),
  last_applied_grid_charging_allowed boolean null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.control_apply_log (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  requested_peak_shaving_w integer not null check (requested_peak_shaving_w >= 0 and requested_peak_shaving_w % 100 = 0),
  requested_grid_charging_allowed boolean not null,
  provider_type public.provider_type not null,
  provider_result public.provider_result not null,
  provider_http_status integer null,
  provider_response jsonb null
);

create index control_apply_log_plant_attempted_at_idx
  on public.control_apply_log(plant_id, attempted_at desc);

create table public.provider_connections (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  provider_type public.provider_type not null,
  display_name text not null check (length(trim(display_name)) > 0),
  config_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plant_id, provider_type)
);

create table public.provider_secrets (
  plant_id uuid not null references public.plants(id) on delete cascade,
  provider_type public.provider_type not null,
  encrypted_json text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (plant_id, provider_type)
);

create table public.user_settings (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  theme_mode public.theme_mode not null default 'system',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.enforce_active_collection_plant_match()
returns trigger
language plpgsql
as $$
declare
  collection_plant_id uuid;
begin
  if new.active_schedule_collection_id is null then
    return new;
  end if;

  select sc.plant_id
    into collection_plant_id
  from public.schedule_collections sc
  where sc.id = new.active_schedule_collection_id;

  if collection_plant_id is null then
    raise exception 'active_schedule_collection_id % does not exist', new.active_schedule_collection_id;
  end if;

  if collection_plant_id <> new.id then
    raise exception 'active_schedule_collection_id % does not belong to plant %', new.active_schedule_collection_id, new.id;
  end if;

  return new;
end;
$$;

create trigger plants_active_collection_match_trg
before insert or update of active_schedule_collection_id
on public.plants
for each row
execute function public.enforce_active_collection_plant_match();

create or replace function public.enforce_week_assignment_collection_match()
returns trigger
language plpgsql
as $$
declare
  week_collection_id uuid;
  daily_collection_id uuid;
begin
  select ws.schedule_collection_id
    into week_collection_id
  from public.week_schedules ws
  where ws.id = new.week_schedule_id;

  if week_collection_id is null then
    raise exception 'week_schedule_id % does not exist', new.week_schedule_id;
  end if;

  select ds.schedule_collection_id
    into daily_collection_id
  from public.daily_schedules ds
  where ds.id = new.daily_schedule_id;

  if daily_collection_id is null then
    raise exception 'daily_schedule_id % does not exist', new.daily_schedule_id;
  end if;

  if week_collection_id <> daily_collection_id then
    raise exception
      'daily_schedule_id % must belong to same schedule_collection as week_schedule_id %',
      new.daily_schedule_id,
      new.week_schedule_id;
  end if;

  return new;
end;
$$;

create trigger week_schedule_day_assignments_match_trg
before insert or update of week_schedule_id, daily_schedule_id
on public.week_schedule_day_assignments
for each row
execute function public.enforce_week_assignment_collection_match();

create trigger plants_set_updated_at_trg
before update on public.plants
for each row
execute function public.set_updated_at();

create trigger plant_invites_set_updated_at_trg
before update on public.plant_invites
for each row
execute function public.set_updated_at();

create trigger schedule_collections_set_updated_at_trg
before update on public.schedule_collections
for each row
execute function public.set_updated_at();

create trigger daily_schedules_set_updated_at_trg
before update on public.daily_schedules
for each row
execute function public.set_updated_at();

create trigger week_schedules_set_updated_at_trg
before update on public.week_schedules
for each row
execute function public.set_updated_at();

create trigger week_schedule_day_assignments_set_updated_at_trg
before update on public.week_schedule_day_assignments
for each row
execute function public.set_updated_at();

create trigger plant_runtime_set_updated_at_trg
before update on public.plant_runtime
for each row
execute function public.set_updated_at();

create trigger provider_connections_set_updated_at_trg
before update on public.provider_connections
for each row
execute function public.set_updated_at();

create trigger provider_secrets_set_updated_at_trg
before update on public.provider_secrets
for each row
execute function public.set_updated_at();

create trigger user_settings_set_updated_at_trg
before update on public.user_settings
for each row
execute function public.set_updated_at();

create trigger plant_invites_normalize_email_trg
before insert or update of invited_email
on public.plant_invites
for each row
execute function public.normalize_invite_email();

create or replace function public.is_plant_member(p_plant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.plant_members pm
    where pm.plant_id = p_plant_id
      and pm.auth_user_id = auth.uid()
  );
$$;

create or replace function public.has_plant_role(p_plant_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.plant_members pm
    where pm.plant_id = p_plant_id
      and pm.auth_user_id = auth.uid()
      and pm.role::text = any(p_roles)
  );
$$;

grant execute on function public.is_plant_member(uuid) to authenticated;
grant execute on function public.has_plant_role(uuid, text[]) to authenticated;

alter table public.plants enable row level security;
alter table public.plant_members enable row level security;
alter table public.plant_invites enable row level security;
alter table public.schedule_collections enable row level security;
alter table public.daily_schedules enable row level security;
alter table public.time_segments enable row level security;
alter table public.week_schedules enable row level security;
alter table public.week_schedule_day_assignments enable row level security;
alter table public.overrides enable row level security;
alter table public.plant_runtime enable row level security;
alter table public.control_apply_log enable row level security;
alter table public.provider_connections enable row level security;
alter table public.provider_secrets enable row level security;
alter table public.user_settings enable row level security;

create policy plants_select_member
  on public.plants
  for select
  using (public.is_plant_member(id));

create policy plants_mutate_owner_admin
  on public.plants
  for all
  using (public.has_plant_role(id, array['owner', 'admin']))
  with check (public.has_plant_role(id, array['owner', 'admin']));

create policy plant_members_select_member
  on public.plant_members
  for select
  using (public.is_plant_member(plant_id));

create policy plant_members_mutate_owner_admin
  on public.plant_members
  for all
  using (public.has_plant_role(plant_id, array['owner', 'admin']))
  with check (public.has_plant_role(plant_id, array['owner', 'admin']));

create policy plant_invites_select_owner_admin
  on public.plant_invites
  for select
  using (public.has_plant_role(plant_id, array['owner', 'admin']));

create policy plant_invites_mutate_owner_admin
  on public.plant_invites
  for all
  using (public.has_plant_role(plant_id, array['owner', 'admin']))
  with check (public.has_plant_role(plant_id, array['owner', 'admin']));

create policy schedule_collections_select_member
  on public.schedule_collections
  for select
  using (public.is_plant_member(plant_id));

create policy schedule_collections_mutate_editors
  on public.schedule_collections
  for all
  using (public.has_plant_role(plant_id, array['owner', 'admin', 'member']))
  with check (public.has_plant_role(plant_id, array['owner', 'admin', 'member']));

create policy daily_schedules_select_member
  on public.daily_schedules
  for select
  using (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = daily_schedules.schedule_collection_id
        and public.is_plant_member(sc.plant_id)
    )
  );

create policy daily_schedules_mutate_editors
  on public.daily_schedules
  for all
  using (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = daily_schedules.schedule_collection_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  )
  with check (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = daily_schedules.schedule_collection_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  );

create policy time_segments_select_member
  on public.time_segments
  for select
  using (
    exists (
      select 1
      from public.daily_schedules ds
      join public.schedule_collections sc on sc.id = ds.schedule_collection_id
      where ds.id = time_segments.daily_schedule_id
        and public.is_plant_member(sc.plant_id)
    )
  );

create policy time_segments_mutate_editors
  on public.time_segments
  for all
  using (
    exists (
      select 1
      from public.daily_schedules ds
      join public.schedule_collections sc on sc.id = ds.schedule_collection_id
      where ds.id = time_segments.daily_schedule_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  )
  with check (
    exists (
      select 1
      from public.daily_schedules ds
      join public.schedule_collections sc on sc.id = ds.schedule_collection_id
      where ds.id = time_segments.daily_schedule_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  );

create policy week_schedules_select_member
  on public.week_schedules
  for select
  using (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = week_schedules.schedule_collection_id
        and public.is_plant_member(sc.plant_id)
    )
  );

create policy week_schedules_mutate_editors
  on public.week_schedules
  for all
  using (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = week_schedules.schedule_collection_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  )
  with check (
    exists (
      select 1
      from public.schedule_collections sc
      where sc.id = week_schedules.schedule_collection_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  );

create policy week_schedule_day_assignments_select_member
  on public.week_schedule_day_assignments
  for select
  using (
    exists (
      select 1
      from public.week_schedules ws
      join public.schedule_collections sc on sc.id = ws.schedule_collection_id
      where ws.id = week_schedule_day_assignments.week_schedule_id
        and public.is_plant_member(sc.plant_id)
    )
  );

create policy week_schedule_day_assignments_mutate_editors
  on public.week_schedule_day_assignments
  for all
  using (
    exists (
      select 1
      from public.week_schedules ws
      join public.schedule_collections sc on sc.id = ws.schedule_collection_id
      where ws.id = week_schedule_day_assignments.week_schedule_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  )
  with check (
    exists (
      select 1
      from public.week_schedules ws
      join public.schedule_collections sc on sc.id = ws.schedule_collection_id
      where ws.id = week_schedule_day_assignments.week_schedule_id
        and public.has_plant_role(sc.plant_id, array['owner', 'admin', 'member'])
    )
  );

create policy overrides_select_member
  on public.overrides
  for select
  using (public.is_plant_member(plant_id));

create policy overrides_mutate_editors
  on public.overrides
  for all
  using (public.has_plant_role(plant_id, array['owner', 'admin', 'member']))
  with check (public.has_plant_role(plant_id, array['owner', 'admin', 'member']));

create policy plant_runtime_select_member
  on public.plant_runtime
  for select
  using (public.is_plant_member(plant_id));

create policy control_apply_log_select_member
  on public.control_apply_log
  for select
  using (public.is_plant_member(plant_id));

create policy provider_connections_select_member
  on public.provider_connections
  for select
  using (public.is_plant_member(plant_id));

create policy provider_connections_mutate_owner_admin
  on public.provider_connections
  for all
  using (public.has_plant_role(plant_id, array['owner', 'admin']))
  with check (public.has_plant_role(plant_id, array['owner', 'admin']));

create policy user_settings_select_own
  on public.user_settings
  for select
  using (auth.uid() = auth_user_id);

create policy user_settings_mutate_own
  on public.user_settings
  for all
  using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);

commit;
