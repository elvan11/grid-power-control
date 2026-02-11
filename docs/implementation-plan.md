# Grid Power Control — Implementation Plan (Supabase + Flutter only)

This plan implements the requirements in `base-needs.md` using only:
- Flutter mobile app (Android/iOS) + Flutter web
- Supabase project **grid-power-control** (`dxkmcxtalenyziaaxigd`) for Auth + Postgres + Edge Functions
- SolisCloud as the first “power control cloud service” (extensible provider module design)

Tooling note (optional): if your Codex setup has **Supabase MCP** and **Stitch MCP**, use them to (1) inspect/manage the Supabase project (`dxkmcxtalenyziaaxigd`) and (2) pull UI screens/widgets/tokens from Stitch project `14483047077387457262`.

## 0) Reality check (Supabase constraints)

- Supabase does not host arbitrary backend app runtimes; server-side code in Supabase is primarily:
  - Postgres (SQL, triggers, RLS, extensions like `vault`)
  - Supabase Edge Functions (Deno/TypeScript)
- On the free tier, Supabase scheduled functions/cron may not be available. For MVP, trigger the “executor/worker” via **GitHub Actions cron** calling an Edge Function endpoint.
- Provider secrets must never live in Flutter; they must be stored server-side (encrypted) and used only by Edge Functions.

## 1) Requirements coverage (from `base-needs.md`)

- [ ] Weekly control schedules exist (daily schedules + weekly assignment with priority)
- [ ] Peak shaving level is in 100 W steps (validated server-side, enforced in UI, and applied to SolisCloud in 100 W granularity)
- [ ] Grid charging allow/disallow is independent of peak shaving (per time segment)
- [ ] Multiple daily schedules can be created, stored, duplicated, deleted (with “in use” warning)
- [ ] Weekly view supports assigning schedules to days and ranges (Mon–Fri shortcuts map to multiple days)
- [ ] Multiple daily schedules can be assigned to the same day with explicit priority (higher priority overlays lower priority)
- [ ] Segment validation: `start_time < end_time`, 15-minute alignment, and no overlap within a daily schedule
- [ ] Default mode when time has no segment is configurable in Settings (per plant) and applied during gaps/unassigned days
- [ ] “Today” view shows active schedule, active segment values, and next change time
- [ ] Temporary override supports: until next segment / until time / off, and UI clearly indicates override active
- [ ] Changes are consistent and confirmed; edits can be canceled before saving

## 2) Target architecture

**Flutter app**
- Uses Supabase Auth (OAuth) for login.
- Reads/writes most schedule data directly to Supabase Postgres via Supabase client (PostgREST) with RLS.
- Calls Supabase Edge Functions for:
  - provider credential management
  - “apply now” (server-side SolisCloud control)
  - scheduled execution (“executor tick”)
  - provider connection test
  - plant sharing (email invites)

**Supabase**
- Auth: OAuth providers (Google/Microsoft/Apple) + email identities.
- Postgres: source of truth for schedules, assignments, overrides, defaults, provider connections, logs.
- Edge Functions (TypeScript): SolisCloud adapter + orchestration.
- Cron/Triggers:
  - **GitHub Actions cron** calls the executor Edge Function endpoint (free tier compatible).
  - Optional later: Supabase scheduled Edge Functions / Postgres cron alternatives if you move off free tier.
  - Optional: DB triggers/webhooks to request an immediate apply after user changes.
  - Plant sharing: invite + accept flows implemented via Edge Functions and DB tables.

**Provider module (SolisCloud initial)**
- Uses SolisCloud endpoints:
  - `/v2/api/atRead` (required pre-read for CIDs that require `yuanzhi`, including `5041`)
  - `/v2/api/control` (write)
- Uses CIDs:
  - `5035` = peak shaving grid power limit (W)
  - `5041` = allow grid charging (ON/OFF) (MVP: only this method)
- Request signing: Content-MD5 + HMAC-SHA1 Authorization per `references/Solis-Cloud-API/*`.

## 3) Implementation checklist

