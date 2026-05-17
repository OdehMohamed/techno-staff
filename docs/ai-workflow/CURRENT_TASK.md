# Current Task

> No active task.

`fix/release-hardening` branch — release-hardening cycle complete through Phase 3. All changes are on this branch and committed. Phase 4 (Shorebird verification) is next before the binary release.

## Release-hardening summary (fix/release-hardening)

### Phase 1 — Source.server audit + FirebasePaths constants (done 2026-05-17)
- `GetOptions(source: Source.server)` applied to every Firestore `.get()` across all repositories (tasks, employees, reports, notifications, attendance, update-gate config, role check at auth time)
- All string literals for Firestore collection paths replaced with `FirebasePaths.*` constants
- `PROJECT_CONTEXT.md` fully rewritten to v1.2.0 state

### Phase 2 — FCM token isolation + security fixes (done 2026-05-17, deployed)
- FCM tokens moved from `users/{uid}.fcmToken` to `fcm_tokens/{uid}` collection (`allow read: if false`)
- All Cloud Functions updated to read via admin SDK (`getFcmToken` / `getFcmTokensBatch` helpers)
- `deleteUserAccount` cleans up `fcm_tokens/{uid}`
- `createEmployeeUser` rejects invalid `role` values at the callable layer
- `generateRecurringTaskInstances` alerts all admins via in-app notification on template errors
- `/* eslint-disable */` suppressor removed; ESLint now enforced by the real predeploy pipeline
- Deploy: `firestore:rules` first, then `functions` — both succeeded cleanly on 2026-05-17

### Phase 3 — Version bump + CHANGELOG (done 2026-05-17)
- `pubspec.yaml` version bumped: `1.1.0+3` → `1.2.0+4`
- `CHANGELOG.md`: v1.1.0 entry written, v1.2.0 entry written (attendance, FCM isolation, Source.server, ESLint, recurring templates, role validation), comparison links corrected for all versions

### Phase 4 — Shorebird asset-patching verification (pending)
- Manual test: build a translation-only patch and verify it lands on a physical device
- Document result (pass or fail) in `docs/release-checklist.md` under the Shorebird section
- This is a mandatory step before committing to the Shorebird release workflow
