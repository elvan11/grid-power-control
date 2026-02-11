-- Configure Supabase-native cron trigger for executor_tick via pg_cron + pg_net.
-- This is intended to replace GitHub Actions scheduled triggering.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net;

create or replace function public.configure_executor_tick_cron(
  p_cron text default '14,29,44,59 * * * *',
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

create or replace function public.remove_executor_tick_cron(
  p_job_name text default 'executor-tick-15m'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_removed integer := 0;
begin
  for v_removed in
    select jobid
    from cron.job
    where jobname = p_job_name
  loop
    perform cron.unschedule(v_removed);
  end loop;

  if exists (select 1 from cron.job where jobname = p_job_name) then
    return 0;
  end if;

  return 1;
end;
$$;

revoke all on function public.configure_executor_tick_cron(text, text, integer) from public;
revoke all on function public.remove_executor_tick_cron(text) from public;
grant execute on function public.configure_executor_tick_cron(text, text, integer) to postgres, service_role;
grant execute on function public.remove_executor_tick_cron(text) to postgres, service_role;