Execution tracking rule:
- Implement incrementally and update this checklist continuously.
- Mark each completed item as `- [x]` in the same commit/PR where the work is completed.
- Do not mark an item complete without corresponding code/config/docs/tests (as applicable).
- If partially done, keep `- [ ]` and add a short status note under the item.
- If there are uncertainties about next coming task to implement (you should be 95% confident), ask me for clarifiction rather then continue with a guessed implementation. 

- [ ] **Supabase foundation**
  - [ ] Enable OAuth providers in Supabase Auth (Google/Microsoft/Apple)
  - [ ] Configure redirect URLs (mobile deep links + web URL + localhost)
  - [x] Create baseline DB schema (tables below)
  - [x] Set up database migrations workflow (Supabase migrations / SQL migration scripts in repo)
  - [x] Add RLS policies for all user data tables
  - [x] Enable required Postgres extensions (as needed): `vault`, `pgcrypto`
  - [x] Set up GitHub Actions cron workflow to call `executor_tick` (free tier)
  - Status: GitHub executor secrets are configured (`SUPABASE_EXECUTOR_TICK_URL`, `EXECUTOR_SECRET`). Remaining manual setup is Supabase Auth provider/redirect configuration and Supabase Function secrets in dashboard.
- [x] **Stitch UI verification**
  - [x] Pull screens/components from Stitch project `14483047077387457262` (via Stitch MCP if available)
  - [x] Produce a screen-to-route map + widget inventory (per screen: API calls, states, primary actions)
  - [x] Define a Stitch parity checklist per screen (layout, text, interactions, loading/empty/error states)
  - [x] Define reusable Flutter component inventory before page assembly
  - [x] Gate: do not implement Flutter pages until all Stitch screens are analyzed and the component inventory is approved
  - Status: Stitch screens now include Settings (`63edaea2bf704b1ba43f7669d231a300`) and Sharing (`265a120827a24b778e519581129c049e`); docs updated in `docs/stitch/` and Flutter implementation gate cleared.
- [x] **Schedule collections (backend-first)**
  - [x] Implement schedule collections in DB (multiple named sets per plant)
  - [x] On plant creation, create a default schedule collection + week schedule
  - [x] Add “active collection” pointer on plant
  - [x] Add Edge Function (optional) to switch active collection safely
  - Status: implemented via SQL/RPC in `supabase/migrations/20260209094000_initial_schema.sql` and `supabase/migrations/20260209120500_schedule_collection_bootstrap.sql` (`create_plant_with_defaults`, `switch_active_schedule_collection`); Edge wrapper remains optional.
- [ ] **Core scheduling domain (DB + shared logic)**
  - [x] Daily schedules + segments CRUD with validation (time order, overlap, 15-min alignment, 100 W step)
  - [x] Enforce “no overlap” and 15-minute alignment at the database level (constraints/triggers) so invalid states can’t be inserted via PostgREST
  - [x] Implement multi-row writes (replace segments list, delete schedule + auto-unassign) via RPC/Edge Function to keep operations transactional
  - [x] Weekly assignment (day-of-week → one or more daily schedules with priority order)
  - [x] Defaults for gaps/unassigned days (stored per plant)
  - [x] Overrides (until next schedule-boundary recalculation / until time / off)
  - [x] Deleting a daily schedule that’s assigned warns and auto-unassigns affected days (fallback to defaults)
  - Status: backend + Flutter flow implemented (`delete_daily_schedule_with_unassign` wired in edit screen with explicit confirmation warning).
- [x] **SolisCloud provider module (Edge Functions)**
  - [x] Implement request signing (Content-MD5 + HMAC-SHA1 `Authorization`)
  - [x] Implement apply: CID `5035` (W, step 100) + CID `5041` (bool, read-then-set with `yuanzhi`)
  - [x] Define SolisCloud `peak_shaving_w` min/max in code/config and enforce (no runtime device-read for max in MVP)
  - [x] Implement provider connection test (sanitized result)
  - [x] Store provider credentials server-side only (encrypted), never returned to client
  - Status: implemented in `supabase/functions/_shared/solis.ts`, `supabase/functions/_shared/crypto.ts`, `supabase/functions/_shared/provider_store.ts`, and Edge Functions `provider_connection_upsert`, `provider_connection_test`, `provider_apply_control`; `5041` now performs `atRead` and sends `yuanzhi` on control writes.
