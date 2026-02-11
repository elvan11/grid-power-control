# Manual Setup Checklist (Supabase Auth + Function Secrets + GitHub)

Project reference: `dxkmcxtalenyziaaxigd`  
Supabase URL: `https://dxkmcxtalenyziaaxigd.supabase.co`  
Executor endpoint URL: `https://dxkmcxtalenyziaaxigd.functions.supabase.co/executor_tick`

## 1) Supabase Auth providers (manual in dashboard)

Open: Supabase Dashboard -> `grid-power-control` -> Authentication -> Providers.

Enable and configure:
- Google
- Microsoft
- Apple

Add each provider's client ID / secret from its provider console.

## 2) Supabase Auth redirect URLs (manual in dashboard)

Open: Supabase Dashboard -> Authentication -> URL Configuration.

Set allowed redirects to include:
- `gridpowercontrol://auth/callback`
- `gridpowercontrol://auth/accept-invite`
- `http://localhost:3000/#/auth/callback`
- `http://localhost:8080/#/auth/callback`
- `http://localhost:5173/#/auth/callback`
- `https://<your-production-domain>/#/auth/callback`
- `https://<your-production-domain>/#/auth/accept-invite`

Use your real production domain values before release.

## 3) Supabase Edge Function secrets (manual in dashboard)

Open: Supabase Dashboard -> Project Settings -> Edge Functions -> Secrets.

Set required:
- `EXECUTOR_SECRET=<same value as GitHub EXECUTOR_SECRET>`
- `PROVIDER_SECRETS_ENCRYPTION_KEY=<base64-encoded 16/24/32-byte key>`

Optional but recommended:
- `SOLIS_PEAK_SHAVING_MIN_W=0`
- `SOLIS_PEAK_SHAVING_MAX_W=10000`
- `SOLIS_API_BASE_URL=https://www.soliscloud.com:13333`

Invite email delivery (optional):
- `RESEND_API_KEY=<resend-api-key>`
- `SHARE_INVITES_FROM_EMAIL=Grid Power Control <noreply@your-domain>`
- `SHARE_INVITES_BASE_URL=https://<your-production-domain>/#/auth/accept-invite`

## 4) Apply database migrations (required)

From repository root, run:
- `supabase db push --project-ref dxkmcxtalenyziaaxigd`

Minimum required migration set includes:
- `20260209094000_initial_schema.sql`
- `20260209120500_schedule_collection_bootstrap.sql`
- `20260209122500_scheduling_rpc.sql`
- `20260209143000_executor_helpers.sql`
- `20260211112907_executor_claim_due_5m_window.sql`

If this step is skipped, installation creation fails with missing RPC errors such as `create_plant_with_defaults`.

## 5) Deploy functions (manual via CLI)

Deploy:
- `provider_connection_upsert` (`--no-verify-jwt`)
- `provider_connection_test` (`--no-verify-jwt`)
- `provider_apply_control` (`--no-verify-jwt`)
- `executor_tick` (`--no-verify-jwt`)
- `plant_sharing_list`
- `plant_sharing_invite`
- `plant_sharing_revoke_invite`
- `plant_sharing_remove_member`
- `plant_sharing_accept_invite`

Note for web clients (GitHub Pages): browser preflight (`OPTIONS`) must receive `200`. Using `--no-verify-jwt` avoids gateway-level preflight rejection; these functions still require user auth in-function via `Authorization` bearer validation.

## 6) Configure Supabase Cron (primary scheduler)

Use Supabase SQL Editor and set Vault secrets:
- `select vault.create_secret('https://dxkmcxtalenyziaaxigd.functions.supabase.co/executor_tick', 'executor_tick_url');`
- `select vault.create_secret('<same value as EXECUTOR_SECRET>', 'executor_secret');`

Create/update the 15-minute cron:
- `select public.configure_executor_tick_cron('14,29,44,59 * * * *', 'executor-tick-15m', 30);`

Executor timing behavior:
- Plants are claimed when `next_due_at <= now() + 5 minutes`.
- Segment transitions are evaluated with a 5-minute lookahead, so a boundary at `04:00` is handled when a tick lands in `03:55` through `04:04:59`.

Verify scheduled job exists:
- `select jobid, jobname, schedule, command from cron.job where jobname = 'executor-tick-15m';`

## 7) Optional GitHub Actions fallback secrets (already configured in repo)

Repository `elvan11/grid-power-control` now has:
- `SUPABASE_EXECUTOR_TICK_URL`
- `EXECUTOR_SECRET`
- `SUPABASE_URL` (for Flutter web build)
- `SUPABASE_ANON_KEY` (for Flutter web build)

Verify any time:
- `gh secret list`

## 8) Post-setup verification

1. Confirm `executor-tick-15m` appears in `cron.job`.
2. Check recent runs in `cron.job_run_details`.
3. Trigger `.github/workflows/executor.yml` manually only as fallback, and confirm `executor_tick` returns HTTP 200.
4. Trigger `.github/workflows/deploy-web.yml` manually and wait for green deploy.
5. Open `https://elvan11.github.io/grid-power-control/` and verify app loads.
6. Test OAuth login on mobile/web.
7. Test sharing invite flow:
   - Add invite email in app
   - Open invite link
   - Accept invite after sign-in

## 9) GitHub Pages plan constraint

Current repo visibility is `PRIVATE`. GitHub API returned:
- `"Your current plan does not support GitHub Pages for this repository."`

To publish to GitHub Pages, either:
- Make the repository public, or
- Upgrade to a plan that supports Pages for private repositories.
