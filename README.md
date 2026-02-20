# Grid Power Control

Grid Power Control is a Flutter app for scheduled control of solar + battery installations.

It lets users define weekly schedules for:
- Peak shaving power limit (W)
- Grid charging allow/disallow

The app connects to Supabase for auth/data/functions and uses SolisCloud as the first provider integration.

## What it does

- Manage multiple installations (plants)
- Create and edit daily schedules made of time segments
- Assign schedules by day of week in a weekly view
- Enforce 100 W control granularity for peak shaving
- Apply manual control instantly from the Today screen (initialized from current active control values on open)
- Create temporary overrides
- Connect and test SolisCloud credentials
- Share plant access (invites, members, role-based access)
- Run scheduled control execution through Supabase Cron (`pg_cron` + `pg_net`)

## Tech stack

- Flutter (mobile + web)
- Riverpod
- GoRouter
- Supabase
  - Postgres + RLS
  - Edge Functions (Deno/TypeScript)
  - Auth (OAuth + email/password)
- SolisCloud API

## Repository layout

- `app/`: Flutter application
- `supabase/migrations/`: SQL schema + RPC migrations
- `supabase/functions/`: Edge Functions and shared provider logic
- `docs/`: implementation/testing/setup notes
- `references/`: SolisCloud API references and example scripts

## Quick start

### Prerequisites

- Flutter SDK (stable)
- Dart SDK (from Flutter)
- Supabase CLI (for backend setup)

### 1) Run app locally (offline preview mode)

From repo root:

```bash
cd app
flutter pub get
flutter run
```

If `SUPABASE_URL` and `SUPABASE_ANON_KEY` are not provided, the app runs in local preview mode with fallback/local data behavior.

### 2) Run app locally with Supabase

```bash
cd app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

For web:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

### 3) Build Android APK with Supabase defines

Use the repo script (PowerShell) so login-capable APKs are built consistently:

```powershell
./scripts/build_android_apk.ps1 `
  -BuildMode debug `
  -SupabaseUrl https://YOUR_PROJECT_REF.supabase.co `
  -SupabaseAnonKey YOUR_SUPABASE_ANON_KEY
```

You can also use environment variables:

```powershell
$env:SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
./scripts/build_android_apk.ps1 -BuildMode debug
```

Optional flags:
- `-SplitPerAbi` to generate one APK per ABI.
- `-Clean` to run `flutter clean` before building.

## Backend setup (Supabase)

Detailed manual setup steps live in `docs/manual-setup-checklist.md`.

High-level flow:

1. Link Supabase project:

```bash
supabase link --project-ref <your-project-ref>
```

2. Apply migrations:

```bash
supabase db push
```

3. Set required Edge Function secrets:

- `PROVIDER_SECRETS_ENCRYPTION_KEY`
- `EXECUTOR_SECRET`

Recommended:

- `SOLIS_API_BASE_URL`
- `SOLIS_PEAK_SHAVING_MIN_W`
- `SOLIS_PEAK_SHAVING_MAX_W`
- `RESEND_API_KEY` (for invite email delivery)
- `SHARE_INVITES_FROM_EMAIL`
- `SHARE_INVITES_BASE_URL`

4. Deploy functions:

```bash
supabase functions deploy provider_connection_upsert --no-verify-jwt
supabase functions deploy provider_connection_test --no-verify-jwt
supabase functions deploy provider_apply_control --no-verify-jwt
supabase functions deploy executor_tick --no-verify-jwt
supabase functions deploy plant_sharing_list
supabase functions deploy plant_sharing_invite
supabase functions deploy plant_sharing_revoke_invite
supabase functions deploy plant_sharing_remove_member
supabase functions deploy plant_sharing_accept_invite
```

Notes:
- `--no-verify-jwt` is used on browser-called provider functions and `executor_tick` to avoid CORS preflight gateway rejection.
- Auth/authorization checks are still enforced in function code.

### Configure scheduler in Supabase (15-minute tick)

This repo includes migrations:
- `supabase/migrations/20260210113000_executor_cron_pg_net.sql` (cron wiring)
- `supabase/migrations/20260211112907_executor_claim_due_5m_window.sql` (executor due-claim lookahead window)

These implement a segment-change application window of about `-5m/+5m`:
- plants are considered due when `next_due_at <= now() + 5 minutes`
- executor evaluates schedule desired state at `now + 5 minutes` (except active overrides, which use current time)

Cron can remain at `14,29,44,59` and still apply segment transitions around the boundary window.

The cron migration adds:
- `public.configure_executor_tick_cron(...)`
- `public.remove_executor_tick_cron(...)`

Store endpoint + shared secret in Vault (one-time):

```sql
select vault.create_secret('https://<project-ref>.functions.supabase.co/executor_tick', 'executor_tick_url');
select vault.create_secret('<same-value-as-EXECUTOR_SECRET>', 'executor_secret');
```

Create/update the 15-minute cron job:

```sql
select public.configure_executor_tick_cron('14,29,44,59 * * * *', 'executor-tick-15m', 30);
```

## CI/CD workflows

- `/.github/workflows/deploy-web.yml`
  - Runs analyze + tests + Flutter web build
  - Publishes production site to GitHub Pages root (`/`)
  - Preserves QA files under `/qa/`
- `/.github/workflows/publish-qa-android.yml`
  - Manual only (`workflow_dispatch`)
  - Publishes QA web build to GitHub Pages `/qa/` without touching production root files
- `/.github/workflows/executor.yml`
  - Manual fallback trigger (`workflow_dispatch`) to call `executor_tick`
  - Optional backup path if you want an out-of-band trigger

## SolisCloud controls

Current command mapping:

- CID `5035`: peak shaving grid power limit (W)
  - Uses `atRead` first and includes returned `yuanzhi` in `/v2/api/control`
- CID `5041`: allow/disallow grid charging
  - Requires `atRead` first and includes returned `yuanzhi` in `/v2/api/control`

Reference scripts:

- `references/poll_solis_atread.py`
- `references/apply_schedule_slot.py`

## Security model

- RLS policies protect per-plant data access via membership
- Provider credentials are encrypted and stored server-side
- Client never reads decrypted provider secrets
- Scheduled executor endpoint uses shared-secret authorization

## Documentation

- Product/base requirements: `base-needs.md`
- Implementation tracker: `docs/implementation-plan.md`
- Manual setup checklist: `docs/manual-setup-checklist.md`
- Test strategy: `docs/testing-plan.md`
- Responsive web QA workflow: `docs/responsive-qa.md`
- Supabase dev notes: `supabase/README.md`

## Project status

Active development. Core scheduling, provider integration, executor, and sharing flows are implemented; testing depth and release hardening are still in progress.
