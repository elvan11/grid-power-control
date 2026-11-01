begin;
-- Default hosted grants can survive REVOKE FROM PUBLIC on older functions.
revoke all on function public.get_executor_secret_from_vault() from public,anon,authenticated;
revoke all on function public.configure_executor_tick_cron(text,text,integer) from public,anon,authenticated;
revoke all on function public.remove_executor_tick_cron(text) from public,anon,authenticated;
grant execute on function public.get_executor_secret_from_vault() to service_role;
grant execute on function public.configure_executor_tick_cron(text,text,integer) to service_role;
grant execute on function public.remove_executor_tick_cron(text) to service_role;
revoke all on function public.compute_plant_desired_control(uuid,timestamptz) from anon;
revoke all on function public.replace_daily_schedule_segments(uuid,jsonb) from anon;
commit;
