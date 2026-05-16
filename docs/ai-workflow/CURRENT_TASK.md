# Current Task

> Last updated: 2026-05-16

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task: Attendance Architecture Stabilization

**Target release**: 1.2.0
**Planning round completed**: 2026-05-16
**Branch**: `feat/attendance-stabilization` (from `dev`, after `feat/attendance-p3-supplement` merges)
**Prerequisite**: PR #37 (`feat/attendance-p3-supplement`) merged to `dev` first.

---

### Background

P1–P3 of the attendance system are complete. Real-device testing uncovered five issues that collectively indicate the architecture needs one stabilization pass before the subsystem is considered locked:

1. **Employee history invisible** — root cause: `firebase.json` is missing `"indexes": "firestore.indexes.json"`, so the composite index was never deployed. Secondary: UI silently shows "no records" on query error.
2. **Single-session-per-day model is too restrictive** — split shifts, leave-and-return, and evening work are realistic and unsupported.
3. **Reports attendance section shows wrong data** — daily roster (operational) belongs in Attendance Management, not Reports. Reports should show monthly attendance per employee.
4. **`local_auth` semantics undocumented** — OS/device authentication vs. app password must be explicit for testers and future maintainers.
5. **`status: 'manual'` conflates status and metadata** — correction is provenance, not an attendance status value.

This task corrects all five before any broader rollout.

---

### Decisions Locked in This Pass

| Dimension | Decision |
|---|---|
| Sessions model | Sessions array on day document (unlimited pairs/day, guard: cannot check-in while session is open) |
| Status values | `present \| absent` only — `manual` removed from new writes; old docs render gracefully via fallback |
| Correction metadata | `isCorrected: bool`, `correctedBy`, `correctedAt`, `notes` — separate from `status` |
| Employee monthly view | Two access paths: (1) new `EmployeeMonthlyAttendanceScreen` for employees via drawer; (2) Reports screen section for admins viewing any employee |
| Index fix | `firebase.json` wires up `firestore.indexes.json`; user deploys `firebase deploy --only firestore:indexes` after merge |

---

### Firestore Data Model (new)

```
attendance/{userId}_{YYYY-MM-DD}
  userId: string
  userName: string
  date: string                        // "YYYY-MM-DD" Asia/Jerusalem — server-computed
  status: 'present' | 'absent'        // 'manual' no longer written — fallback rendering kept for old docs
  isCorrected: boolean                // false by default; true after any admin correction
  totalDurationMinutes: number        // sum of all closed session durations; 0 if no closed sessions
  sessions: [                         // array; grows with each check-in/out pair
    {
      checkInAt: Timestamp,
      checkOutAt: Timestamp | null,   // null = session currently open
      durationMinutes: number | null  // null until session closed
    }
  ]
  notes: string | null                // admin correction notes
  correctedBy: string | null          // uid of admin who last corrected
  correctedAt: Timestamp | null
  createdAt: Timestamp
  updatedAt: Timestamp
```

**Removed fields** (from old model): `checkInAt` (now derived getter), `checkOutAt` (derived getter), `durationMinutes` (renamed `totalDurationMinutes`), `biometricVerified` (not surfaced in UI).

**attendance_logs**: unchanged — server-only, same structure.

---

### Composite Indexes (`firestore.indexes.json`)

Keep existing:
- `attendance`: `(date ASC, status ASC)` — admin daily roster
- `attendance`: `(userId ASC, date DESC)` — employee history / monthly query

Add:
- `attendance`: `(userId ASC, date ASC)` — monthly range query (Reports, ascending chronological order)

Wire up: `firebase.json` Firestore block must include `"indexes": "firestore.indexes.json"`.

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

---

### Cloud Functions (`functions/index.js`) — Changes Only

#### `recordAttendance` — sessions array logic

