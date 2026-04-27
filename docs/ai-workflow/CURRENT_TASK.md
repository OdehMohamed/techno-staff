# Current Task

> Last updated: 2026-04-27

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Release metadata fixes — release-prep PR #2 of 5 for v1.0.0.**

The second of five small PRs preparing the app for v1.0.0 store submission. See `BACKLOG.md` → "Release v1.0.0 readiness" for the series.

## Goal

Fix release metadata so the app presents a coherent identity on both stores and in tooling: real description, real README, consistent user-facing app name, and a long-broken English translation key for the dashboard pie chart legend.

## Branch

`chore/release-metadata`, branched from `dev` after PR #11 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-27)

1. **README** — concise (~30 lines): short overview, tech stack list, basic setup commands, pointers to `CLAUDE.md` and `docs/ai-workflow/`. Must NOT duplicate `CLAUDE.md` or `PROJECT_CONTEXT.md` content.
2. **iOS `CFBundleName`** — change to `Techno Staff` for consistency with the existing `CFBundleDisplayName`.
3. **`pubspec.yaml` `description`** — set to:
   `Bilingual (en/ar) staff and task-management app for the Techno team — role-based, with Firebase Auth/Firestore/Functions and FCM-driven notifications.`
4. **Translation key fix** — rename `in_pending_tasks` → `pending_tasks` in `en.json`. The Arabic side already has the correct key (`pending_tasks`); the English side has a typo that causes the chart legend to render the literal `pending_tasks` key in English builds.

## Scope — file-by-file

### 1. `pubspec.yaml`
- Replace the `description:` value with the locked sentence in product decision #3.
- **Do NOT change** `name: techno_staff` — that is the Dart package name and is referenced in import paths throughout `lib/`.
- **Do NOT change** `version: 1.0.0+1` — version bumps happen at release time.

### 2. `README.md`
Replace the entire current content (the default Flutter starter) with a concise project README. Suggested structure (~30 lines total):

```
# Techno Staff

<one-paragraph description — see pubspec description for tone, expand
slightly to mention the two roles>

## Tech stack

- Flutter (Dart SDK ^3.9.2) — Android, iOS, Web
- flutter_bloc (Cubit pattern)
- easy_localization (en, ar)
- Firebase (Auth, Firestore, Cloud Functions, FCM)
- flutter_lints + ESLint (Google) for Cloud Functions

## Getting started

flutter pub get
flutter run

For Cloud Functions:

cd functions
npm install
npm run lint

## Project documentation

- CLAUDE.md — operational guide for AI and human contributors.
- docs/ai-workflow/ — shared workflow docs (project context, current task,
  backlog, decisions, rules, session log).

## Firebase project

`techno-staff` (see `.firebaserc` and `lib/firebase_options.dart`).
```

- Total length should be roughly 25–35 lines.
- Do NOT duplicate `CLAUDE.md` (commands, architecture, modules) or `docs/ai-workflow/PROJECT_CONTEXT.md` (modules table, Firestore data model, Cloud Functions).
- Do NOT add a license section (no LICENSE file in the repo today; out of scope).

