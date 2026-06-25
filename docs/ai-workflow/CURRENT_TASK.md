# Current Task

## In Progress — v1.10.0 Reports + Chat + Admin UX Improvements

**Branch**: `feat/reports-chat-admin-improvements` (merged → `main`, PR #46)  
**Status**: ✅ COMPLETE — v1.10.0 released 2026-06-25

---

## What's being built

Three items in one release cycle:

1. **Reports multi-month attendance** — `AttendanceCubit.loadMonthlyAttendance` is extended to support arbitrary date ranges. Selecting June 15 – July 20 now correctly loads attendance from both months. PDF export reflects the full range. The v1.9.0 single-month limitation is removed.

2. **Employee deactivation confirmation** — The `isActive` switch in the Employees screen fires immediately on tap with no confirmation. Deactivation now requires a confirmation dialog ("Deactivate [Name]? They will lose app access immediately."). Activation remains immediate. EmployeesCubit errors are surfaced as snackbars.

3. **Chat Phase 3 — group member management** — A new `GroupSettingsScreen` (gear icon in group `ConversationScreen` AppBar, visible to admin/creator only) lets admins add or remove members from existing group conversations. Firestore rules require targeted expansion; the exact diff is shown for approval before any `firestore.rules` edit.

---

## Architecture decisions

| Decision | Rationale |
|----------|-----------|
| `loadAttendanceRange(userId, start, end)` as new cubit method (not replacing `loadMonthlyAttendance`) | `loadMonthlyAttendance` is called from `AdminAttendanceScreen` and `EmployeeMonthlyAttendanceScreen` for non-report purposes; replacing it would change behavior at those call sites. The reports screen switches to the new method only. |
| Single Firestore query for multi-month range | The `date` field is `"YYYY-MM-DD"` — ISO dates sort lexicographically. A single `where date >= start && date <= end` query covers any range without multiple round-trips. |
| Attendance state reuses `monthlyRecords` field name | Avoids a naming migration across every consumer of `AttendanceState`; the semantic is "records for the current loaded period" regardless of how many months. |
| PDF report header shows full date range | `PdfReportService` signature extended to accept `startDate`/`endDate`; header updated from "Month YYYY" to "DD MMM YYYY – DD MMM YYYY". |
| Employee deactivation confirmation only (not activation) | Accidentally activating someone is recoverable; accidentally locking someone out mid-shift is not. Activation remains a one-tap action. |
| Group settings accessible to admin OR original creator | Restricts member management to trusted users; creator maintains rights over their own group even if not an admin. |
| System message on member add/remove | `onNewChatMessage` CF already skips FCM for system messages; new system text keys follow the existing `"added to group"` / `"removed from group"` pattern. Firestore write happens client-side (same path as new message create). |

---

## Implementation order

1. Employee deactivation confirmation (smallest, standalone) ← start here
2. Reports multi-month attendance + PDF (medium, isolated to reports feature)
3. Chat Phase 3 group member management (largest; requires Firestore rules review before merge)

---

## Files to change

### Item 1 — Employee deactivation confirmation
- `lib/features/employees/presentation/screens/employees_screen.dart` — wrap switch in dialog for `value == false`
- `assets/translations/en.json` + `ar.json` — `deactivate_employee_confirm` body key (reuse existing `confirm`/`cancel`/`deactivate` if present)

### Item 2 — Reports multi-month attendance
- `lib/features/attendance/data/repositories/attendance_repository.dart` — `getAttendanceRange(userId, start, end)`
- `lib/features/attendance/presentation/cubit/attendance_cubit.dart` — `loadAttendanceRange(userId, start, end)`
- `lib/features/attendance/presentation/cubit/attendance_state.dart` — no change (reuses `monthlyRecords` + `monthlyStatus` fields)
- `lib/features/reports/presentation/screens/reports_screen.dart` — BlocListener switches to `loadAttendanceRange`; multi-month hint label
- `lib/core/services/pdf_report_service.dart` — extend signature; update header
- `lib/features/reports/presentation/cubit/reports_cubit.dart` — pass range to PDF service
- `assets/translations/en.json` + `ar.json` — 1 key for multi-month hint (optional; confirm during implementation)

### Item 3 — Chat Phase 3 group member management
- `lib/features/chat/data/repositories/chat_repository.dart` — `addMember`, `removeMember`
- `lib/features/chat/presentation/cubit/chat_list_cubit.dart` — `addMember`, `removeMember` wrappers
- `lib/features/chat/presentation/cubit/chat_list_state.dart` — error state for member operations (if needed)
- `lib/features/chat/presentation/screens/group_settings_screen.dart` — new screen
- `lib/features/chat/presentation/screens/conversation_screen.dart` — gear icon in AppBar
- `lib/core/routes/route_names.dart` — `groupSettings` constant
- `lib/core/routes/app_router.dart` — new route
- `firestore.rules` — ⚠️ **SHOW DIFF FOR APPROVAL BEFORE EDITING**
- `assets/translations/en.json` + `ar.json` — ~6 new keys

---

## Quality gates

- [x] `flutter analyze lib/` — zero errors/warnings
- [x] `npm run lint` — ESLint clean (functions not touched in v1.10.0)
- [x] Translation parity (401 EN == 401 AR)
- [x] Owner smoke test: all three items — PASS 2026-06-25
- [x] Firestore rules diff approved by owner (2026-06-25)

---

## Release steps (owner)

```bash
# 1. Merge PR feat/reports-chat-admin-improvements → main

# 2. Tag
git tag v1.10.0
git push origin v1.10.0

# 3. Firebase deploy (Firestore rules changed)
firebase deploy --only firestore:rules

# 4. Shorebird
shorebird release android
shorebird release ios

# 5. Store uploads (full binary — translation changes)
```