- [ ] **Executor (scheduled)**
  - [x] Implement `executor_tick` Edge Function (select due plants, compute desired state, apply if changed)
  - [x] Implement shared-secret auth on `executor_tick` (Authorization header)
  - [x] Create GitHub Actions workflow (`.github/workflows/executor.yml`) with cron schedule (every 1 minute recommended; every 5 minutes acceptable for MVP)
  - [x] Add `EXECUTOR_SECRET` to GitHub repo secrets
  - [x] Add rate limiting/backoff + idempotency (skip if already applied)
  - [x] Add audit logs + last applied state snapshot
  - Status: implemented in `supabase/functions/executor_tick/index.ts` with DB helpers in `supabase/migrations/20260209143000_executor_helpers.sql`; GitHub secrets are configured and remaining manual step is setting matching `EXECUTOR_SECRET` in Supabase Function secrets and deploying functions.
  - Status update (2026-02-11): added segment transition tolerance window (`-5m/+5m`) by claiming plants due within 5 minutes (`20260211112907_executor_claim_due_5m_window.sql`) and evaluating schedule-driven desired state at `now + 5 minutes` in `executor_tick`.
- [x] **Flutter MVP UI (based on Stitch)**
  - [x] Implement Supabase OAuth login (Google/Microsoft/Apple)
  - [x] Implement app shell + navigation based on Stitch screens
  - [x] Implement pages: Auth, Plants, Today, Week, Daily Schedule Library, Edit Daily Schedule, Settings/Connect Cloud Service
  - [x] Persist theme mode (System/Light/Dark) and apply via Flutter `ThemeMode`
  - [x] Implement weekly assignment UX exactly as Stitch shows (dedicated Week view or integrated toggles)
  - Status: Flutter MVP scaffolding + routed pages are implemented in `app/lib/` with Supabase-backed flows and offline-safe fallbacks; day-of-week assignment now uses integrated `M T W T F S S` buttons in Daily Schedule Library.
  - Status update (2026-02-09): Edit Daily Schedule now supports an end-time option at midnight (`24:00` shown as `00:00`) so the last 15-minute slot can be configured, and shared page padding was adjusted in `GpPageScaffold` to prevent top-field/header clipping.
  - Status update (2026-02-11): Today page now initializes `Manual apply now` values from the same active runtime control values shown in `Active control` when the screen opens or installation changes.
- [x] **Responsive layout (tablet + desktop web)**
  - [x] Define shared breakpoints and layout classes (`compact`, `medium`, `expanded`) and document width thresholds
  - [x] Add adaptive app shell behavior: keep current mobile navigation for `compact`; use `NavigationRail`/side navigation and wider content regions for `medium`/`expanded`
  - [x] Add reusable responsive layout primitives (max content width, adaptive paddings/gutters, single-column to two-column composition helpers)
  - [x] Apply responsive layout updates to: Plants, Today, Week, Daily Schedule Library, Edit Daily Schedule, Settings/Connect Cloud Service
  - [x] Ensure desktop/tablet UX parity for pointer + keyboard input (hover/focus states, tab traversal, scroll behavior)
  - [x] Add responsive UI verification at representative widths (390, 768, 1280) and update `docs/stitch/parity-checklist.md`
  - Status update (2026-02-11): implemented adaptive shell + page layouts in `app/lib/` with shared breakpoints (`gp_responsive.dart`), responsive shell nav (`NavigationBar`/`NavigationRail`), and width-aware page compositions for Installations/Today/Schedules/Edit/Settings/Connect/Sharing/Weekly. Added widget tests for 390/768/1280 shell behavior in `app/test/responsive_shell_test.dart` and updated Stitch parity checklist with responsive verification items.
  - Status update (2026-02-11): added repeatable responsive QA harness via `scripts/qa/run_responsive_qa.ps1` (Flutter web build + local static serve + Playwright CLI screenshots) with artifacts/reports in `output/playwright/`; workflow documented in `docs/responsive-qa.md`.
