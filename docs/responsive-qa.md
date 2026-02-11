# Responsive QA Workflow (Flutter Web)

This workflow generates screenshot artifacts for key routes at:
- `390x900` (mobile/compact)
- `768x900` (tablet/medium)
- `1280x900` (desktop/expanded)

It also emits a markdown report with capture timings and failures (if any).

## Prerequisites

- Flutter SDK available in PATH
- Python available in PATH (used for static file serving)
- Playwright CLI available in PATH (`playwright --version`)

Install Playwright CLI if missing:

```powershell
npm install -g @playwright/cli@latest
playwright install chromium
```

## One-command run

From repo root (PowerShell):

```powershell
.\scripts\qa\run_responsive_qa.ps1
```

Artifacts are written to:

```text
output/playwright/responsive-<timestamp>/
```

Output includes:
- PNG screenshots per route and viewport
- `report.md` with timing + capture errors

## Route set (default)

- `/#/installations`
- `/#/today`
- `/#/schedules`
- `/#/settings`
- `/#/settings/sharing`

## Custom routes/base URL

```powershell
.\scripts\qa\run_responsive_qa.ps1 `
  -BaseUrl "http://127.0.0.1:7357" `
  -Routes "/#/installations,/#/today,/#/schedules"
```

## Suggested QA pass steps

1. Run the script and open generated PNGs side-by-side by width.
2. Verify no clipping/overflow and expected layout adaptation by breakpoint.
3. Check `report.md` for any capture failures.
4. Update `docs/stitch/parity-checklist.md` responsive items after manual review.