**check_in:**
1. Auth guard (unchanged).
2. Compute Jerusalem date → `docId` (unchanged).
3. Read `users/{uid}` for `userName` (unchanged).
4. In Firestore transaction:
   - Get day doc (may not exist).
   - Read `sessions` array (default `[]` if doc missing or field absent).
   - Guard: if last session exists and `lastSession.checkOutAt == null` → throw `HttpsError('already-exists', 'already-checked-in')`.
   - Append new session: `{ checkInAt: serverTimestamp, checkOutAt: null, durationMinutes: null }`.
   - If doc does not exist: `set({ userId, userName, date, status: 'present', isCorrected: false, totalDurationMinutes: 0, sessions: [newSession], createdAt: serverTimestamp, updatedAt: serverTimestamp })`.
   - If doc exists: `update({ sessions: updatedArray, status: 'present', updatedAt: serverTimestamp })`.
   - Write `attendance_logs` entry: `action: 'check_in'` (unchanged pattern).
5. Return `{ success: true, docId }`.

**check_out:**
1. Auth guard (unchanged).
2. Compute `docId` (unchanged).
3. In Firestore transaction:
   - Get day doc. If missing → throw `HttpsError('failed-precondition', 'not-checked-in')`.
   - Read `sessions`. Find open session: `sessions[sessions.length - 1]` where `checkOutAt == null`.
   - If no open session → throw `HttpsError('failed-precondition', 'not-checked-in')`.
   - Close session: `checkOutAt = now`, `durationMinutes = Math.max(0, Math.round((now - openSession.checkInAt.toDate()) / 60000))`.
   - Replace last element in sessions array with closed session.
   - Recompute `totalDurationMinutes = sessions.reduce((sum, s) => sum + (s.durationMinutes || 0), 0)`.
   - `update({ sessions: updatedArray, totalDurationMinutes, updatedAt: serverTimestamp })`.
   - Write `attendance_logs` entry: `action: 'check_out'` (unchanged pattern).
4. Return `{ success: true }`.

**Remove**: the `already-checked-out` error code is gone. Check-out only fails on "no open session." Check-in only fails on "open session already exists."

#### `adminCorrectAttendance` — sessions replace + `isCorrected`

Input payload changes:
```
request.data: {
  userId: string,
  date: string,          // "YYYY-MM-DD"
  fields: {
    checkInAt?: string,  // ISO string
    checkOutAt?: string, // ISO string
    notes?: string
  }
}
```

**Remove** `fields.status` from the callable interface — status is no longer caller-settable.

Logic:
1. Admin auth guard (unchanged).
2. `docId = "${userId}_${date}"` (unchanged).
3. In Firestore transaction:
   - Snapshot `previousValue` (unchanged).
   - Build update map:
     - Always set: `isCorrected: true`, `correctedBy: adminUid`, `correctedAt: serverTimestamp`, `updatedAt: serverTimestamp`.
     - If `fields.notes` provided: set `notes`.
     - If both `checkInAt` and `checkOutAt` provided:
       - Parse ISO strings to Timestamps (with NaN guard, unchanged pattern).
       - `durationMinutes = Math.max(0, Math.round((checkOutAt - checkInAt) / 60000))`.
       - `sessions = [{ checkInAt: checkInAtTimestamp, checkOutAt: checkOutAtTimestamp, durationMinutes }]`.
       - `totalDurationMinutes = durationMinutes`.
       - `status = 'present'`.
     - If neither time provided: do not touch `sessions` or `status` — notes-only correction.
   - If doc does not exist: also set `userId`, `userName` (fetch from `users/{userId}`), `date`, `createdAt: serverTimestamp`.
   - Write `attendance_logs` entry: `action: 'admin_correction'` (unchanged pattern).
4. Return `{ success: true, docId }`.

#### `sendDailyAbsenceMarker` — minor update

When creating the absent doc for employees with no record, write the new structure:
```js
{
  userId, userName, date,
  status: 'absent',
  isCorrected: false,
  totalDurationMinutes: 0,
  sessions: [],
  createdAt: serverTimestamp,
  updatedAt: serverTimestamp
}
```

No other changes to this function.

---

### Flutter — Data Layer

#### New: `lib/features/attendance/data/models/attendance_session.dart`

```dart
class AttendanceSession {
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;

  const AttendanceSession({
    required this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
  });

  factory AttendanceSession.fromMap(Map<String, dynamic> data) {
    return AttendanceSession(
      checkInAt: _toDateTime(data['checkInAt'])!,
      checkOutAt: _toDateTime(data['checkOutAt']),
      durationMinutes: data['durationMinutes'] is int
          ? data['durationMinutes'] as int
          : null,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
```