- [ ] **Plant sharing**
  - [x] Add plant membership model (many users per plant, roles)
  - [x] Implement transactional plant creation (create plant + owner membership + default collection + week schedule)
  - [x] Implement email-invite flow (create invite, send email, accept invite)
  - [ ] Choose and configure transactional email provider for invites + email templates
  - [x] Implement UI to view/manage members + invites per plant
  - Status: sharing Edge Functions implemented (`plant_sharing_list`, `plant_sharing_invite`, `plant_sharing_revoke_invite`, `plant_sharing_remove_member`, `plant_sharing_accept_invite`) and Flutter sharing UI is wired to them; remaining step is configuring provider secrets (Resend) in Supabase for live email delivery.
- [ ] **Deployment**
  - [ ] Android: Google Play (signed release)
  - [ ] iOS: App Store (signing + Apple requirements)
  - [ ] Web: build Flutter web and deploy static files to GitHub Pages
  - Status: Added GitHub Actions workflow `.github/workflows/deploy-web.yml` and verified local `flutter build web` with repo base href. Publishing is currently blocked because repository `elvan11/grid-power-control` is private and current plan does not support GitHub Pages for private repos.

## 4) Data model sketch (Supabase Postgres)

Notes:
- Supabase has `auth.users`. Use `auth_user_id` (UUID) as the user identifier.
- Treat the schema as versioned: apply changes via migrations (conventional approach is the Supabase CLI migration system, committed to the repo).
- Store times as:
  - `time` for segment boundaries (interpreted in plant local time zone)
  - `timestamptz` for absolute times in UTC (overrides, logs, runtime)
- Segment boundaries must align to 15-minute grid (00/15/30/45).
- Overlap constraints are easiest to enforce if segments are represented as ranges. If `time`-based constraints become awkward, switch to storing `start_minute`/`end_minute` (0..1440) and enforce non-overlap with an exclusion constraint on an `int4range`.

### Core entities

**plants**
- `id` (uuid, PK)
- `name` (text)
- `time_zone` (text, IANA, e.g. `Europe/Stockholm`)
- `active_schedule_collection_id` (uuid, nullable, FK → schedule_collections)
- `default_peak_shaving_w` (int) — default for gaps/unassigned
- `default_grid_charging_allowed` (bool) — default for gaps/unassigned
- `created_at` / `updated_at` (timestamptz)
Constraints (MVP):
- `active_schedule_collection_id` must reference a `schedule_collections` row belonging to the same plant (enforce via trigger or only allow changing it via Edge Function/RPC).

**plant_members**
- `plant_id` (uuid, FK → plants)
- `auth_user_id` (uuid, FK → auth.users)
- `role` (text: `owner` | `admin` | `member` | `viewer`)
- `created_at` (timestamptz)
- PK: (`plant_id`, `auth_user_id`)
Constraints (MVP):
- Each plant must always have at least one `owner` (enforce in business logic / Edge Function).

**plant_invites**
- `id` (uuid, PK)
- `plant_id` (uuid, FK → plants)
- `invited_email` (text)
- `invited_by_auth_user_id` (uuid, FK → auth.users)
- `role` (text: `admin` | `member` | `viewer`)
- `token_hash` (text) — store hash only (never store raw token)
- `status` (text: `pending` | `accepted` | `revoked` | `expired`)
- `expires_at` (timestamptz)
- `created_at` (timestamptz)
- `accepted_at` (timestamptz, nullable)
- `accepted_by_auth_user_id` (uuid, nullable)
Constraints (MVP):
- One pending invite per (`plant_id`, `invited_email`) (unique partial index on `status='pending'`).
- Compare/store emails case-insensitively (store normalized lowercase in `invited_email`).

**schedule_collections**
- `id` (uuid, PK)
- `plant_id` (uuid, FK → plants)
- `name` (text) — e.g. “Default”, “Vacation”
- `created_at` / `updated_at` (timestamptz)

**daily_schedules**
- `id` (uuid, PK)
- `schedule_collection_id` (uuid, FK → schedule_collections)
- `name` (text)
- `created_at` / `updated_at` (timestamptz)

