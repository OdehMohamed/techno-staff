# Current Task

> Last updated: 2026-04-27

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Strip debug logging — release-prep PR #1 of 5 for v1.0.0.**

This is the first of five small PRs that prepare the app for v1.0.0. Each PR has a tightly scoped responsibility. See `BACKLOG.md` → "Release v1.0.0 readiness" for the full series.

## Goal

Remove all `debugPrint` statements from `lib/` so release builds do not leak user identifiers, FCM tokens, or task metadata to device logs. `debugPrint` is **not stripped from release builds** by Flutter; it ships verbatim. Structured error reporting will be reintroduced in PR #5 (Crashlytics).

## Branch

`chore/strip-debug-logging`, branched from `dev` after PR #10 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-27)

1. **Delete, don't wrap.** All 20 `debugPrint` calls are deleted outright. We do not wrap in `if (kDebugMode) ...` because keeping the lines invites future agents to add similar logging.
2. **No replacement logging in this PR.** Crashlytics + structured breadcrumbs land in PR #5.
3. **Scope is mechanical.** No behavior changes, no refactors, no new tests.

## Scope — file-by-file

### 1. `lib/main.dart`
- Line 31 — remove `debugPrint('🔵 Background Message: ${message.notification?.title}');` inside the background message handler.

### 2. `lib/features/auth/presentation/cubit/auth_cubit.dart`
- Line 130 — remove `debugPrint("🔥 FCM TOKEN: $token");`. **Highest-priority deletion** — currently leaks the user's FCM token to release logs.

### 3. `lib/features/tasks/presentation/cubit/tasks_cubit.dart`
- Remove all 6 `debugPrint` calls:
  - `debugPrint('FETCHING TASKS ASSIGNED TO USER ID: $userId');`
  - `debugPrint('TASKS COUNT ASSIGNED TO USER: ${tasks.length}');`
  - `debugPrint('FETCH ASSIGNED TASKS ERROR: $e');` (inside a `catch (e)`)
  - `debugPrint('FETCHING TASKS CREATED BY USER ID: $userId');`
  - `debugPrint('TASKS COUNT CREATED BY USER: ${tasks.length}');`
  - `debugPrint('FETCH CREATED TASKS ERROR: $e');` (inside a `catch (e)`)
- After removal, change the two `catch (e) {` lines that previously bound `e` only for the print to `catch (_) {` to keep `flutter analyze` clean (`unused_local_variable`).
- The error-state emission (`emit(state.copyWith(...errorMessage: 'failed_to_load_tasks'))`) stays untouched — error reporting still works through the existing UI path.

### 4. `lib/features/reports/data/repositories/reports_repository.dart`
- Remove all 7 `debugPrint` calls (lines ~31, 32, 33, 42, 47, 48, 49):
  - `REPORT EMPLOYEE ID`, `REPORT START`, `REPORT END`, `REPORT TASKS COUNT`, `TASK DOC ID`, `TASK ASSIGNED TO`, `TASK DUE DATE`.
- The surrounding loop / data parsing logic stays unchanged. Confirm the iteration variable is still used elsewhere; if not, rename to `_`.

### 5. `lib/features/reports/presentation/cubit/reports_cubit.dart`
- Remove the `debugPrint('PDF EXPORT ERROR: $e');` at line 115.
- Change the enclosing `catch (e) {` to `catch (_) {`.

### 6. `lib/features/reports/presentation/screens/reports_screen.dart`
- Remove the 4 `debugPrint` calls at approximately lines 490, 504, 530, 544 in the test-reminder and test-escalation button callbacks. Two of them are inside `catch (e) {` blocks — change those to `catch (_) {`.
- The user-facing snackbars stay untouched — they already convey the success/failure to the admin.

### 7. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append a short entry titled "Strip debug logging before v1.0.0" recording: 20 `debugPrint` calls removed, no replacement logging in this PR, structured error reporting deferred to Crashlytics in release-prep PR #5.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — no changes expected (no fact about the project changes).
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Strip debug logging" out of the "Release v1.0.0 readiness" section's `Should-fix` list into `Done` with completion date.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings. Pay attention to `unused_local_variable` if any `catch (e)` was missed.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Verification step

After all edits, run:
```
grep -rn "debugPrint" lib | wc -l
```
Expected output: **`0`**. If any `debugPrint` remains in `lib/`, the task is not done.

## Manual smoke tests

This is a no-behavior-change PR. The only "tests" are the gates above. Optional human spot check:
1. Sign in as employee and switch tabs — task lists still load (no UI regression).
2. Open the reports screen as admin — buttons still trigger and snackbars still appear.

## Definition of Done

- [ ] All 20 `debugPrint` calls removed from `lib/`.
- [ ] `grep -rn "debugPrint" lib | wc -l` returns `0`.
- [ ] `catch (e) {}` blocks where `e` is now unused are changed to `catch (_) {}`.
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `BACKLOG.md` "Strip debug logging" item moved to `Done` (within the Release v1.0.0 readiness section).
- [ ] `SESSION_LOG.md` entry added.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `chore(logging): strip debug logging before v1.0.0`.

## Out of scope

- No `firestore.rules` changes.
- No `functions/index.js` changes.
- No new dependencies. No new files. No refactors. No new tests.
- No `kDebugMode`-wrapped logging — we are deleting, not preserving.
- No Crashlytics or other replacement logging — that is PR #5 (`chore/release-readiness`).
- No metadata changes (pubspec description, README, app names) — that is PR #2 (`chore/release-metadata`).
- Items B2, B3, B4 from the audit — they belong to PRs #3 and #4.