#### Updated: `lib/features/attendance/data/models/attendance_model.dart`

Fields:
- Keep: `id`, `userId`, `userName`, `date`, `status`, `notes`, `correctedBy`, `createdAt`, `updatedAt`
- Add: `sessions: List<AttendanceSession>`, `totalDurationMinutes: int`, `isCorrected: bool`, `correctedAt: DateTime?`
- Remove direct fields: `checkInAt`, `checkOutAt`, `durationMinutes`, `biometricVerified`
- Add computed getters:
  ```dart
  DateTime? get checkInAt => sessions.isNotEmpty ? sessions.first.checkInAt : null;
  DateTime? get checkOutAt => sessions.isNotEmpty ? sessions.last.checkOutAt : null;
  bool get hasOpenSession => sessions.isNotEmpty && sessions.last.checkOutAt == null;
  ```

`fromMap` changes:
```dart
sessions: (data['sessions'] as List<dynamic>? ?? [])
    .map((s) => AttendanceSession.fromMap(s as Map<String, dynamic>))
    .toList(),
totalDurationMinutes: data['totalDurationMinutes'] as int? ?? 0,
isCorrected: data['isCorrected'] as bool? ??
    (data['status'] == 'manual'),  // backward compat: old docs with status:'manual'
correctedAt: _toDateTime(data['correctedAt']),
```

Status backward compat in `fromMap`:
```dart
status: (() {
  final s = data['status'] as String? ?? 'absent';
  // Old docs had 'manual' — treat as 'present' for display; isCorrected handles the annotation.
  return s == 'manual' ? 'present' : s;
})(),
```

#### Updated: `lib/features/attendance/data/repositories/attendance_repository.dart`

Add method:
```dart
Future<List<AttendanceModel>> fetchMonthlyAttendance(
  String userId,
  int year,
  int month,
) async {
  final start = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
  final nextMonth = month == 12
      ? '${year + 1}-01-01'
      : '${year.toString().padLeft(4, '0')}-${(month + 1).toString().padLeft(2, '0')}-01';

  final snapshot = await _firestore
      .collection('attendance')
      .where('userId', isEqualTo: userId)
      .where('date', isGreaterThanOrEqualTo: start)
      .where('date', isLessThan: nextMonth)
      .orderBy('date', descending: false)
      .get();

  return snapshot.docs
      .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
      .toList();
}
```

Remove from `adminCorrect`: `fields` no longer carries `status` — remove it from the payload map construction.

#### Updated: `lib/features/attendance/presentation/cubit/attendance_state.dart`

Add fields:
```dart
final AttendanceLoadStatus monthlyStatus;
final List<AttendanceModel> monthlyRecords;
final String? monthlyError;
```

Add clear flag: `clearMonthlyError`.

#### Updated: `lib/features/attendance/presentation/cubit/attendance_cubit.dart`

Add method:
```dart
Future<void> loadMonthlyAttendance(String userId, int year, int month) async {
  emit(state.copyWith(
    monthlyStatus: AttendanceLoadStatus.loading,
    clearMonthlyError: true,
  ));
  try {
    final records = await _attendanceRepository.fetchMonthlyAttendance(userId, year, month);
    emit(state.copyWith(
      monthlyStatus: AttendanceLoadStatus.loaded,
      monthlyRecords: records,
    ));
  } catch (_) {
    emit(state.copyWith(
      monthlyStatus: AttendanceLoadStatus.error,
      monthlyError: 'network_error',
    ));
  }
}
```

---

### Flutter — Presentation Layer

#### Updated: `lib/features/attendance/presentation/widgets/attendance_check_button.dart`

Button state logic changes. Current logic uses `checkOutAt != null` as terminal state. New logic:

- `todayRecord == null` OR `!todayRecord.hasOpenSession` → show "Check In" button
- `todayRecord.hasOpenSession` → show "Check Out" button
- No "done for today" terminal state — after checkout, check-in button reappears immediately

