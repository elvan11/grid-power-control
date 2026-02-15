# Testing Plan

Date: 2026-02-09  
Project: Grid Power Control

## 1) Current Baseline

- Flutter tests: smoke + responsive shell tests are present (`app/test/widget_test.dart`, `app/test/responsive_shell_test.dart`).
- Integration tests: none.
- Edge Function tests: none.
- SQL/RPC tests: none.
- CI executes `flutter analyze` + `flutter test` only.

## 2) Test Goals

- Catch regressions in core schedule/control behavior before deploy.
- Protect routing/auth/navigation behavior.
- Validate Supabase RPC and Edge Function contracts.
- Add confidence in web/mobile critical flows (installations, schedules, provider, sharing).

## 3) Phase Plan

## Phase 1: Foundation (fast setup)

Objective: establish reusable test scaffolding and CI wiring.

Checklist:
- [x] Add test helpers for Riverpod provider overrides and router bootstrapping.
- [ ] Add mocks/fakes for Supabase client and function invocation boundaries.
- [ ] Add test script targets (`flutter test`, optional coverage command).
- [ ] Update CI to publish coverage artifact (optional in first pass, recommended).

Deliverable:
- Reusable test harness in `app/test/` with at least one real test using helpers.

Exit criteria:
- Developers can add new unit/widget tests in <10 minutes using shared helpers.

## Phase 2: Critical Unit/Widget Tests (highest ROI)

Objective: protect highest-risk app logic and UI behavior.

Scope:
- Routing and auth redirects (`app/lib/app/router.dart`).
- Shared scaffold back behavior and fallback routes (`app/lib/core/widgets/gp_scaffold.dart`).
- Edit schedule validation and edge-time behavior (`app/lib/features/schedules/edit_schedule_page.dart`).
- Provider function service payload/response handling (`app/lib/data/provider_functions_service.dart`).
- Sharing service mapping/error handling (`app/lib/data/sharing_functions_service.dart`).

Checklist:
- [x] Router redirect tests for unauthenticated/authenticated states.
- [x] Back button tests for pop and fallback route behavior.
- [ ] Schedule segment validation tests including end-of-day (`23:45` -> `00:00`).
- [ ] Service-layer tests for success/error payload handling.
  - Status: added offline-path and model parsing tests for provider/sharing services; response-path mocking is still pending.

Deliverable target:
- 15-25 focused unit/widget tests.

Exit criteria:
- Common regressions in routing, schedule validation, and function payload handling are covered.

## Phase 3: App Integration Tests (UI + state + data boundaries)

Objective: verify critical user journeys end-to-end inside Flutter test runner.

Scope:
- Installation creation and selection.
- Connect cloud service (test + save flows with mocked backend).
- Daily schedule create/edit with multiple segments.
- Weekly assignment interactions.
- Today view render/update paths.
- Sharing flow basics (list/invite/remove/accept with mocked responses).

Checklist:
- [ ] Add `integration_test/` suite and bootstrap.
- [ ] Create stable test fixtures for plants/schedules/runtime states.
- [ ] Add integration tests for top 4-6 journeys.

Deliverable:
- Integration test suite that runs on CI (nightly or gated on main).

Exit criteria:
- Core user journeys pass consistently across local and CI runs.

## Phase 4: Backend Validation (Edge + SQL/RPC)

Objective: validate backend behavior independently of UI.

Scope:
- Edge Functions:
  - `executor_tick`
  - `provider_connection_upsert`
  - `provider_connection_test`
  - `provider_apply_control`
  - `plant_sharing_*`
- SQL/RPC contracts:
  - `create_plant_with_defaults`
  - `replace_daily_schedule_segments`
  - `delete_daily_schedule_with_unassign`
  - `claim_due_plants`
  - `compute_plant_desired_control`

Checklist:
- [ ] Add function tests with mocked external providers (Solis/Resend).
- [ ] Add DB-level RPC validation script/tests for happy-path + key failures.
- [ ] Add schema contract checks for required function signatures.

Deliverable:
- Automated backend tests runnable pre-deploy.

Exit criteria:
- Known backend failures (missing function, signature mismatch, ambiguous SQL errors) are detectable by tests.

## Phase 5: CI Gate Strategy

Objective: enforce practical quality gates without slowing iteration.

Proposed split:
- PR pipeline:
  - `flutter analyze`
  - fast unit/widget tests (Phase 2 subset)
- Main/nightly pipeline:
  - integration tests (Phase 3)
  - backend tests (Phase 4)

Checklist:
- [ ] Add separate jobs for fast vs deep test tiers.
- [ ] Set required checks for PR merge.
- [ ] Add flaky-test monitoring and retry policy for integration tier.

Exit criteria:
- Regressions are blocked before release, with acceptable CI runtime.

## 4) Priority Order

1. Phase 1 (foundation)
2. Phase 2 (critical unit/widget)
3. Phase 3 (app integration)
4. Phase 4 (backend validation)
5. Phase 5 (final CI hardening)

## 5) Suggested First Sprint Scope

- Deliver all of Phase 1.
- Deliver at least 12 tests from Phase 2:
  - router redirects
  - scaffold back behavior
  - schedule end-time validation
  - provider/sharing service parsing

Success metric:
- Test suite moves from 1 smoke test to meaningful coverage of top regression vectors.
