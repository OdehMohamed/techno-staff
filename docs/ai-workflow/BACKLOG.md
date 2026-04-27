# Backlog

> Last updated: 2026-04-27
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

### Release v1.0.0 readiness

> Coordinated meta-task. Prepare the app for v1.0.0 store submission via 5 small, sequential PRs. Sweep findings and the agreed plan are in the `2026-04-27 — Release-readiness sweep for v1.0.0` entry in `DECISIONS_LOG.md` once that lands; the high-level breakdown is captured here.

#### 1. Strip debug logging — `chore/strip-debug-logging`

- **Priority**: Should-fix (release blocker)
- **Status**: In progress — planning complete, see `CURRENT_TASK.md`
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-27 (branch `chore/strip-debug-logging`)
- **Description**: Remove all 20 `debugPrint` calls in `lib/`. `debugPrint` is not stripped in release builds and currently leaks the user's FCM token, user IDs, task IDs, and report metadata to device logs.
- **Notes**:
  - Highest-priority deletion: `auth_cubit.dart` line 130 (FCM token).
  - Replacement structured logging (Crashlytics breadcrumbs) lands in PR #5.

#### 2. Release metadata fixes — `chore/release-metadata`

- **Priority**: Should-fix (release blocker)
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Description**: Fix release metadata: pubspec description (currently default placeholder), README (currently default Flutter starter), Android `android:label` and iOS `CFBundleName` (lowercase `techno_staff`) → user-facing `Techno Staff`. Also fix translation key typo: `en.json` has `in_pending_tasks` while `ar.json` has `pending_tasks`.

#### 3. Notifications permission for Android 13+ — `feat/notifications-permission`

- **Priority**: Should-fix (release blocker)
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Description**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to `AndroidManifest.xml` and request runtime permission via `firebase_messaging` on app start. Without this, FCM notifications silently fail on Android 13+ (the majority of users).

#### 4. Account deletion + privacy policy — `feat/account-deletion-and-privacy`

- **Priority**: Should-fix (release blocker)
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Description**: (a) Add a Cloud Function callable `deleteUserAccount` that deletes the user's Firestore data + Firebase Auth account atomically. (b) Add a "Delete account" affordance in Settings with a confirmation dialog. (c) Write a privacy policy and host it on GitHub Pages. (d) Add a Settings → "About" screen showing app version + a link to the privacy policy. Required by Apple App Store (since 2022) and Google Play (since 2024).

#### 5. Release readiness — `chore/release-readiness`

- **Priority**: Should-fix (release blocker)
- **Status**: Open
- **Owner**: unassigned
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Description**: Add `firebase_crashlytics` and wire `FlutterError.onError` + `PlatformDispatcher.onError`. Bump all Firebase Flutter packages by one minor version (`cloud_firestore` 6.2 → 6.3, etc.). Add `CHANGELOG.md` capturing v1.0.0 features. Add basic operational checklist for the release: enable Firestore scheduled backup, configure Android signed release keystore, configure iOS provisioning. Real-device smoke test on Android 13+ to confirm notifications.

_Deferred (post-v1.0.0)_: offline UX hardening, performance tuning, app size analysis, full dark mode QA, app store metadata drafting (descriptions / screenshots / keywords), `task_logs/` cascade-delete, FCM notification on task delete, major-version dependency bumps.

---

## Nice-to-have

_None yet._

## Done

### Add task search and filtering

- **Priority**: Should-fix
- **Status**: Done (completed 2026-04-27)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Planned**: 2026-04-27 (branch `feature/task-search-and-filtering`)
- **Description**: Added global client-side search/filter/sort controls for tasks with a dedicated bottom-sheet widget and active-filter UI indicators.
- **Acceptance criteria**:
  1. Search covers title, description, assigned-to name, and assigned-by name.
  2. Status and priority filters apply with intersection semantics.
  3. Sort supports newest first, due soonest, and priority high-to-low.
  4. Filter state is global across tabs.
  5. Filtered-empty uses `no_matching_tasks` and non-filtered-empty uses `no_tasks_found`.
  6. Required translation keys were added in EN/AR.
  7. All three quality gates green.
- **Notes**:
  - Implemented in `lib/features/tasks/presentation/screens/tasks_screen.dart` and `lib/features/tasks/presentation/widgets/task_filter_bottom_sheet.dart`.
  - No repository/cubit/state/rules/functions changes.

### Add task delete UI for admins and creators

- **Priority**: Should-fix
- **Status**: Done (completed 2026-04-27)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Planned**: 2026-04-26 (branch `feature/task-delete-ui`)
- **Description**: Added a task delete affordance for admins and task creators in the task details AppBar with confirmation, localized feedback, and role-specific list refresh via the cubit.
- **Acceptance criteria**:
  1. Delete action visible only for admins and creators.
  2. Confirmation dialog required before destructive call.
  3. Success returns to list and refreshes role-relevant tabs.
  4. Failure shows localized snackbar without navigating away.
  5. Locale keys added in both `en.json` and `ar.json`.
  6. All three quality gates green.
- **Notes**:
  - Implemented in `tasks_repository.dart`, `tasks_cubit.dart`, and `task_details_screen.dart`.
  - Intentionally no `firestore.rules` or `functions/index.js` changes.
  - `task_logs/` are preserved (no cascade-delete in this PR).

### Add admin task tabs (Assigned to me + All tasks)

- **Priority**: Should-fix
- **Status**: Done (completed 2026-04-26)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-25
- **Planned**: 2026-04-26 (branch `feature/admin-task-tabs`)
- **Description**: The admin tasks screen now mirrors the employee tabs pattern with two tabs: `Assigned to me` and `All tasks`.
- **Acceptance criteria**:
  1. For admin users, `tasks_screen.dart` shows two tabs: `Assigned to me` and `All tasks`.
  2. The first tab is backed by `state.tasksAssignedToMe`; the second is backed by `state.tasks`.
  3. On admin load and after admin status updates, both task streams refresh so both tabs stay in sync.
  4. Translation keys for `all_tasks` and `tasks_overview` exist in `en.json` and `ar.json`.
  5. Employee view remains unchanged.
  6. All three quality gates green.
- **Notes**:
  - Implemented in `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, and locale files.
  - `flutter analyze`, `flutter test`, and `cd functions && npm run lint` all passed on 2026-04-26.

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