The `onCheckIn` callback is active when `canCheckIn` and not submitting. The `onCheckOut` callback is active when `canCheckOut` and not submitting.

#### Updated: `lib/features/attendance/presentation/widgets/attendance_record_card.dart`

- Replace `record.durationMinutes` with `record.totalDurationMinutes` for the duration display.
- Add `isCorrected` indicator: if `record.isCorrected`, show a small `Icon(Icons.edit_outlined, size: 14)` next to the status chip. No new translation key needed — icon only.
- The `_StatusChip` maps `'manual'` → fallback to `'attendance_status_present'` key (unchanged from current), but this path is now only for old docs.

#### Updated: `lib/features/attendance/presentation/screens/attendance_screen.dart`

Fix the history section error state:
```dart
if (state.historyStatus == AttendanceLoadStatus.loading && state.history.isEmpty)
  const Center(child: CircularProgressIndicator())
else if (state.historyStatus == AttendanceLoadStatus.error)
  Padding(
    padding: const EdgeInsets.only(top: AppSizes.sm),
    child: Text((state.historyError ?? 'network_error').tr()),
  )
else if (state.history.isEmpty)
  Padding(
    padding: const EdgeInsets.only(top: AppSizes.sm),
    child: Text('no_attendance_records'.tr()),
  )
else
  ...state.history.map(...)
```

No other structural changes to this screen.

#### New: `lib/features/attendance/presentation/screens/employee_monthly_attendance_screen.dart`

Employee-accessible screen for their own monthly attendance history.

- `StatefulWidget` with `_year` (int) and `_month` (int) state, initialized to current month.
- `initState` → `WidgetsBinding.instance.addPostFrameCallback` → `attendanceCubit.loadMonthlyAttendance(user.id, _year, _month)`.
- Month navigator: left/right arrow buttons + `"Month Year"` label (localized via `DateFormat.yMMMM`). Tapping arrows steps month; calls `loadMonthlyAttendance` on change. Cannot navigate to a future month.
- `BlocBuilder<AttendanceCubit, AttendanceState>` on `monthlyStatus` / `monthlyRecords`:
  - Loading → `CircularProgressIndicator`
  - Error → error text
  - Loaded, empty → `EmptyStateWidget`
  - Loaded → summary stats row + `ListView` of `AttendanceRecordCard` (already shows date, times, duration, correction indicator)
- Summary stats row (above the list): `days_present` count, `days_absent` count, `total_hours_worked` (totalDurationMinutes sum ÷ 60, formatted as "Xh Ym"), `corrections` count (records where `isCorrected == true`).
- `AppBar` title: `'monthly_attendance'.tr()`. `AppDrawer` included.

Wire up:
- `RouteNames.employeeMonthlyAttendance = '/employee-monthly-attendance'`
- `app_router.dart`: add route → `EmployeeMonthlyAttendanceScreen()`
- `app_drawer.dart`: add employee entry after "My Attendance" entry → `RouteNames.employeeMonthlyAttendance`

#### Updated: `lib/features/reports/presentation/screens/reports_screen.dart`

**Remove**: the daily roster attendance section that currently shows all employees for one selected date.

**Add**: monthly attendance section for the selected employee and month (same pickers already used by the task report section). Trigger: when the report loads (employee + month are already selected), also call `context.read<AttendanceCubit>().loadMonthlyAttendance(selectedEmployee.id, year, month)`.

Attendance section layout:
1. Section header: `'monthly_attendance'.tr()`
2. Summary stats row: same four stats as `EmployeeMonthlyAttendanceScreen` above.
3. `BlocBuilder<AttendanceCubit, AttendanceState>` on `monthlyStatus` / `monthlyRecords` — list of day cards.

This section is rendered only when a report has been generated (employee + month selected). Use `shrinkWrap: true, physics: const NeverScrollableScrollPhysics()` since the Reports screen is already inside a scroll view.

Admin only — Firestore rules already allow admin to read any `userId`'s attendance.

---

### Translation Keys (5 new — parity target: 286/286)

