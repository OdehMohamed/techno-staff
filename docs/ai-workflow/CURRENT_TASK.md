# Current Task

> No active task. v1.3.0 cycle complete — PR #40 merged to main (2026-05-27). Owner deploy step pending (see below).

## Owner-required steps before v1.3.0 is live in production

### 1. Firebase deploy (run from repo root after pulling main)

```bash
firebase deploy --only functions,firestore:rules
```

This release adds one new Cloud Function (`adminResetAttendance`) and does not change Firestore rules or indexes. No `firestore:indexes` deploy needed.

### 2. Post-deploy verification

- Admin attendance screen → expand any roster row → "Reset Day" button appears
- Tap Reset Day → confirmation dialog → confirm → roster refreshes, success snackbar shows
- Firestore console → `attendance_logs` → new doc with `action: "admin_reset"`, `previousStatus`, `previousSessions` fields
- Attend check-in or check-out on employee device → button state changes immediately (no delay)
- Admin attendance correction → if a permission error occurs, shows correct message (not "network failure")

---

## Work done this cycle on feat/v1.3.0-improvements

### Bug fixes (all done)
- **Employees screen FAB overlap** — `ListView.separated` padding `bottom: 80` so the schedule button on lower cards is not blocked by the extended FAB.
- **Attendance correction always showing "network failure"** — `adminCorrect` catch block changed from `catch (_)` to `catch (e)` with `_mapAttendanceError`; added `permission-denied → not_authorized` and `invalid-argument → invalid_correction_data` mappings.
- **Check-in/check-out button not refreshing immediately** — cubit caches `_currentUserId` from `startListeningToday`; `fetchTodayRecord` (server-forced one-shot) called after check-in/check-out success; button state updates without waiting for stream propagation.

### Features (all done)
- **Assignee name on admin task cards** — admin "All Tasks" tab shows assigned employee name inline below the task description.
- **Recurring task creation in Add Task flow** — "Repeat this task" toggle (admin-only) progressively reveals recurrence type, weekday/day-of-month pickers, and "Create first task now" toggle. Normal task form unchanged for employees.
- **Multi-assignee recurring templates** — when repeat mode is active, single-employee dropdown is replaced by a multi-select `FilterChip` picker. Toggle transition preserves selection in both directions. First-instance creation loops per selected employee.
- **Admin task filter by assigned employee** — filter bottom sheet has an "Assigned To" chip row for admins; `TaskFilters.filterAssigneeId` wired into active and completed task lists.
- **Admin attendance day reset** — "Reset Day" button in roster expanded section; confirmation dialog; `adminResetAttendance` Cloud Function reads schedule to classify reset as `absent` or `off_day`; transaction overwrites attendance doc and writes audit entry to `attendance_logs` (action: `admin_reset`, preserves `previousStatus` and `previousSessions`); `resetStatus`/`resetError` state fields independent of correction state.

### Files changed (PR #40)
- `assets/translations/en.json` + `ar.json` — 12 new keys each
- `functions/index.js` — `adminResetAttendance` callable added
- `lib/features/admin/presentation/screens/admin_attendance_screen.dart`
- `lib/features/attendance/data/repositories/attendance_repository.dart`
- `lib/features/attendance/presentation/cubit/attendance_cubit.dart`
- `lib/features/attendance/presentation/cubit/attendance_state.dart`
- `lib/features/employees/presentation/screens/employees_screen.dart`
- `lib/features/tasks/presentation/screens/add_task_screen.dart`
- `lib/features/tasks/presentation/screens/tasks_screen.dart`
- `lib/features/tasks/presentation/widgets/task_filter_bottom_sheet.dart`
