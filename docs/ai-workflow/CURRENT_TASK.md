# Current Task

> Last updated: 2026-04-30

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Release readiness — release-prep PR #5 of 5 for v1.0.0.**

The final release-prep PR before tagging v1.0.0. After this PR merges, the only remaining work is the `dev → main` release PR, the `v1.0.0` tag, and the operational steps captured in the release checklist this PR adds.

## Goal

Ship the operational and observability scaffolding the app needs to be safely runnable in production:

1. Add **Firebase Crashlytics** with global error handlers and per-user identification.
2. Bump the **5 outdated Firebase Flutter packages** by one minor version each.
3. Add a **`CHANGELOG.md`** capturing v1.0.0 features in Keep-a-Changelog format.
4. Add a **`docs/release-checklist.md`** capturing the operational steps the project owner runs around the v1.0.0 cut (Pages enablement, signing keystore, dSYM upload, Firestore backups, the release flow itself).

## Branch

`chore/release-readiness`, branched from `dev` after PR #14 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-30)

1. **Crashlytics scope** — minimal: global `FlutterError.onError` + `PlatformDispatcher.onError` + `setUserIdentifier` only. **No** per-catch breadcrumbs, **no** custom keys, **no** manual `recordError` calls in cubits.
2. **Dependency bumps** — exactly the 5 Firebase Flutter packages, one minor each. **No** transitive bumps, **no** non-Firebase deps, **no** major bumps.
3. **CHANGELOG drafted by implementing agent** based on the squash commits on `dev` since the start of this workflow. User reviews wording on the PR.
4. **Release checklist** lives at `docs/release-checklist.md` (standalone file, reusable as a template for future releases).
5. **Version unchanged** — `pubspec.yaml` stays at `1.0.0+1`. Build numbers increment on subsequent uploads for the same version name.
6. **iOS dSYM upload** is a manual one-time Xcode step captured in the release checklist; not automated in code.

## Scope — file-by-file

### 1. `pubspec.yaml`

Add one new dependency and bump five existing ones. Use `flutter pub add firebase_crashlytics` + manual constraint edits, do not hand-edit the `pubspec.lock` (it regenerates from `flutter pub get`).

**Add:**
```yaml
firebase_crashlytics: ^5.x.x   # latest stable major; agent picks the exact ^x.y from pub.dev
```

**Bump (exact targets):**
| Package | From | To |
|---|---|---|
| `cloud_firestore` | `^6.2.0` | `^6.3.0` |
| `cloud_functions` | `^6.1.0` | `^6.2.0` |
| `firebase_auth` | `^6.3.0` | `^6.4.0` |
| `firebase_core` | `^4.6.0` | `^4.7.0` |
| `firebase_messaging` | `^16.1.3` | `^16.2.0` |

After editing constraints, run `flutter pub get` to regenerate `pubspec.lock`.

**Do NOT** change: `name`, `version`, `description`, any other Flutter dependency, any `dev_dependencies`, any `functions/package.json`. Major-version bumps for `flutter_local_notifications` (20→21) and `flutter_lints` (5→6) remain deferred to v1.1.

### 2. `lib/main.dart`

Wire global error handlers immediately after `Firebase.initializeApp(...)` (currently line ~36) and before the `FirebaseMessaging.onBackgroundMessage(...)` call:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// inside main() — after `await Firebase.initializeApp(...)`:
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

`PlatformDispatcher` is exported from `package:flutter/material.dart` (re-exported from `dart:ui`), so no additional import is needed.

**Do NOT** add `runZonedGuarded` — the two handlers above cover Flutter framework errors and async errors that escape the framework. Adding a zoned guard layers complexity without value at the current scope.

### 3. `lib/features/auth/presentation/cubit/auth_cubit.dart`

Add Crashlytics user identification:

- After successful sign-in (inside `_setupFCM(uid)` — first line of the method body): `await FirebaseCrashlytics.instance.setUserIdentifier(uid);`
- Inside the existing sign-out method (locate via grep `signOut` in the file): `await FirebaseCrashlytics.instance.setUserIdentifier('');` before any state emission that clears the user.

