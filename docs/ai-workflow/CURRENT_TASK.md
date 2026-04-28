# Current Task

> Last updated: 2026-04-28

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Notifications permission for Android 13+ — release-prep PR #3 of 5 for v1.0.0.**

The third of five small PRs preparing the app for v1.0.0 store submission. See `BACKLOG.md` → "Release v1.0.0 readiness" for the series.

## Goal

Make FCM notifications actually appear on Android 13+. The app already calls `FirebaseMessaging.requestPermission(...)` at runtime in `auth_cubit.dart` (`_setupFCM`), but Android 13+ silently no-ops that call unless the manifest declares `android.permission.POST_NOTIFICATIONS`. Add the declaration. That is the entire functional change.

## Branch

`feat/notifications-permission`, branched from `dev` after PR #12 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-28)

1. **Minimal scope.** Add only the manifest permission line. No `_setupFCM` change, no denied-state UX, no Crashlytics breadcrumbs, no iOS changes.
2. **Placement.** The `<uses-permission>` line goes at the **top of `<manifest>`**, before `<application>`, matching standard Android convention. There are no existing `<uses-permission>` declarations today.
3. **Verification gate.** A real-device test on Android 13+ is required before this PR can be marked complete. Emulator confirmation is not sufficient because some emulators auto-grant runtime permissions.

## Scope — file-by-file

### 1. `android/app/src/main/AndroidManifest.xml`

Add **one line** at the top of `<manifest>`, before `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

The expected diff is exactly one inserted line. No other manifest changes — do not touch `<application>`, `<activity>`, the `<queries>` block, or the `flutterEmbedding` meta-data.

### 2. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append a short entry titled "Add POST_NOTIFICATIONS for Android 13+" recording: manifest declaration added; runtime call was already in place in `_setupFCM`; denied-state UX intentionally deferred.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — no changes expected.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Notifications permission for Android 13+ — `feat/notifications-permission`" out of the `Should-fix` → "Release v1.0.0 readiness" subsection into the `Done` → "Release v1.0.0 readiness" subsection with completion date. Keep the section grouping intact for the two remaining items (#4, #5).
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session, including the real-device smoke-test outcome.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Manual smoke tests

These checks must happen on real devices, not just emulators.

1. **Android 13+ fresh install** (REQUIRED): wipe the app data or uninstall, then install the debug build, sign in, and observe the system runtime permission prompt for notifications. Tap "Allow".
2. **FCM push lands**: trigger a real task assignment (admin assigns a task to the test user) and confirm the notification appears in the system tray.
3. **Tap-through**: tap the notification → app opens to the task details screen for the correct task ID.
4. **Android 13+ deny path**: on a second test install, deny the prompt. Verify the app continues to function (sign-in succeeds, lists load) — only the system tray notifications are missing. No crashes.
5. **Android 12 or older regression**: install on an Android 12 device or emulator; the permission auto-grants without a prompt, and notifications still arrive.
6. **iOS regression**: install on an iOS device; the existing iOS permission prompt still shows on first sign-in, and notifications still arrive.
7. **`flutter analyze` / `flutter test` / `functions/` lint all green.**

## Definition of Done

- [ ] `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` added at the top of `AndroidManifest.xml`, before `<application>`.
- [ ] Diff is exactly one inserted line in the manifest.
- [ ] No changes to `_setupFCM` or any other Dart code.
- [ ] No iOS changes.
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] Manual smoke tests 1–6 pass on the appropriate devices (Android 13+ device test is mandatory before merge approval).
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `BACKLOG.md` item moved to Done within the Release v1.0.0 readiness section grouping.
- [ ] `SESSION_LOG.md` entry added (note the Android 13+ real-device verification outcome).
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `feat(notifications): add POST_NOTIFICATIONS for Android 13+`.

## Out of scope

- No changes to `lib/` (the runtime `requestPermission(...)` call is already correct).
- No changes to `functions/index.js`.
- No `firestore.rules` changes.
- No new dependencies.
- No iOS changes — `requestPermission()` already works on iOS.
- No denied-state UX (no snackbar, no "Open Settings" button, no in-app banner) — defer to a follow-up backlog item if desired.
- No Crashlytics integration — that is PR #5 (`chore/release-readiness`).
- No other manifest changes (icon, label, queries, activity attributes).
- No `targetSdk` / `minSdk` / `compileSdk` changes.
