# Current Task

> Last updated: 2026-05-15

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task: BACKLOG #14 — Attendance / Check-in / Check-out System

**Target release**: 1.2.0
**Planning round completed**: 2026-05-15
**Implementation strategy**: 4 phased PRs (see below)

---

### Overview

Employee check-in / check-out system with biometric gate (`local_auth`), server-authoritative timestamps, and admin correction capability. Architecture-first planning round is complete; this spec is locked and ready for phase-by-phase implementation.

---

### Phased Implementation Plan

The feature is split into four independent PRs to keep review scope manageable and to isolate the one Shorebird-breaking change (Phase 2's native plugin) from purely Dart-layer phases.

| Phase | Branch | What ships | Shorebird |
|---|---|---|---|
| **P1 — Backend Foundation** | `feat/attendance-p1-backend` | 3 Cloud Functions, Firestore rules (2 blocks), 2 composite indexes, all 26 translation keys | patch-eligible (no Flutter changes) |
| **P2 — Employee Flow** | `feat/attendance-p2-employee` | `local_auth` native config, employee feature directory, check-in/check-out biometric flow, personal history screen, employee drawer entry | **full binary release required** |
| **P3 — Admin Management** | `feat/attendance-p3-admin` | Admin attendance screen, Reports tab, admin dashboard summary card, admin drawer entry | patch-eligible (pure Dart) |
| **P4 — Polish** | `feat/attendance-p4-polish` | UX edge cases, reporting refinements, runtime validation from real-device testing | patch-eligible (pure Dart) |

**Sequencing rule**: each phase branches from `dev` after the previous phase is merged. P1 can be deployed to Firebase independently and smoke-tested before P2 starts.

**P4 is not specced upfront** — its content is determined by real-device testing feedback from P1–P3.

---

#### Phase 1 Scope — Backend Foundation (`feat/attendance-p1-backend`)

Files changed:

- `functions/index.js` — 3 new exports: `recordAttendance` (onCall), `adminCorrectAttendance` (onCall), `sendDailyAbsenceMarker` (onSchedule). Full logic in the Cloud Functions section below.
- `firestore.rules` — add `attendance` and `attendance_logs` blocks (see Firestore Rules section below)
- `firestore.indexes.json` — add 2 composite indexes: `(date ASC, status ASC)` and `(userId ASC, date DESC)` on `attendance` collection
- `assets/translations/en.json` — add all 26 new keys (see Translation Keys section below)
- `assets/translations/ar.json` — matching Arabic for all 26 keys

Phase 1 acceptance criteria:
- [x] `npm run lint` clean
- [x] `recordAttendance` callable rejects unauthenticated calls
- [x] `recordAttendance` blocks double check-in (same-day Jerusalem)
- [x] `recordAttendance` blocks check-out without prior check-in
- [x] `recordAttendance` sets `durationMinutes` on check-out
- [x] `adminCorrectAttendance` rejects non-admin callers
- [x] `attendance` and `attendance_logs` Firestore rules present
- [x] `firestore.indexes.json` updated
- [x] Translation parity: 272/272

Phase 1 implementation status: completed in `feat/attendance-p1-backend` and ready to merge to `dev`.
Post-merge deployment required: `firebase deploy --only functions,firestore`.

---

#### Phase 2 Scope — Employee Flow (`feat/attendance-p2-employee`)

Files changed:

- `pubspec.yaml` — add `local_auth` (check if `connectivity_plus` already present from BACKLOG #9; add if missing)
- `android/app/src/main/AndroidManifest.xml` — add `USE_BIOMETRIC` permission
- `android/app/build.gradle` — verify `minSdkVersion >= 23`
- `ios/Runner/Info.plist` — add `NSFaceIDUsageDescription`
- `lib/features/attendance/data/models/attendance_model.dart` — new
- `lib/features/attendance/data/repositories/attendance_repository.dart` — new
- `lib/features/attendance/presentation/cubit/attendance_cubit.dart` — new
- `lib/features/attendance/presentation/cubit/attendance_state.dart` — new
- `lib/features/attendance/presentation/screens/attendance_screen.dart` — new
- `lib/features/attendance/presentation/widgets/attendance_check_button.dart` — new
- `lib/features/attendance/presentation/widgets/attendance_record_card.dart` — new
- `lib/main.dart` — wire `AttendanceRepository` and `AttendanceCubit` in existing global `MultiBlocProvider`
- `lib/core/routes/route_names.dart` — add `RouteNames.attendance`
- `lib/core/routes/app_router.dart` — add `RouteNames.attendance` → `AttendanceScreen()`
- `lib/shared/widgets/app_drawer.dart` — add "My Attendance" entry for employees

Phase 2 acceptance criteria:
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [x] Employee can check in (biometric prompt → callable → `attendance` doc created, `status: 'present'`)
- [x] Employee cannot check in twice on the same day
- [x] Employee can check out (biometric → callable → `checkOutAt` + `durationMinutes` set)
- [x] Employee cannot check out without a prior check-in
- [x] Check-in/out button disabled when offline; `no_internet_for_attendance` shown
- [x] Biometric unavailable → error snackbar, check-in blocked
- [x] Employee can view their own attendance history on `AttendanceScreen`
- [x] Employee drawer "My Attendance" entry navigates correctly

Phase 2 implementation status: completed in `feat/attendance-p2-employee`.

---

#### Phase 3 Scope — Admin Management (`feat/attendance-p3-admin`)

Files changed:

- `lib/features/admin/presentation/screens/admin_attendance_screen.dart` — new
- `lib/features/reports/presentation/screens/reports_screen.dart` — add "Attendance" tab
- `lib/features/admin/presentation/screens/admin_dashboard_screen.dart` — add today's attendance summary card
- `lib/core/routes/route_names.dart` — add `RouteNames.adminAttendance`
- `lib/core/routes/app_router.dart` — add `RouteNames.adminAttendance` → `AdminAttendanceScreen()`
- `lib/shared/widgets/app_drawer.dart` — add "Attendance Management" entry for admins

Phase 3 acceptance criteria:
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [x] Admin can view all employees' attendance for a selected date
- [x] Admin can correct any attendance record (edit times, status, notes)
- [x] Correction is logged in `attendance_logs` (via `adminCorrectAttendance` callable)
- [x] Today's attendance summary card visible on admin dashboard (present / total active)
- [x] Attendance tab visible in Reports screen (admin only)
- [x] Admin drawer "Attendance Management" entry navigates correctly

Phase 3 implementation status: completed in `feat/attendance-p3-admin`.

---

### Architecture Decisions (all locked)

| Dimension | Decision |
|---|---|
| Biometric | `local_auth`; `biometricOnly: false` (allow OS PIN/pattern/passcode fallback) |
| Write path | Cloud Function callables for all writes — client never writes to `attendance` directly |
| Doc ID | Deterministic `{userId}_{YYYY-MM-DD}` where date is Jerusalem date computed server-side |
| Collection layout | Flat `attendance/{docId}` (not subcollection) + `attendance_logs/{logId}` (server-only) |
| v1 statuses | `present \| absent \| manual` only — no `late` (deferred; data model stays compatible) |
| Offline | Block check-in/out when offline; online-only; never use Firestore offline cache for attendance |
| Absence tracking | `sendDailyAbsenceMarker` cron at 23:00 Asia/Jerusalem |
| Reporting | New "Attendance" tab in existing Reports screen (admin-only content) |
| Employee self-view | `AttendanceScreen` via employee drawer — own history + today's check-in/out button |
| Admin corrections | `adminCorrectAttendance` callable + `attendance_logs` server-only audit trail |
| Admin dashboard | Today's attendance summary card (present count / total active employees) |
| WiFi/geofencing | Explicitly out of scope for v1 |
| `local_auth` + Shorebird | Adding `local_auth` requires a full binary release — never patch-eligible |

---

### Firestore Structure

```
attendance/{userId}_{YYYY-MM-DD}
  userId: string
  userName: string
  date: string                   // "YYYY-MM-DD" in Asia/Jerusalem — server-computed
  checkInAt: Timestamp | null    // FieldValue.serverTimestamp() via Cloud Function
  checkOutAt: Timestamp | null
  biometricVerified: boolean     // client-reported soft signal — not cryptographic proof
  status: 'present' | 'absent' | 'manual'
  durationMinutes: number | null // computed on check-out: (checkOutAt - checkInAt) / 60000
  notes: string | null           // admin correction notes
  correctedBy: string | null     // uid of admin who corrected
  correctedAt: Timestamp | null
  createdAt: Timestamp           // serverTimestamp
  updatedAt: Timestamp           // serverTimestamp

attendance_logs/{logId}
  attendanceId: string           // "${userId}_${YYYY-MM-DD}"
  userId: string
  action: 'check_in' | 'check_out' | 'admin_correction'
  performedBy: string            // uid
  performedByName: string
  previousValue: map             // snapshot of changed fields before edit (null on check_in create)
  newValue: map
  performedAt: Timestamp         // serverTimestamp
  // allow write: if false — server-only, same pattern as task_logs
```

**Composite indexes needed** (add to `firestore.indexes.json`):
- `attendance`: `(date ASC, status ASC)` — admin date-based roster query
- `attendance`: `(userId ASC, date DESC)` — employee history query

---

### Cloud Functions (`functions/index.js`)

#### `recordAttendance` — onCall

Called by the Flutter client after a successful biometric challenge.

```
request.data: {
  action: 'check_in' | 'check_out',
  biometricVerified: boolean
}
request.auth.uid: employee uid (validated server-side)
```

Logic:
1. Validate `request.auth` exists; reject unauthenticated calls.
2. Compute Jerusalem date using existing `ymdInJerusalem(now)` helper → `docId = "${uid}_${date}"`
3. Read `users/{uid}` to get `userName`.
4. In a Firestore transaction:
   - **check_in**: if doc exists and `checkInAt != null` → throw `already-checked-in` error. Otherwise create/update doc with `checkInAt: FieldValue.serverTimestamp(), status: 'present', biometricVerified, createdAt/updatedAt`.
   - **check_out**: if doc does not exist or `checkInAt == null` → throw `not-checked-in` error. If `checkOutAt != null` → throw `already-checked-out` error. Otherwise update doc with `checkOutAt: FieldValue.serverTimestamp()`, compute `durationMinutes` from `(now - checkInAt.toDate()) / 60000` (round to nearest minute), set `updatedAt`.
   - In same transaction: write `attendance_logs` entry with the action and new values.
5. Return `{ success: true, docId }`.

#### `adminCorrectAttendance` — onCall

Called by admin to create or patch an attendance record.

```
request.data: {
  userId: string,
  date: string,         // "YYYY-MM-DD" (Jerusalem)
  fields: {
    checkInAt?: string,      // ISO string — Cloud Function converts to Timestamp
    checkOutAt?: string,
    status?: 'present' | 'absent' | 'manual',
    notes?: string
  }
}
```

Logic:
1. Validate caller is admin (read `users/{request.auth.uid}.role == 'admin'`).
2. `docId = "${userId}_${date}"`.
3. In a Firestore transaction:
   - Read current doc if it exists → snapshot `previousValue`.
   - Merge `fields` into doc; always set `correctedBy: adminUid`, `correctedAt: serverTimestamp`, `status: 'manual'` (unless fields.status is explicitly set), `updatedAt: serverTimestamp`.
   - If creating (doc didn't exist): also set `userId`, `userName` (fetch from `users/{userId}`), `date`, `createdAt: serverTimestamp`.
   - Recompute `durationMinutes` if both `checkInAt` and `checkOutAt` are now present.
   - Write `attendance_logs` entry: `action: 'admin_correction'`, `performedBy: adminUid`, `performedByName`, `previousValue` (or null), `newValue` (updated fields only).
4. Return `{ success: true, docId }`.

#### `sendDailyAbsenceMarker` — onSchedule

```js
exports.sendDailyAbsenceMarker = onSchedule(
  { schedule: "0 23 * * *", timeZone: "Asia/Jerusalem" },
  async () => { ... }
);
```

Logic:
1. Compute today's Jerusalem date: `ymdInJerusalem(new Date())`.
2. Query `users` where `isActive == true` and `role == 'employee'`.
3. For each employee: check if `attendance/${uid}_${date}` exists with `checkInAt != null`.
4. For those missing or with `checkInAt == null`: `set({ userId, userName, date, status: 'absent', createdAt: serverTimestamp, updatedAt: serverTimestamp }, { merge: true })`.
5. No `attendance_logs` entry needed for automated absence marking (system-generated, not a correction).

---

### Flutter Implementation Scope

#### New feature directory: `lib/features/attendance/`

```
lib/features/attendance/
  data/
    models/
      attendance_model.dart          // AttendanceModel fromMap/toMap
      attendance_log_model.dart      // AttendanceLogModel fromMap/toMap
    repositories/
      attendance_repository.dart     // wraps Cloud Function callables + Firestore queries
  presentation/
    cubit/
      attendance_cubit.dart          // AttendanceCubit
      attendance_state.dart          // AttendanceState
    screens/
      attendance_screen.dart         // employee self-view: today's status + button + history
    widgets/
      attendance_check_button.dart   // biometric gate + callable invocation
      attendance_record_card.dart    // list tile for a single attendance record
```

#### `AttendanceModel` fields (mirror Firestore exactly):
`id`, `userId`, `userName`, `date`, `checkInAt` (nullable `DateTime`), `checkOutAt` (nullable `DateTime`), `biometricVerified`, `status`, `durationMinutes` (nullable `int`), `notes` (nullable `String`), `correctedBy` (nullable `String`), `correctedAt` (nullable `DateTime`), `createdAt`, `updatedAt`.

#### `AttendanceRepository` methods:
- `Future<void> checkIn(String userId, bool biometricVerified)` — calls `recordAttendance`
- `Future<void> checkOut(String userId, bool biometricVerified)` — calls `recordAttendance`
- `Future<void> adminCorrect({ userId, date, fields, notes })` — calls `adminCorrectAttendance`
- `Stream<AttendanceModel?> streamTodayRecord(String userId)` — Firestore stream on `attendance/${userId}_${today}`
- `Future<List<AttendanceModel>> fetchHistory(String userId, { int limit = 30 })` — ordered by `date desc`
- `Future<List<AttendanceModel>> fetchRosterForDate(String date)` — admin query for all employees on a date

#### `AttendanceCubit` states:
- Loading / loaded / error for today's record
- Loading / loaded / error for history list
- Submitting / success / error for check-in/check-out action

#### `AttendanceScreen` (employee):
- Header: today's date, current status chip (`present` / `absent` / no record)
- Check-in / check-out button (disabled when offline — use `connectivity_plus`)
- Biometric tap flow: call `LocalAuthentication.authenticate(localizedReason: 'biometric_reason_check_in'.tr())`, on `true` → call cubit → repository → Cloud Function
- If `biometric not available` → `ScaffoldMessenger` error snackbar with `biometric_not_available` key
- If offline → button disabled, subtitle shows `no_internet_for_attendance` key
- Below button: scrollable list of past records using `AttendanceRecordCard`

#### New admin screen: `lib/features/admin/presentation/screens/admin_attendance_screen.dart`

- Date picker row (default: today; tap to open `showDatePicker`)
- StreamBuilder / FutureBuilder on `fetchRosterForDate(selectedDate)`
- Each row: employee name, status chip, check-in time (if present), check-out time (if present), duration
- Tap row → bottom sheet / dialog for admin correction:
  - Check-in time picker, check-out time picker, status dropdown, notes field
  - "Save" → calls `adminCorrect` → closes sheet on success

#### Modified files:

**`lib/features/reports/presentation/screens/reports_screen.dart`**
- Add a new tab "Attendance" (after existing task-report content)
- Admin-only tab: date picker + roster list (reuse `admin_attendance_screen.dart` or inline the same logic)

**`lib/features/admin/presentation/screens/admin_dashboard_screen.dart`**
- Add a today's attendance summary `_DashboardStatCard` below the existing task stat row
- Show `present / total active employees` count
- Data fetched from `fetchRosterForDate(today)` — count docs with `status == 'present'`

**`lib/shared/widgets/app_drawer.dart`**
- Employee: add "My Attendance" drawer entry → `RouteNames.attendance`
- Admin: add "Attendance Management" drawer entry → `RouteNames.adminAttendance`

**`lib/core/routes/route_names.dart`**
- `static const attendance = '/attendance';`
- `static const adminAttendance = '/admin-attendance';`

**`lib/core/routes/app_router.dart`**
- Add `RouteNames.attendance` → `AttendanceScreen()`
- Add `RouteNames.adminAttendance` → `AdminAttendanceScreen()`

**`lib/app/app.dart` (MultiBlocProvider)**
- Add `BlocProvider(create: (_) => AttendanceCubit(attendanceRepository))`

**`lib/main.dart` (or wherever repositories are wired)**
- Instantiate `AttendanceRepository(functions: FirebaseFunctions.instance, firestore: FirebaseFirestore.instance)`
- Pass to `AttendanceCubit`

**`pubspec.yaml`**
- Add `local_auth: ^2.3.0` (or latest stable; check pub.dev)
- Add `connectivity_plus` if not already present (check existing deps first — it may have been added in BACKLOG #9 mandatory-update feature)

---

### Native Configuration

These changes require a full binary release (never Shorebird patch-eligible):

**Android (`android/app/src/main/AndroidManifest.xml`)**:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

**Android (`android/app/build.gradle`)**:
Verify `minSdkVersion >= 23` (required for BiometricPrompt API). Do not lower it if already set higher.

**iOS (`ios/Runner/Info.plist`)**:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Used to verify your identity for attendance check-in and check-out.</string>
```

---

### Firestore Rules

Add to `firestore.rules`:

```
match /attendance/{docId} {
  // Employee reads own records; admin reads all
  allow read: if isAdmin() || resource.data.userId == request.auth.uid;
  // All writes go through Cloud Functions
  allow write: if false;
}
match /attendance_logs/{logId} {
  // Admin read only — used for corrections audit trail
  allow read: if isAdmin();
  allow write: if false;
}
```

---

### Translation Keys (26 new keys — parity target: 272/272)

All keys in `assets/translations/en.json` and `assets/translations/ar.json`:

| Key | English | Arabic |
|---|---|---|
| `attendance` | Attendance | الحضور |
| `my_attendance` | My Attendance | حضوري |
| `attendance_management` | Attendance Management | إدارة الحضور |
| `check_in` | Check In | تسجيل الحضور |
| `check_out` | Check Out | تسجيل الانصراف |
| `checked_in` | Checked In | تم تسجيل الحضور |
| `checked_out` | Checked Out | تم تسجيل الانصراف |
| `check_in_success` | Checked in successfully | تم تسجيل حضورك بنجاح |
| `check_out_success` | Checked out successfully | تم تسجيل انصرافك بنجاح |
| `already_checked_in` | You are already checked in for today | لقد سجلت حضورك بالفعل اليوم |
| `not_checked_in_yet` | You haven't checked in today | لم تسجل حضورك بعد اليوم |
| `already_checked_out` | You have already checked out today | لقد سجلت انصرافك بالفعل اليوم |
| `biometric_reason_check_in` | Confirm your identity to check in | أكد هويتك لتسجيل الحضور |
| `biometric_reason_check_out` | Confirm your identity to check out | أكد هويتك لتسجيل الانصراف |
| `biometric_not_available` | Biometric authentication is not available on this device. Contact your admin. | المصادقة البيومترية غير متاحة على هذا الجهاز. تواصل مع المدير. |
| `no_internet_for_attendance` | Internet connection required to record attendance | يلزم الاتصال بالإنترنت لتسجيل الحضور |
| `attendance_status_present` | Present | حاضر |
| `attendance_status_absent` | Absent | غائب |
| `attendance_status_manual` | Corrected | تم التصحيح |
| `check_in_time` | Check-in Time | وقت الحضور |
| `check_out_time` | Check-out Time | وقت الانصراف |
| `duration_minutes` | {minutes} min | {minutes} د |
| `attendance_history` | Attendance History | سجل الحضور |
| `no_attendance_records` | No attendance records yet | لا توجد سجلات حضور بعد |
| `correct_attendance` | Correct Attendance | تصحيح الحضور |
| `attendance_corrected` | Attendance record corrected | تم تصحيح سجل الحضور |
| `today_attendance` | Today's Attendance | حضور اليوم |

---

### Out of Scope for This PR

Do NOT implement any of the following:
- WiFi / SSID / BSSID validation
- Geofencing or location tracking
- Breaks / pause-resume
- Shift schedules or expected hours
- Overtime calculation
- Leave management
- Multiple check-in/check-out cycles per day
- Offline sync (Firestore offline cache)
- CSV / Excel export
- "Late" status computation (data model is compatible but evaluation is deferred)

---

### Acceptance Criteria

- [ ] Employee can check in once per day (biometric prompt → Cloud Function → doc created, `status: 'present'`)
- [ ] Employee cannot check in a second time on the same day (error: `already_checked_in`)
- [ ] Employee can check out after checking in (biometric prompt → Cloud Function → `checkOutAt` set, `durationMinutes` computed)
- [ ] Employee cannot check out without a prior check-in (error: `not_checked_in_yet`)
- [ ] Check-in / check-out button disabled when offline; `no_internet_for_attendance` message shown
- [ ] Biometric unavailable → blocking error, check-in not permitted
- [ ] Employee can view their own attendance history on `AttendanceScreen`
- [ ] Admin can view all employees' attendance for a selected date on `AdminAttendanceScreen`
- [ ] Admin can correct any attendance record (edit times, status, notes); correction logged in `attendance_logs`
- [ ] `sendDailyAbsenceMarker` runs at 23:00 Jerusalem and creates `status: 'absent'` docs for employees with no check-in
- [ ] Today's attendance summary card visible on admin dashboard
- [ ] Attendance tab/section visible in Reports screen (admin only)
- [ ] Employee drawer shows "My Attendance" entry; admin drawer shows "Attendance Management" entry
- [ ] `flutter analyze` clean
- [ ] `flutter test` all green
- [ ] `npm run lint` clean
- [ ] Translation parity: 272/272 (246 existing + 26 new)
- [ ] `attendance` and `attendance_logs` Firestore rules are in place and tested
- [ ] `firestore.indexes.json` updated with required composite indexes
