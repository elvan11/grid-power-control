# Supabase Workflow

This directory contains SQL migrations for the Supabase project `dxkmcxtalenyziaaxigd`.

Manual setup runbook:
- `docs/manual-setup-checklist.md`

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

## Executor scheduling (Supabase Cron)

Primary scheduler is Supabase Cron (`pg_cron` + `pg_net`) via migration:
- `supabase/migrations/20260210113000_executor_cron_pg_net.sql`
- `supabase/migrations/20260211112907_executor_claim_due_5m_window.sql` (executor claims due plants up to 5 minutes ahead)

One-time setup in SQL editor:
- `select vault.create_secret('https://<project-ref>.functions.supabase.co/executor_tick', 'executor_tick_url');`
- `select vault.create_secret('<same-value-as-EXECUTOR_SECRET>', 'executor_secret');`
- `select public.configure_executor_tick_cron('14,29,44,59 * * * *', 'executor-tick-15m', 30);`

Runtime behavior:
- `claim_due_plants` now claims plants with `next_due_at <= now() + 5 minutes`.
- `executor_tick` computes schedule desired state at `now + 5 minutes` for schedule-driven controls (active overrides still use current time).
- This yields practical segment transition handling inside a `-5m/+5m` window without requiring exact cron second alignment.

Optional manual fallback:
- `.github/workflows/executor.yml` (`workflow_dispatch` only)

## Solis provider Edge Functions

Implemented functions:
- `provider_connection_upsert` - stores `provider_connections` + encrypted `provider_secrets`
- `provider_connection_test` - tests Solis API connectivity with sanitized response
- `provider_apply_control` - applies CID `5035` and `5041` (with `atRead` + `yuanzhi` pre-read for `5041`), logs attempts to `control_apply_log`
- `executor_tick` - claims due plants (5-minute lookahead), computes desired controls, applies only when changed, logs audit outcomes
- `plant_sharing_list` - lists plant members and invites (owner/admin)
- `plant_sharing_invite` - creates/reissues invite token and optionally sends email
- `plant_sharing_revoke_invite` - revokes a pending invite
- `plant_sharing_remove_member` - removes plant member with last-owner protections
- `plant_sharing_accept_invite` - accepts invite token for authenticated user email

Required function secrets/environment variables:
- `PROVIDER_SECRETS_ENCRYPTION_KEY` (base64-encoded AES key; 16/24/32 bytes)
- `SOLIS_API_BASE_URL` (optional, default `https://www.soliscloud.com:13333`)
- `SOLIS_PEAK_SHAVING_MIN_W` (optional, default `0`)
- `SOLIS_PEAK_SHAVING_MAX_W` (optional, default `10000`)
- `EXECUTOR_SECRET` (required by `executor_tick` shared-secret auth)
- `RESEND_API_KEY` (optional; enables invite emails)
- `SHARE_INVITES_FROM_EMAIL` (optional; sender identity for invite emails, e.g. `Grid Power Control <noreply@example.com>`)
- `SHARE_INVITES_BASE_URL` (optional; invite URL base or template with `{token}`; default `gridpowercontrol://auth/accept-invite`)

Deploy example:
- `supabase functions deploy provider_connection_upsert`
- `supabase functions deploy provider_connection_test`
- `supabase functions deploy provider_apply_control`
- For browser clients (web), deploy the three provider functions above with `--no-verify-jwt` so CORS preflight `OPTIONS` is accepted at the gateway.
- `supabase functions deploy executor_tick --no-verify-jwt`
- `supabase functions deploy plant_sharing_list`
- `supabase functions deploy plant_sharing_invite`
- `supabase functions deploy plant_sharing_revoke_invite`
- `supabase functions deploy plant_sharing_remove_member`
- `supabase functions deploy plant_sharing_accept_invite`

Set secrets example:
- `supabase secrets set PROVIDER_SECRETS_ENCRYPTION_KEY=<base64-key>`
- `supabase secrets set EXECUTOR_SECRET=<shared-secret>`
- `supabase secrets set SOLIS_PEAK_SHAVING_MIN_W=0 SOLIS_PEAK_SHAVING_MAX_W=10000`
- `supabase secrets set RESEND_API_KEY=<resend-key> SHARE_INVITES_FROM_EMAIL="Grid Power Control <noreply@example.com>" SHARE_INVITES_BASE_URL="https://your-web-app/#/auth/accept-invite"`
