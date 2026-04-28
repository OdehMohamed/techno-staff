# Current Task

> Last updated: 2026-04-28

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Account deletion + privacy policy — release-prep PR #4 of 5 for v1.0.0.**

The fourth and largest of the five release-prep PRs. Required by Apple App Store (since 2022) and Google Play (since 2024). See `BACKLOG.md` → "Release v1.0.0 readiness" for the series.

## Goal

Make the app submission-ready by giving every user a way to delete their account and read a privacy policy. Specifically:

- A Cloud Function callable that atomically deletes the caller's Firestore data and Firebase Auth account.
- A "Delete account" flow in Settings with a confirmation dialog.
- A privacy policy hosted on GitHub Pages.
- A Settings → About screen showing app version, privacy policy link, and open-source licenses.

## Branch

`feat/account-deletion-and-privacy`, branched from `dev` after PR #13 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-28)

1. **Tasks the deleted user touched are kept**, with their displayed names overwritten with the literal string `"Deleted user"` (English-only marker for v1; localizing the marker is a follow-up if anyone asks). `assignedBy` and `assignedTo` UIDs stay intact for traceability so an admin can later reassign or delete.
2. **Confirmation is a simple AlertDialog** (Cancel + Delete, destructive-styled). No type-to-confirm.
3. **Privacy policy is drafted by the implementing agent**; user reviews wording on the PR before merge.
4. **About screen** shows: app name, version, privacy-policy link, and an `Open-source licenses` entry (Flutter's built-in `showLicensePage()`). No support-contact email in v1.
5. **Two new dependencies approved**: `package_info_plus` (version display) and `url_launcher` (open privacy URL). Both Flutter team official plugins.
6. **GitHub Pages is served from `main` branch, `/docs` folder.** Privacy policy file lives at `docs/privacy-policy.md`. URL: `https://odehmohamed.github.io/techno-staff/privacy-policy/`.

## Scope — file-by-file

### 1. **NEW** — `functions/index.js` export `deleteUserAccount`

Add a callable function modeled on the existing `createEmployeeUser`:

- Authentication: reject if `request.auth` is null with `HttpsError("unauthenticated", ...)`.
- Derive uid: `const uid = request.auth.uid;` — **do not accept a uid input parameter**. A user can only delete themselves.
- Operations, in order, with proper error handling:
  1. `tasks` where `assignedBy == uid` → batched `update({ assignedByName: "Deleted user" })`. Use Firestore batched writes (max 500 ops per batch; chunk if necessary).
  2. `tasks` where `assignedTo == uid` → batched `update({ assignedToName: "Deleted user" })`.
  3. `notifications` where `userId == uid` → batched `delete()`.
  4. `users/{uid}` → `delete()`.
  5. `admin.auth().deleteUser(uid)`.
- The Auth deletion is the last step. If steps 1–4 succeed but step 5 fails, throw `HttpsError("internal", ...)`. The user can retry; subsequent calls will be idempotent because steps 1–4 have already happened (the queries return no documents the second time).
- Return `{ success: true }`.
- Region: default (no explicit region — match existing functions).
- **Do NOT** delete or modify `task_logs/` documents (audit trail).
- **Do NOT** touch `firestore.rules` — the admin SDK in Cloud Functions bypasses rules.

### 2. `pubspec.yaml`

Add two dependencies (use `flutter pub add`, do not hand-edit):

- `package_info_plus` (latest stable major — currently `^8.x`)
- `url_launcher` (latest stable major — currently `^6.x`)

**Do NOT** change other dependency versions. **Do NOT** change `name`, `version`, or `description`.

### 3. `lib/features/auth/presentation/cubit/auth_cubit.dart`

Add a `Future<void> deleteAccount()` method:

- Calls `FirebaseFunctions.instance.httpsCallable('deleteUserAccount').call()`.
- On success: do nothing further — the existing Firebase Auth state listener will catch the user becoming null and route to login automatically.
- On `FirebaseFunctionsException` or generic `Exception`: emit an error state so the UI can show a snackbar with key `failed_to_delete_account`. Re-throw so the caller can also handle if needed.
- Add a method-level guard: `if (state.user == null) return;` (do not attempt deletion when not signed in).

### 4. `lib/features/settings/presentation/screens/settings_screen.dart`

Convert from `StatelessWidget` to `StatefulWidget` (need local loading state).

Add a new "Account" section at the bottom of the existing `ListView`:

- A `SectionHeader`-style label `'account'.tr()`.
- A `ListTile` (inside a `Card`) with `Icons.info_outline`, title `'about'.tr()`, that pushes `RouteNames.about` on tap.
- A `ListTile` with `Icons.delete_forever` (red `colorScheme.error`), title `'delete_account'.tr()` styled red, that triggers the delete flow.

Delete flow:
1. `showDialog<bool>(builder: AlertDialog(...))` — title `'delete_account_confirm_title'.tr()`, content `'delete_account_confirm_message'.tr()`, "Cancel" returns `false`, "Delete" (red) returns `true`.
2. `if (!context.mounted) return;` after the dialog awaits.
3. If confirmed, set local loading state (disable the tile and show a small spinner), then `await context.read<AuthCubit>().deleteAccount()`.
4. On success: the auth listener takes over — no extra UI work in this method. Optionally show a fleeting `SnackBar('account_deleted'.tr())` before sign-out routes away.
5. On `Exception`: clear loading state, show `SnackBar('failed_to_delete_account'.tr())`, stay on Settings.

Use `if (!context.mounted) return;` after every `await` boundary in the handler — `flutter_lints` enforces `use_build_context_synchronously`.

### 5. **NEW** — `lib/features/settings/presentation/screens/about_screen.dart`

Stateful widget. Loads the package info in `initState`.

Layout:
- AppBar title: `'about'.tr()`.
- Scrollable body with:
  - App icon (use `assets/images/logo.png` — already an asset).
  - App name "Techno Staff" (literal, not translated — it is the brand name).
  - Version line: `'app_version'.tr()` + ' ' + `packageInfo.version` + ' (' + `packageInfo.buildNumber` + ')'`.
  - `Divider`.
  - `ListTile` "Privacy policy" with `Icons.privacy_tip_outlined`, on tap calls `url_launcher` `launchUrl(Uri.parse('https://odehmohamed.github.io/techno-staff/privacy-policy/'), mode: LaunchMode.externalApplication)`. Failure → snackbar with `'failed_to_open_link'.tr()`.
  - `ListTile` "Open-source licenses" with `Icons.description_outlined`, on tap calls `showLicensePage(context: context, applicationName: 'Techno Staff', applicationVersion: packageInfo.version)`.

### 6. `lib/core/routes/route_names.dart`

Add: `static const String about = '/about';`.

### 7. `lib/core/routes/app_router.dart`

Add a `case RouteNames.about:` returning `MaterialPageRoute(builder: (_) => const AboutScreen())`. Import the new screen.

### 8. **NEW** — `docs/privacy-policy.md`

The implementing agent drafts a standard privacy policy in **English**. Required sections (Markdown headings):

1. **Introduction** — who runs the service (Techno team), what the document is.
2. **Data we collect** — email, name, role (admin/employee), `isActive`, FCM token, tasks (title/description/dates/status/priority), notifications. Cover both data the user provides and data automatically collected (FCM token, timestamps).
3. **How we use the data** — task assignment, notifications, basic analytics implied by Firebase usage.
4. **Where data is stored** — Firebase project `techno-staff` (Auth, Firestore, Cloud Functions, FCM). Hosted by Google Cloud. Region per Firebase project default.
5. **Retention** — data is retained until the user deletes their account. Tasks the user created or was assigned to may persist for the team's audit trail with the user's display name replaced by "Deleted user".
6. **Sharing with third parties** — only with Firebase / Google as the infrastructure provider. No marketing partners.
7. **Your rights** — access, correction, deletion. Deletion is self-service via Settings → Account → Delete account; describe the steps.
8. **Contact** — placeholder email `support@example.com` (the implementing agent flags this in the PR body so the project owner replaces before publishing).
9. **Children's data** — not intended for users under 16; if you discover one, contact us.
10. **Changes to this policy** — last updated date; users will see updates on next sign-in.
11. **Last updated** — 2026-04-28.

Aim for ~250–400 words, plain Markdown, no fancy styling. The document does not need to be a legal masterpiece for v1.0.0 — accurate and complete is enough.

### 9. Translations (10 new keys, both locales)

Add to **`assets/translations/en.json`** and **`assets/translations/ar.json`**. Verify each does not already exist before adding (grep first).

| Key | EN | AR |
|---|---|---|
| `account` | "Account" | "الحساب" |
| `delete_account` | "Delete account" | "حذف الحساب" |
| `delete_account_confirm_title` | "Delete account?" | "حذف الحساب؟" |
| `delete_account_confirm_message` | "This permanently deletes your account and removes your personal data from Techno Staff. Tasks you created or are assigned to remain visible to the team but show your name as 'Deleted user'. This action cannot be undone." | "سيتم حذف حسابك وبياناتك الشخصية من تطبيق Techno Staff نهائياً. ستبقى المهام التي أنشأتها أو المُسندة إليك مرئية للفريق ولكن سيظهر اسمك كـ 'مستخدم محذوف'. لا يمكن التراجع عن هذا الإجراء." |
| `account_deleted` | "Account deleted" | "تم حذف الحساب" |
| `failed_to_delete_account` | "Failed to delete account" | "فشل في حذف الحساب" |
| `about` | "About" | "حول" |
| `app_version` | "Version" | "الإصدار" |
| `privacy_policy` | "Privacy policy" | "سياسة الخصوصية" |
| `open_source_licenses` | "Open-source licenses" | "تراخيص المصادر المفتوحة" |
| `failed_to_open_link` | "Could not open link" | "تعذر فتح الرابط" |

That is 11 keys (one helper key for the link-launch failure state). Translation parity must remain even at the end.

### 10. GitHub Pages enablement (manual, documented in PR body)

The implementing agent **does not configure Pages** (it is a repo Settings UI step). Instead, the PR body lists the steps for the user:

1. Repo Settings → Pages.
2. Source: "Deploy from a branch".
3. Branch: `main`, folder: `/docs`.
4. Save.
5. Wait ~1–2 minutes; visit `https://odehmohamed.github.io/techno-staff/privacy-policy/`.

Mention in the PR body that the privacy policy URL inside the app **will not work until the user enables Pages** — this is intentional and acceptable because Pages enablement is one-time and outside the code repo.

### 11. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append "Account deletion + privacy policy for v1.0.0" recording: Cloud Function approach, task-name overwrite vs delete, confirmation strength, GitHub Pages source folder, the placeholder support email pending.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — small additions: under §6 Cloud Functions, add the new `deleteUserAccount` row; under §4 Modules, note the About screen under `settings`.
- **`docs/ai-workflow/RULES.md`** — no changes.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Account deletion + privacy policy — `feat/account-deletion-and-privacy`" from `Should-fix` → "Release v1.0.0 readiness" → 4 into `Done` → "Release v1.0.0 readiness" with completion date. Keep the section grouping intact for the remaining item (#5).
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green.

Special gate for this PR (because of the iOS plugin add):
- After `flutter pub get`, run `cd ios && pod install` if the iOS pods cache prompts for it.

## Manual smoke tests

These checks happen on real devices.

### Account deletion flow (in this exact order — destructive)
1. Create a fresh test employee account. Sign in with it.
2. As that user, create a task assigned to another user (call it `taskA`).
3. As another user (admin), create a task assigned to the test user (call it `taskB`).
4. Confirm both tasks are visible to the test user.
5. As the test user, open Settings → tap **Delete account** → tap **Cancel** in the dialog → confirm nothing happens (still signed in, account intact).
6. Repeat — tap **Delete** in the dialog. Observe a brief snackbar `account_deleted` (optional) before the app routes to the login screen because Auth state changed.
7. Try to sign in again with the same email/password — sign-in should fail (account is gone).
8. As admin (or in Firebase console), confirm:
   - `users/{deletedUid}` is gone.
   - All `notifications` for that uid are gone.
   - `taskA` (created by deleted user) still exists; `assignedByName` is now `"Deleted user"`; `assignedBy` UID is unchanged.
   - `taskB` (assigned to deleted user) still exists; `assignedToName` is now `"Deleted user"`; `assignedTo` UID is unchanged.
   - Firebase Auth: the user is gone.
   - `task_logs/` entries are still present (untouched).

### About screen
9. Sign in (any account) → Settings → tap **About** → see app name, version (matches `pubspec.yaml`), privacy policy link, open-source licenses link.
10. Tap **Privacy policy** → device browser opens to `https://odehmohamed.github.io/techno-staff/privacy-policy/`. (Will 404 until you enable Pages — that is expected and noted in the PR.)
11. Tap **Open-source licenses** → Flutter's built-in license page renders.
12. Switch device locale to Arabic → re-open About; labels translate correctly. RTL layout reads correctly.

### Regression checks
13. Existing flows still work: sign-in, sign-out, task list (admin tabs and employee tabs), task create / edit / delete, status update, FCM notifications.
14. `flutter analyze` / `flutter test` / `functions/` lint all green.

## Definition of Done

- [ ] `functions/index.js` has `deleteUserAccount` callable, modelled on `createEmployeeUser`, that updates task names, deletes notifications + user doc, and deletes the Auth user.
- [ ] `pubspec.yaml` has `package_info_plus` and `url_launcher`. No other dependency / version changes.
- [ ] `AuthCubit.deleteAccount()` exists and is wired to the Cloud Function.
- [ ] `SettingsScreen` has an Account section with About + Delete account entries.
- [ ] Confirmation dialog shows the locked title/message; Cancel + destructive-styled Delete.
- [ ] `AboutScreen` renders app name, version, privacy link, open-source licenses link.
- [ ] `RouteNames.about` and `AppRouter` cover the new route.
- [ ] `docs/privacy-policy.md` exists with all 11 required sections.
- [ ] All 11 translation keys exist in both `en.json` and `ar.json`. Translation parity preserved (count en == count ar; symmetric difference empty).
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [ ] `DECISIONS_LOG.md`, `PROJECT_CONTEXT.md`, `BACKLOG.md`, `SESSION_LOG.md` updated.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `feat(account): add account deletion, privacy policy, and About screen`. PR body lists the GitHub Pages enablement steps and flags the placeholder support email for the user to replace.

## Out of scope

- No `firestore.rules` changes (admin SDK bypasses rules).
- No FCM notification on account deletion.
- No GDPR-style data export.
- No type-to-confirm two-step UX.
- No support-contact email in About (only privacy + licenses).
- No Crashlytics breadcrumbs around the delete flow — that is PR #5.
- No localization of the `"Deleted user"` task marker (literal English for v1; follow-up if requested).
- No `task_logs/` cascade-delete or modification — audit trail preserved.
- No major-version dependency bumps (only the two specified additions).
- No `pubspec.yaml` `name` / `version` / `description` changes.
- No new top-level folders other than the existing `docs/` (the privacy markdown lives there).

## Risks

- **Pages enablement is a manual step** outside the code. The privacy URL in the app will be a 404 until the project owner enables Pages — this is the only post-merge step required and is documented in the PR body.
- **Deletion is irreversible.** Smoke tests must use throwaway test accounts.
- **Cloud Function timeout** is 60 seconds by default. For test accounts with a handful of tasks/notifications this is fine. If a real account ever has thousands of records, batching as specified handles 500 per batch and a single function invocation can do 5+ batches in 60s. Documented but not currently a concern.
- **`url_launcher` on iOS** requires `LSApplicationQueriesSchemes` if launching specific schemes; for `https` URLs no entitlement is needed.
- **`package_info_plus` on iOS** sometimes requires `pod install` after `flutter pub get`. The implementing agent runs it if prompted.
