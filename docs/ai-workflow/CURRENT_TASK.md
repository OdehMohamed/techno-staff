# Current Task

> Last updated: 2026-04-24

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Implement employee task creation — backlog item "Allow employees to create and assign tasks".**

## Goal

Extend the app so any authenticated user (admin or employee) can create tasks and assign them to any other user. The creator has full edit and delete rights on tasks they created, mirroring admin rights on those specific tasks. Admin retains global full access on all tasks.

## Branch

`feature/employee-task-creation`, branched from `dev` at commit `d214827`.

## Product decisions (locked 2026-04-24)

1. **Any-to-any assignment.** Any user can assign a task to any other user, regardless of role.
2. **Relax `users` read rule.** Any authenticated user may read any document in `users/` (required so employees can pick assignees).
3. **Tabs for employees.** The tasks screen shows two tabs for non-admin users: "Assigned to me" and "Created by me". Admin view stays as today (single list of all tasks).
4. **Creator can delete.** Task creators can delete the tasks they created, in addition to admin.
5. **`assignedBy` is immutable.** After a task is created, `assignedBy` cannot change (enforced by Firestore rules).

## Approved rules diff

Apply this **verbatim** to `firestore.rules`:

```diff
   match /tasks/{taskId} {
     allow read: if isAdmin() || taskCreator() || taskAssignee();

     allow create: if signedIn() && (
-      isAdmin() || creatingOwnTask()
+      creatingOwnTask()
     );

-    allow update: if isAdmin()
-      || taskCreator()
-      || (taskAssignee() && onlyAllowedTaskStatusFieldsChanged());
+    allow update: if (
+      (isAdmin() || taskCreator())
+      && request.resource.data.assignedBy == resource.data.assignedBy
+    ) || (taskAssignee() && onlyAllowedTaskStatusFieldsChanged());

-    allow delete: if isAdmin();
+    allow delete: if isAdmin() || taskCreator();
   }
```

And relax the `users` read rule:

```diff
   match /users/{userId} {
-    allow read: if isAdmin() || isCurrentUser(userId);
+    allow read: if signedIn();

     allow create: if isAdmin() || isCurrentUser(userId);
     ...
   }
```

Notes:

- `creatingOwnTask()` already covers admins (their uid === `assignedBy` on admin-created tasks), so the explicit `isAdmin()` on `create` is redundant.
- `request.resource.data.assignedBy == resource.data.assignedBy` locks `assignedBy` immutable on update for both admin and creator paths. Assignee-status-only updates remain constrained by `onlyAllowedTaskStatusFieldsChanged()`.

## Scope — file-by-file

### 1. `firestore.rules`

Apply the two diffs above. Nothing else.

### 2. `lib/core/constants/firebase_paths.dart`

Add:

```dart
static const String assignedBy = 'assignedBy';
```

### 3. `lib/features/tasks/data/repositories/tasks_repository.dart`

- Rename `getTasksForUser(userId)` → `getTasksAssignedTo(userId)` (keep the existing query; just rename for clarity).
- Add `getTasksCreatedBy(String userId)` — same shape, but `where(FirebasePaths.assignedBy, isEqualTo: userId)`.
- Update all callers of `getTasksForUser` to use `getTasksAssignedTo`.

### 4. `lib/features/tasks/presentation/cubit/tasks_cubit.dart` and `tasks_state.dart`

- Replace `fetchTasksForUser(userId)` with `fetchTasksAssignedTo(userId)` and add `fetchTasksCreatedBy(userId)`.
- State holds two additional fields: `tasksAssignedToMe` and `tasksCreatedByMe`, each with its own status/error. Admin keeps using `tasks` (all tasks) and `fetchAllTasks()` as today.
- Follow the immutable-state + `copyWith` + `clear*` flag pattern described in `RULES.md §2 Principle II`.

### 5. `lib/features/tasks/presentation/screens/tasks_screen.dart`

- Remove the `isAdmin` gate on the FAB (line ~53). The FAB shows for all users.
- For non-admin users, wrap the body in a `DefaultTabController` with two tabs: `assigned_to_me` and `created_by_me`. Each tab renders the current list UI backed by the appropriate state field.
- Status-update dropdown condition — change from `if (!isAdmin)` to `if (task.assignedTo == currentUser.id)`. This keeps the dropdown only on tasks the user is the assignee of, regardless of role. Admin view loses the inline dropdown for tasks they are not assigned to (admin edits via tap, unchanged).
- Admin view (single list of all tasks) stays as today.

### 6. `lib/features/tasks/presentation/screens/add_task_screen.dart`

