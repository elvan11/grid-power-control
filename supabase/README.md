# Supabase Workflow

This directory contains SQL migrations for the Supabase project `dxkmcxtalenyziaaxigd`.

## Apply migrations

1. Install Supabase CLI.
2. Link the project:
   - `supabase link --project-ref dxkmcxtalenyziaaxigd`
3. Push migrations:
   - `supabase db push`

## New migrations

Create timestamped migrations in `supabase/migrations/`:
- `supabase migration new <name>`

Then edit the SQL file and commit it.

## Executor cron workflow

GitHub Actions workflow:
- `.github/workflows/executor.yml`

Required repository secrets:
- `SUPABASE_EXECUTOR_TICK_URL` (full HTTPS URL to `executor_tick` Edge Function)
- `EXECUTOR_SECRET` (shared secret expected by the function)

## Solis provider Edge Functions

Implemented functions:
- `provider_connection_upsert` - stores `provider_connections` + encrypted `provider_secrets`
- `provider_connection_test` - tests Solis API connectivity with sanitized response
- `provider_apply_control` - applies CID `5035` and `43110`, logs attempts to `control_apply_log`
- `executor_tick` - claims due plants, computes desired controls, applies only when changed, logs audit outcomes

Required function secrets/environment variables:
- `PROVIDER_SECRETS_ENCRYPTION_KEY` (base64-encoded AES key; 16/24/32 bytes)
- `SOLIS_API_BASE_URL` (optional, default `https://www.soliscloud.com:13333`)
- `SOLIS_PEAK_SHAVING_MIN_W` (optional, default `0`)
- `SOLIS_PEAK_SHAVING_MAX_W` (optional, default `10000`)
- `EXECUTOR_SECRET` (required by `executor_tick` shared-secret auth)

Deploy example:
- `supabase functions deploy provider_connection_upsert`
- `supabase functions deploy provider_connection_test`
- `supabase functions deploy provider_apply_control`
- `supabase functions deploy executor_tick --no-verify-jwt`

Set secrets example:
- `supabase secrets set PROVIDER_SECRETS_ENCRYPTION_KEY=<base64-key>`
- `supabase secrets set EXECUTOR_SECRET=<shared-secret>`
- `supabase secrets set SOLIS_PEAK_SHAVING_MIN_W=0 SOLIS_PEAK_SHAVING_MAX_W=10000`