### 3. `android/app/src/main/AndroidManifest.xml`
- Line 3: change `android:label="techno_staff"` → `android:label="Techno Staff"`. This is the launcher home-screen label users see.
- **Do NOT change** any `<uses-permission>` declarations (the `POST_NOTIFICATIONS` permission is the scope of PR #3 `feat/notifications-permission`, NOT this PR).

### 4. `ios/Runner/Info.plist`
- Change `<key>CFBundleName</key>` value from `techno_staff` → `Techno Staff` (mostly internal — Spotlight, About box on macOS — but kept consistent with `CFBundleDisplayName` which is already `Techno Staff`).
- **Do NOT change** `CFBundleDisplayName` (already correct).
- **Do NOT change** `CFBundleIdentifier` (uses `$(PRODUCT_BUNDLE_IDENTIFIER)` — store identity, must not move).
- **Do NOT change** `CFBundleShortVersionString` / `CFBundleVersion` (pulled from Flutter build settings — version bumps happen at release time).

### 5. `assets/translations/en.json`
- Rename the key `in_pending_tasks` to `pending_tasks`. The value `"Pending Tasks"` stays the same.
- Verification: after the rename, `grep -rn "in_pending_tasks" lib assets test | wc -l` should return `0`. The Arabic file (`ar.json`) is already correct and needs no change.
- Translation key parity must remain at 171 vs 171 between `en.json` and `ar.json`.

### 6. `android/app/build.gradle.kts`
- **Do NOT change** `applicationId = "com.mohamedodeh.technostaff"`. That is the Play Store unique identifier — changing it produces a different app and breaks anyone who has the existing build installed.

### 7. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append a short entry titled "Release metadata fixes for v1.0.0" recording the 5 changes (description, README, Android label, iOS CFBundleName, translation typo).
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — no changes expected; existing facts stay accurate.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Release metadata fixes — `chore/release-metadata`" out of the `Should-fix` → "Release v1.0.0 readiness" subsection into the `Done` → "Release v1.0.0 readiness" subsection with completion date. Keep the section grouping intact for the three remaining items (#3, #4, #5).
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Verification step

After all edits:
```
grep -rn "in_pending_tasks" lib assets test | wc -l
```
Expected output: **`0`**.

## Manual smoke tests

1. **Dashboard chart legend in English** → as admin, open the dashboard pie chart on a device set to English. The pending-tasks legend label should now read `Pending Tasks` (it currently shows the literal string `pending_tasks` because the key was orphaned).
2. **Dashboard chart legend in Arabic** → as admin on an Arabic device, the legend should still read `المهام المعلقة` (no regression).
3. **Android launcher label** → install the debug build on an Android device. The home-screen launcher label should read `Techno Staff` (currently `techno_staff`). A clean install (uninstall + reinstall) may be needed if the device is caching the previous label.
4. **iOS Spotlight / About** → after `flutter clean && flutter build ios`, the bundle's internal name should be `Techno Staff`. Display name on the home screen continues to read `Techno Staff` (no regression).
5. **README renders correctly** on GitHub.
6. **No regressions**: app boots, sign-in works, tasks list loads, no analyzer warnings.

## Definition of Done

- [ ] `pubspec.yaml` description updated; `name` and `version` unchanged.
- [ ] `README.md` rewritten (~25–35 lines), with pointers to `CLAUDE.md` and `docs/ai-workflow/`.
- [ ] `AndroidManifest.xml` `android:label` is `"Techno Staff"`.
- [ ] `ios/Runner/Info.plist` `CFBundleName` is `Techno Staff`.
- [ ] `en.json` key renamed: `in_pending_tasks` → `pending_tasks`.
- [ ] `grep -rn "in_pending_tasks" lib assets test | wc -l` returns `0`.
- [ ] Translation parity: `en.json` and `ar.json` both have 171 keys.
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `BACKLOG.md` item moved to Done within the Release v1.0.0 readiness section grouping.
- [ ] `SESSION_LOG.md` entry added.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `chore(release): metadata fixes — description, README, app label, translation typo`.

## Out of scope

- No code changes in `lib/` or `functions/` (this is metadata-only).
- No `firestore.rules` changes.
- No new dependencies.
- No `applicationId` or `PRODUCT_BUNDLE_IDENTIFIER` changes — these are store identities.
- No `pubspec.yaml` `name:` change — that is the Dart package name; renaming would break every `import 'package:techno_staff/...'` in the project.
- No `version:` bump — version moves in PR #5 / final release flow.
- No `POST_NOTIFICATIONS` permission — that is PR #3 `feat/notifications-permission`.
- No new translation keys; only the typo rename.
- No README content beyond the structure above (no full architecture overview, no Firebase setup walkthrough — those live in `CLAUDE.md` / `docs/ai-workflow/`).
