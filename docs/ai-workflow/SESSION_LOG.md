# AI Session Log

> Append-only log of AI-assisted work sessions. One entry per meaningful session, newest at the top.

The goal is a quick skim-friendly history so you can answer "what did we do last week?" without digging through git logs or chat transcripts.

---

## Template

```
### YYYY-MM-DD — <Agent> — <short title>

- **Agent**: Claude Code (Opus 4.7) | Cursor | ChatGPT | Gemini | other
- **Branch**: <branch-name>
- **Goal**: one-line summary of the intent
- **Outcome**: what shipped, what was decided, or what was learned
- **Files touched**: brief list or "see commit <sha>"
- **Follow-ups**: items added to BACKLOG.md / NEXT_STEPS.md / DECISIONS_LOG.md
```

---

## 2026-05-07 — GitHub Copilot (GPT-5.3-Codex) — Implement auth/account-deletion lifecycle fix (v1.1 PR #1)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `fix/auth-and-account-deletion-flow`
- **Goal**: Implement CURRENT_TASK scope for B1/B3: clear FCM token lifecycle on sign-out/deletion and ensure delete-account routes to login reliably.
- **Outcome**: Updated `AuthCubit.signOut()` to best-effort delete `users/{uid}.fcmToken` and call `FirebaseMessaging.deleteToken()` (both wrapped in try/catch with `FirebaseCrashlytics.recordError`). Updated `AuthCubit.deleteAccount()` to best-effort delete FCM token, clear Crashlytics user id, sign out, and emit `unauthenticated` on callable success. Updated Settings delete flow to remove success snackbar, add `BlocListener<AuthCubit, AuthState>` for unauthenticated routing to login, and defensively reset `_isDeleting` before navigation while preserving the `failed_to_delete_account` snackbar path. Verified top-level routing in `lib/app/app.dart` already existed; no change required. Quality gates passed.
- **Files touched**: `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Run/record full manual smoke tests on Android+iOS devices (Firebase-console checks for token removal/leakage), then merge PR after review.

## 2026-05-01 — Claude Code (Opus 4.7) — v1.1 roadmap + plan PR #1 (auth + account deletion flow)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `fix/auth-and-account-deletion-flow`
- **Goal**: Audit current state, lock the v1.1 architectural decisions, and write the spec for the first v1.1 PR (auth lifecycle + account deletion fixes).
- **Outcome**: Synthesized v1.1 roadmap covering 4 tester bugs (B1 FCM-after-logout, B2 notification language, B3 delete-account stuck, B4 theme persistence), 3 feature areas (F1 account settings, F2 attendance MVP, F3 task improvements with countdown/recurring/target sub-features). Locked 5 architectural decisions: (1) server-side notification localization driven by `users/{uid}.languageCode`; (2) account settings v1.1 scope = name + password only; (3) attendance MVP = timestamp + biometric (no location, defer privacy policy update); (4) recurring tasks via `isTemplate` boolean on existing `tasks` collection (not a separate collection); (5) adaptive screen-level countdown ticker (1Hz when any task <1h away, 1/min otherwise — no per-card timers). Audited `auth_cubit.dart` and `settings_screen.dart` for B1/B3 root causes: signOut() never clears FCM (Firestore + device); deleteAccount() relies on a passive auth listener that never explicitly fires + settings screen never resets `_isDeleting` on success. Wrote complete `CURRENT_TASK.md` spec (B1+B3 combined into PR #1) with affected files, expected flow changes, edge cases, 6 smoke tests, rollback considerations, DoD, and explicit workflow doc update plan. Seeded "v1.1 — testing-phase fixes and improvements" subsection in `BACKLOG.md` with PR #1 in progress and a list of upcoming entries.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #1 from `CURRENT_TASK.md`. Subsequent v1.1 PRs each get their own planning round before delegation. v1.1.0 release tag after task improvements ship; attendance MVP ships in v1.2.0.

## 2026-05-01 — GitHub Copilot (Claude Sonnet 4.6) — Implement Android release signing (PR B)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `chore/android-release-signing`
- **Goal**: Configure strict release signing in `android/app/build.gradle.kts` via `android/key.properties` (gitignored); update `docs/release-checklist.md` with a copy-pasteable `keytool` + `key.properties` template.
- **Outcome**: Three structural edits applied to `build.gradle.kts`: (1) `import java.util.Properties` / `import java.io.FileInputStream` + `keystorePropertiesFile`/`keystoreProperties` block above `plugins {}`; (2) `signingConfigs { create("release") { ... } }` with `keystorePropertiesFile.exists()` guard, inside `android {}`; (3) `buildTypes.release` uses `signingConfigs.getByName("release")` — TODO comment removed, debug-key fallback removed. `docs/release-checklist.md` updated with `keytool` command, `key.properties` template, and `flutter build appbundle --release` verification step. All 4 quality gates green. All 4 smoke tests green (release fails without `key.properties` ✓; throwaway-keystore signed AAB + `jarsigner -verify` ✓; iOS no-codesign ✓ 54.9 MB; git status clean ✓).
- **Files touched**: `android/app/build.gradle.kts`, `docs/release-checklist.md`, workflow docs.
- **Follow-ups**: PR B (#20) merged to `dev`. Owner must create `~/upload-keystore.jks` + `android/key.properties` before first Play Console upload (see `docs/release-checklist.md`).

## 2026-05-01 — GitHub Copilot (GPT-5.3-Codex) — Implement app icons pre-build polish (PR A)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/app-icons`
- **Goal**: Implement PR A by adding launcher icon generation config and regenerating Android/iOS launcher assets from the committed square master icon.
- **Outcome**: Added `flutter_launcher_icons: ^0.14.4` to `dev_dependencies`, added launcher config in `pubspec.yaml`, ran `flutter pub get` and `dart run flutter_launcher_icons`, regenerated Android mipmap icons and iOS app icon assets, and verified required file dimensions/hash changes. Quality gates passed: `flutter analyze`, `flutter test`, and `cd functions && npm run lint`.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/res/mipmap-*/ic_launcher.png`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, workflow docs.
- **Follow-ups**: PR A (#19) merged to `dev` on 2026-05-01.

## 2026-04-30 — GitHub Copilot (GPT-5.3-Codex) — Implement release-prep PR #5 (Crashlytics + bumps + release docs)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/release-readiness`
- **Goal**: Implement the final release-prep PR for v1.0.0 exactly as planned in `CURRENT_TASK.md`.
- **Outcome**: Added `firebase_crashlytics` and bumped the 5 Firebase Flutter packages by one minor each. Wired global Crashlytics handlers in `main.dart` and user identifier set/clear in `auth_cubit.dart`. Added `CHANGELOG.md` (Keep a Changelog format, v1.0.0 draft) and `docs/release-checklist.md`. Quality gates and verification commands passed. Manual smoke tests requiring real devices and Firebase console interaction were documented in the PR body.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `CHANGELOG.md`, `docs/release-checklist.md`, workflow docs.
- **Follow-ups**: Open PR to `dev`, reviewer to complete real-device smoke tests (including Crashlytics test-crash confirmation), then owner runs release flow (`dev -> main` PR, `v1.0.0` tag, operational checklist).

