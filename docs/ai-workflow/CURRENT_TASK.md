# Current Task

## In Progress — v1.8.0 Attachment Workflow Completion + Maintenance

**Branch**: `feat/v1.8.0`  
**Status**: Implementation complete — awaiting version bump, commit, PR, Firebase deploy + Shorebird

---

## What's being built

Six items shipped together in one cycle:

1. **Individual attachment deletion** — admin / task-creator / uploader can delete individual attachment photos. Firestore rule expanded; repository + cubit + UI updated.
2. **Real-time attachment sync** — replaced one-time `.get()` with a Firestore `snapshots()` stream; new/deleted attachments appear instantly without screen refresh.
3. **Notification auto-expiry** — new `cleanupExpiredNotifications` Cloud Function (weekly cron, Sunday 02:00 Asia/Jerusalem) deletes notifications older than 30 days. Server-side Admin SDK bypass; 500-doc batch deletes.
4. **Cloud Functions modularization** — split 1999-line `functions/index.js` into 6 focused modules under `functions/lib/`. Zero behavioral change; all 18 exported function names unchanged.
5. **Android toolchain cleanup** — removed deprecated `android.builtInKotlin=false` and `android.newDsl=false` flags from `android/gradle.properties`. Both were injected by the Flutter Gradle migrator; not needed since the project already uses Kotlin DSL.
6. **Employee → Tasks shortcut** — `Icons.task_alt_outlined` button on each employee card in `EmployeesScreen` navigates to `TasksScreen` with the employee ID as a route argument; `TasksScreen.initState` reads the argument and pre-filters by assignee.

---

## Architecture decisions

| Decision | Choice |
|---|---|
| Attachment stream | `snapshots()` on the `attachments` sub-collection; cubit owns `StreamSubscription`, cancels in `clear()` and `close()` |
| Post-delete UI update | Stream delivers the removal automatically; no manual list update needed |
| Delete order | Firestore delete first (throws on permission denied), then `unawaited(deleteStorageFile())` fire-and-forget |
| Firestore rule for delete | `isAdmin() \|\| relatedTask(taskId).data.assignedBy == request.auth.uid \|\| resource.data.uploadedBy == request.auth.uid` |
| CF module system | Node.js `require`/`module.exports`; `admin.initializeApp()` once in `index.js` before any `require()` of lib modules |
| Notification expiry query | Single-field `createdAt < cutoff` — covered by Firestore auto single-field index; no `firestore.indexes.json` entry needed |
| Tasks shortcut argument passing | `ModalRoute.of(context)?.settings.arguments` read in `initState` `addPostFrameCallback`; no router changes needed |

---

## Files changed

**New files**
- `functions/lib/shared.js` — timezone helpers, i18n, FCM/notification helpers
- `functions/lib/tasks.js` — `generateRecurringTaskInstances`, `cleanupTaskAttachments`
- `functions/lib/task-notifications.js` — all 6 task notification functions
- `functions/lib/attendance.js` — `recordAttendance`, `adminCorrectAttendance`, `adminResetAttendance`, `sendDailyAbsenceMarker`
- `functions/lib/users.js` — `createEmployeeUser`, `deleteUserAccount`, `revokeUserSessions`
- `functions/lib/chat.js` — `onNewChatMessage`
- `functions/lib/notifications.js` — `cleanupExpiredNotifications`

**Modified files**
- `functions/index.js` — rewritten to ~30-line thin re-export; `admin.initializeApp()` here
- `firestore.rules` — attachment `allow delete` rule expanded from `if false` to admin / creator / uploader
- `lib/features/tasks/data/repositories/task_attachments_repository.dart` — `getAttachments()` removed; `watchAttachments()` stream + `deleteAttachment()` added
- `lib/features/tasks/presentation/cubit/task_attachments_state.dart` — `isDeleting: bool` field added
- `lib/features/tasks/presentation/cubit/task_attachments_cubit.dart` — rewritten with `StreamSubscription`, `deleteAttachment()`, `clear()` async, `close()` override
- `lib/features/tasks/presentation/widgets/attachment_tile.dart` — `taskId` + `canDelete` params; `_DeleteButton` overlay with confirmation dialog + snackbar
- `lib/features/tasks/presentation/widgets/task_attachments_section.dart` — `canDeleteAny` param; per-tile `canDelete` logic; upload/delete gating on `!isDeleting`
- `lib/features/tasks/presentation/screens/task_details_screen.dart` — `canDeleteAny: canEditOrDelete` on both sections
- `lib/features/tasks/presentation/screens/edit_task_screen.dart` — `canDeleteAny: canEditTask` on brief section
- `lib/features/employees/presentation/screens/employees_screen.dart` — `task_alt_outlined` `IconButton` on each employee card
- `lib/features/tasks/presentation/screens/tasks_screen.dart` — reads `ModalRoute` argument in `initState`; pre-sets `filterAssigneeId`
- `android/gradle.properties` — removed 2 deprecated flags + their comments
- `assets/translations/en.json` — 4 new keys: `delete_attachment`, `delete_attachment_confirm`, `attachment_deleted`, `attachment_delete_failed`
- `assets/translations/ar.json` — 4 new keys (Arabic equivalents)

---

## Quality gates

- `flutter analyze lib/` — no issues ✅
- `npm run lint` — clean ✅
- `flutter test` — pending owner run

---

## Owner smoke-test checklist

### Attachment deletion
1. Admin opens any task details → taps evidence thumbnail → red X overlay visible → tap X → confirm dialog appears → tap Delete → photo disappears in ~300 ms (stream update)
2. Task creator (non-admin) opens their task → can delete any attachment on that task
3. Uploader (assignee who uploaded evidence) → red X on their own uploads; no X on photos they didn't upload when they are not the creator
4. Non-creator / non-admin / non-uploader → no red X visible at all
5. Admin opens Edit Task → can delete task materials from the brief section
6. Delete confirmation dialog has Cancel and Delete buttons; Cancel returns without deleting

### Real-time sync
7. Admin has task details open on one device; another user uploads evidence → tile appears without screen refresh

### Notification auto-expiry
8. After deploy: verify `cleanupExpiredNotifications` appears in Firebase Functions console (no deploy error)
9. Optional: check notifications collection — after the next Sunday 02:00 Asia/Jerusalem run, docs older than 30 days are gone

### Employee → Tasks shortcut
10. Admin opens Employees screen → each employee card has a task icon button → tap it → Tasks screen opens with that employee's name pre-filtered in the assignee filter
11. Clear filters button removes the pre-filter

### Android build
12. `flutter build apk --debug` completes without deprecated-flag warnings in Gradle output

---

## Pending release steps

1. Bump version: `pubspec.yaml` `1.7.0+10` → `1.8.0+11`
2. Update `CHANGELOG.md`
3. Commit + PR `feat/v1.8.0 → main`
4. `firebase deploy --only functions,firestore:rules`
5. Shorebird patch eligibility: **No** — attachment delete is a new Firestore listener path + CF deploy required → full binary
6. Build release binary + store submission

---

## Previous release — v1.7.0+10

**Branch**: `feat/task-attachments` → merged to `main` via PR #43  
**Tag**: `v1.7.0`  
**Status**: Merged ✅
