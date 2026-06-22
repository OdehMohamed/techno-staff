# Current Task

## In Progress — v1.9.0 Toolchain Upgrade + Product Improvements

**Branch**: `feat/v1.9.0`  
**Status**: Implementation complete — awaiting owner smoke test, PR merge, Firebase deploy + Shorebird release

---

## What's being built

Five items shipped together:

1. **Toolchain upgrade** — Gradle 8.14.1, AGP 8.11.1, Kotlin 2.2.20, Flutter 3.44.2 (aligned with Shorebird stable). Verified with debug APK build.
2. **Sign Out of All Other Devices** — Settings → Account tile triggers confirmation + `revokeUserSessions` CF call. User stays signed in on current device; all other sessions invalidated.
3. **Attendance original-session audit** — Admin correction sheet shows original (pre-correction) session times when viewing a previously corrected attendance record.
4. **Reports custom date range** — Month picker replaced with `showDateRangePicker`. Admins can generate task reports for any arbitrary date range.
5. **Documentation cleanup** — PROJECT_CONTEXT.md and NEXT_STEPS.md updated to reflect v1.8.0 ship and v1.9.0 scope.

---

## Architecture decisions

| Decision | Rationale |
|----------|-----------|
| `signOutOtherDevices()` throws instead of emitting error state | Settings screen owns the loading UX via `_isSigningOutOtherDevices`; emitting cubit states for a one-shot action would force the screen to become a `BlocListener` unnecessarily |
| Reports: attendance still loads by `startDate.month` | `AttendanceCubit.loadMonthlyAttendance` takes year+month; supporting multi-month ranges requires repository changes beyond v1.9.0 scope. Documented limitation. |
| PDF service unchanged | `PdfReportService.generateEmployeeMonthlyReport` still takes `month: DateTime`; cubit passes `startDate` as month. PDF title/header shows the start-date month. |
| `originalSessions` displayed always-expanded (no toggle) | Simplest UX for audit use case; the correction sheet already scrolls |

---

## Changed files

### Toolchain
- `android/gradle/wrapper/gradle-wrapper.properties` — Gradle 8.14.1
- `android/settings.gradle.kts` — AGP 8.11.1, Kotlin 2.2.20

### Sign Out of All Other Devices
- `lib/features/auth/presentation/cubit/auth_cubit.dart` — `signOutOtherDevices()`
- `lib/features/settings/presentation/screens/settings_screen.dart` — tile + handler
- `assets/translations/en.json` + `ar.json` — 5 new keys

### Attendance audit visibility
- `lib/features/attendance/data/models/attendance_model.dart` — `originalSessions` field
- `lib/features/admin/presentation/screens/admin_attendance_screen.dart` — `_CorrectionSheet` display
- `assets/translations/en.json` + `ar.json` — 1 new key

### Reports custom date range
- `lib/features/reports/presentation/cubit/reports_state.dart` — `selectedStartDate` / `selectedEndDate`
- `lib/features/reports/data/repositories/reports_repository.dart` — `getTasksForEmployee`
- `lib/features/reports/presentation/cubit/reports_cubit.dart` — `generateReport(startDate, endDate)`
- `lib/features/reports/presentation/screens/reports_screen.dart` — `DateTimeRange` picker
- `assets/translations/en.json` + `ar.json` — 3 new keys

### Documentation + release
- `docs/ai-workflow/PROJECT_CONTEXT.md` — version, CF modularization, FCM path, translation count
- `docs/ai-workflow/NEXT_STEPS.md` — 6 completed items closed
- `docs/ai-workflow/SESSION_LOG.md` — v1.9.0 entry added
- `CHANGELOG.md` — `[1.9.0]` entry
- `pubspec.yaml` — version `1.9.0+12`

---

## Quality gates

- [x] `dart analyze lib/` — zero errors/warnings in our code
- [x] `npm run lint` — ESLint clean
- [x] `flutter build apk --debug` — toolchain upgrade verified
- [ ] Owner smoke test: sign-out-other-devices flow, attendance correction audit, reports date range
- [ ] `shorebird release android` + `shorebird release ios`
- [ ] Store binary submissions (full release required — translation changes)

---

## Release steps (owner)

```bash
# 1. Merge PR feat/v1.9.0 → main

# 2. Tag
git tag v1.9.0
git push origin v1.9.0

# 3. Firebase deploy (no CF or rules changes in this cycle — skip if clean)
# cd functions && npm run deploy  ← not required

# 4. Shorebird
shorebird release android
shorebird release ios

# 5. Store uploads
# iOS: Transporter (IPA)
# Android: Play Console (AAB)
```

**Note:** No Firebase deploy or Firestore rules changes in this cycle. Only Dart + toolchain changes.