| Key | English | Arabic |
|---|---|---|
| `monthly_attendance` | Monthly Attendance | الحضور الشهري |
| `total_hours_worked` | Total Hours Worked | إجمالي ساعات العمل |
| `days_present` | Days Present | أيام الحضور |
| `days_absent` | Days Absent | أيام الغياب |
| `corrections` | Corrections | التصحيحات |

Keep existing `attendance_status_manual` → "Corrected" / "تم التصحيح" — backward compat for old documents.

---

### Files Changed (complete list)

**Backend:**
- `firebase.json` — add `"indexes": "firestore.indexes.json"` to Firestore block
- `firestore.indexes.json` — add `(userId ASC, date ASC)` index
- `functions/index.js` — update `recordAttendance` (sessions), `adminCorrectAttendance` (isCorrected, remove status), `sendDailyAbsenceMarker` (new doc structure)

**Data layer:**
- `lib/features/attendance/data/models/attendance_session.dart` — new
- `lib/features/attendance/data/models/attendance_model.dart` — updated
- `lib/features/attendance/data/repositories/attendance_repository.dart` — add `fetchMonthlyAttendance`, update `adminCorrect` payload

**State:**
- `lib/features/attendance/presentation/cubit/attendance_state.dart` — add monthly fields
- `lib/features/attendance/presentation/cubit/attendance_cubit.dart` — add `loadMonthlyAttendance`

**UI:**
- `lib/features/attendance/presentation/widgets/attendance_check_button.dart` — sessions-based button state
- `lib/features/attendance/presentation/widgets/attendance_record_card.dart` — `totalDurationMinutes`, correction icon
- `lib/features/attendance/presentation/screens/attendance_screen.dart` — fix error state
- `lib/features/attendance/presentation/screens/employee_monthly_attendance_screen.dart` — new
- `lib/features/reports/presentation/screens/reports_screen.dart` — remove daily roster, add monthly section
- `lib/shared/widgets/app_drawer.dart` — add employee monthly attendance entry
- `lib/core/routes/route_names.dart` — add `employeeMonthlyAttendance`
- `lib/core/routes/app_router.dart` — add route

**i18n:**
- `assets/translations/en.json` — 5 new keys
- `assets/translations/ar.json` — 5 new keys

**Docs:**
- `docs/ai-workflow/DECISIONS_LOG.md` — local_auth semantics, sessions model, correction semantics, reports semantics

---

### Out of Scope for This Pass

Do NOT implement:
- Schedule-aware lateness (`status: 'late'`) — needs scheduling model, deferred
- Session-level admin correction (correct individual sessions) — correction remains day-level
- Correct-to-absent from correction sheet (edge case) — deferred to P4
- CSV / Excel export
- Leave management, overtime

---

### Acceptance Criteria

**Bug fixes:**
- [ ] Employee can see their own attendance history (composite index deployed, query succeeds)
- [ ] `AttendanceScreen` shows an error message (not "no records") when history query fails

**Sessions model:**
- [ ] Employee can check in, check out, and check in again on the same day (multiple sessions)
- [ ] Check-in blocked while a session is open (`already_checked_in`)
- [ ] Check-out blocked when no session is open (`not_checked_in_yet`)
- [ ] `totalDurationMinutes` on day document equals sum of all closed session durations
- [ ] Check-in button reappears after checkout (no terminal "done for today" state)

**Correction semantics:**
- [ ] Admin correction sets `isCorrected: true` (not `status: 'manual'`)
- [ ] Corrected records show a pencil icon annotation next to their status chip
- [ ] `adminCorrectAttendance` callable no longer accepts `fields.status`

**Reports:**
- [ ] Reports attendance section shows monthly attendance for selected employee + month
- [ ] Daily roster removed from Reports (lives only in Attendance Management)
- [ ] Summary stats correct: days present, days absent, hours worked, corrections count

**Employee monthly view:**
- [ ] `EmployeeMonthlyAttendanceScreen` accessible from drawer
- [ ] Month navigation (prev/next) works; cannot navigate to future month
- [ ] Summary stats match monthly records

**Quality gates:**
- [ ] `npm run lint` clean
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Translation parity: 286/286
- [ ] Post-merge user action: `firebase deploy --only firestore:indexes,functions,firestore:rules`
