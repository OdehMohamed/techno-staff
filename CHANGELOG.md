# Changelog

All notable changes to Techno Staff are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.1] - 2026-05-28

### Fixed

- Admin attendance correction always failed when notes were left blank. The Cloud Function wrote `notes: undefined` into a nested Firestore map inside the `attendance_logs` audit entry, which Firebase Admin SDK v12 rejects as an invalid value, producing an `internal` error on every note-free correction attempt. Fixed by conditionally omitting `notes` from the audit log's `newValue` map when not provided.
- Task filter "Assigned To" employee list was empty when the filter sheet was opened without first visiting the Employees screen. The task screen now preloads the employee list silently on initialization so the filter is always ready.

## [1.3.0] - 2026-05-27

### Added

- Admin attendance day reset — admins can clear all sessions for one employee on one day from the roster's expanded row. The reset is schedule-aware (classifies the day as `absent` or `off_day` based on the employee's schedule) and writes a full audit entry to `attendance_logs` preserving the previous status and sessions (`action: admin_reset`).
- Recurring task creation in the Add Task flow — admins see a "Repeat this task" toggle that reveals recurrence configuration (daily, weekly, monthly) without leaving the task creation screen. When repeat mode is active, the single-employee dropdown is replaced by a multi-select chip picker so templates can be assigned to multiple employees at once. Toggling back restores the previous single selection. A "Create first task now" option generates one task instance per selected employee immediately alongside the template.
- Assigned employee name shown on admin task cards — admin All Tasks view now displays the assignee's name below each task description.
- Admin task filter by assigned employee — the filter sheet includes a new "Assigned To" chip row for admins, wired into both active and completed task lists.

### Fixed

- Admin attendance correction showed "Network error" regardless of the actual server error — the catch block was discarding the exception type and hardcoding the error key; now correctly maps `permission-denied` and `invalid-argument` codes to the corresponding localized messages.
- Check-in and check-out button state now updates immediately after each action instead of waiting for the Firestore stream to propagate — the cubit fetches the updated record directly from the server after the callable returns.
- Add Employee button on the Employees screen was obscured by the floating action button on lower list cards — fixed with bottom padding on the list.

### Changed

- Recurring task controls (repeat toggle, recurrence configuration, multi-assignee picker, first-instance toggle) are now admin-only; employees continue to see only the standard one-time task creation form.

## [1.2.0] - 2026-05-17

### Added

- Attendance system — server-authoritative check-in/check-out via biometric-guarded callable (`recordAttendance`); multi-session daily records; `attendance/{userId_YYYY-MM-DD}` document shape with `sessions[]`, `totalDurationMinutes`, and `status` (present/absent/late).
- Admin attendance roster — date-picker view of all employees' daily status; expandable session cards; admin correction sheet (`adminCorrectAttendance` callable) with audit trail preserved in `originalSessions`.
- Employee attendance history screen — scrollable personal record with expandable daily cards; monthly attendance summary with per-status counts, attendance rate progress bar, and worked/not-worked grouping.
- Daily absence marker — Cloud Function cron (`sendDailyAbsenceMarker`, 23:00 Asia/Jerusalem) marks employees with no sessions as `absent`; idempotent, skips employees with existing session data.
- Attendance section in admin Reports screen — per-employee monthly breakdown alongside the existing task report; included in PDF export.
- Today's attendance card on the employee home screen — live check-in status, time, and session duration; tappable to the attendance screen; loading placeholder holds layout during stream initialization.
- Attendance summary card on the admin dashboard — present + late headline, conditional chips for late and absent counts; tappable to the admin attendance roster.
- Overdue alert card on the admin dashboard — surfaces when open overdue tasks exist; uses error-container styling; tappable to the tasks screen.
- Recurring task templates — admin-only template management (daily / weekly / monthly recurrence); `generateRecurringTaskInstances` cron generates deterministic instances per assignee per day with layered idempotency; multi-assignee template support.
- `testTaskDeadlineReminders` and `testOverdueTaskEscalations` admin-callable dry-run functions for deadline/escalation pipelines.
- Recurring template errors now surface to all admins via in-app notification instead of only appearing in Cloud Functions logs.
- Exact-time deadlines — tasks can now specify an exact due time alongside their date (`hasDueTime` flag); date-only tasks continue to target end-of-day; countdown chip, urgency grouping, task-detail display, and due-label coloring all adapt accordingly.
- Completed task tab — both admin and employee task views now have a third "Completed" tab with recency grouping (This Week / This Month / Older); fetched lazily on first visit.
- Task quick-filter chips — persistent Overdue / Due Soon / High Priority chip row above the search bar for one-tap filtering; urgency groups collapse automatically when a quick filter is active; filter icon shows an active-count badge; a single clear action resets search, sheet filters, and quick filters together.

### Changed

