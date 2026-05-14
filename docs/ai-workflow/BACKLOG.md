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
- **Status**: Done — 2026-05-08
- **Owner**: GitHub Copilot (GPT-5.3-Codex)
- **Target release**: 1.1.0
- **Added**: 2026-05-08
- **Planned**: 2026-05-08 (branch `fix/theme-persistence`)
- **Description**: Persist the user-selected theme mode (system / light / dark) across app launches via `shared_preferences`. Hydrate the cubit synchronously in `main()` before `runApp()` so the first frame paints the correct theme — no flicker on cold start. `ThemeCubit` gains `prefs` + `initialMode` constructor params; setters write to prefs after `emit` (best-effort with Crashlytics on failure). No changes to Settings screen, `app.dart`, `MaterialApp.themeMode` mapping, Firestore, or rules. New dep: `shared_preferences ^2.x.x` (Flutter team official). No Firestore sync — local-only persistence; cross-device sync deferred.
- **Completed**: 2026-05-08. Added direct `shared_preferences` dependency, implemented `ThemeCubit` persistence with best-effort Crashlytics logging, and hydrated initial theme in `main()` before `runApp()` with defensive fallback to `AppThemeMode.system` for missing/invalid stored values.

#### 4. Account settings — `feat/account-settings`

- **Priority**: Should-fix (feature)
- **Status**: Done — 2026-05-08
- **Owner**: GitHub Copilot (Claude Sonnet 4.6) + GitHub Copilot (GPT-5.4 first supplement + second supplement)
- **Target release**: 1.1.0
- **Added**: 2026-05-08
- **Planned**: 2026-05-08 (branch `feat/account-settings`)
- **Description**: Add Edit profile (name) and Change password screens reachable from Settings → Account. Two separate screens (cleaner UX, security isolation between mundane name edits and password changes). Name validation: 2–50 chars after trim. Password minimum 8 chars (stricter than Firebase's 6). Password change always reauthenticates with current password before `updatePassword` to avoid `requires-recent-login`. Firestore rules `users/{userId}` self-update mask extends to include `name`. Firebase Auth `displayName` is NOT synced — Firestore `users/{uid}.name` remains the single source of truth. Email change deferred. Two supplements shipped on the same branch: (a) `AuthCubit` subscribes to `FirebaseAuth.authStateChanges()` to react when Firebase invalidates a session server-side; (b) a new `revokeUserSessions` Cloud Function calls `admin.auth().revokeRefreshTokens(uid)` after a successful password change so other-device sessions actually get invalidated (current Firebase Auth's `updatePassword` does NOT auto-revoke refresh tokens). Same PR also adds a small iOS APNS token race-condition handler in `AuthCubit._setupFCM` that silently tolerates the `apns-token-not-set` error on first launch.
- **Initial implementation completed**: 2026-05-08 — repos, cubit methods, two new screens, rules update, 16 translation keys. Smoke tests #1-7, #9-11 passed. Smoke test #8 (cross-device sign-out) revealed the auth-listener gap, addressed by the first supplemental fix.
- **First supplement completed**: 2026-05-08 — added the locked `authStateChanges()` listener, authenticated-state/null-user guards, and subscription cleanup in `AuthCubit.close()`. Real-device validation showed the listener never fires after `updatePassword` because Firebase Auth doesn't auto-revoke refresh tokens; another iteration required.
- **Second supplement completed**: 2026-05-08 — added `revokeUserSessions` callable Cloud Function, best-effort call from `AuthCubit.changePassword` after `updatePassword` succeeds, plus iOS APNS race-condition handling in `_setupFCM`. Quality gates green. Real-device cross-device smoke tests remain pending project-owner execution.

#### 5. Task countdown timer — `feat/task-countdown-timer`

