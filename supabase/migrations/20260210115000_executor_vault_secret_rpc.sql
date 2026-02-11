-- Helper to read executor secret from Vault through RPC.
-- Edge Functions can call this without direct PostgREST access to vault schema objects.

create or replace function public.get_executor_secret_from_vault()
returns text
language sql
security definer
set search_path = public
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = 'executor_secret'
  order by created_at desc
  limit 1;
$$;

revoke all on function public.get_executor_secret_from_vault() from public;
grant execute on function public.get_executor_secret_from_vault() to postgres, service_role;
