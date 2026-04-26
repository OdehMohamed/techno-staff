# Current Task

> Last updated: 2026-04-26

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Add admin task tabs — backlog item "Add admin task tabs (Assigned to me + All tasks)".**

## Goal

Split the admin tasks screen into two tabs that mirror the employee tabs pattern shipped in PR #6: "Assigned to me" (admin's own assigned tasks) and "All tasks" (every team task). Employee view is unchanged.

## Branch

`feature/admin-task-tabs`, branched from `dev` at commit `2b8affe`. The branch already exists locally and on `origin` — do **not** create a new branch.

## Product decisions (locked 2026-04-26)

1. **Tab order**: "Assigned to me" first, "All tasks" second.
2. **Tab labels**: reuse the existing `assigned_to_me` key; add a new `all_tasks` key with EN "All tasks" / AR "كل المهام".
3. **Subtitle**: above the TabBar (admin only) — EN "Tasks overview" / AR "نظرة عامة على المهام". Add a new `tasks_overview` key.

## Scope — file-by-file

### 1. `lib/features/tasks/presentation/screens/tasks_screen.dart`

- **`_loadTasks()` admin branch**: in addition to `fetchAllTasks()`, also call `fetchTasksAssignedTo(user.id)`.
- **Replace `_buildAdminTasks` with `_buildAdminTabs(state, user)`** — mirror `_buildEmployeeTabs` exactly:
  - `DefaultTabController(length: 2)`.
  - `SectionHeader(title: 'tasks'.tr(), subtitle: 'tasks_overview'.tr())`.
  - `TabBar` with two tabs: `'assigned_to_me'.tr()` first, `'all_tasks'.tr()` second.
  - `TabBarView` with two `_buildTasksTabContent` calls in the same order:
    1. `status: state.tasksAssignedToMeStatus`, `errorKey: state.tasksAssignedToMeErrorMessage`, `tasks: state.tasksAssignedToMe`, `currentUser: user`, `isAdmin: true`.
    2. `status: state.status`, `errorKey: state.errorMessage`, `tasks: state.tasks`, `currentUser: user`, `isAdmin: true`.
- **"Should load" guard in `build`**: `shouldLoadAdmin` must now also require the assigned-to-me list to be initial.
  ```dart
  final shouldLoadAdmin = isAdmin
      && state.status == TasksStatus.initial
      && state.tasksAssignedToMeStatus == TasksStatus.initial;
  ```

### 2. `lib/features/tasks/presentation/cubit/tasks_cubit.dart`

- **`updateTaskStatus`** — when `isAdmin == true`, sequentially refresh both `fetchAllTasks()` AND `fetchTasksAssignedTo(currentUserId)` so the "Assigned to me" admin tab stays in sync after the inline status change. Do not change the method signature.

### 3. Translations

- **`assets/translations/en.json`** — add:
  - `"all_tasks": "All tasks"`
  - `"tasks_overview": "Tasks overview"`
- **`assets/translations/ar.json`** — add:
  - `"all_tasks": "كل المهام"`
  - `"tasks_overview": "نظرة عامة على المهام"`
- The existing `assigned_to_me` key is reused — do **not** duplicate it.

### 4. Tests

- Optional. If a widget test for the admin TabBar is straightforward (Cubit + Auth providers wired with mocks), add it. If wiring is heavy, skip and rely on the manual smoke tests below. Do **not** add a brittle test just to tick a box.

### 5. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append an entry titled "Admin task tabs (Assigned to me + All tasks)" recording the tab order, label, and subtitle choices and the cubit refresh behavior.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — short addition under §4 Modules (or §6/related): note the admin tasks view now uses tabs consistent with the employee view.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Add admin task tabs (Assigned to me + All tasks)" out of `Should-fix` into the `Done` section with completion date.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session (date, agent, branch, outcome, files touched, follow-ups).
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace the file with a "No active task" placeholder (the same pattern this file used at the end of the previous task).

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all tests green.
- `cd functions && npm run lint` — green (no functions changes expected; run anyway).

## Manual smoke tests

1. **Admin sees tabs** → sign in as admin, open Tasks. Two tabs visible: "Assigned to me", "All tasks".
2. **Tab content** → "Assigned to me" lists only tasks where the admin is the assignee. "All tasks" lists every task in the system.
3. **Empty state** → if the admin has no assigned tasks, the "Assigned to me" tab shows the empty state; "All tasks" still shows the team tasks.
4. **Inline status update** → on a task in the "Assigned to me" tab, change the status via the inline dropdown. Both tabs refresh and reflect the new status.
5. **Add task FAB** → still visible on both tabs; flow unchanged.
6. **Employee view unchanged** → sign in as employee, tabs are still "Assigned to me" + "Created by me" with no regression.
7. **Localization** → toggle to Arabic; tab labels show "المهام المسندة لي" and "كل المهام"; subtitle shows "نظرة عامة على المهام".

## Definition of Done

- [ ] `_loadTasks()` admin branch fetches both lists.
- [ ] `_buildAdminTabs` mirrors `_buildEmployeeTabs` and renders both tabs in the locked order.
- [ ] "should load" guard for admin includes `tasksAssignedToMeStatus`.
- [ ] `updateTaskStatus` admin branch refreshes both `fetchAllTasks` and `fetchTasksAssignedTo`.
- [ ] Two new translation keys added in both `en.json` and `ar.json`.
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `PROJECT_CONTEXT.md` notes the admin tabs.
- [ ] `BACKLOG.md` item moved to `Done`.
- [ ] `SESSION_LOG.md` entry added.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `feat(tasks): add admin task tabs (assigned + all)`.

## Out of scope

- No `firestore.rules` changes.
- No repository / state class changes.
- No employee view changes — those tabs already shipped in PR #6.
- No filter / search work — that is the separate backlog item "Add task search and filtering".
- No new top-level folders, no new dependencies.
- No refactors outside the files listed above.