**time_segments**
- `id` (uuid, PK)
- `daily_schedule_id` (uuid, FK → daily_schedules)
- `start_time` (time)
- `end_time` (time)
- `peak_shaving_w` (int) — enforce divisible by 100
- `grid_charging_allowed` (bool)
- `sort_order` (int)

**week_schedules**
- `id` (uuid, PK)
- `schedule_collection_id` (uuid, FK → schedule_collections)
- `name` (text) — MVP: keep one per collection, e.g. “Week”
- `created_at` / `updated_at` (timestamptz)
Constraints (MVP):
- Enforce one week schedule per schedule collection (unique index on `schedule_collection_id`).

**week_schedule_day_assignments**
- `id` (uuid, PK)
- `week_schedule_id` (uuid, FK → week_schedules)
- `day_of_week` (smallint; 1=Mon … 7=Sun)
- `daily_schedule_id` (uuid, FK → daily_schedules)
- `priority` (int) — higher number = higher priority
- `created_at` / `updated_at` (timestamptz)
Constraints (MVP):
- Unique priority per day: unique index on (`week_schedule_id`, `day_of_week`, `priority`).
- If `daily_schedule_id` is set, it must belong to the same `schedule_collection_id` as the parent `week_schedule_id` (enforce via trigger).
- If a day has no assignments, plant defaults apply.

### Overrides + applied state

**overrides**
- `id` (uuid, PK)
- `plant_id` (uuid, FK → plants)
- `created_by_auth_user_id` (uuid)
- `created_at` (timestamptz)
- `starts_at` (timestamptz)
- `ends_at` (timestamptz, nullable)
- `until_next_segment` (bool)
- `peak_shaving_w` (int, nullable)
- `grid_charging_allowed` (bool, nullable)
- `is_active` (bool)

**plant_runtime**
- `plant_id` (uuid, PK, FK → plants)
- `next_due_at` (timestamptz) — next time executor should consider applying
- `last_applied_at` (timestamptz, nullable)
- `last_applied_peak_shaving_w` (int, nullable)
- `last_applied_grid_charging_allowed` (bool, nullable)
- `updated_at` (timestamptz)

**control_apply_log**
- `id` (uuid, PK)
- `plant_id` (uuid, FK → plants)
- `attempted_at` (timestamptz)
- `requested_peak_shaving_w` (int)
- `requested_grid_charging_allowed` (bool)
- `provider_type` (text)
- `provider_result` (text; `success`/`skipped`/`failed`)
- `provider_http_status` (int, nullable)
- `provider_response` (jsonb, nullable)

### Provider connections / secrets

**provider_connections**
- `id` (uuid, PK)
- `plant_id` (uuid, FK → plants)
- `provider_type` (text; `soliscloud`)
- `display_name` (text)
- `config_json` (jsonb) — non-secret config (e.g., inverter SN, station/plant identifiers if needed)
- `created_at` / `updated_at` (timestamptz)

**provider_secrets**
- `plant_id` (uuid, FK → plants)
- `provider_type` (text; `soliscloud`)
- `encrypted_json` (bytea or text) — encrypted payload (apiId/apiSecret/etc.)
- `created_at` / `updated_at` (timestamptz)
PK: (`plant_id`, `provider_type`)
RLS:
- Client must never be able to `select` secrets. Writes should be via an Edge Function only.

### User settings

**user_settings**
- `auth_user_id` (uuid, PK)
- `theme_mode` (text: `system` | `light` | `dark`)
- `created_at` / `updated_at` (timestamptz)

## 5) Security model (RLS + functions)

- Use RLS on all tables:
  - access is via membership: user can read/write rows that join to a `plant_members` row for `auth.uid()`
  - collections/schedules/segments join back to plants the user is a member of
- Role model (recommended):
  - `owner`/`admin`: can edit schedules, defaults, provider connection, members/invites
  - `member`: can edit schedules + overrides (but not provider secrets or membership)
  - `viewer`: read-only
- Provider secrets:
  - Table `provider_secrets` has **no select** for clients.
  - Expose an Edge Function to upsert secrets; it checks `auth.uid()` is an `owner/admin` of the plant, encrypts, stores.
