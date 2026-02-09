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
