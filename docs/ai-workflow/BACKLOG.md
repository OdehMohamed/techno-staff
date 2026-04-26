# Backlog

> Last updated: 2026-04-24
> We start with an empty backlog on purpose. Items are added as we discover them through real work — no speculative lists.

---

## How to add an item

Append the item under the section that matches its priority. Use this template:

```
### <short title>

- **Priority**: Blocker | Should-fix | Nice-to-have
- **Status**: Open | In progress | Blocked | Done
- **Owner**: <name, or `unassigned`>
- **Target release**: <version or `TBD`>
- **Added**: YYYY-MM-DD
- **Description**: What is the problem or improvement?
- **Acceptance criteria**: How do we know it's done?
- **Notes**: Related PRs / issues / decisions.
```

When an item is completed, move it to the `Done` section with the completion date appended.

## Priority definitions

- **Blocker** — must be resolved before the next release. Examples: security gap, data loss, broken critical flow.
- **Should-fix** — should land soon, but a release can ship without it. Examples: UX papercuts, missing tests for important paths, minor performance issues.
- **Nice-to-have** — worth doing when there is spare capacity. Examples: polish, refactors, small quality-of-life improvements.

---

## Blockers

_None yet._

## Should-fix

### Add task delete UI for admins and creators

- **Priority**: Should-fix
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Description**: `firestore.rules` already permits task deletion for admins and task creators (PR #6, 2026-04-24), but no UI surfaces this action — neither admins nor creators can currently delete a task from the app. Add a delete affordance on the task details / edit screen, visible only when the current user is an admin or the task's creator.
- **Acceptance criteria**:
  1. A delete action is visible on the task details (or edit) screen if and only if `currentUser.role == 'admin' || task.assignedBy == currentUser.id`.
  2. Tapping the delete action shows a confirmation dialog before any destructive call.
  3. On confirm, the task document is deleted from Firestore via the existing `TasksRepository`; on success the user navigates back and the relevant tab (admin "All tasks", or employee "Created by me") is refreshed.
  4. Failure shows a localized error snackbar; the task remains in the list.
  5. Translation keys (`delete`, `delete_task_confirm_title`, `delete_task_confirm_message`, `task_deleted`, `failed_to_delete_task`) added to both `en.json` and `ar.json`.
  6. All three quality gates green: `flutter analyze`, `flutter test`, `cd functions && npm run lint`.
- **Notes**:
  - Touches `lib/features/tasks/data/repositories/tasks_repository.dart` (add `deleteTask`), `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, and likely `task_details_screen.dart` (or `edit_task_screen.dart`).
  - No `firestore.rules` change required — the rule was already updated in PR #6.
  - Consider whether a deleted task should also delete related `task_logs/` entries. Current rules forbid client writes to `task_logs/` (server-only), so any cleanup must happen server-side or be deferred. Flag for the planning round.

### Add admin task tabs (Assigned to me + All tasks)

- **Priority**: Should-fix
- **Status**: In progress — planning complete, see `CURRENT_TASK.md`
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Planned**: 2026-04-26 (branch `feature/admin-task-tabs`)
- **Description**: The admin tasks screen currently shows a single merged list of all tasks. Mirror the employee tabs pattern by splitting the admin view into two tabs: "Assigned to me" and "All tasks". This gives admins a quick personal view without losing the full team picture.
- **Acceptance criteria**:
  1. For admin users, `tasks_screen.dart` shows two tabs: "Assigned to me" and "All tasks for all employees" (label TBD by translation key).
  2. The "Assigned to me" tab is backed by `state.tasksAssignedToMe` (already exists in the cubit/state — reuse it).
  3. The "All tasks" tab is backed by `state.tasks` (already used by the existing admin view).
  4. On admin login, the cubit fetches both `fetchAllTasks()` and `fetchTasksAssignedTo(currentUser.id)`.
  5. Status-update dropdown logic remains gated by `task.assignedTo == currentUser.id` — already satisfied; no change needed there.
  6. Translation key for the "All tasks" tab added in `en.json` and `ar.json` (re-use the existing `assigned_to_me` key for the first tab).
  7. Employee view unchanged.
  8. All three quality gates green.
- **Notes**:
  - Touches only `lib/features/tasks/presentation/screens/tasks_screen.dart` and one or two translation entries.
  - The existing employee `_buildEmployeeTabs` is a strong reference; the admin variant should reuse the same `_buildTasksTabContent` / `_buildTasksList` helpers.
  - No rules change required.

### Add task search and filtering

- **Priority**: Should-fix
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Description**: Add a search field and filter / sort controls on the tasks screen so users can quickly narrow the list. Applies to all tabs (employee tabs and admin tabs).
- **Acceptance criteria**:
  1. A search input filters the visible tasks by `title` and `description` (case-insensitive substring match), live-updated as the user types.
  2. Filter controls allow filtering by `status` (`pending`, `in_progress`, `completed`, `all`) and by `priority` (`low`, `medium`, `high`, `all`).
  3. Sort options: by `createdAt` (default, descending), `dueDate` (ascending), and `priority` (high → low).
  4. Search and filters apply per-tab independently — switching tabs preserves each tab's filter state for the session.
  5. Empty state ("no_tasks_found" or a more specific "no_results_match") is shown when filters yield zero results.
  6. New translation keys added in both locales for: search placeholder, filter labels, sort labels, and the empty-results message.
  7. Filtering happens client-side on the already-fetched task lists — no new Firestore queries, no `firestore.rules` change.
  8. All three quality gates green.
- **Notes**:
  - Touches `lib/features/tasks/presentation/screens/tasks_screen.dart` and possibly extracts a small filter widget into the same file or `lib/shared/widgets/`.
  - State decision (pending the planning round): keep filter state in `tasks_screen.dart` local state, OR push it into `TasksState` so it survives navigation. Recommend local for now (simpler, smaller PR).
  - Consider performance only if the tasks list grows large; for current expected volumes (~hundreds), client-side filter is fine.

## Nice-to-have

_None yet._

## Done

### Allow employees to create and assign tasks

- **Priority**: Should-fix
- **Status**: Done (completed 2026-04-24)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-24
- **Planned**: 2026-04-24 (branch `feature/employee-task-creation`)
- **Description**: Today only admins can create tasks. Extend the model so that any authenticated user (admin or employee) can create a task and assign it to any other user. The creator gains full edit rights on tasks they created, mirroring what admins have on those specific tasks. Admin retains global full access.
- **Acceptance criteria**:
  1. Employee shell surfaces a "Create Task" entry point and a "Tasks I created" list separate from "Tasks assigned to me".
  2. `firestore.rules` permits `create` on `tasks/` for any authenticated user; the `update`/`delete` rule treats `request.auth.uid == resource.data.assignedBy` as an owner, in addition to admin.
  3. `assignedBy` is immutable after create (rules enforce this).
  4. `sendTaskAssignedNotification` correctly handles the case where the assigner is an employee (notification payload shows assigner name; admins are still notified when appropriate).
  5. An employee cannot escalate their own permissions via task creation (cannot set a task's `role`, `isActive`, or anything outside the task document).
  6. All three quality gates green: `flutter analyze`, `flutter test`, `functions/` ESLint.
- **Notes**:
  - Touches `firestore.rules`, `lib/features/tasks/`, `lib/features/employees/`, and localization files.
  - Rules change followed the approved diff in `CURRENT_TASK.md`.
