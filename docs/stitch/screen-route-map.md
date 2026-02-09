# Stitch Screen-to-Route Map (MCP Verified)

Project: `14483047077387457262`  
Pull date: `2026-02-09`  
Source artifacts: Stitch MCP metadata + local exports in `output/stitch/*.html` where available.

## Navigation model observed in Stitch

- Auth screens have no app shell nav.
- Main app screens use a 4-tab bottom nav with destinations: Installations/Today, Schedules, Weekly, Settings.
- Icon names differ between screens, but destination labels are consistent.

## Screen contracts

| Stitch screen title | Screen ID | Hidden in Stitch | Flutter route | Nav entry point | Primary actions | Data/API dependencies | Required states |
|---|---|---|---|---|---|---|---|
| Sign In to Energy Manager | `4867ad76ed26441bab846e065654dd55` | No | `/auth/sign-in` | App launch when unauthenticated | OAuth sign-in (Google/Microsoft/Apple), email+password sign-in, forgot-password, navigate to sign-up | Supabase Auth OAuth + password auth | loading, auth_error, success |
| Create Your Account | `b694cd0ef208400892ec00053dd5adb1` | No | `/auth/sign-up` | From sign-in footer link | OAuth sign-up (Google/Microsoft), email sign-up, accept terms, navigate to sign-in | Supabase Auth sign-up, terms acceptance validation | loading, validation_error, auth_error, success |
| My Installations | `c199f095616a4d0087011804e2ebc915` | No | `/installations` | Default post-auth landing | Select installation, open manage flow, add installation, retry offline installation | `plants`, `plant_members`, `plant_runtime`, create-plant transactional function | loading, empty, success, partial_offline, error |
| Connect Cloud Service | `41b60f86bf764cabadbe663badf19ca0` | No | `/installations/:plantId/connect-service` | Installations manage flow | Enter provider credentials, test connection, save installation/provider config | `provider_connections`, provider secret upsert Edge Function, provider test Edge Function | loading, validation_error, test_success, test_error, save_success |
| Today's Status Dashboard | `d9438c6801b84f54ab12fddfeba134c8` | No | `/today` | Bottom nav Today | Switch installation, open override sheet, view timeline, add installation from selector | schedule read model, `plant_runtime`, `overrides`, `control_apply_log`, `apply_now` Edge Function | loading, success, empty_timeline, stale_data, error |
| Daily Schedule Library | `75559b6c019c47a8bf7f94bd63518faa` | No | `/schedules` | Bottom nav Schedules | Create new schedule, duplicate schedule, edit schedule, switch filter tabs | `daily_schedules`, usage across `week_schedule_day_assignments`, create/duplicate/delete transactional APIs | loading, empty, success, action_error |
| Edit Daily Schedule | `8e33f9e06c3f4ff39fd5add84b37b1ff` | No | `/schedules/:scheduleId/edit` | From schedule library edit action | Rename schedule, add/edit/remove segment, set peak-shaving slider, toggle grid charging, save, delete | `daily_schedules`, `time_segments`, transactional replace-segments API/RPC with server validation | loading, success, validation_error, save_error |
| Weekly Assignment Planner | `0c3a6b3664b64e6881c9e7352fa4ad33` | Yes | `/weekly` | Bottom nav Weekly | Assign per-day schedule, bulk apply Mon-Fri, set weekend profiles, apply changes | `week_schedules`, `week_schedule_day_assignments`, `daily_schedules`, bulk assignment write API | loading, success, validation_error, save_error |
| Global & Plant Settings | `63edaea2bf704b1ba43f7669d231a300` | No | `/settings` | Bottom nav Settings | Change theme mode, edit plant defaults, open cloud connection management, navigate to sharing, logout | `user_settings`, `plants` defaults, `provider_connections`, auth session/logout | loading, success, validation_error, save_error |
| Share Installation Access | `265a120827a24b778e519581129c049e` | No | `/settings/sharing` | Settings action/link | Add email to access list, remove email access entries | `plant_members` (email-backed access list), invite/member mutation function(s) | loading, empty, success, validation_error, save_error |
| Today's Status Dashboard (alt variant) | `a8f5815aaf34425ebdd93bf5025bd51a` | Yes | N/A (archive candidate) | N/A | Older variant of Today screen without installation selector sheet | None (do not implement as primary route unless promoted in Stitch) | N/A |

## Notes

- Settings and sharing routes are now covered by Stitch screens.
- Sharing UX was simplified to list-based email access management (add/remove) to match product decision.
