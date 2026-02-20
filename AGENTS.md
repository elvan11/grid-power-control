# AGENTS.md

This base needs in the project is documented in [base-needs.md](base-needs.md).

## Project Overview

A mobile app for scheduled control of solar + battery installations. Users create weekly control schedules to manage peak shaving (adjustable power limits) and grid charging settings across different time segments and days of the week. The app supports multiple daily schedules that can be assigned to specific days or day ranges, with real-time display of active controls and manual override capabilities.

## Tools and Technologies

- **Stitch**: Used for UI layout design. Project ID: 14483047077387457262
- **SolisCloud API**: Integration with Solis inverter cloud API for remote control of solar + battery systems

## MCP Servers

The following MCP servers are available for use:

- **Supabase MCP Server**: Provides access to Supabase project management, database migrations, Edge Functions, and project configuration
- **Stitch MCP Server**: Enables programmatic access to Stitch project screens and generation capabilities

## Stitch MCP Skills

Two specialized skills are available under `.github/skills/` for working with Stitch:

### design-md
Analyzes Stitch project screens and synthesizes a semantic design system into a `DESIGN.md` file. This design system serves as the source of truth for prompting Stitch to generate new screens that align with existing design language and color values.

### stitch-loop
Teaches iterative website building using Stitch with an autonomous baton-passing loop pattern. Enables continuous frontend development through repeatable cycles: generate a page with Stitch, integrate it into the site, and prepare the next task in a `next-prompt.md` baton file.

## Stitch-to-Flutter Implementation Rule

When implementing Flutter UI from Stitch, use this order:
1. Pull/read Stitch screens from project `14483047077387457262`.
2. Create a screen-to-route map and widget inventory before coding.
3. Implement reusable widgets first, then compose pages from those widgets.
4. Verify parity per screen (layout, labels, interactions, loading/empty/error states).

## Execution Tracking Rule

During implementation, update checklist progress incrementally in `implementation-plan.md`:
1. Mark completed items as `- [x]` when done.
2. Keep incomplete/partial items as `- [ ]` and add a short status note if needed.
3. Only mark complete when corresponding implementation artifacts exist.

## Test Coverage Rule

When changing code, update tests in the same change set so coverage follows the implementation.

- For Flutter changes: add or update unit/widget/integration tests under `app/test/` (and `integration_test/` when applicable).
- For Supabase Edge Function TypeScript handler changes: add or update handler unit tests under `supabase/functions/**/handler_test.ts`.
- Do not treat implementation as complete unless relevant tests are added/updated and passing.
- If a change is intentionally not covered by tests, document why in the PR/commit notes.

## Supabase Deploy Rule

When deploying Edge Functions in this project, preserve existing gateway behavior by disabling JWT verification at deploy time unless explicitly requested otherwise.

- Default deploy command: `npx -y supabase functions deploy <function_slug> --project-ref <project_ref> --no-verify-jwt`
- Do **not** switch `verify_jwt` from `false` to `true` accidentally during routine deploys.
- If JWT verification is intentionally changed, call it out explicitly before/after deploy and verify function auth flow end-to-end.

### Post-Deploy Smoke Test Rule

After deploying Edge Functions, run:
- `./scripts/smoke/smoke_edge_functions.ps1 -ProjectRef <project_ref>`

For deeper validation with credentials, run:
- `./scripts/smoke/smoke_edge_functions.ps1 -ProjectRef <project_ref> -IncludeAuthenticatedChecks -UserJwt "<access_token>" -ExecutorSecret "<executor_secret>"`

## SolisCloud API Integration

### Key Control Parameters (CID)
- **CID 5035**: Peak shaving grid power limit (W)
- **CID 5041**: Allow/disallow grid charging (ON/OFF)

### API Reference Implementation
Python reference scripts demonstrating API usage patterns:
- [poll_solis_atread.py](references/poll_solis_atread.py) - Reading parameter values from SolisCloud
- [apply_schedule_slot.py](references/apply_schedule_slot.py) - Applying schedule-based control commands to inverter

Refer to [soliscloud_command_list.md](references/Solis-Cloud-API/soliscloud_command_list.md) for complete CID command reference.
