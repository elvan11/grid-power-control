begin;
do $$
begin
 assert not has_function_privilege('anon','public.get_executor_secret_from_vault()','execute');
 assert not has_function_privilege('authenticated','public.get_executor_secret_from_vault()','execute');
 assert not has_function_privilege('anon','public.configure_executor_tick_cron(text,text,integer)','execute');
 assert not has_function_privilege('authenticated','public.remove_executor_tick_cron(text)','execute');
 assert has_function_privilege('service_role','public.get_executor_secret_from_vault()','execute');
 assert has_function_privilege('authenticated','public.compute_plant_desired_control(uuid,timestamptz)','execute');
 assert not has_function_privilege('anon','public.compute_plant_desired_control(uuid,timestamptz)','execute');
end $$;
rollback;
