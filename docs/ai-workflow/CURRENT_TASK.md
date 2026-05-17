# Current Task

> **Branch `feat/attendance-stabilization` is merge-ready.** All code complete, validation passed, docs updated (2026-05-17). Execute the merge sequence below.

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

## Merge sequence for v1.2.0

All prerequisites are complete:
- `firestore:indexes` deployed ✅
- Owner validation on physical device passed ✅
- `flutter analyze` clean ✅
- CHANGELOG and release checklist updated ✅

### Step 1 — Merge

Open a PR `feat/attendance-stabilization → main` titled `release: v1.2.0`.
Body: link to the `[1.2.0]` CHANGELOG section.
Use a **merge commit** (not squash) to preserve per-feature history.

### Step 2 — Post-merge Firebase deploy

```
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Run from repo root after `main` is up to date. This release touches Cloud Functions
(schedule-aware statuses, FCM token migration, template-error alerting), Firestore rules
(fcm_tokens, schedules), and indexes (task completed-at indexes).

### Step 3 — Tag and GitHub Release

```
git checkout main && git pull
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
```

Create a GitHub Release on the `v1.2.0` tag. Body = the `[1.2.0]` section of `CHANGELOG.md`.

### Step 4 — Store binary

This release includes `local_auth` (native plugin) — not Shorebird patch-eligible.
Requires a full store binary:

```
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS (macOS required)
```

Upload to Google Play Console (internal track first) and App Store Connect (TestFlight first).

### Step 5 — Mandatory update gate

After store approval, decide in `config/app_settings` whether to bump
`minimumAndroidVersion` / `minimumIosVersion` to force existing users onto v1.2.0.
The attendance system requires this binary — if you want to gate attendance access,
bump the minimum. If not, leave unchanged (users update at their own pace).

### Step 6 — Version bump for next cycle

After tagging, bump `pubspec.yaml` on `main`:
`1.2.0+4` → `1.3.0+5` (or whichever next version is chosen).

### Shorebird Phase 4 verification (deferred, not blocking)

Manual device test — modify one translation value only, create a Shorebird patch,
verify it reaches a device without a store update. Record result in `docs/release-checklist.md`.
This is informational and does not block the v1.2.0 binary release.
