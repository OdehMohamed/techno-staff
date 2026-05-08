# Backlog

> Last updated: 2026-05-01
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

### v1.1 — testing-phase fixes and improvements

> Coordinated v1.1 work covering tester-facing bug fixes, account settings, task improvements, and a deferred attendance MVP. Roadmap and architectural decisions are in `DECISIONS_LOG.md` (2026-05-01 entries). Locked decisions: server-side notification localization driven by `users/{uid}.languageCode`; account settings v1.1 scope = name + password only; attendance MVP = timestamp + biometric (no location, deferred); recurring tasks via `isTemplate` boolean on the existing `tasks` collection; adaptive screen-level countdown ticker (no per-card timers).

#### 1. Auth + account deletion flow — `fix/auth-and-account-deletion-flow`

- **Priority**: Should-fix (tester-facing)
- **Status**: Done — 2026-05-07
- **Owner**: GitHub Copilot (GPT-5.3-Codex)
- **Target release**: 1.1.0
- **Added**: 2026-05-01
- **Planned**: 2026-05-01 (branch `fix/auth-and-account-deletion-flow`)
- **Description**: Fix FCM token leakage after sign-out (B1) and the delete-account flow getting stuck on a loading spinner (B3). `AuthCubit.signOut()` clears `users/{uid}.fcmToken` (best-effort) and calls `FirebaseMessaging.deleteToken()` before signing out. `AuthCubit.deleteAccount()` explicitly signs out and emits `unauthenticated` after the Cloud Function succeeds — no longer relies on a passive auth state listener. `account_deleted` snackbar dropped (auth state transition is the success signal). Pure client-side; no Firestore rules or Cloud Functions changes.
- **Completed**: 2026-05-07. Code changes shipped in `auth_cubit.dart` + `settings_screen.dart`; `app.dart` already had top-level unauthenticated routing listener and required no changes. Quality gates green (`flutter analyze`, `flutter test`, `cd functions && npm run lint`).

#### 2. Notification language — `fix/notification-language`

- **Priority**: Should-fix (tester-facing)
- **Status**: Done — 2026-05-07
- **Owner**: GitHub Copilot (GPT-5.3-Codex)
- **Target release**: 1.1.0
- **Added**: 2026-05-07
- **Planned**: 2026-05-07 (branch `fix/notification-language`)
- **Description**: Make FCM push notifications respect the recipient's chosen language. Cloud Functions read `users/{uid}.languageCode` and send already-localized `title` and `body` strings. In-app notifications already localize correctly client-side (no change there). New field `users/{uid}.languageCode: 'en' | 'ar'` (default `'en'`) persisted on sign-in and on locale change. Single `firestore.rules` update extends the self-update mask from `hasOnly(['fcmToken'])` to `hasOnly(['fcmToken', 'languageCode'])`. Server-side translation table covers ~5 string sets across 4 FCM send sites + 2 test callables.
- **Completed**: 2026-05-07. Implemented server-side i18n in `functions/index.js` across all 4 FCM send paths + 2 test callables; added client persistence for `languageCode` on auth success and locale change; added `FirebasePaths.languageCode`; updated `firestore.rules` self-update mask to include `languageCode`. Quality gates green (`flutter analyze`, `flutter test`, `cd functions && npm run lint`).

#### 3. Theme persistence — `fix/theme-persistence`

- **Priority**: Should-fix (tester-facing)
- **Status**: In progress — planning complete, see `CURRENT_TASK.md`
- **Owner**: implementation delegated
- **Target release**: 1.1.0
- **Added**: 2026-05-08
- **Planned**: 2026-05-08 (branch `fix/theme-persistence`)
- **Description**: Persist the user-selected theme mode (system / light / dark) across app launches via `shared_preferences`. Hydrate the cubit synchronously in `main()` before `runApp()` so the first frame paints the correct theme — no flicker on cold start. `ThemeCubit` gains `prefs` + `initialMode` constructor params; setters write to prefs after `emit` (best-effort with Crashlytics on failure). No changes to Settings screen, `app.dart`, `MaterialApp.themeMode` mapping, Firestore, or rules. New dep: `shared_preferences ^2.x.x` (Flutter team official). No Firestore sync — local-only persistence; cross-device sync deferred.

_Other v1.1 entries (added when each enters its planning round)_:
- F1 — Account settings (name editing + password change)
- F3.A — Task countdown timer (adaptive screen-level ticker)
- F3.C — Target/counter task type
- F3.B — Recurring tasks (`isTemplate` + cron-driven instances)

_Deferred to v1.2.0_: F2 — Attendance MVP (timestamp + biometric, no location).

---

## Nice-to-have

_None yet._

## Done

### Pre-build polish (v1.0.1 stores)

#### B. Android release signing — `chore/android-release-signing`

