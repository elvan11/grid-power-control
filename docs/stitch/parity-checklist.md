# Stitch Parity Checklist (MCP Verified Baseline)

Project: `14483047077387457262`  
Pull date: `2026-02-09`  
Source: Stitch MCP screen contracts + local exports in `output/stitch/*.html`.

## How to use

- Check items only after side-by-side verification with Stitch screenshots/HTML.
- If an intentional deviation is needed, keep the item checked and add a one-line note under the screen section.
- Re-run this checklist whenever Stitch screens are regenerated.

## Global

- [ ] Theme tokens match Stitch values (Inter, primary green, light/dark backgrounds, radius scale).
- [ ] Adaptive primary navigation matches responsive rules: bottom navigation on compact and side rail on medium/expanded with correct active-state behavior per route.
- [ ] Glass/blur surfaces and card elevations match Stitch intent.
- [ ] All routes implement loading/empty/error/success states.

## Responsive Verification (390 / 768 / 1280)

- [ ] Run `.\scripts\qa\run_responsive_qa.ps1` and attach latest artifact folder in PR notes.
- [x] Shell navigation switches correctly at representative widths (widget test coverage in `app/test/responsive_shell_test.dart`).
- [ ] Installations, Today, Schedules, Edit Schedule, Settings, Connect Service, Sharing, and Weekly layouts avoid overflow/cutoff at all three widths.
- [ ] Keyboard navigation and visible focus states are validated on tablet/desktop web.
- [ ] Pointer/hover behavior is validated for interactive controls on tablet/desktop web.
- [ ] Stitch parity check completed for key flows at 390, 768, and 1280 widths.

## Sign In (`/auth/sign-in`, screen `4867ad76ed26441bab846e065654dd55`)

- [ ] Hero area and brand treatment match layout and hierarchy.
- [ ] OAuth provider button order and labels match (Google, Microsoft, Apple).
- [ ] Email/password fields include icon placement, visibility toggle, and forgot-password link.
- [ ] Footer links and Terms/Privacy text match.
- [ ] Auth failures and retry UX are implemented.

## Create Account (`/auth/sign-up`, screen `b694cd0ef208400892ec00053dd5adb1`)

- [ ] Social sign-up buttons and email separator match.
- [ ] Full name/email/password fields match labels, icon placement, and styles.
- [ ] Password strength meter and helper text are implemented.
- [ ] Terms checkbox row and `Create Account` CTA match.
- [ ] Validation and server error states are surfaced clearly.

## My Installations (`/installations`, screen `c199f095616a4d0087011804e2ebc915`)

- [ ] Installation cards render online/offline variants with correct badge logic.
- [ ] Card content includes connection mode, battery %, active schedule summary, and metrics.
- [ ] Manage/Retry actions are wired and stateful.
- [ ] Add-installation FAB is present and positioned correctly.
- [ ] Empty and network-error states are implemented.

## Connect Cloud Service (`/installations/:plantId/connect-service`, screen `41b60f86bf764cabadbe663badf19ca0`)

- [ ] Header/back behavior and explanatory info card match.
- [ ] Form fields match labels and order: installation name, provider, API key, secret.
- [ ] Secret visibility toggle works.
- [ ] `Test Connection` and `Save Installation` actions match visual hierarchy and state handling.
- [ ] Validation, test-result, and save-error messages are implemented.

## Today (`/today`, screen `d9438c6801b84f54ab12fddfeba134c8`)

- [ ] Installation selector and header actions match.
- [ ] Active schedule pill, peak-shaving hero card, and key metric cards match.
- [ ] Countdown to next change matches structure and formatting.
- [ ] Temporary override CTA opens correct override flow.
- [ ] Timeline rows render past/current/upcoming states and copy.
- [ ] Selector sheet supports installation switching and add-installation action.

## Daily Schedule Library (`/schedules`, screen `75559b6c019c47a8bf7f94bd63518faa`)

- [ ] Header and top filter tabs (`Templates`, `Active`, `History`) match.
- [ ] `Create New Schedule` CTA and card list hierarchy match.
- [ ] Each schedule card supports duplicate and edit actions.
- [ ] Mini timeline strip and weekday chips render correctly.
- [ ] Empty/error states and destructive action confirmations are implemented.

## Edit Daily Schedule (`/schedules/:scheduleId/edit`, screen `8e33f9e06c3f4ff39fd5add84b37b1ff`)

- [ ] Schedule name editing and delete action match.
- [ ] Segment cards include time range, labels, slider, and grid charging toggle.
- [ ] Overlap warning banner and conflict card styling are implemented.
- [ ] `Add New` and dashed add-segment placeholder behaviors match.
- [ ] Save footer/button behavior and unsaved-change handling are implemented.
- [ ] Server-driven validation for 15-min alignment, overlap, and 100W step is surfaced inline.

## Weekly (`/weekly`, hidden screen `0c3a6b3664b64e6881c9e7352fa4ad33`)

- [ ] Weekly header and quick-assign card match.
- [ ] Day assignment cards render day/date, selected profile, and dropdown controls.
- [ ] Mon-Fri bulk apply flow is implemented.
- [ ] Weekend compact assignment cards match.
- [ ] `Apply Changes` sticky CTA is implemented with save/validation feedback.
- [ ] Priority/overlay behavior from backend model is represented in UI copy and interactions.

## Settings (`/settings`, screen `63edaea2bf704b1ba43f7669d231a300`)

- [ ] Theme mode selector matches options and interaction.
- [ ] Plant default controls for peak-shaving and grid charging are present and validated.
- [ ] Cloud connection management entry/action is present.
- [ ] Sharing screen navigation entry is present.
- [ ] Save and logout actions match placement and behavior.

## Sharing (`/settings/sharing`, screen `265a120827a24b778e519581129c049e`)

- [ ] Add-email input and primary add action are implemented.
- [ ] Access list rows render current emails correctly.
- [ ] Remove action includes confirmation.
- [ ] Duplicate and invalid email validation are surfaced inline.
- [ ] Loading, empty, and save-error states are implemented.