- Line ~127: remove the `where((user) => user.role == 'employee')` filter. The dropdown lists all users from the loaded employees (rename the variable if it helps readability).
- **Self-assignment is allowed.** The current user MUST remain visible in the assignee dropdown — a user may assign a task to themselves (revised 2026-04-24, see `DECISIONS_LOG.md`).
- No other behavioral change — `assignedBy: currentUser.id` is already set correctly.

### 7. `lib/features/employees/` (verify only)

- After the `users` read rule is relaxed, `EmployeesCubit.fetchEmployees` should succeed for employees too. Verify the cubit is already provided at the top-level `MultiBlocProvider` in `lib/app/app.dart`. If it is employee-gated anywhere, remove the gate.
- If `EmployeesCubit.fetchEmployees` filters by `role == 'employee'` on the repository side, update it to fetch all users (admins + employees) for the picker. Keep any existing admin-specific list untouched if it is used elsewhere — prefer adding a new method (e.g. `fetchAllUsers()`) rather than widening the existing one.

### 8. Translations (`assets/translations/en.json` + `ar.json`)

Add keys:

- `assigned_to_me` → "Assigned to me" / "المهام المسندة لي"
- `created_by_me` → "Created by me" / "المهام التي أنشأتها"

All other keys (`add_task`, `task_title`, `description`, `assign_to`, etc.) already exist.

### 9. Workflow docs (after implementation)

- `docs/ai-workflow/DECISIONS_LOG.md` — append an entry titled "Allow employee task creation + relax users read rule" explaining the rule changes and the trade-off on the users collection read surface.
- `docs/ai-workflow/PROJECT_CONTEXT.md` — update the Firestore Data Model table to reflect "creator can update/delete", "any authed user can create", and the new `users` read rule.
- `docs/ai-workflow/BACKLOG.md` — move the item "Allow employees to create and assign tasks" to the `Done` section with completion date.
- `docs/ai-workflow/SESSION_LOG.md` — add an entry for the implementation session.
- `docs/ai-workflow/CURRENT_TASK.md` — check all DoD items.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all tests green. Add a widget or unit test for the new repository method or the tab behavior if feasible.
- `cd functions && npm run lint` — green (no functions changes expected; run anyway).

## Manual smoke tests

1. **Employee creates a task** → signed in as employee, tap FAB, assign to another user (try both an employee and an admin), save.
2. **Notification delivery** → the assignee receives the FCM push and an in-app notification; tapping navigates to the task.
3. **Employee tabs** → creator sees the task in "Created by me"; assignee sees it in "Assigned to me".
4. **Creator edit / delete** → creator can edit the task (via tap → edit screen) and can delete it; admin can still edit / delete any task.
5. **Immutability** → attempting to change `assignedBy` via the Firebase console while signed in as the creator fails (rule blocks it). This is a manual security check.
6. **Admin view** → admin still sees the full list of tasks without tabs.
7. **Self-assignment allowed** → current user appears in the assignee dropdown and a user can successfully assign a task to themselves (intentional — see `DECISIONS_LOG.md`).

## Definition of Done

- [x] Firestore rules diff applied exactly as written.
- [x] `firebase_paths.dart` has `assignedBy` constant.
- [x] Repository + cubit + state support both "assigned to me" and "created by me".
- [x] Tasks screen has tabs for non-admin users; FAB visible to all users.
- [x] Add-task screen allows any-to-any assignment; current user is visible (self-assignment allowed — see `DECISIONS_LOG.md`).
- [x] `EmployeesCubit` works for both roles.
- [x] New translation keys added to `en.json` and `ar.json`.
- [x] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [x] `DECISIONS_LOG.md` has an entry for the rule changes.
- [x] `PROJECT_CONTEXT.md` updated.
- [x] `BACKLOG.md` item moved to `Done`.
- [x] `SESSION_LOG.md` entry added.
- [x] PR opened against `dev` with a summary, test plan, and links to the rule diff.

## Out of scope

- No refactors outside the files listed above.
- No dependency upgrades.
- No changes to Cloud Functions (`functions/index.js`) — they already handle any assigner correctly.
- No new top-level folders.

## Security notes

- Per `RULES.md §5` and `§6`, the rules diff was reviewed and approved by the project owner on 2026-04-24 before this task was unblocked. Do not expand the rules change beyond the approved diff without explicit approval.
- The `users` read relaxation exposes `email`, `name`, `role`, `isActive`, `fcmToken` to all authenticated users. `fcmToken` is not actionable without Firebase admin access. The trade-off was accepted to keep the feature simple; a `public_users/` split remains an option if this changes.
