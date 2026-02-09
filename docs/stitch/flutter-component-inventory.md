# Flutter Component Inventory (Stitch Derived)

Project: `14483047077387457262`  
Pull date: `2026-02-09`  
Source: Stitch MCP screen contracts plus local exports in `output/stitch/*.html`.

## Design tokens to codify first

- `GpColors.primary = #13EC5B` (minor variant `#13EC80` appears on Connect screen; keep one canonical app token).
- `GpColors.backgroundDark = #102216`, `GpColors.backgroundLight = #F6F8F6`.
- `GpTypography.family = Inter`.
- Radius scale from Stitch: 4/8/12/full.
- Glass/blur surfaces used in Today + Installations + Weekly.

## App shell components

- `GpAppScaffold`: page shell with optional sticky header and safe-area paddings.
- `GpBottomNavBar`: 4-tab bar (`Installations/Today`, `Schedules`, `Weekly`, `Settings`) with per-screen active state.
- `GpTopBar`: title + optional leading/trailing icon buttons.
- `GpAsyncStateView`: shared `loading`, `empty`, `error`, `success` wrapper.

## Core primitives

- `GpPrimaryButton`: filled primary CTA (e.g., `Save`, `Apply Changes`, `Sign In`).
- `GpSecondaryButton`: outlined/tonal action (e.g., `Test Connection`).
- `GpIconButton`: circular icon-only actions.
- `GpStatusBadge`: online/offline/active badges.
- `GpGlassCard`: reusable translucent card treatment.
- `GpInfoBanner` and `GpWarningBanner`: inline info/error strips.
- `GpTextField`, `GpPasswordField`, `GpSelectField`, `GpToggleSwitch`.

## Auth feature components

- `AuthHeroHeader`: brand icon + title/subtitle block.
- `OAuthProviderButton`: Google/Microsoft/Apple button variants.
- `AuthFormCard`: sign-in container card with divider and footer links.
- `PasswordStrengthMeter`: 4-segment meter from sign-up screen.
- `TermsCheckboxRow`: terms/privacy acceptance row.

## Installations feature components

- `InstallationCard`: image header, connectivity status, battery %, active schedule summary, manage/retry action.
- `InstallationMetricRow`: solar/grid or solar/charging mini metrics.
- `InstallationFab`: add-installation floating action button.
- `InstallationPickerSheet`: Today screen installation selector bottom sheet.

## Today feature components

- `TodayActiveSchedulePill`: active schedule badge with animated dot.
- `PeakShavingHeroCard`: large current watt value card.
- `KeyMetricCard`: compact cards for grid charging and battery health.
- `CountdownUnitCard`: next-change countdown item (hours/minutes/seconds).
- `TimelineEventRow`: past/current/upcoming event row variants.
- `TemporaryOverrideButton`: prominent override trigger CTA.

## Schedule library feature components

- `ScheduleLibraryHeader`: title + add button + top filter tabs (`Templates`, `Active`, `History`).
- `ScheduleProfileCard`: name, description, active badge, duplicate/edit actions.
- `ScheduleTimelineStrip`: mini 24h visual strip with tick labels.
- `WeekdayChipRow`: assigned-day indicator chips.

## Edit schedule feature components

- `ScheduleNameField`: editable schedule title row.
- `SegmentCard`: segment container with time range and actions menu.
- `PeakShavingSlider`: bounded W slider with current value and min/max labels.
- `GridChargingTile`: label + toggle surface.
- `SegmentConflictCard`: red bordered overlap state.
- `AddSegmentPlaceholder`: dashed add-slot panel.
- `SaveFooterBar`: sticky save CTA + bottom nav host.

## Weekly assignment feature components

- `WeeklyHeroCard`: planner title, explanatory text, quick-assign action.
- `DayAssignmentCard`: day/date header + schedule dropdown + optional note.
- `WeekendAssignmentCard`: compact Sat/Sun assignment cards.
- `BulkAssignButton`: Mon-Fri bulk apply control.
- `ApplyChangesStickyButton`: bottom floating apply action.

## Connect cloud service components

- `ProviderConnectionInfoCard`: instruction/info block.
- `ProviderCredentialForm`: installation name, provider, api key, secret.
- `ConnectionActionGroup`: `Test Connection` + `Save Installation` actions.

## Settings and sharing components

- `SettingsSectionCard`: grouped settings section container.
- `ThemeModeSegmentedControl`: `System | Light | Dark` selector.
- `PlantDefaultsForm`: default peak-shaving (100W step) + default grid-charging toggle.
- `SettingsNavRow`: row-style setting action (connect service, sharing, logout).
- `EmailAccessInputRow`: email input + add action for sharing.
- `EmailAccessListRow`: email row with optional `You` chip and remove action.
- `ConfirmRemoveAccessDialog`: remove-access confirmation dialog.

## Build order for Flutter implementation

1. Build `GpColors`, typography, spacing, and base button/field primitives.
2. Build `GpBottomNavBar`, `GpTopBar`, `GpAppScaffold`, and async state wrappers.
3. Build feature-level reusable cards/rows listed above.
4. Compose pages from these widgets without new one-off page-specific controls.
