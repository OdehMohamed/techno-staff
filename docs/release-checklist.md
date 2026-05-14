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

- [ ] Create Firestore config doc for mandatory update gate: `config/app_settings`
      with fields `minimumAndroidVersion`, `minimumIosVersion`,
      `androidStoreUrl`, `iosStoreUrl`.
- [ ] Deploy Firestore rules after update-gate changes:

      ```
      firebase deploy --only firestore:rules
      ```

- [ ] Replace placeholder `support@example.com` in `docs/privacy-policy.md`
      with the team's real support address.
- [ ] Enable GitHub Pages: repo Settings -> Pages -> Source: Deploy from a
      branch -> Branch: `main`, Folder: `/docs` -> Save. Confirm
      `https://odehmohamed.github.io/techno-staff/privacy-policy/` resolves.
- [ ] iOS Crashlytics dSYM upload: open `ios/Runner.xcworkspace` in Xcode,
      select the `Runner` target -> Build Phases -> add a Run Script Phase
      with the FlutterFire-recommended `upload-symbols` invocation, and add
      `$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` to its Input Files. Without
      this, iOS crashes are reported but stack traces are not symbolicated.
- [ ] **Configure Android signed release keystore (one-time per project owner)** —
      Required before any `flutter build appbundle --release` or upload to Play
      Console. Skip this if the keystore is already generated and `android/key.properties`
      is in place.
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

- [ ] iOS signing and provisioning: Apple Developer account, distribution
      certificate, App Store provisioning profile, configured in Xcode for
      the `Runner` target.
- [ ] Enable Firestore scheduled backups: Firebase console -> Firestore ->
      Backups -> configure daily scheduled backup.

## Release flow

- [ ] Open release PR `dev -> main` titled `release: v1.0.0`. Body links the
      CHANGELOG entry.
- [ ] Use a merge commit (not squash) so per-feature history on `main`
      remains traceable.
- [ ] After merge, locally: `git checkout main && git pull`,
      `git tag -a v1.0.0 -m "v1.0.0"`, `git push origin v1.0.0`.
- [ ] Create a GitHub Release on the `v1.0.0` tag. Body = the v1.0.0 section
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

- [ ] Android: `flutter build appbundle --release`, upload to Google Play
      Console internal track first, then production.
- [ ] iOS: `flutter build ipa --release`, upload to App Store Connect via
      Xcode or `xcrun altool`. TestFlight first, then App Store review.
- [ ] Store listing metadata (descriptions, screenshots, keywords, support
      URL, privacy policy URL) populated in both consoles. Privacy URL must
      match the GitHub Pages address from above.

---

Items below are deferred for post-v1.0.0 and tracked in
`docs/ai-workflow/BACKLOG.md`: offline UX hardening, performance tuning, app
size analysis, full dark mode QA, `task_logs/` cascade-delete, FCM notification
on task delete, and major-version dependency bumps.