- **Priority**: Should-fix (store blocker)
- **Status**: Done — 2026-05-01 (PR #20)
- **Owner**: GitHub Copilot (Claude Sonnet 4.6)
- **Target release**: 1.0.1
- **Added**: 2026-05-01
- **Description**: Replaced the Flutter-scaffolding debug-key fallback with a strict `signingConfigs.create("release")` block driven by `android/key.properties` (gitignored). `flutter build apk --release` / `flutter build appbundle --release` fail hard when `key.properties` is absent. `docs/release-checklist.md` updated with copy-pasteable `keytool` + `key.properties` template.
- **Completed**: 2026-05-01. Quality gates green (`flutter analyze` → No issues, `flutter test` → 2/2 passed, `npm run lint` → clean, `flutter build apk --debug` → ✓). Smoke tests: (1) release APK fails without `key.properties` ✓; (2) signed AAB with throwaway keystore → `jarsigner -verify` passed ✓; (3) `flutter build ios --release --no-codesign` ✓; (4) `git status` — no `key.properties` or `.jks` tracked ✓.

#### A. App icons — `chore/app-icons`

- **Priority**: Should-fix (store requirement)
- **Status**: Done — 2026-05-01 (PR #19)
- **Owner**: GitHub Copilot (GPT-5.3-Codex)
- **Target release**: 1.0.1
- **Added**: 2026-05-01
- **Description**: Added `flutter_launcher_icons` to `dev_dependencies`, committed source icon `assets/icon/app_icon.png`, and ran `dart run flutter_launcher_icons` to generate all required Android mipmap and iOS `Assets.xcassets/AppIcon.appiconset` sizes.
- **Notes**:
  - Verification: Android `mipmap-xxxhdpi/ic_launcher.png` is `192 x 192`; iOS `Icon-App-1024x1024@1x.png` is `1024 x 1024`.
  - Verification: iOS icon SHA1 changed from the default Flutter value (`7b0546f...`) to `6c3b1e4b0e02dc9e665728bcc2c653ece7e69c7f`.

### Release v1.0.0 readiness

#### 5. Release readiness — `chore/release-readiness`

- **Priority**: Should-fix (release blocker)
- **Status**: Done — 2026-04-30
- **Owner**: GitHub Copilot (GPT-5.3-Codex)
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-30 (branch `chore/release-readiness`)
- **Description**: Added minimal Firebase Crashlytics wiring (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `setUserIdentifier` on auth sign-in/sign-out), bumped the 5 Firebase Flutter packages by one minor each, and added release artifacts `CHANGELOG.md` and `docs/release-checklist.md`.
- **Completed**: 2026-04-30. Quality gates green (`flutter analyze`, `flutter test`, `cd functions && npm run lint`), verification commands passed (Crashlytics wiring grep, dependency grep, translation parity `182 182 []`, changelog header, checklist file presence). Manual smoke tests documented in PR body.

#### 4. Account deletion + privacy policy — `feat/account-deletion-and-privacy`

- **Priority**: Should-fix (release blocker)
- **Status**: Done — 2026-04-28
- **Owner**: GitHub Copilot (Claude Sonnet 4.6)
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-28 (branch `feat/account-deletion-and-privacy`)
- **Description**: (a) Cloud Function callable `deleteUserAccount` deletes the caller's Firestore data + Firebase Auth atomically; tasks the user created or was assigned to are kept with `assignedByName` / `assignedToName` overwritten to literal `"Deleted user"`; `task_logs/` preserved. (b) Settings → Account section with "Delete account" entry + simple confirmation dialog. (c) Privacy policy at `docs/privacy-policy.md`, hosted via GitHub Pages from `main` branch `/docs` folder; user enables Pages manually post-merge. (d) Settings → About screen with app name, version (`package_info_plus`), privacy policy link (`url_launcher`), and `showLicensePage()` for open-source licenses. Two new dependencies: `package_info_plus` and `url_launcher`. Required by Apple App Store (since 2022) and Google Play (since 2024).
- **Completed**: 2026-04-28. All 5 surfaces implemented. Quality gates (flutter analyze, flutter test, functions lint) all green. Translation parity 182 == 182 []. Real-device smoke tests pending reviewer before merge. GitHub Pages enablement documented in PR body.

#### 3. Notifications permission for Android 13+ — `feat/notifications-permission`

- **Priority**: Should-fix (release blocker)
- **Status**: Done — 2026-04-28
- **Owner**: GitHub Copilot (Claude Sonnet 4.6)
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-28 (branch `feat/notifications-permission`)
- **Description**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to `AndroidManifest.xml`. The runtime `FirebaseMessaging.requestPermission(...)` call already exists in `auth_cubit.dart` `_setupFCM`; only the manifest declaration is missing, which is why the prompt never shows on Android 13+ today.
- **Completed**: 2026-04-28. One manifest line added. Quality gates (flutter analyze, flutter test, functions lint) all green. Real-device Android 13+ verification pending reviewer smoke test before merge.

#### 1. Strip debug logging — `chore/strip-debug-logging`

- **Priority**: Should-fix (release blocker)
- **Status**: Done (completed 2026-04-27)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-27 (branch `chore/strip-debug-logging`)
- **Description**: Removed all 20 `debugPrint` calls in `lib/` to avoid release-log leakage of FCM token, user/task identifiers, and report metadata.
- **Notes**:
  - Verification: `grep -rn "debugPrint" lib | wc -l` returned `0`.
  - Replacement structured logging (Crashlytics breadcrumbs) remains scoped to PR #5.

#### 2. Release metadata fixes — `chore/release-metadata`

- **Priority**: Should-fix (release blocker)
- **Status**: Done (completed 2026-04-27)
- **Owner**: implementation delegated
- **Target release**: 1.0.0
- **Added**: 2026-04-27
- **Planned**: 2026-04-27 (branch `chore/release-metadata`)
- **Description**: Fixed release metadata with five scoped edits: pubspec description, README rewrite, Android launcher label, iOS bundle name, and `en.json` key rename `in_pending_tasks` → `pending_tasks`.
- **Notes**:
  - Verification: `grep -rn "in_pending_tasks" lib assets test | wc -l` returned `0`.
  - Translation parity check: `171 171 []`.

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