- **Priority**: Should-fix (feature)
- **Status**: Done — 2026-05-09
- **Owner**: TBD (implementing agent)
- **Target release**: 1.1.0
- **Added**: 2026-05-08
- **Planned**: 2026-05-08 (branch `feat/task-countdown-timer`, branched from `dev` after PR #26 merge)
- **Completed**: 2026-05-09 — added `CountdownClockProvider` + `CountdownChip`, replaced the static due-date chip on the tasks list and task details screen, added 6 EN + 6 AR countdown keys, and kept rebuilds scoped to the chip leaf via `ValueListenableBuilder`.
- **Description**: Replace the static "Due date: yyyy-MM-dd" chip on the tasks list and task details screen with a live countdown chip ("Due in 5h 32m", "Overdue by 2h", "Due today"). Adaptive single screen-level ticker per consuming screen — 60s default cadence, upgrades to 1s when any visible task's `endOfDay(dueDate) - now < 1h`. Pauses on `AppLifecycleState.paused`. Subscribers bound to a leaf `CountdownChip` via `ValueListenableBuilder` so parent `AppCard` / `InkWell` / `_buildTasksList` body don't rebuild on tick. Counts to **end-of-day of `dueDate`** (Option A from audit) — preserves the existing date-only model and aligns with overdue logic across dashboard / reports / Cloud Functions reminder paths. No `TaskCard` widget extraction in v1.1 (Option B from audit). No data-model change, no `firestore.rules` change, no Cloud Functions change. 6 new translation keys × 2 locales. Spec in `CURRENT_TASK.md`.

#### 6. Counter task type — `feat/counter-tasks`

- **Priority**: Should-fix (feature)
- **Status**: Done — 2026-05-09
- **Owner**: TBD (implementing agent)
- **Target release**: 1.1.0
- **Added**: 2026-05-09
- **Planned**: 2026-05-09 (branch `feat/counter-tasks`, branched from `dev` after PR #27 merge)
- **Completed**: 2026-05-09 — shipped counter-task fields (`taskType` / `targetCount` / `currentCount`), status derivation helper, transactional `incrementTaskCounter`, counter UI in add/edit/list/details, and the one-line `firestore.rules` assignee-mask widening for `currentCount`. Automated gates: `flutter analyze` (clean), `flutter test` (all passed), `cd functions && npm run lint` (clean), translation parity `214 214 []`. Smoke tests #4-#6, #8-#10, #13, #14 deferred to project owner (real-device/ops dependent).
- **Description**: Add a second task variant alongside the existing standard task: a counter task whose progress is tracked as `currentCount / targetCount`. Assignees increment from the task list / task details via a `+` button; status (`pending` / `in_progress` / `completed`) is **derived from the counts and persisted into the existing `status` field** so every downstream consumer (dashboards, reports, FCM completion notifications, deadline-reminder filters, countdown chip, Firestore rules, `task_logs`) keeps working without per-type branches. Storage is flat fields on the existing `tasks` collection (`taskType`, `targetCount`, `currentCount`); zero migration. Increment goes through a `runTransaction` so concurrent device taps never lose progress. Firestore rules diff is a single line — extending the assignee self-update mask to include `currentCount`. No Cloud Functions changes. 10 new translation keys × 2 locales. Spec in `CURRENT_TASK.md`.

#### 7. Recurring tasks — `feat/recurring-tasks`

- **Priority**: Should-fix (feature)
- **Status**: Done
- **Owner**: TBD (implementing agent)
- **Target release**: 1.1.0
- **Added**: 2026-05-09
- **Completed**: 2026-05-09 (initial) + 2026-05-14 (multi-assignee supplement) — shipped `TaskTemplateModel` + `RecurrenceRule`, `TemplatesRepository`, `TemplatesCubit`, three admin screens (list / add / edit), `generateRecurringTaskInstances` cron Cloud Function (daily 6 am Asia/Jerusalem) with 7 timezone helpers + layered idempotency, Firestore `task_templates` rules block, drawer entry, 27 translation keys × 2 locales (EN + AR). Supplement (2026-05-14): templates extended to multi-assignee (`assignedToIds`/`assignedToNames` arrays), one instance per assignee per day (`${templateId}_${assigneeId}_${YYYY-MM-DD}` deterministic ID), `lastGeneratedAt` demoted to metadata-only, backward compat for legacy single-assignee docs. `flutter analyze` clean, `flutter test` 6/6, `npm run lint` clean. Smoke tests deferred to project owner (real-device/ops dependent).
- **Planned**: 2026-05-09 (branch `feat/recurring-tasks`, branched from `dev` after PR #28 merge)
- **Description**: Add admin-authored recurring task templates that auto-generate fresh task instances on a daily / weekly / monthly schedule. Templates live in a **separate `task_templates` collection** (revising the original 2026-05-01 `isTemplate` flag decision after audit found ~13 downstream consumers would need filtering); the existing `tasks` collection stays semantically clean and continues to represent only actionable runtime instances. Generation is **server-only** in a new `generateRecurringTaskInstances` `onSchedule` Cloud Function (daily 6 am Asia/Jerusalem, before the existing 9 am reminder sweep). Idempotency is layered: deterministic instance document IDs `${templateId}_${YYYY-MM-DD}` plus `lastGeneratedAt` same-day guard on the template, both inside one Firestore transaction. Generated instances **snapshot** template fields at generation time — historical instances stay stable when the template is later renamed or paused. Counter-task templates supported (each instance starts fresh with `currentCount: 0`). Monthly clamps overflow days to the last valid day of the month (so day-31 templates generate on Feb 28/29). All recurrence + date-boundary math uses Asia/Jerusalem wall-clock via `Intl.DateTimeFormat` helpers — no raw UTC math. Soft pause via `isActive: false`; hard delete preserves historical instances. Admin-only authoring (rules + UI). Last v1.1 feature before cutting v1.1.0. Spec in `CURRENT_TASK.md`.

#### 8. Offline connectivity guard + pull-to-refresh — `feat/connectivity-and-refresh`

- **Priority**: Should-fix (v1.1.0 stabilization)
- **Status**: Done
- **Owner**: TBD (implementing agent)
- **Target release**: 1.1.0
- **Added**: 2026-05-14
- **Completed**: 2026-05-14 — shipped `connectivity_plus` + `ConnectivityService`, `MaterialApp.builder` offline banner overlay, silent refresh fetch parameters in `TasksCubit` / `DashboardCubit` / `EmployeesCubit`, pull-to-refresh on `TasksScreen`, `EmployeeHomeScreen`, `AdminDashboardScreen`, and `EmployeesScreen`, and 1 new translation key × 2 locales (`242 242 []`). Quality gates: `flutter analyze` clean, `flutter test` 6/6 passed, `cd functions && npm run lint` clean.
- **Planned**: 2026-05-14 (branch `feat/connectivity-and-refresh`, created from `dev` after PR #29 squash-merge)
- **Description**: Two v1.1.0 pre-release stabilization items shipped together. (1) **Offline guard**: top-anchored red banner via `MaterialApp.builder` Stack overlay (NOT a route push). Powered by `connectivity_plus ^6.x` singleton `ConnectivityService` with `Stream<bool>`. Banner is informational only — does not block navigation, disable buttons, or intercept Firestore writes. (2) **Pull-to-refresh**: `RefreshIndicator` on `TasksScreen` (per-tab, due to `TabBarView` incompatibility), `EmployeeHomeScreen`, `AdminDashboardScreen`, `EmployeesScreen`. Silent refresh via `{bool silent = false}` on cubit fetch methods to avoid full-screen spinner flash during refresh. Initial load guard: full-screen spinner only when data list is empty. Empty/error states wrapped in `ListView` so drag gesture always reaches the indicator. 1 new translation key `no_internet_connection` × 2 locales → 242/242 parity. Zero changes to Firestore rules, Cloud Functions, data models, routing, or existing state shape. Spec in `CURRENT_TASK.md`.
- **Acceptance criteria**: (1) Airplane mode triggers red banner; banner disappears on reconnect. (2) Pull-to-refresh on all 4 screens updates data without full-screen loading flash. (3) Empty/error states on all 4 screens are still draggable. (4) `flutter analyze` clean, `flutter test` all green, translation parity `242 242 []`.

_All v1.1 features are complete. v1.1.0 shipped 2026-05-14._

---

### v1.2 — next development cycle (unified; no v1.1.1 / v1.2.0 split)

> Roadmap consolidated 2026-05-14 after v1.1.0 deployment. v1.1.1 and v1.2.0 collapsed into one unified cycle. Ordering is locked: mandatory update first (production safety valve), Shorebird audit second (gates release strategy), stabilization triage ongoing, then features in parallel, attendance last (architecture-first). See `DECISIONS_LOG.md` 2026-05-14 for rationale.

#### 9. Mandatory app-update system — `feat/mandatory-app-update`

- **Priority**: Should-fix (operational safety valve)
- **Status**: Done — 2026-05-14
- **Owner**: TBD (implementing agent)
- **Target release**: 1.2.0
- **Added**: 2026-05-14
- **Completed**: 2026-05-14 — shipped `AppUpdateService` singleton (fail-open Firestore version check, semver tuple comparison), `UpdateRequiredScreen` (non-dismissible, `PopScope(canPop:false)`, store deep-link via `url_launcher`), `SplashScreen._checkVersionThenAuth()` hook before `checkAuthStatus()`, `config/` Firestore rules block (public read), `RouteNames.updateRequired` + `AppRouter` case, 3 translation keys × 2 locales (245/245 parity), `docs/release-checklist.md` update. `firebase deploy --only firestore:rules` executed. `config/app_settings` doc created in Firestore console. Runtime-validated: pass-through, force-update block, non-dismissible navigation, Android store link, iOS null-url disabled button. Quality gates: `flutter analyze` clean, `flutter test` green.
- **Description**: On app startup, fetch a minimum supported version from a Firestore `config/app_settings` doc (`minimumAndroidVersion` / `minimumIosVersion` string fields). If the installed version is below minimum, block app usage with a non-dismissible update UI that deep-links to Google Play (Android) or TestFlight/App Store (iOS). Version comparison uses tuple semver logic (not string comparison). Blocking UI appears before or during splash, before any auth gate. Soft-update mode (banner, not block) is a future extension — out of scope for this PR. Firestore `config/app_settings` chosen over Firebase Remote Config (already in stack, no new service, admin-editable from Firestore console).
- **Acceptance criteria**: (1) Device with version below minimum is blocked on cold start with update UI and correct store link. (2) Device with version at or above minimum passes through normally. (3) Firestore doc update takes effect on next app cold start (no binary push needed). (4) `flutter analyze` clean, `flutter test` green.

#### 10. Shorebird feasibility audit — (planning only, no branch yet)

- **Priority**: Should-fix (release strategy decision)
- **Status**: Done — 2026-05-14 (decision: conditional adoption)
- **Owner**: Claude Code (Sonnet 4.6) — audit; Mohamed Odeh — decision
- **Target release**: N/A (audit only)
- **Added**: 2026-05-14
- **Completed**: 2026-05-14 — full audit across free-tier limits, Dart-only patch surface, FCM compatibility (ANR bug #695 confirmed fixed), Crashlytics integration (adequate via custom key for testing phase), iOS App Store compliance (guideline 3.3.1b), obfuscation status (iOS requires Flutter 3.41.2+, current install 3.35.7), private-repo CI limitation (free tier excludes it — manual CLI), operational workflow change, longevity risk. Decision: **conditional adoption**. Patch-eligibility checklist and Shorebird release flow added to `docs/release-checklist.md`. Decision recorded in `DECISIONS_LOG.md`.
- **Description**: Dedicated read-only audit (no implementation) covering: free-tier constraints (5,000 active devices/month, 1 app), Dart-only patch surface and what that excludes (`firebase_messaging` background isolate, `local_auth` biometric, FCM token setup, `flutter_local_notifications` channel config), Crashlytics symbol mapping compatibility with patched builds, iOS App Store / TestFlight policy compliance, rollback behavior, and explicit semantics for how Shorebird patches and the mandatory update system coexist (patch = Dart-only silent fix; mandatory update = breaking change requiring a full binary). Decision gates release strategy for all subsequent features.

#### 11. Stabilization — real-world usage triage (ongoing)

- **Priority**: Should-fix (stability)
- **Status**: Open — collection ongoing from v1.1.0 testing
- **Owner**: Mohamed Odeh (triage); TBD (fixes)
- **Target release**: 1.2.0
- **Added**: 2026-05-14
- **Description**: Collect and triage tester feedback from v1.1.0 closed testing cycle. Known watch areas: offline write queue user expectation (task completed while offline — does it sync?), notification timing behavior, recurring task generation edge cases, refresh expectations, admin workflow friction. First formal triage pass after ~2 weeks of real usage. Fixes sized and promoted to individual BACKLOG items as they are discovered.
- **Acceptance criteria**: First formal triage document complete. High-severity items promoted to BACKLOG with priority. Low-severity items captured in NEXT_STEPS.

#### 12. Progressive deadline reminder notifications — `feat/progressive-reminders`

- **Priority**: Should-fix (feature)
- **Status**: In progress — branch `feat/progressive-reminders`, spec locked 2026-05-14
- **Owner**: TBD (implementing agent)
- **Target release**: 1.2.0
- **Added**: 2026-05-14
- **Description**: Extend `sendTaskDeadlineReminders` Cloud Function from a single 24h-before reminder to a 72h + 24h progressive pattern. Fix existing timezone bug (raw `new Date()` → `ymdInJerusalem` + `jerusalemMidnightAsUTC` helpers). Fix same-day check bug in `sendOverdueTaskEscalations`. Deduplication via two server-written Timestamp fields on task doc: `reminderSent72hAt`, `reminderSent24hAt`. New i18n key `task_deadline_72h_body` in `functions/index.js` + both translation JSON files. Scope: Cloud Functions + translation JSON only — no Dart/rules/pubspec changes. Not Shorebird patch-eligible; requires `firebase deploy --only functions` post-merge.
- **Acceptance criteria**: At most one reminder per task per threshold per Jerusalem calendar day. Timezone bug fixed in both functions. `npm run lint` clean, `flutter analyze` clean, `flutter test` green, translation parity `246 246 []`.

#### 13. UI/UX improvements (admin dashboard, reports, employee home/workflow)

- **Priority**: Should-fix (polish)
- **Status**: Open — scope to be defined from tester feedback
- **Owner**: TBD
- **Target release**: 1.2.0
- **Added**: 2026-05-14
- **Description**: Targeted UX improvements informed by real v1.1.0 testing feedback. Known candidates: admin dashboard layout, reports screen usability, employee home/workflow friction. Exact scope deferred until stabilization triage (item #11) produces signal. Do not spec or implement before tester feedback is available.
- **Acceptance criteria**: Specific items defined and closed. No regressions on existing screens.

#### 14. Attendance / check-in / check-out system — (architecture-first planning round required)

- **Priority**: Should-fix (feature)
- **Status**: Open — blocked on architecture planning round
- **Owner**: TBD
- **Target release**: 1.2.0
- **Added**: 2026-05-14 (carried from 2026-05-01 v1.2.0 deferral)
- **Description**: Admin-visible employee check-in / check-out system. Known scope: timestamp recording + biometric gate (`local_auth`). No geolocation in initial scope. Architecture-first planning round required before any code — open questions: collection structure (`attendance/{uid}/records/{date}` vs flat), admin reporting view (existing Reports screen vs new screen), relationship to task model (orthogonal or linked), whether the no-location constraint still holds after testing feedback. `local_auth` is a native plugin — permanently outside Shorebird patch surface.
- **Acceptance criteria**: Architecture planning round complete with locked CURRENT_TASK.md spec before any implementation begins.

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