- Edge Functions should use a service role key (function secret) for DB writes that bypass RLS where appropriate, but still enforce ownership checks in code.
Encryption note (MVP):
- Store an encryption key as an Edge Function secret (env var). Encrypt/decrypt `provider_secrets.encrypted_json` inside Edge Functions; never send decrypted secrets to clients.
Plant sharing notes:
- Creating invites and accepting invites should be done via Edge Functions (so you can: validate permissions, generate token, hash/store it, and send email).
- When accepting an invite, verify the signed-in user’s email matches `plant_invites.invited_email` before adding to `plant_members`.
- Sending invites requires an email provider (e.g., Resend) or other transactional email mechanism; Supabase Auth emails are not a general-purpose invite mailer.
- Consider requiring a verified email for invite acceptance (or enforce verification in the accept function).

## 6) Scheduling + executor (Supabase cron + Edge Functions)

### Decision logic (shared)
1. Determine plant’s active schedule collection (`plants.active_schedule_collection_id`).
2. Load the collection’s week schedule.
3. Load all daily schedules assigned for today’s day-of-week, sorted by `priority` descending.
4. At current local time in the plant’s time zone, pick the active segment from the highest-priority schedule that has a matching segment.
5. Apply override on top (if active), according to the selected end condition:
   - until next schedule-boundary recalculation (segment start/end considering priorities)
   - until a chosen timestamp
   - turned off
6. If no assigned schedule has an active segment at the current time (or the day is unassigned), use plant defaults:
  - `default_peak_shaving_w`
  - `default_grid_charging_allowed`

### Execution strategy (MVP — Free Tier)
**Scheduler: GitHub Actions cron**
- GitHub Actions workflow calls `executor_tick` via HTTPS with a shared secret (stored in GitHub repo secrets).
- Recommended cadence: every 1 minute (best boundary behavior). Acceptable MVP: every 5 minutes (up to ~5 minutes late at boundaries).

**`executor_tick` Edge Function logic:**
- Select plants where `plant_runtime.next_due_at <= now() + 5 minutes` (or null ⇒ due)
- Prevent double-processing when overlapping ticks occur (use row locks like `FOR UPDATE SKIP LOCKED` or an advisory lock per plant)
- Compute desired control values with a 5-minute lookahead for schedule-driven controls (`now + 5 minutes`) so ticks slightly before boundary can pre-apply the next segment; keep current-time behavior for active overrides
- Compare with last applied values (in `plant_runtime`) and apply only if changed
- Enforce:
  - `peak_shaving_w` step = 100 W
  - rate limiting to respect SolisCloud limits (2 req/sec) (MVP: process sequentially and cap per tick)
- Update `plant_runtime.next_due_at` to the next relevant boundary for that plant (next segment start/end across all assigned priorities, or override boundary)

**"Apply now":**
- Edge Function `apply_now` to compute and apply immediately (used by Today view + after saving changes)

Optional (later):
- DB trigger/webhook that updates `next_due_at = now()` when schedules/overrides change so the next scheduled tick picks it up quickly.

## 7) SolisCloud provider module (Edge Functions)

### Mapping (MVP)
- Peak shaving limit: CID `5035` (watts), always rounded to 100 W
- Grid charging allow/disallow: CID `5041` only (no CID `636` bit flags in MVP)

### Error handling & retry logic (SolisCloud API)
- **Transient failures** (network timeout, 5xx, slow response): retry up to 3 times with exponential backoff (2s, 5s, 10s)
- **Permanent failures** (4xx, invalid credentials): log error, notify user via dashboard/logs, do not retry
- **Slow API**: SolisCloud may take 5-10 seconds; set Edge Function timeout to 30s
- **Idempotency**: do not apply if `plant_runtime.last_applied_peak_shaving_w` and `last_applied_grid_charging_allowed` match desired values

### Implementation notes
- Use signing rules from `references/Solis-Cloud-API/*`:
  - Content-MD5 of the exact JSON body
  - Date in GMT
  - Canonical resource path (e.g., `/v2/api/control`)
  - Authorization `API {apiId}:{signature}`
