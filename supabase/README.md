# Supabase Workflow

This directory contains SQL migrations for the Supabase project.

Manual setup runbook:
- `docs/manual-setup-checklist.md`

## Apply migrations

1. Install Supabase CLI.
2. Link the project:
   - `supabase link --project-ref <project-ref>`
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
- `provider_battery_soc` - reads station battery SOC from Solis (`/v1/api/stationDetail`) for Today page display
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
- `supabase functions deploy provider_battery_soc`
- For browser clients (web), deploy the provider functions above with `--no-verify-jwt` so CORS preflight `OPTIONS` is accepted at the gateway.
- `supabase functions deploy executor_tick --no-verify-jwt`
- `supabase functions deploy plant_sharing_list`
- `supabase functions deploy plant_sharing_invite`
- `supabase functions deploy plant_sharing_revoke_invite`
- `supabase functions deploy plant_sharing_remove_member`
- `supabase functions deploy plant_sharing_accept_invite`

## Edge Function unit tests (local)

Current unit tests:
- `supabase/functions/_shared/solis_test.ts` (mocked Solis API; no live provider calls)
- `supabase/functions/provider_apply_control/handler_test.ts` (unit tests with injected auth/store/provider deps)
- `supabase/functions/provider_battery_soc/handler_test.ts` (station SOC retrieval handler tests with injected auth/store/provider deps)
- `supabase/functions/provider_connection_test/handler_test.ts` (inline vs stored credential flow tests)
- `supabase/functions/provider_connection_upsert/handler_test.ts` (upsert flow + validation tests)
- `supabase/functions/executor_tick/handler_test.ts` (executor auth/method behavior)
- `supabase/functions/plant_sharing_list/handler_test.ts` (method + payload validation behavior)
- `supabase/functions/plant_sharing_invite/handler_test.ts` (method + payload validation behavior)
- `supabase/functions/plant_sharing_revoke_invite/handler_test.ts` (method + payload validation behavior)
- `supabase/functions/plant_sharing_remove_member/handler_test.ts` (method + payload validation behavior)
- `supabase/functions/plant_sharing_accept_invite/handler_test.ts` (method + auth validation behavior)

Run:
- `npm run test:handlers` (runs all `supabase/functions/**/*_test.ts` using Vitest)

## Post-deploy smoke test

Run a safe endpoint/auth smoke test after deploy:
- `./scripts/smoke/smoke_edge_functions.ps1 -ProjectRef <project_ref>`
- Or (if linked locally): `./scripts/smoke/smoke_edge_functions.ps1`

What it checks per function:
- `OPTIONS` returns `200` (CORS/preflight path reachable)
- `GET` returns `405` (method guard works)
- `POST` without auth returns `401` (auth/secret guard works)

Optional authenticated checks:
- `./scripts/smoke/smoke_edge_functions.ps1 -ProjectRef <project_ref> -IncludeAuthenticatedChecks -UserJwt "<access_token>" -ExecutorSecret "<executor_secret>"`

Authenticated mode behavior:
- User-auth functions: sends authenticated `POST {}` and expects `400` (proves request passed auth and reached handler validation, without mutating data).
- `executor_tick`: sends authenticated `POST {}` with executor secret and expects `200`.

Set secrets example:
- `supabase secrets set PROVIDER_SECRETS_ENCRYPTION_KEY=<base64-key>`
- `supabase secrets set EXECUTOR_SECRET=<shared-secret>`
- `supabase secrets set SOLIS_PEAK_SHAVING_MIN_W=0 SOLIS_PEAK_SHAVING_MAX_W=10000`
- `supabase secrets set RESEND_API_KEY=<resend-key> SHARE_INVITES_FROM_EMAIL="Grid Power Control <noreply@example.com>" SHARE_INVITES_BASE_URL="https://your-web-app/#/auth/accept-invite"`