Add the import:
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
```

**Do NOT** instrument any `try/catch` block in this file (or any other cubit) with `recordError` — out of scope. Unhandled errors that escape catches are caught by the global handlers from §2.

### 4. **NEW** — `CHANGELOG.md` at repo root

Draft a v1.0.0 entry following the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Source the items from the `dev` squash-merge commit history since the start of the workflow (`git log --oneline 643c659..HEAD` covers the v1.0.0 work; the agent infers categories from commit messages).

Required structure:

```
# Changelog

All notable changes to Techno Staff are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - YYYY-MM-DD

### Added
- (e.g.) Employee task creation with any-to-any assignment (PR #6)
- Admin task tabs: "Assigned to me" and "All tasks" (PR #8)
- Task delete UI for admins and creators (PR #9)
- Task search and filtering with a global filter state and bottom-sheet UX (PR #10)
- Account deletion via Cloud Function callable; Settings → Account section (PR #14)
- Privacy policy at `/docs/privacy-policy.md` and Settings → About screen (PR #14)
- POST_NOTIFICATIONS Android 13+ permission (PR #13)
- Firebase Crashlytics global error reporting (this PR)

### Changed
- Bilingual app surface using `easy_localization` (en, ar) with full RTL support
- Tasks screen now supports global search, filter, sort across role-specific tabs (PR #10)
- App display name standardized to "Techno Staff" across Android and iOS (PR #12)
- Bumped Firebase Flutter packages: cloud_firestore 6.3, cloud_functions 6.2, firebase_auth 6.4, firebase_core 4.7, firebase_messaging 16.2 (this PR)

### Fixed
- English chart legend rendering: rename `in_pending_tasks` → `pending_tasks` (PR #12)

### Security
- Removed all `debugPrint` calls from `lib/`, eliminating release-log leakage of FCM tokens, user IDs, and task metadata (PR #11)
- Tightened `firestore.rules` to require `assignedBy` immutability on task updates (PR #6)

[Unreleased]: https://github.com/OdehMohamed/techno-staff/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/OdehMohamed/techno-staff/releases/tag/v1.0.0
```

The above is a guide — the implementing agent fills in actual PR numbers from history and adjusts wording as needed. Date stays as `YYYY-MM-DD` placeholder; project owner replaces with the actual tag date when cutting the release.

### 5. **NEW** — `docs/release-checklist.md`

A reusable operational checklist for cutting a release. The implementing agent drafts this following the structure below.

```
# Release Checklist

A repeatable checklist for cutting a Techno Staff release. The first
target is **v1.0.0**.

## Pre-merge to `main`

- [ ] All planned PRs merged into `dev`.
- [ ] `flutter analyze`, `flutter test`, and `cd functions && npm run lint` all green on `dev`.
- [ ] Manual regression smoke test on a real Android 13+ device and an iOS device:
      sign-in, task list (admin and employee tabs), create/edit/delete task,
      receive a push notification, About screen + privacy policy link, delete
      account.

## Configuration items (one-time per release setup)

- [ ] Replace placeholder `support@example.com` in `docs/privacy-policy.md`
      with the team's real support address.
- [ ] Enable GitHub Pages — repo Settings → Pages → Source: "Deploy from a
      branch" → Branch: `main`, Folder: `/docs` → Save. Confirm
      `https://odehmohamed.github.io/techno-staff/privacy-policy/` resolves.
- [ ] iOS Crashlytics dSYM upload — open `ios/Runner.xcworkspace` in Xcode,
      select the `Runner` target → Build Phases → add a Run Script Phase
      with the FlutterFire-recommended `upload-symbols` invocation, and add
      `$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` to its Input Files. Without
      this, iOS crashes are reported but stack traces are not symbolicated.
- [ ] Android signed release keystore — generate a keystore with `keytool`,
      place it at `android/app/upload-keystore.jks` (gitignored), create
      `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`,
      `keyPassword` (gitignored), and reference it from
      `android/app/build.gradle.kts` `signingConfigs.release`.
- [ ] iOS signing & provisioning — Apple Developer account, distribution
      certificate, App Store provisioning profile, configured in Xcode for
      the `Runner` target.
- [ ] Enable Firestore scheduled backups — Firebase console → Firestore →
      Backups → configure daily scheduled backup.

## Release flow

- [ ] Open release PR `dev → main` titled `release: v1.0.0`. Body links the
      CHANGELOG entry.
- [ ] Use a **merge commit** (not squash) so per-feature history on `main`
      remains traceable.
- [ ] After merge, locally: `git checkout main && git pull`,
      `git tag -a v1.0.0 -m "v1.0.0"`, `git push origin v1.0.0`.
- [ ] Create a GitHub Release on the `v1.0.0` tag, body = the v1.0.0 section
      of `CHANGELOG.md`.
- [ ] Bump `pubspec.yaml` build number for the next build (`1.0.0+2`) on
      `dev` after the tag.

## Post-release verification

- [ ] Crashlytics console receives crashes from the production build (force a
      test crash on a debug build first to confirm wiring; production crashes
      should arrive within ~5 minutes).
- [ ] Push notifications received by at least one admin and one employee
      user on the production build.
- [ ] Firestore scheduled backup ran successfully (check Firebase console).

## Store submission

- [ ] Android — `flutter build appbundle --release`, upload to Google Play
      Console internal track first, then production.
- [ ] iOS — `flutter build ipa --release`, upload to App Store Connect via
      Xcode or `xcrun altool`. TestFlight first, then App Store review.
- [ ] Store listing metadata (descriptions, screenshots, keywords, support
      URL, privacy policy URL) populated in both consoles. Privacy URL must
      match the GitHub Pages address from above.

---

Items below are deferred for post-v1.0.0; tracked in `docs/ai-workflow/BACKLOG.md` deferred list:
offline UX hardening, performance tuning, app size analysis, full dark mode QA,
`task_logs/` cascade-delete, FCM notification on task delete, major-version
dependency bumps.
```

### 6. Translations

No new translation keys required. Verify by checking that no new user-facing strings appear in the diff. Translation parity must remain at `182 == 182` after this PR.

### 7. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append "Crashlytics + minor Firebase bumps + CHANGELOG + release checklist" recording the 6 product decisions and noting that v1.1 deferrals (offline UX, perf, app size, dark mode QA, major-version bumps) carry forward.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — update §2 Tech Stack: add `firebase_crashlytics` under Backend (Firebase); bump the listed minor versions for the 5 packages. Under §"Quality" or as a new bullet, mention `CHANGELOG.md` and `docs/release-checklist.md` as project artifacts.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "5. Release readiness — `chore/release-readiness`" from the `Should-fix` → "Release v1.0.0 readiness" subsection into `Done` → "Release v1.0.0 readiness" with completion date. The Should-fix "Release v1.0.0 readiness" subsection becomes empty (all 5 items done) — remove the empty subsection so the section reads `_None yet._` again.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder noting that v1.0.0 is ready for the `dev → main` release PR.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Verification step

- `grep -E "FlutterError.onError|PlatformDispatcher.instance.onError|setUserIdentifier" lib/main.dart lib/features/auth/presentation/cubit/auth_cubit.dart` returns at least 4 matches (2 in main.dart, 2 in auth_cubit.dart).
- `grep -E "firebase_crashlytics" pubspec.yaml` returns one match.
- `python3 -c "import json; en=set(json.load(open('assets/translations/en.json'))); ar=set(json.load(open('assets/translations/ar.json'))); print(len(en), len(ar), sorted(en^ar))"` returns `182 182 []`.
- `cat CHANGELOG.md | head -5` shows the Keep a Changelog header.
- `ls docs/release-checklist.md` exists.

## Manual smoke tests

These checks happen on real devices.

1. **App launches** without crashing after the dep bumps and Crashlytics wiring.
2. **Sign-in** still works (admin and employee). Inspect Crashlytics console: the test session should show a `userIdentifier` set.
3. **Sign-out** clears the Crashlytics userIdentifier.
4. **Test crash** — in a debug build, add a temporary button or use the Flutter inspector to trigger `FirebaseCrashlytics.instance.crash()`. Confirm the crash appears in the Firebase Crashlytics console within 5 minutes. **Remove the temporary trigger before opening the PR.**
5. **Notifications regression** (PR #3 baseline) — push notification still arrives on Android 13+ and iOS.
6. **Tasks regression** — admin tabs, employee tabs, search/filter, create/edit/delete all still work.
7. **Account deletion regression** (PR #14 baseline) — Settings → Delete account flow still works end-to-end.
8. **About screen regression** (PR #14 baseline) — version and privacy policy link still work.
9. **Localization** — Arabic locale still renders correctly with the new dep versions.

## Definition of Done

- [ ] `pubspec.yaml` adds `firebase_crashlytics` and bumps exactly the 5 Firebase packages by one minor each. No other dep changes.
- [ ] `lib/main.dart` has `FlutterError.onError` and `PlatformDispatcher.instance.onError` wired to Crashlytics, placed after `Firebase.initializeApp`.
- [ ] `auth_cubit.dart` calls `setUserIdentifier(uid)` after sign-in and `setUserIdentifier('')` on sign-out.
- [ ] `CHANGELOG.md` exists at repo root with v1.0.0 entry following Keep a Changelog format.
- [ ] `docs/release-checklist.md` exists and follows the structure above.
- [ ] No new translation keys; translation parity holds at `182 == 182`.
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All 9 manual smoke tests pass; Crashlytics test crash verified in console.
- [ ] `DECISIONS_LOG.md`, `PROJECT_CONTEXT.md`, `BACKLOG.md`, `SESSION_LOG.md` updated.
- [ ] `CURRENT_TASK.md` reset to a "No active task" placeholder.
- [ ] PR opened against `dev` titled `chore(release): add Crashlytics, bump Firebase deps, add CHANGELOG and release checklist`.

## Out of scope

- No `version:` bump in `pubspec.yaml` (stays at `1.0.0+1`).
- No major dep bumps (`firebase-admin`, `firebase-functions`, `eslint`, `flutter_local_notifications`, `flutter_lints`).
- No transitive non-Firebase minor bumps (e.g. `path_provider_android`, `characters`).
- No per-catch breadcrumbs, no custom Crashlytics keys, no `runZonedGuarded`.
- No `firebase_analytics`, no `firebase_performance`.
- No `firestore.rules` changes.
- No `functions/index.js` changes.
- No actual GitHub Pages enablement, signing keystore setup, dSYM Xcode script, or store metadata work — these are operational steps in the checklist that the project owner runs manually.
- No actual `dev → main` release PR or `v1.0.0` tag — that is a separate post-merge step.

## Risks

- **5 minor bumps + a new dep is the largest dep diff in the release series.** Each minor bump trusts the publisher's SemVer contract. A regression smoke pass is therefore mandatory before merging.
- **Crashlytics initialization order is sensitive.** It must run after `Firebase.initializeApp()` but before any code that could throw. The spec puts the handlers immediately after `Firebase.initializeApp`, before any other `FirebaseMessaging` calls.
- **`PlatformDispatcher.instance.onError` returning `true` swallows the error from the Flutter engine's perspective.** That is the documented FlutterFire pattern — Crashlytics records it, then we tell the engine "handled". Returning `false` would re-throw and likely crash the process. Spec specifies `return true`.
- **iOS without dSYM upload still records crashes** but with deobfuscated traces only — acceptable for v1.0.0 launch. The checklist captures the manual setup step.
- **Removing the test-crash trigger before merge** is critical. Smoke test #4 explicitly notes this.