## 2026-04-30 — Claude Code (Opus 4.7) — Plan release-prep PR #5 (release readiness — Crashlytics + bumps + CHANGELOG)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/release-readiness`
- **Goal**: Lock scope for the final release-prep PR (Crashlytics, Firebase minor bumps, CHANGELOG, release checklist) before tagging v1.0.0.
- **Outcome**: Audited current error-handling surface (zero — no `FlutterError.onError`, no `PlatformDispatcher.onError`, no zoned guard), Firebase dep freshness (5 packages one minor behind, deltas confirmed), version (`1.0.0+1` — no bump needed for first build), absence of `CHANGELOG.md` and `docs/release-checklist.md`. Locked 6 product decisions: minimal Crashlytics (global handlers + user identifier only); exactly 5 Firebase Flutter minor bumps and nothing else; CHANGELOG drafted by implementing agent in Keep-a-Changelog format; standalone `docs/release-checklist.md`; version stays at `1.0.0+1`; iOS dSYM upload remains a documented manual Xcode step. Wrote `CURRENT_TASK.md` with file-by-file scope, exact dep-version deltas, exact main.dart/auth_cubit.dart additions, the CHANGELOG and release-checklist structures, 9 manual smoke tests (including the Crashlytics test crash), and risk + out-of-scope rails. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #5 from `CURRENT_TASK.md` on the existing `chore/release-readiness` branch. After PR #5 merges: open `dev → main` release PR (merge commit, not squash), tag `v1.0.0`, create GitHub Release, then run the operational items in the release checklist (Pages enablement, dSYM, signing, backups). Post-v1.0.0 product ideas explicitly deferred per the user.