- FCM token storage moved from `users/{uid}.fcmToken` to a dedicated `fcm_tokens/{uid}` collection (`allow read: if false`); clients can no longer read each other's push tokens. Cloud Functions use admin SDK to bypass rules. Existing users receive a passive migration — token is written to the new location on next sign-in.
- `createEmployeeUser` callable now rejects any `role` value outside `admin | employee` at the server layer.
- All Firestore `.get()` reads across every repository now use `GetOptions(source: Source.server)` to prevent stale cache from surfacing after mutations (tasks, employees, reports, notifications, attendance, update-gate config, role reads at auth time).
- All Firestore collection path string literals replaced with `FirebasePaths.*` constants throughout the codebase.
- ESLint enforcement is now real — blanket `/* eslint-disable */` suppressor removed from `functions/index.js`; `require-jsdoc` turned off and `max-len` set to 120 in `.eslintrc.js`; all formatting violations auto-fixed; predeploy lint gate now catches real violations.
- Employee home task preview is urgency-sorted (overdue float to top, then nearest deadline first), raised from 3 to 5 cards, and each card shows a due-date label with red/orange/grey coloring.
- Admin reports attendance summary redesigned to match the employee screen layout — attendance rate progress bar at top, worked vs. not-worked grouping, correction row; replaces the previous flat chip list.
- Attendance rate is now schedule-aware on both employee and admin reporting surfaces: denominator is the employee's scheduled working days for the selected month, not recorded-absence counts.

### Fixed

- Attendance records correctly use Asia/Jerusalem wall-clock date for all session grouping and daily-marker logic; no raw UTC date math.
- Admin correction preserves the original sessions array in `originalSessions` on first correction only, so the initial employee-recorded state is never overwritten by subsequent admin edits.
- Completed task tab preserves Firestore `completedAt` DESC ordering regardless of any active client-side filters.
- Task list refresh is consistent after status change, delete, or task-detail edits — all affected tabs refresh together.

### Security

- FCM token isolation: tokens no longer readable by any authenticated client (previously any signed-in user could read any other user's FCM token from the `users` collection). Isolated to `fcm_tokens` collection with `allow read: if false`.
- `deleteUserAccount` now cleans up `fcm_tokens/{uid}` in addition to the `users/{uid}` doc and notification history.

## [1.1.0] - 2026-05-14

### Added

- Counter task type — tasks with a target count and an increment button on the assignee's card; completion is derived from progress and persisted as the task's status so existing dashboards / reports / notifications continue to work unchanged.
- Live countdown timer chip on the tasks list and task details screens, using adaptive 1s/60s ticker cadence, end-of-day deadline semantics, and RTL-friendly localized labels.
- Edit Profile screen (Settings → Account → Edit Profile) — users can update their display name (2–50 chars). Save button disabled until value is valid and changed from current.
- Change Password screen (Settings → Account → Change Password) — reauthenticates with current password before updating; minimum 8 chars; confirm-field cross-validation.
- Password change now revokes refresh tokens for all of the user's sessions, so other signed-in devices route back to login on their next token refresh (eventual, up to ~1 hour).

### Fixed

- Auth lifecycle now clears FCM token state on sign-out and successful account deletion, and delete-account now reliably transitions to login by emitting unauthenticated state instead of relying on passive listener behavior.
- Account changes made on one device now propagate to other devices logged into the same account: when Firebase server-invalidates the session after password change, account deletion, disablement, or token revocation, affected devices route back to login once the SDK reports the invalidated session.
- iOS first-launch `apns-token-not-set` race no longer logs spuriously; FCM token is obtained on subsequent sign-in.
- FCM push notifications now respect the recipient's chosen language (English / Arabic). In-app notifications were already localized; this fix covers the system-tray push payload.
- Theme preference (system / light / dark) now persists across app launches via `shared_preferences`. The persisted choice is hydrated before the first frame paints, so cold start does not flash the default theme.

## [1.0.1] - 2026-04-30

### Fixed

- Privacy policy URL inside the About screen no longer returns 404 (switched to `.md` path).
- Final support email applied in `privacy-policy.md`.
- CHANGELOG date placeholder corrected.

## [1.0.0] - 2026-04-30

### Added

- Employee task creation with any-to-any assignment (PR #6).
- Admin task tabs: "Assigned to me" and "All tasks" (PR #8).
- Task delete UI for admins and creators (PR #9).
- Task search and filtering with global filter state and bottom-sheet UX (PR #10).
- Account deletion via Cloud Function callable and Settings account section (PR #14).
- Privacy policy at `docs/privacy-policy.md` and Settings About screen (PR #14).
- Android 13+ POST_NOTIFICATIONS manifest permission (PR #13).
- Firebase Crashlytics global error reporting and per-user identification (PR #5).

### Changed

- Bilingual app surface using `easy_localization` (en, ar) with RTL support.
- Tasks screen supports global search, filter, and sort across role-specific tabs (PR #10).
- App display name standardized to "Techno Staff" across Android and iOS (PR #12).
- Bumped Firebase Flutter packages: cloud_firestore 6.3, cloud_functions 6.2, firebase_auth 6.4, firebase_core 4.7, firebase_messaging 16.2 (PR #5).

### Fixed

- English chart legend rendering: rename `in_pending_tasks` to `pending_tasks` (PR #12).

### Security

- Removed all `debugPrint` calls from `lib/`, eliminating release-log leakage of FCM tokens, user IDs, and task metadata (PR #11).
- Tightened Firestore rules to require `assignedBy` immutability on task updates (PR #6).

[Unreleased]: https://github.com/OdehMohamed/techno-staff/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/OdehMohamed/techno-staff/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/OdehMohamed/techno-staff/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/OdehMohamed/techno-staff/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/OdehMohamed/techno-staff/releases/tag/v1.0.0
