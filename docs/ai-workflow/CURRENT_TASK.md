# Current Task

> Last updated: 2026-04-26

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Add task delete UI for admins and creators — backlog item "Add task delete UI for admins and creators".**

## Goal

Surface a delete affordance for tasks. The Firestore rules already permit deletion for the task creator and any admin (shipped in PR #6). The client just needs a button + confirmation. No rules, Cloud Functions, or notification changes.

## Branch

`feature/task-delete-ui`, branched from `dev` after PR #8 merged. The branch already exists locally and on `origin` — do **not** create a new branch.

## Product decisions (locked 2026-04-26)

1. **Location**: Delete button is an AppBar icon (`Icons.delete_outline`) on `task_details_screen.dart`, sitting next to the existing edit icon.
2. **Visibility**: Same gate as edit — visible iff `currentUser.role == 'admin' || task.assignedBy == currentUser.id`. Rename the local `canEditTask` to `canEditOrDelete` to reflect the dual purpose.
3. **Confirmation dialog**: Required before any destructive call. Includes the task title in the message.
4. **Notifications on delete**: **Out of scope.** No FCM / in-app notification when a task is deleted. (Backlog candidate if needed later.)
5. **`task_logs/` cleanup**: **Out of scope.** Logs remain as the audit trail. Cleanup would require a Cloud Function on task `onDelete`.

## Scope — file-by-file

### 1. `lib/features/tasks/data/repositories/tasks_repository.dart`

Add a single method:
```dart
Future<void> deleteTask(String taskId) async {
  await _firestore.collection(FirebasePaths.tasks).doc(taskId).delete();
}
```

### 2. `lib/features/tasks/presentation/cubit/tasks_cubit.dart`

Add a `deleteTask` method modelled exactly on `updateTaskStatus`:
```dart
Future<void> deleteTask({
  required String taskId,
  required bool isAdmin,
  required String currentUserId,
}) async {
  await _tasksRepository.deleteTask(taskId);

  if (isAdmin) {
    await fetchAllTasks();
    await fetchTasksAssignedTo(currentUserId);
  } else {
    await fetchTasksAssignedTo(currentUserId);
    await fetchTasksCreatedBy(currentUserId);
  }
}
```
Errors propagate; the screen handles snackbar feedback.

### 3. `lib/features/tasks/presentation/screens/task_details_screen.dart`

- Rename the local `canEditTask` to `canEditOrDelete` (same boolean, same gate).
- After the existing edit `IconButton` in the AppBar `actions: [...]`, add a second `IconButton`:
  - `icon: const Icon(Icons.delete_outline)`.
  - Wrap with `if (canEditOrDelete)` (same gate as the edit icon).
  - `onPressed`: open a confirmation dialog (see below). On confirm, call `context.read<TasksCubit>().deleteTask(...)`. On success, show a success snackbar and `Navigator.pop(context, true)` so `tasks_screen.dart` refreshes via its existing callback. On failure (caught exception), show the failure snackbar; do **not** pop.
- Confirmation dialog: use `showDialog<bool>` returning a Material `AlertDialog`:
  - Title: `'delete_task_confirm_title'.tr()`.
  - Content: `'delete_task_confirm_message'.tr(args: [task.title])`.
  - "Cancel" action returns `false`; "Delete" action returns `true` and uses `TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)`.
  - Reuse existing `cancel` translation key if present; otherwise add `cancel` (verify before adding to avoid duplication).
- Use `if (!context.mounted) return;` after every `await` boundary inside the handler — `flutter_lints` enforces `use_build_context_synchronously`.

### 4. Translations

Verify `cancel` does not already exist before adding it. Add the rest unconditionally.

**`assets/translations/en.json`** — add:
- `"delete": "Delete"`
- `"cancel": "Cancel"` _(only if not already present)_
- `"delete_task_confirm_title": "Delete task?"`
- `"delete_task_confirm_message": "This will permanently delete '{}'. This action cannot be undone."`
- `"task_deleted": "Task deleted"`
- `"failed_to_delete_task": "Failed to delete task"`

**`assets/translations/ar.json`** — add the matching keys:
- `"delete": "حذف"`
- `"cancel": "إلغاء"` _(only if not already present)_
- `"delete_task_confirm_title": "حذف المهمة؟"`
- `"delete_task_confirm_message": "سيتم حذف المهمة '{}' نهائياً. لا يمكن التراجع عن هذا الإجراء."`
- `"task_deleted": "تم حذف المهمة"`
- `"failed_to_delete_task": "فشل حذف المهمة"`

The `{}` placeholder is the `easy_localization` positional-args format, used as `'key'.tr(args: [task.title])`.

### 5. Tests

Optional. Do **not** add a brittle widget test. Repository / cubit unit tests are out of scope for this PR.

### 6. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append a short entry titled "Add task delete UI for admins and creators" recording: location (AppBar icon), confirmation pattern, and the explicit "no notifications, no `task_logs/` cleanup in this PR" scope decisions.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — small note under §4 Modules `tasks` row: the row currently mentions "create/edit by creator or admin" — add "delete by creator or admin" so the table stays accurate.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Add task delete UI for admins and creators" out of `Should-fix` into `Done` with completion date.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes expected; run anyway).

## Manual smoke tests

1. **Admin deletes another's task** → as admin, open a task assigned to someone else, tap trash → confirmation dialog shows the task title → confirm → success snackbar → returns to list → task gone in both admin tabs.
2. **Cancel** → trash → confirmation dialog → tap "Cancel" → dialog closes, no delete, task still in list.
3. **Creator deletes own task** → as employee, open a task you created (in "Created by me"), tap trash → confirm → task gone in both employee tabs.
4. **No button for assignee-only** → as employee, open a task that was assigned to you but not created by you → trash icon is **not** visible.
5. **Failure path** → simulate by temporarily adding a deny rule (or by deleting the same task twice rapidly) → failure snackbar shows; task still appears (or list reflects reality on next load).
6. **Localization** → toggle to Arabic; dialog title, message, buttons, and snackbars all show Arabic copy.
7. **Audit logs preserved** → confirm via Firebase console that the `task_logs/` entries for the deleted task are still present (not cleaned up — intentional).

## Definition of Done

- [ ] `tasks_repository.dart` has a `deleteTask(String taskId)` method.
- [ ] `tasks_cubit.dart` has a `deleteTask(...)` method that refreshes both relevant lists per role.
- [ ] `task_details_screen.dart` has the trash `IconButton` in the AppBar gated by `canEditOrDelete`.
- [ ] Confirmation dialog shows the task title, "Cancel" + "Delete" buttons, with the destructive button styled.
- [ ] Success snackbar + `Navigator.pop(context, true)` on success; failure snackbar without pop on error.
- [ ] All required translation keys exist in both locales (no duplicate `cancel` key).
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `PROJECT_CONTEXT.md` `tasks` row updated.
- [ ] `BACKLOG.md` item moved to `Done`.
- [ ] `SESSION_LOG.md` entry added.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `feat(tasks): add task delete UI for admins and creators`.

## Out of scope

- No `firestore.rules` changes — already shipped in PR #6.
- No `functions/index.js` changes.
- No FCM / in-app notification on delete.
- No `task_logs/` cascade-delete (logs preserved as audit trail).
- No employee-shell or admin-shell changes outside `task_details_screen.dart`.
- No new top-level folders, no new dependencies.
- No refactors outside the files listed above.
