# Current Task

> No active task. v1.2.0 released — PR #39 merged to main, tagged `v1.2.0`, GitHub Release created, version bumped to `1.3.0+5` (2026-05-17).

## Work done this session on feat/attendance-stabilization

### T1 — Data layer (done)
- `task_model.dart`: `hasDueTime` in `fromMap` / `toMap` / `copyWith`
- `FirebasePaths.completedAt` constant added
- `tasks_repository.dart`: `getCompletedTasksAssignedTo`, `getCompletedTasksCreatedBy`, `getAllCompletedTasks`
- `firestore.indexes.json`: 3 completed-task indexes + 3 active-task indexes (total 6 task indexes)
- `tasks_state.dart` + `tasks_cubit.dart`: `completedTasks` / `completedTasksStatus` / `fetchCompletedTasks`

### T2 — Deadline-time UI (done)
- `DueDateTimePicker` shared widget (add_task + edit_task screens)
- `hasDueTime`-aware `CountdownChip` (orange "due today" window for date-only)
- `_effectiveDeadline` helper in tasks_screen for correct urgency grouping
- `task_details_screen`: conditional time display based on `hasDueTime`

### T3 — Completed tab (done)
- Third "Completed" tab in both admin and employee task views
- Lazy loading (only fetches on first visit)
- Recency grouping: This Week / This Month / Older
- Refresh consistency after status change / delete / task detail edits

### T4 — Filter/Discovery UX (done)
- `_QuickFilter` chip row: Overdue / Due Soon / High (always visible above search bar)
- Group-collapse behaviour: urgency groups disappear when a quick filter narrows the view
- `_clearAllFilters()` single path clears search + sheet filters + quick filters
- `_applyCompletedFilters`: preserves Firestore `completedAt DESC` ordering for completed tab
- `_priorityRank` helper; active-filter badge on the filter icon
- New i18n keys: `no_time`, `custom_time`, `completed_this_week`, `completed_this_month`, `completed_older`, `due_soon`

### Phase 4 — Dashboard restructuring (done)
- **Employee Home**: `_TodayAttendanceCard` — check-in status, check-in time and duration, tappable → attendance screen. Loading placeholder holds card height during stream init. Task preview urgency-sorted (overdue float to top), cap raised 3 → 5, `_TaskDueLabel` with red/orange/grey coloring on each card.
- **Admin Dashboard**: `_AttendanceSummaryCard` replaces single-number card — shows present + late headline, conditional `_AttendanceChip` badges for late and absent counts, tappable → admin attendance screen. `_OverdueAlertCard` appears below filter chips when `overdueOpenTasks > 0`, uses `errorContainer` color, tappable → tasks screen.

## Pending owner actions for v1.2.0 store release

The following require owner execution (device, store, or Firebase credentials):

### 1. Firebase deploy (run from repo root after pulling main)
```
firebase deploy --only functions,firestore:rules,firestore:indexes
```
This release touches Cloud Functions (schedule-aware statuses, FCM token migration,
template-error alerting), Firestore rules (fcm_tokens, schedules collections), and
indexes (task completedAt DESC indexes).

### 2. Store binary build and upload
This release includes `local_auth` (native plugin) — not Shorebird patch-eligible.
Requires a full store binary:
```
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS (macOS required)
```
Upload to Google Play Console (internal track first) and App Store Connect (TestFlight first).

### 3. Mandatory update gate decision
After store approval, decide in Firestore console `config/app_settings` whether to bump
`minimumAndroidVersion` / `minimumIosVersion`. Bump if you want to gate attendance access
to users on v1.2.0+. Leave unchanged if you prefer natural update pace.

### 4. Post-release verification (from docs/release-checklist.md)
- Crashlytics receives events from production binary
- Push notifications work end-to-end on production build
- Attendance check-in/check-out end-to-end on production binary
- `sendDailyAbsenceMarker` cron verified morning after release (check Firestore console)

### 5. Shorebird asset-patching verification (deferred, not blocking)
Empirical test: create a Shorebird patch with only a translation value change, verify it
reaches a device without a store update. Record result in `docs/release-checklist.md`.
