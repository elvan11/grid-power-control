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

## 4) Deploy functions (manual via CLI)

Deploy:
- `provider_connection_upsert`
- `provider_connection_test`
- `provider_apply_control`
- `executor_tick` (`--no-verify-jwt`)
- `plant_sharing_list`
- `plant_sharing_invite`
- `plant_sharing_revoke_invite`
- `plant_sharing_remove_member`
- `plant_sharing_accept_invite`

## 5) GitHub Actions secrets (already configured in repo)

Repository `elvan11/grid-power-control` now has:
- `SUPABASE_EXECUTOR_TICK_URL`
- `EXECUTOR_SECRET`
- `SUPABASE_URL` (for Flutter web build)
- `SUPABASE_ANON_KEY` (for Flutter web build)

Verify any time:
- `gh secret list`

## 6) Post-setup verification

1. Trigger `.github/workflows/executor.yml` manually from GitHub Actions.
2. Confirm successful `executor_tick` call (HTTP 200).
3. Trigger `.github/workflows/deploy-web.yml` manually and wait for green deploy.
4. Open `https://elvan11.github.io/grid-power-control/` and verify app loads.
5. Test OAuth login on mobile/web.
6. Test sharing invite flow:
   - Add invite email in app
   - Open invite link
   - Accept invite after sign-in

## 7) GitHub Pages plan constraint

Current repo visibility is `PRIVATE`. GitHub API returned:
- `"Your current plan does not support GitHub Pages for this repository."`

To publish to GitHub Pages, either:
- Make the repository public, or
- Upgrade to a plan that supports Pages for private repositories.
