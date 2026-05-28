# Current Task

> No active task. v1.3.1 hotfix merged to main (2026-05-28). Owner action required (see below).

## Owner-required steps for v1.3.1

### 1. Firebase deploy (run from repo root after pulling main)

```bash
firebase deploy --only functions
```

This deploys the fix for `adminCorrectAttendance` — attendance corrections submitted without notes no longer fail. No Firestore rules or index changes.

### 2. Shorebird patch (delivers the Dart-side employee filter fix)

```bash
shorebird patch android
shorebird patch ios
```

Both fixes are pure Dart / CF — no native plugin changes. Shorebird patch is the correct delivery path for the Dart side.

### 3. Post-deploy verification

- Admin attendance screen → open correction sheet for any employee → submit **without** entering notes → correction should succeed (roster updates, success snackbar shows)
- Admin task screen → tap filter icon → "Assigned To" section shows employee names without needing to visit the Employees screen first

---

## v1.3.1 hotfix — what was fixed

### Bug 1 — Attendance correction always failed without notes (CF)

`adminCorrectAttendance` wrote `notes: nextValue.notes` into a nested Firestore map inside the `attendance_logs` audit entry. When the admin submits without notes, `nextValue.notes` is `undefined`. Firebase Admin SDK v12 throws a sync `Error` for `undefined` in nested maps; Functions wraps it as `internal`; Flutter maps `internal` to `network_error`. Fixed by conditionally spreading `notes` only when defined.

### Bug 2 — Employee filter chip list empty before visiting Employees screen (Dart)

`_openFilterBottomSheet` snapshots `EmployeesCubit.state.employees` at open time. `fetchEmployees()` was only triggered by `EmployeesScreen.initState`. `TasksScreen` now calls `fetchEmployees(silent: true)` in its own `initState` for admin users so the list is pre-populated.

### Files changed (PR #41)

- `functions/index.js` — conditional spread in `adminCorrectAttendance` audit log write
- `lib/features/tasks/presentation/screens/tasks_screen.dart` — eager `fetchEmployees` in `initState`
- `pubspec.yaml` — version bumped to `1.3.1+6`
- `CHANGELOG.md` — added v1.3.1 and backfilled missing v1.3.0 entry
