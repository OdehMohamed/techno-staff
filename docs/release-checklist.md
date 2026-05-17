# Release Checklist

A repeatable checklist for cutting a Techno Staff release.

## Pre-merge to `main`

- [ ] All planned feature branches merged and validated.
- [ ] `flutter analyze`, `flutter test`, and `cd functions && npm run lint` all green.
- [ ] Manual regression smoke test on a real Android 13+ device and an iOS device:
      sign-in, task list (admin and employee tabs), create/edit/delete task,
      receive a push notification, About screen + privacy policy link, delete account.
- [ ] **Attendance smoke test** — employee check-in (biometric prompt, session recorded),
      check-out (duration shown), history screen; admin roster date-picker, correction
      sheet, attendance report with rate bar and worked/not-worked grouping.

## Configuration items (one-time per release setup)

> Items marked ✅ are already complete and do not need to be repeated.

- ✅ Create Firestore config doc for mandatory update gate: `config/app_settings`
  with fields `minimumAndroidVersion`, `minimumIosVersion`, `androidStoreUrl`, `iosStoreUrl`.
  Update the minimum version values after each binary release that breaks backward compatibility.
- ✅ Deploy initial Firestore rules (done via `firebase deploy --only firestore:rules`).
  Re-run this command only when `firestore.rules` changes in a release.
- ✅ Replace placeholder `support@example.com` in `docs/privacy-policy.md`.
- ✅ Enable GitHub Pages: Branch `main`, Folder `/docs`.
  URL: `https://odehmohamed.github.io/techno-staff/privacy-policy/`
- ✅ iOS Crashlytics dSYM upload script configured in Xcode Run Script Phase.
- ✅ **Android signed release keystore configured** — `android/key.properties` is in place.
  Skip keytool steps below if keystore is already generated.

  <details><summary>Keystore setup (first time only)</summary>

  1. Generate the upload keystore (run from anywhere — store it OUTSIDE the repo):

     ```
     keytool -genkey -v \
       -keystore ~/upload-keystore.jks \
       -keyalg RSA -keysize 2048 -validity 10000 \
       -alias upload
     ```

     `keytool` will prompt for: a store password, a key password, and a Distinguished
     Name (CN, OU, O, L, ST, C). Use any values; record the passwords in a password
     manager — losing them is unrecoverable.

  2. Create `android/key.properties` (gitignored — never commit):

     ```
     storePassword=<store-password-from-step-1>
     keyPassword=<key-password-from-step-1>
     keyAlias=upload
     storeFile=/Users/<your-username>/upload-keystore.jks
     ```

     `storeFile` must be an **absolute path** to the .jks from step 1.

  3. Verify by building a release App Bundle:

     ```
     flutter build appbundle --release
     ```

     Should complete successfully and produce a signed `.aab` at
     `build/app/outputs/bundle/release/app-release.aab`.

     If you get `keystore was tampered with, or password was incorrect` →
     password mismatch, re-check `key.properties`.
     If you get `Keystore file '/...jks' not found` → wrong path in
     `storeFile`.

  </details>

- [ ] iOS signing and provisioning: Apple Developer account, distribution
      certificate, App Store provisioning profile, configured in Xcode for
      the `Runner` target.
- [ ] Enable Firestore scheduled backups: Firebase console → Firestore →
      Backups → configure daily scheduled backup.

## Release flow

- [ ] Merge the release branch into `main` with a merge commit (not squash)
      so per-feature history remains traceable. PR title: `release: vX.Y.Z`.
      Body links the CHANGELOG entry.
- [ ] **Post-merge Firebase deploy** — required after any release that touches
      Cloud Functions, Firestore rules, or Firestore indexes:
      ```
      firebase deploy --only functions,firestore:rules,firestore:indexes
      ```
      Run this from the repo root after `main` is up to date.
- [ ] After merge, locally tag and push:
      ```
      git checkout main && git pull
      git tag -a vX.Y.Z -m "vX.Y.Z"
      git push origin vX.Y.Z
      ```
- [ ] Create a GitHub Release on the `vX.Y.Z` tag. Body = the matching
      CHANGELOG section.
- [ ] Update `config/app_settings` in Firestore console — bump
      `minimumAndroidVersion` / `minimumIosVersion` if this release contains
      breaking changes that require users to update (leave unchanged otherwise).
- [ ] Bump `pubspec.yaml` version for the next development cycle on `main`
      after the tag (e.g. `1.2.0+4` → `1.3.0+5`).

## Post-release verification

- [ ] Crashlytics console receives crashes from the production build (force a
      test crash on a debug build first to confirm wiring; production crashes
      should arrive within ~5 minutes).