- Store `apiId`, `apiSecret`, and any other required identifiers in `provider_secrets` (encrypted).
- Store `inverterSn` in `provider_connections.config_json`.
- Enforce safe bounds for `peak_shaving_w` in code/config (MVP: provider-level deploy-time config, e.g. min 0 / max 10000 for SolisCloud).

## 8) Flutter frontend plan (based on Stitch project 14483047077387457262)

### Required Stitch-to-Flutter workflow
1. Extract Stitch screens and components from project `14483047077387457262` (via Stitch MCP when available).
2. Produce a screen contract for each screen before coding:
   - route name and navigation entry points
   - required queries/Edge Function calls
   - state model (`loading`, `empty`, `error`, `success`)
   - primary user actions
3. Build a reusable widget inventory first (for example: buttons, cards, schedule chips, segment editor rows, day assignment controls).
4. Implement pages by composing the reusable widgets; avoid one-off page-specific widget duplication.
5. Run parity review per screen against Stitch:
   - visual structure and spacing
   - text labels and CTA hierarchy
   - interaction behavior (including disabled/validation/error states)
6. If Stitch MCP is unavailable, use exported screenshots/PDF as source-of-truth artifacts and still produce the same route map + widget inventory + parity checklist.

### App structure
- Routing: `go_router`
- State: Riverpod (or BLoC; pick one)
- Supabase: `supabase_flutter` for auth + session persistence
- Theme:
  - Single source of truth (`ThemeData` for light/dark)
  - `ThemeMode` controlled by Settings (System/Light/Dark)

### Responsive strategy (mobile/tablet/desktop)
- Use width-based layout classes from a single helper so all pages apply the same rules:
  - `compact`: `< 600` logical px (mobile layout)
  - `medium`: `600..1023` logical px (tablet layout)
  - `expanded`: `>= 1024` logical px (desktop layout)
- Keep one code path per page with adaptive composition; avoid separate page implementations per device.
- App shell behavior by class:
  - `compact`: current mobile navigation pattern
  - `medium`/`expanded`: side navigation (`NavigationRail` or equivalent) with persistent page chrome and reduced route churn
- Shared responsive primitives:
  - Content width constraints (for readability on large screens)
  - Adaptive page padding/gutters per class
  - Reusable split-pane/two-column scaffolding for form + summary or list + detail layouts
- Page-level adaptation targets:
  - Today: stack cards on `compact`; two-column control/status layout on `medium`/`expanded`
  - Week + Daily Schedule Library: prioritize list/detail composition on larger widths
  - Edit Daily Schedule: keep segment editor readable on larger widths (wider rows, optional side summary panel)
  - Settings/Connect Cloud Service: center constrained form and allow two-column groups where appropriate
- Interaction + accessibility requirements on web/tablet:
  - Keyboard navigable controls and visible focus states
  - Hover states for interactive elements on pointer devices
  - No nested primary scrolling regions unless intentionally designed
- Verification gates before completion:
  - Widget/screenshot or golden checks at `390`, `768`, and `1280` widths
  - Manual parity check against Stitch across all three widths for key flows
  - Browser sanity test for Flutter web on latest Chrome and Safari

### Pages (MVP — verify with Stitch)
- **Auth**
  - Continue with Google/Microsoft/Apple (Supabase OAuth)
  - Deep link handling for mobile + web redirects
- **Plants** (may be labeled “My Installations” in Stitch)
  - List/select plant
  - Create plant (name + time zone + defaults)
  - Share plant: invite by email, manage members/invites
- **Connect Cloud Service** (or under Settings)
  - Provider (SolisCloud for MVP)
  - Enter SolisCloud credentials (API ID + Secret) + inverter SN
  - Test connection (Edge Function)
- **Today**
  - Active schedule/segment values now + next change time
  - Override UI (until next segment / until time / off)
  - Apply-now + last apply status/logs
  - Refresh strategy: refresh on view open + manual pull-to-refresh; optional periodic refresh while foreground (e.g., 30–60s)
- **Week** (or integrated in Library if Stitch does it that way)
  - Assign one or more daily schedules to day(s) and ranges (Mon–Fri shortcut)
  - Set priority order for schedules assigned to the same day (higher overlays lower)
  - Allow leaving days unassigned (defaults apply)
