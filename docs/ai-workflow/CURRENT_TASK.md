# Current Task

## In Progress — v1.7.0 Task Attachments

**Branch**: `feat/task-attachments` → merged to `main` via PR #43  
**Tag**: `v1.7.0`  
**GitHub release**: https://github.com/OdehMohamed/techno-staff/releases/tag/v1.7.0  
**Status**: Merged ✅ — awaiting Firebase deploy + Shorebird binary generation + store upload

---

## What's being built

Unified `task_attachments` sub-collection under each task document. Two attachment types:

- **Task Materials** (`type: 'brief'`) — reference files attached by the task creator / admin at creation or edit time
- **Completion Evidence** (`type: 'evidence'`) — photos uploaded by the assignee as proof of completion

v1.7.0 scope: image-only (camera + photo library). Documents deferred to v1.8.0.

---

## Architecture decisions

| Decision | Choice |
|---|---|
| Storage structure | `tasks/{taskId}/attachments/{uuid}` in Firebase Storage |
| Firestore structure | `tasks/{taskId}/attachments/{attachmentId}` sub-collection |
| UUID strategy | Same UUID for Storage key and Firestore doc ID — O(1) cleanup lookup |
| Task ID for creation | Pre-generated in `initState` via `const Uuid().v4()` |
| Write order | Storage upload → task doc create → Firestore attachment records |
| Orphan files | Accepted as deliberate trade-off; `dispose()` cleanup covers ~99% |
| Access control gate | Firestore sub-collection rules (Storage rules are auth-only permissive) |
| Max attachments | 5 per type per task |

---

## Files changed

**New files**
- `storage.rules` — Firebase Storage rules (auth-only, permissive)
- `lib/features/tasks/data/models/task_attachment_model.dart`
- `lib/features/tasks/data/repositories/task_attachments_repository.dart`
- `lib/features/tasks/presentation/cubit/task_attachments_state.dart`
- `lib/features/tasks/presentation/cubit/task_attachments_cubit.dart`
- `lib/features/tasks/presentation/widgets/attachment_tile.dart`
- `lib/features/tasks/presentation/widgets/task_attachments_section.dart`

**Modified files**
- `pubspec.yaml` — version `1.7.0+10`; added `firebase_storage ^13.4.2`, `image_picker ^1.1.2`
- `firebase.json` — added `storage` rules deployment
- `firestore.rules` — added `attachments` sub-collection block inside `tasks/{taskId}`
- `lib/core/constants/firebase_paths.dart` — added `taskAttachments = 'attachments'`
- `ios/Runner/Info.plist` — camera + photo library usage strings
- `lib/main.dart` — `TaskAttachmentsRepository` + `TaskAttachmentsCubit` wired into `MultiBlocProvider`
- `lib/features/tasks/data/repositories/tasks_repository.dart` — `createTask` uses `set()` when ID is pre-generated
- `lib/features/tasks/presentation/screens/add_task_screen.dart` — pre-generated task ID, `_PendingUpload`, Task Materials section
- `lib/features/tasks/presentation/screens/edit_task_screen.dart` — Task Materials section, `loadAttachments` lifecycle
- `lib/features/tasks/presentation/screens/task_details_screen.dart` — both sections, `loadAttachments`/`clear` lifecycle
- `assets/translations/en.json` + `ar.json` — 14 new keys

---

## Quality gates

- `flutter analyze lib/` — no issues
- `flutter test` — pending run by owner

---

## Owner smoke-test checklist

1. Admin creates a task, attaches 1–2 photos before saving → photos visible in Task Details
2. Photos persist after navigating away and returning
3. Admin opens Edit Task → existing materials visible; can add more (up to 5)
4. Assignee opens Task Details → sees Task Materials (read-only), can upload Completion Evidence
5. Admin can also upload Completion Evidence
6. Task creator (non-admin employee) can view Task Details → sees Task Materials (read-only), can upload evidence if they're the assignee
7. Non-admin / non-assignee cannot see an "Add Photo" button for evidence
8. Tapping a thumbnail opens full-screen viewer; pinch-to-zoom works; close button dismisses
9. Camera source and gallery source both work on iOS + Android
10. Upload failure shows snackbar "Failed to upload attachment"
11. Abandoning Add Task screen after uploading materials does not leave visible artifacts (Storage cleanup)
12. Recurring task templates do not show attachment section (correct — brief section is gated `if (!_isRecurring)`)

---

## Pending release steps after owner approval

1. Create PR `feat/task-attachments → main`
2. `firebase deploy --only firestore:rules,storage` (new storage.rules + firestore attachment rules)
3. Version bump already in code (`1.7.0+10`) — no separate step
4. Shorebird release (requires full binary — new native plugins `firebase_storage` + `image_picker`)
5. Store submission

---

## Previous release — v1.6.0+9

**Branch**: `feat/chat-phase-2` → merged to `main` via PR #42  
**Tag**: `v1.6.0`  
**Status**: Awaiting Firebase deploy + Shorebird binary generation + store upload