- [ ] Push notifications received by at least one admin and one employee
      user on the production build.
- [ ] Attendance check-in/check-out works end-to-end on the production binary
      (biometric prompt → session recorded → history screen shows entry).
- [ ] `sendDailyAbsenceMarker` cron fires at 23:00 Jerusalem and creates
      `absent` docs for employees with no check-in (verify in Firestore console
      the following morning).
- [ ] Firestore scheduled backup ran successfully (check Firebase console).

## Store submission

**Choose one build path per release — Flutter-only or Shorebird binary:**

**Flutter-only (current default until Shorebird is adopted):**
- [ ] Android: `flutter build appbundle --release`, upload to Google Play
      Console internal track first, then production.
- [ ] iOS: `flutter build ipa --release`, upload to App Store Connect via
      Xcode or `xcrun altool`. TestFlight first, then App Store review.

**Shorebird binary (use once `shorebird_code_push` is in `pubspec.yaml`):**
- See "Shorebird store binary release" section below.

- [ ] Store listing metadata (descriptions, screenshots, keywords, support
      URL, privacy policy URL) populated in both consoles. Privacy URL must
      match the GitHub Pages address from above.

---

Items tracked in `docs/ai-workflow/BACKLOG.md` and `NEXT_STEPS.md`:
offline write-queue UX, late attendance status (schedule-aware v2),
sign-out-all-devices Settings action, performance tuning, `task_logs/`
cascade-delete, and major-version dependency bumps.

---

## Shorebird patch-eligibility checklist

Run this before every `shorebird patch`. A patch is only allowed when **all** of
the following are true. If any is false, do a full store binary release instead.

- [ ] No changes to `pubspec.yaml` or `pubspec.lock` (no new or changed packages).
- [ ] No changes to any native file: `.kt`, `.java`, `.swift`, `.m`, `*.gradle`,
      `Podfile`, `AndroidManifest.xml`, `Info.plist`, `GeneratedPluginRegistrant.*`.
- [ ] No changes to `firestore.rules` (deploy separately via
      `firebase deploy --only firestore:rules`).
- [ ] No changes to `functions/index.js` (deploy separately via
      `firebase deploy --only functions`).
- [ ] No new platform permissions or notification channel configuration.
- [ ] The `shorebird patch` CLI reports no native changes detected — confirm
      before proceeding.
- [ ] Change is limited to `.dart` source files, and optionally asset files
      (verify asset/translation patching works on your first Shorebird build —
      see `NEXT_STEPS.md`).

Patch commands (run from repo root):
```
shorebird patch android
shorebird patch ios          # macOS required
```

---

## Shorebird store binary release

Required whenever the patch-eligibility checklist above cannot be fully checked
(new package, native change, rules/functions change, `pubspec.yaml` change).
Also required for the **initial Shorebird adoption** (adding `shorebird_code_push`
to `pubspec.yaml` and rebuilding with the Shorebird engine).

- [ ] **iOS only — Xcode constraint:** in the "Distribute App" flow, ensure
      **"Manage Version and Build Number" is unchecked**. If Xcode manages the
      build number, it overwrites the version metadata Shorebird uses to target
      patches and users stop receiving them.
- [ ] Build with Shorebird CLI (replaces `flutter build`):
      ```
      shorebird release android
      shorebird release ios          # macOS required; produces an .xcarchive
      ```
- [ ] Upload the resulting archive to Google Play Console / App Store Connect
      via the normal submission flow.
- [ ] After store approval, decide whether to bump `config/app_settings`
      minimum version (force-update semantics via mandatory update gate) or
      leave the minimum unchanged (users receive the new binary on natural update).

### First-time Shorebird setup (one-time)

- [ ] Install Shorebird CLI: `curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash`
- [ ] Authenticate: `shorebird login`
- [ ] Add `shorebird_code_push` to `pubspec.yaml` under `dependencies`.
- [ ] Initialize in the repo: `shorebird init` (creates `shorebird.yaml`).
- [ ] On first Shorebird-enabled build, run FCM smoke test: airplane mode → send
      FCM message → restore connectivity. Confirm no ANR or background hang
      (known issue #695 is fixed but verify with your Firebase version).
- [ ] Verify Crashlytics patch tagging: add `ShorebirdUpdater().readCurrentPatch()`
      call in `main()` after Firebase init, set
      `FirebaseCrashlytics.instance.setCustomKey('shorebird_patch_number', ...)`.
- [ ] Verify asset/translation patching (see `NEXT_STEPS.md` "Shorebird asset
      patching" item) and record the result here.
