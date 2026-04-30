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
- [ ] Enable GitHub Pages: repo Settings -> Pages -> Source: Deploy from a
      branch -> Branch: `main`, Folder: `/docs` -> Save. Confirm
      `https://odehmohamed.github.io/techno-staff/privacy-policy/` resolves.
- [ ] iOS Crashlytics dSYM upload: open `ios/Runner.xcworkspace` in Xcode,
      select the `Runner` target -> Build Phases -> add a Run Script Phase
      with the FlutterFire-recommended `upload-symbols` invocation, and add
      `$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` to its Input Files. Without
      this, iOS crashes are reported but stack traces are not symbolicated.
- [ ] Android signed release keystore: generate a keystore with `keytool`,
      place it at `android/app/upload-keystore.jks` (gitignored), create
      `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`,
      `keyPassword` (gitignored), and reference it from
      `android/app/build.gradle.kts` `signingConfigs.release`.
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