## 2026-04-28 — Claude Code (Opus 4.7) — Plan release-prep PR #4 (account deletion + privacy)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/account-deletion-and-privacy`
- **Goal**: Lock scope for the largest release-prep PR (account deletion + privacy policy + About screen for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited Settings (93-line stateless screen, no Account section), routes (only `/settings` exists; need `/about`), Cloud Functions (7 existing exports; `createEmployeeUser` is the perfect template — admin SDK with auth check + HttpsError pattern), and dependencies (`cloud_functions` already wired; `package_info_plus` and `url_launcher` need to be added). Locked 6 product decisions: keep tasks of deleted users with `assignedByName`/`assignedToName` overwritten to `"Deleted user"`; simple AlertDialog confirmation; privacy policy drafted by implementing agent for user review on PR; About shows app name + version + privacy + licenses (no support email); approved both new dependencies; GitHub Pages from `main`/`/docs`. Wrote a comprehensive `CURRENT_TASK.md` covering 11 sections of file-by-file scope, exact translation values for 11 new keys (en + ar), 14 manual smoke tests, GitHub Pages enablement instructions for the user, and explicit risk + out-of-scope rails. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #4 from `CURRENT_TASK.md` on the existing `feat/account-deletion-and-privacy` branch. After merge: project owner enables GitHub Pages from `main`/`/docs` (one-time UI step) and replaces the placeholder support email in `docs/privacy-policy.md`.

## 2026-04-28 — GitHub Copilot (Claude Sonnet 4.6) — Implement account deletion, privacy policy, and About screen (PR #4)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/account-deletion-and-privacy`
- **Goal**: Implement the 5 surfaces in release-prep PR #4: Cloud Function `deleteUserAccount`, Settings Account section + delete flow, About screen, privacy policy, and 11 new translation keys.
- **Outcome**: All 5 surfaces implemented. `deleteUserAccount` callable atomically overwrites task display names, deletes notifications, deletes user doc, then deletes Auth account. Settings screen converted to StatefulWidget with Account section (About tile + Delete account tile with confirmation dialog). `AboutScreen` shows version via `package_info_plus` and opens privacy URL via `url_launcher`. `docs/privacy-policy.md` drafted with all 10 required sections. 11 translation keys added with parity (182 == 182 keys). All three quality gates green. Real-device smoke tests pending reviewer before merge.
- **Files touched**: `functions/index.js`, `pubspec.yaml`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `lib/features/settings/presentation/screens/about_screen.dart` (new), `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `docs/privacy-policy.md` (new), `assets/translations/en.json`, `assets/translations/ar.json`, workflow docs.
- **Follow-ups**: (1) Reviewer to run 14 manual smoke tests on real devices before merge. (2) Owner to enable GitHub Pages (repo Settings → Pages → `main` branch `/docs` folder) after PR #4 merges to `main`. (3) Owner to replace `support@example.com` in `docs/privacy-policy.md`.

## 2026-04-28 — GitHub Copilot (Claude Sonnet 4.6) — Implement notifications permission (PR #3)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/notifications-permission`
- **Goal**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to `AndroidManifest.xml` to fix silent FCM permission suppression on Android 13+.
- **Outcome**: Single manifest line inserted as first child of `<manifest>` before `<application>`. All three quality gates passed: `flutter analyze` → No issues found, `flutter test` → All tests passed, `npm --prefix functions run lint` → clean. Real-device Android 13+ smoke tests are pending reviewer verification before merge. PR opened to `dev`: `feat(notifications): add POST_NOTIFICATIONS for Android 13+`.
- **Files touched**: `android/app/src/main/AndroidManifest.xml`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Reviewer to run 7 smoke tests on a real Android 13+ device (see `CURRENT_TASK.md` §5) before merging. Next: PR #4 account deletion + privacy policy.

## 2026-04-28 — Claude Code (Opus 4.7) — Plan release-prep PR #3 (notifications permission)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/notifications-permission`
- **Goal**: Lock scope for release-prep PR #3 of 5 (Android 13+ POST_NOTIFICATIONS for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited the FCM setup. Discovered the runtime `FirebaseMessaging.requestPermission(...)` call already exists at `auth_cubit.dart:125` (inside `_setupFCM`, called after successful sign-in) — meaning iOS permission has been working all along. The Android 13+ failure is purely a missing `<uses-permission>` manifest declaration. PR collapses to one line in `AndroidManifest.xml`. Locked 3 product decisions: minimal scope (manifest only, no UX scope creep), placement at top of `<manifest>` before `<application>` per Android convention, real-device Android 13+ verification gate before merge. Wrote `CURRENT_TASK.md` capturing the spec, 7 manual smoke tests (3 must run on a real device — Android 13+ fresh install, deny path, regression checks), and out-of-scope rails.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #3 from `CURRENT_TASK.md` on the existing `feat/notifications-permission` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement release metadata fixes

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/release-metadata`
- **Goal**: Execute the metadata-only release-prep PR #2 with exactly five scoped edits and no changes under `lib/` or `functions/` code paths.
- **Outcome**: Updated `pubspec.yaml` description, replaced starter `README.md` with a concise project README, changed Android launcher label to `Techno Staff`, changed iOS `CFBundleName` to `Techno Staff`, and renamed `in_pending_tasks` to `pending_tasks` in `assets/translations/en.json`. Verification passed (`grep` result `0`), translation key parity remained `171 171 []`, and quality gates passed (`flutter analyze`, `flutter test`, `npm --prefix functions run lint`).
- **Files touched**: `pubspec.yaml`, `README.md`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `assets/translations/en.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Open PR to `dev` titled `chore(release): metadata fixes — description, README, app label, translation typo`.

## 2026-04-27 — Claude Code (Opus 4.7) — Plan release-prep PR #2 (release metadata)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/release-metadata`
- **Goal**: Lock scope and product decisions for release-prep PR #2 of 5 (metadata fixes for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited pubspec (default placeholder description), README (16 lines of Flutter starter content), `AndroidManifest.xml` (`android:label="techno_staff"` — visible on launcher), iOS `Info.plist` (`CFBundleName: techno_staff`, `CFBundleDisplayName: Techno Staff`), and the `in_pending_tasks` / `pending_tasks` translation key mismatch. Confirmed via grep that `in_pending_tasks` is orphaned in `en.json` — no code references it; `dashboard_pie_chart.dart` uses `pending_tasks` only. Locked 4 product decisions: concise README (~30 lines, no duplication of CLAUDE.md), iOS CFBundleName change to `Techno Staff` for consistency, real pubspec description, English key rename `in_pending_tasks` → `pending_tasks`. Wrote a complete file-by-file `CURRENT_TASK.md` with explicit "do NOT change" lines for `applicationId`, `PRODUCT_BUNDLE_IDENTIFIER`, `pubspec name`, and `version` (each easy to touch by accident with high blast radius). Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #2 from `CURRENT_TASK.md` on the existing `chore/release-metadata` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement strip debug logging

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/strip-debug-logging`
- **Goal**: Execute the mechanical release-prep cleanup by deleting all `debugPrint` calls under `lib/` without changing behavior.
- **Outcome**: Removed all 20 `debugPrint` calls from the 6 scoped files, updated now-unused `catch (e)` bindings to `catch (_)`, and removed now-unused `flutter/foundation.dart` imports. Verification command `grep -rn "debugPrint" lib | wc -l` returned `0`; quality gates passed (`flutter analyze`, `flutter test`, `cd functions && npm run lint`).
- **Files touched**: `lib/main.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/reports/data/repositories/reports_repository.dart`, `lib/features/reports/presentation/cubit/reports_cubit.dart`, `lib/features/reports/presentation/screens/reports_screen.dart`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Open PR to `dev` titled `chore(logging): strip debug logging before v1.0.0`.

## 2026-04-27 — Claude Code (Opus 4.7) — Release-readiness sweep + plan PR #1 (strip debug logging)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/strip-debug-logging`
- **Goal**: Run a release-readiness sweep for v1.0.0, agree a 5-PR breakdown, then plan the first PR (debug-log strip).
- **Outcome**: Audited TODO/FIXME (zero), `debugPrint` census (20 calls leaking FCM token + user IDs + task IDs to release logs), Flutter & Functions dep freshness (minor versions behind, major bumps deferred), app metadata (default pubspec description, default README, Android label is lowercase internal name, iOS display correct), permissions (Android 13+ `POST_NOTIFICATIONS` missing — release blocker), privacy surface (no privacy policy / no account deletion — both required by Apple/Google), translation parity (1 typo: `in_pending_tasks` vs `pending_tasks`). User accepted the 5-PR breakdown, locked Cloud Function for account deletion, GitHub Pages for privacy policy, Crashlytics + minor dep bumps in v1.0.0, additional checks A1/A5/A6/A8/A9. Wrote a complete file-by-file `CURRENT_TASK.md` for PR #1, added a `Release v1.0.0 readiness` section to `BACKLOG.md` listing all 5 PRs (PR #1 In progress, others Open), and logged two `DECISIONS_LOG.md` entries.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #1 from `CURRENT_TASK.md` on the existing `chore/strip-debug-logging` branch. PRs #2–#5 each get their own planning round before delegation.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement task search and filtering

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/task-search-and-filtering`
- **Goal**: Implement the approved client-side task search/filter/sort UX with global screen-level filter state and no cubit/state/repository changes.
- **Outcome**: Added the new `task_filter_bottom_sheet.dart` widget (`TaskFilters`, `TaskSortOption`, apply/cancel flow), integrated global local-state search/filter/sort in `tasks_screen.dart`, added active-filter indicators and distinct filtered-empty state, and added EN/AR localization keys. Quality gates passed (`flutter analyze`, `flutter test`, `functions` lint).
- **Files touched**: `lib/features/tasks/presentation/widgets/task_filter_bottom_sheet.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Execute full in-app manual smoke tests (16 scenarios) and review PR against `dev`.

## 2026-04-27 — Claude Code (Opus 4.7) — Plan task search and filtering

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/task-search-and-filtering`
- **Goal**: Lock scope, UX shape, and product decisions for the "Add task search and filtering" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited `TaskModel` (rich enough to filter on title, description, assignedToName, assignedByName, status, priority, dueDate, createdAt), `tasks_screen.dart` (346 lines — flagged extraction of a bottom-sheet widget as mandatory), `tasks_cubit.dart` / `tasks_state.dart` (no changes needed), and translation files (zero existing search/filter/sort keys). Pushed back on two BACKLOG defaults: filter state should be GLOBAL across tabs (not per-tab) for consistency, and the empty-results state should use a new `no_matching_tasks` key with a clear-filters hint (not reuse `no_tasks_found`). Locked 8 product decisions: search covers 4 fields including assignee names, filters limited to status + priority (assignee filter and date range deferred), 3 sort options, global filter state, local widget state (not in TasksState), bottom-sheet UI, badge dot indicator, distinct empty state. Wrote a complete file-by-file `CURRENT_TASK.md` spec with exact translation values for en + ar (13 new keys), 16 manual smoke tests, and DoD. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/task-search-and-filtering` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement task delete UI

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/task-delete-ui`
- **Goal**: Implement the approved delete UX for task creators/admins without expanding scope beyond client repository/cubit/UI and localization.
- **Outcome**: Added `deleteTask` repository + cubit methods, added delete AppBar action on task details with confirmation and mounted-safe async flow, added EN/AR translation keys, and kept scope boundaries intact (no rules/functions/task-log cleanup changes). Ran all three quality gates successfully.
- **Files touched**: `lib/features/tasks/data/repositories/tasks_repository.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Execute manual runtime smoke tests in app and review PR against `dev`.

## 2026-04-26 — Claude Code (Opus 4.7) — Plan task delete UI

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/task-delete-ui`
- **Goal**: Lock scope and product decisions for the "Add task delete UI for admins and creators" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited `task_details_screen.dart`, `tasks_repository.dart`, and `tasks_cubit.dart`. Confirmed the existing edit-icon AppBar pattern is the right blueprint and the rules already permit creator + admin delete (shipped in PR #6). Locked 5 product decisions: AppBar icon location, same gate as edit, confirmation dialog with task title interpolation, no notifications on delete, no `task_logs/` cleanup. Wrote a complete file-by-file `CURRENT_TASK.md` spec with exact translation values for en + ar (using `easy_localization` positional `{}` args), 7 manual smoke tests, and DoD. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/task-delete-ui` branch.

## 2026-04-26 — GitHub Copilot (GPT-5.4) — Implement admin task tabs

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feature/admin-task-tabs`
- **Goal**: Implement the approved admin tasks UX so admins can switch between their own assigned tasks and the full team task list without changing the employee flow.
- **Outcome**: Updated the admin tasks screen to fetch and render two task streams (`Assigned to me`, `All tasks`) using the same tab pattern as the employee view, refreshed both streams after admin inline status updates, added the required locale keys, and ran all three quality gates successfully.
- **Files touched**: `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Manual in-app smoke tests and PR creation remain the only external steps.

## 2026-04-26 — Claude Code (Opus 4.7) — Plan admin task tabs

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/admin-task-tabs`
- **Goal**: Lock scope and product decisions for the "Add admin task tabs (Assigned to me + All tasks)" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited current `tasks_screen.dart` admin path. Confirmed the cubit and state already expose everything needed (`fetchAllTasks`, `fetchTasksAssignedTo`, `state.tasks`, `state.tasksAssignedToMe`, per-tab status fields) — no state, repository, or rules changes required. Locked 3 product decisions (tab order, `all_tasks` label, `tasks_overview` subtitle). Wrote a complete file-by-file `CURRENT_TASK.md` spec with explicit Definition of Done, 7 manual smoke tests, and exact translation values for en + ar. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/admin-task-tabs` branch.

## 2026-04-24 — GitHub Copilot (GPT-5.3-Codex) — Implement employee task creation

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/employee-task-creation`
- **Goal**: Implement the approved scope to allow employees to create and assign tasks without changing architecture decisions.
- **Outcome**: Applied the approved `firestore.rules` diff, added `assignedBy` constants, extended task repository/cubit/state for assigned-vs-created task lists, added non-admin task tabs and universal task FAB, enabled any-user assignment (excluding self) in add-task flow, added localization keys in en/ar, and added state unit tests. Also resolved existing analyzer infos so quality gates are green.
- **Files touched**: `firestore.rules`, `lib/core/constants/firebase_paths.dart`, `lib/features/tasks/**`, `lib/features/employee/presentation/screens/employee_home_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `test/features/tasks/presentation/cubit/tasks_state_test.dart`, plus lint-only fixes in `lib/features/dashboard/**`, `lib/features/employees/**`, `lib/features/notifications/**`, and `lib/features/reports/**`.
- **Follow-ups**: Manual smoke tests from `CURRENT_TASK.md` still require runtime verification against Firebase users/devices.

## 2026-04-24 — Claude Code (Opus 4.7) — Plan employee task creation

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/employee-task-creation`
- **Goal**: Lock in scope, rules diff, and product decisions for the "Allow employees to create and assign tasks" backlog item, then hand off implementation to a separate agent.
- **Outcome**: Audited `firestore.rules`, `lib/features/tasks/`, `add_task_screen.dart`, and `functions/index.js`. Found the backend is ~80% already compatible with the feature. Locked in 5 product decisions (any-to-any assignment, relax `users` read, tabs for employee view, creator can delete, `assignedBy` immutable). Rewrote `CURRENT_TASK.md` as a full file-by-file implementation spec including the exact approved rules diff, scope, smoke tests, and DoD. Moved the `BACKLOG.md` item to "In progress". Implementation will be carried out by another agent against this branch.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md`.

## 2026-04-24 — Claude Code (Opus 4.7) — Bootstrap AI workflow docs

- **Agent**: Claude Code (Opus 4.7)
- **Branch**: `chore/ai-workflow-docs`
- **Goal**: Create `/docs/ai-workflow/` as the shared source of truth across AI agents and human developers. Remove the unused Spec Kit setup.
- **Outcome**: Created 7 workflow files (`PROJECT_CONTEXT.md`, `CURRENT_TASK.md`, `BACKLOG.md`, `DECISIONS_LOG.md`, `RULES.md`, `NEXT_STEPS.md`, `SESSION_LOG.md`). Migrated the ratified constitution v1.0.0 into `RULES.md` and extended it with git/commit conventions and an "agents must not do X without asking" list. Deleted `specs/`, `.specify/`, and the `speckit-*` skills under `.claude/skills/`. Added a pointer from `CLAUDE.md` to the new workflow folder.
- **Files touched**: `docs/ai-workflow/*.md` (new), `CLAUDE.md` (small addition), `specs/` (deleted), `.specify/` (deleted), `.claude/skills/speckit-*` (deleted).
- **Follow-ups**: Next task to be picked by the team. `BACKLOG.md` and `NEXT_STEPS.md` are intentionally empty and ready to fill with real work.