- **Daily Schedule Library**
  - List/create/duplicate/delete daily schedules
  - Navigate to Edit Daily Schedule
- **Edit Daily Schedule**
  - Segment list (add/edit/remove/reorder)
  - Enforce 15-minute boundary pickers (00/15/30/45), 100 W step, no overlaps
  - Save/Cancel actions
- **Settings**
  - Theme mode: System / Light / Dark
  - Plant defaults for gaps
  - Manage members + invites
  - Logout

### Plant sharing flows (MVP)
- Invite: owner/admin enters an email → Edge Function creates `plant_invites` row + sends email with link containing a one-time token.
- Accept: user opens link, signs in (OAuth), Edge Function validates token + email match → inserts/updates `plant_members`.
- Manage: owner/admin can revoke pending invites and remove members (but can’t remove the last owner).

### Stitch mapping notes (to keep implementation unblocked)
- The Stitch project is the source of truth for page layout and widget composition. Mirror Stitch screen names in route names and folder structure.
- Confirm navigation model from Stitch (bottom tabs vs drawer vs stacked routes) and implement it exactly to avoid rework.
- For each Stitch screen, document: route name, required DB queries / Edge Function calls, UI states (loading/empty/error), and primary actions (create/edit/delete/apply/override).
- If Stitch MCP is unavailable, export/share screen names (and ideally a PDF/PNG export) so the route map + widget inventory can still be produced accurately.

## 9) Deployment plan

**OAuth Redirect URLs** (configured per platform; use standard patterns)
- **Web** (GitHub Pages): `https://[github-pages-domain]/#/auth/callback` (hash routing)
- **iOS**: Deep link scheme (e.g., `gridpowercontrol://auth/callback`)
- **Android**: URL scheme (e.g., `https://auth.gridpowercontrol.app/callback`)
- Each platform's redirect URL configured in Supabase Auth dashboard + OAuth provider console

**Android (Google Play)**
- Build signed AAB
- Configure OAuth redirect URI in Supabase Auth settings + Google Cloud console

**iOS (App Store)**
- Build signed IPA
- Configure OAuth redirect URI in Supabase Auth settings + Apple Developer console

**Web (GitHub Pages)**
- Build Flutter web and deploy as static files
- Configure OAuth redirect URI in Supabase Auth settings
- Use hash routing (`/#/`) for static hosting compatibility
- Run responsive regression checks (390/768/1280 widths) before publishing

OAuth setup notes:
- Google/Microsoft: straightforward
- Apple Sign In (especially on web): may require extra setup (Service ID, domain association file)
- Plan a short spike during first deploy to validate all three providers across all platforms

## 10) Decisions locked in (from you)

- A Plant (one SolisCloud plant installation) is separate from a user: multiple users can be members of one plant, and a user can share a plant with another user via **email invite**.
- Multiple schedules are stored in a **Daily Schedule Library**, and edited via **Edit Daily Schedule** (as per Stitch).
- The data model must support multiple **schedule collections** (multiple named week-schedule sets per plant), even if the frontend doesn’t expose it yet.
- Default mode when no segment matches is configurable in Settings (defaults apply for gaps/unassigned days).
- Segment resolution is 15 minutes (00/15/30/45).
- Override ends at the next schedule-boundary recalculation; when a higher-priority segment ends, runtime falls back to the next lower-priority active segment, then defaults.
- Peak shaving max is configured at deploy time per provider (no runtime device read for max in MVP). Typical SolisCloud range: 0..10000 W.
- Database stores absolute timestamps in UTC; time zone is configured per plant in the UI and used for schedule evaluation.
- Deletion supports deleting time segments and whole daily schedules; batch ops can wait.
- Supabase hosts Auth + Postgres + Edge Functions; no separate backend service.
- Executor is triggered via **GitHub Actions cron** calling `executor_tick` (free tier).
- SolisCloud credentials are entered via Connect Cloud Service/Settings screen and stored server-side (encrypted).
- Grid charging uses CID `5041` only for MVP.
- SolisCloud API calls use retries/backoff for transient errors and conservative timeouts.
- OAuth uses standard patterns configured per platform (redirect URLs in Supabase Auth + provider consoles).
