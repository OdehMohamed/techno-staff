# Decisions Log

> Append-only log of non-trivial technical or product decisions. Newest at the top.

Decisions capture "why we did it" so that a future reader (human or AI) can tell whether a constraint is still load-bearing or safe to revisit.

---

## Template

```
### YYYY-MM-DD — <Short decision title>

- **Decision**: What did we decide?
- **Reason**: Why? What alternatives did we consider?
- **Impact**: What changes because of this decision? Who / what is affected?
- **Owner**: Who made the call?
- **Related**: Links to PRs, commits, backlog items, or other decisions.
```

---

## 2026-04-27 — Strip debug logging before v1.0.0

- **Decision**: Completed the mechanical cleanup by deleting all 20 `debugPrint` calls under `lib/` with no replacement logging in this PR.
- **Reason**: `debugPrint` statements ship in Flutter release builds and were leaking sensitive and operational metadata (including FCM token and user/task identifiers) to device logs.
- **Impact**: `grep -rn "debugPrint" lib | wc -l` now returns `0`; analyzer/test/functions-lint gates are green; structured error reporting remains deferred to release-prep PR #5 (Crashlytics).
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness".

## 2026-04-27 — Release-readiness sweep for v1.0.0

- **Decision**: Ship v1.0.0 via 5 sequential, small PRs that close out the release-readiness audit findings: (1) strip debug logging, (2) release metadata fixes, (3) Android 13+ notifications permission, (4) account deletion + privacy policy, (5) Crashlytics + minor dep bumps + CHANGELOG. Account deletion uses a Cloud Function callable for atomicity. Privacy policy is hosted on GitHub Pages. Release flow: all PRs merge into `dev`, then a `release: v1.0.0` PR fast-forwards `main` from `dev`, and `v1.0.0` is tagged with annotated `git tag` and a GitHub Release.
- **Reason**: The audit found six release-blocking issues (debug log leakage of FCM tokens and user IDs; missing Android 13+ notifications permission; no privacy policy; no account deletion; default pubspec description; default README) plus four should-fix items (app name inconsistencies, one translation key typo, no Crashlytics, minor deps behind). Small sequential PRs keep each change reviewable and make it easy to gate or roll back individually.
- **Impact**: A `Release v1.0.0 readiness` section is added to `BACKLOG.md` listing the 5 PRs. Major dependency bumps (`firebase-admin`, `firebase-functions`, `eslint`, `flutter_local_notifications`) are deferred to v1.1. Operational follow-ups (CI/CD, staging Firebase project, full offline UX, performance tuning, dark mode QA, store metadata) are deferred but tracked.
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` → "Release v1.0.0 readiness", `CURRENT_TASK.md`.

## 2026-04-27 — Strip debug logging before v1.0.0

- **Decision**: Delete all 20 `debugPrint` calls in `lib/` outright (not wrap them in `if (kDebugMode) ...`). Structured error reporting will be reintroduced via Firebase Crashlytics in release-prep PR #5.
- **Reason**: `debugPrint` is not stripped from release builds in Flutter, so calls like `auth_cubit.dart` printing the user's FCM token leak sensitive data to device logs. Wrapping each call in `kDebugMode` preserves visual clutter and tempts future agents to add more such calls. A clean delete plus Crashlytics is the right pattern.
- **Impact**: `lib/main.dart`, `auth_cubit.dart`, `tasks_cubit.dart`, `reports_repository.dart`, `reports_cubit.dart`, and `reports_screen.dart` are touched. A handful of `catch (e)` blocks become `catch (_)` to keep `flutter analyze` clean. No behavior changes.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness" → 1.

## 2026-04-27 — Task search and filtering — global state, client-side, bottom sheet UX

- **Decision**: Implement task search and filtering entirely on the client over already-fetched tab lists, with one global filter state shared across tabs in `TasksScreen`, and a `showModalBottomSheet` apply-flow for status/priority/sort controls.
- **Reason**: Expected list size is small enough for local filtering, and global cross-tab state gives a consistent user mental model while keeping scope limited to UI logic.
- **Impact**: `tasks_screen.dart` now applies search on title/description/assigned-to/assigned-by names plus status/priority/sort, shows active-filter affordances (badge, count, clear action), and uses a dedicated `task_filter_bottom_sheet.dart` widget with a `TaskFilters` value object.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, backlog item "Add task search and filtering".

## 2026-04-27 — Add task delete UI for admins and creators

- **Decision**: Implement task deletion from `task_details_screen.dart` as an AppBar action (`Icons.delete_outline`) using the same visibility gate as edit (`admin` or task creator), with a required confirmation dialog that interpolates the task title.
- **Reason**: Reusing the existing details-screen action pattern keeps permissions and UX consistent while minimizing scope and regression risk.
- **Impact**: Client now supports delete for authorized users through `TasksRepository.deleteTask`, `TasksCubit.deleteTask`, and localized confirmation/success/failure copy. This PR intentionally does not emit delete notifications and does not clean up `task_logs/`.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, backlog item "Add task delete UI for admins and creators".

## 2026-04-26 — Admin task tabs (Assigned to me + All tasks)

- **Decision**: The admin tasks screen now mirrors the employee tab pattern with two locked tabs in this order: `Assigned to me` first and `All tasks` second, with the admin subtitle using `tasks_overview`.
- **Reason**: Admins need both a personal work queue and a global team view, and reusing the employee tab pattern keeps the tasks experience consistent across roles.
- **Impact**: `TasksScreen` now fetches both admin task streams on load, renders `_buildAdminTabs()` instead of a single list, and `TasksCubit.updateTaskStatus()` refreshes both `fetchAllTasks()` and `fetchTasksAssignedTo(currentUserId)` after an admin status change so both tabs stay synchronized.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: `CURRENT_TASK.md`, backlog item "Add admin task tabs (Assigned to me + All tasks)".

## 2026-04-24 — Self-assignment is allowed (reversal of earlier scope detail)

- **Decision**: A user may assign a task to themselves. The current user MUST remain visible in the assignee dropdown on the add-task screen.
- **Reason**: During the initial planning round for the employee-task-creation feature, the scope called for excluding the current user from the assignee dropdown. On review, the team decided self-assignment is a legitimate use case (e.g. a user tracking their own work item as a formal task) and restricting it adds no security or UX value — `assignedBy` and `assignedTo` being the same uid is harmless.
- **Impact**: `CURRENT_TASK.md §6` and manual smoke test #7 updated to reflect this. Implementation in `add_task_screen.dart` intentionally does NOT filter out the current user. Any future agent reading the old "exclude self" instruction should ignore it.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, PR #6.

## 2026-04-24 — Allow employee task creation + relax users read rule

- **Decision**: Implement employee task creation with any-to-any assignment by updating `firestore.rules` so any signed-in user can read `users/`, any task creator can create/update/delete their own tasks, and `assignedBy` remains immutable after task creation.
- **Reason**: Employees must be able to choose any assignee (employee or admin), view assignee choices in-app, and manage tasks they originated without requiring admin-only task creation.
- **Impact**: Non-admin task screens now show split views (`assigned_to_me` and `created_by_me`), task creation is available to all users, and security rules enforce ownership boundaries while preserving assignee status-only edits.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, backlog item "Allow employees to create and assign tasks".

## 2026-04-24 — Adopt `/docs/ai-workflow/` as the single shared source of truth

- **Decision**: All cross-session project context, rules, decisions, backlog, and forward-looking ideas live under `/docs/ai-workflow/` as plain markdown. Every AI agent and human developer reads these files before starting a task and updates them after finishing.
- **Reason**: We work with multiple AI agents that do not share memory across sessions. A file-based source of truth prevents drift, reduces hallucinations, and survives changes to the specific models or tools we use.
- **Impact**: New mandatory workflow — see `RULES.md` for the "Workflow for every task" section. `CLAUDE.md` now points here as the entry point.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md`, `PROJECT_CONTEXT.md`.

## 2026-04-24 — Remove Spec Kit; migrate the constitution into `RULES.md`

- **Decision**: Delete `specs/`, `.specify/`, and the `speckit-*` skills under `.claude/skills/`. The ratified constitution v1.0.0 (previously in `.specify/memory/constitution.md`) moves into `/docs/ai-workflow/RULES.md`. Spec Kit slash commands are no longer the workflow.
- **Reason**: The team prefers one lightweight markdown-based workflow over two overlapping systems. Spec Kit introduced `/specs/` folders, templates, and slash commands that duplicated what `/docs/ai-workflow/` will cover. Keeping both would split context across two systems and increase the chance of stale docs.
- **Impact**: Fewer concepts to keep in sync. All project rules live in one file. No more `/speckit.*` commands; new features are documented via `CURRENT_TASK.md` + `BACKLOG.md` + (optionally) a short design note inside the PR description.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md` (contains the migrated constitution content).
