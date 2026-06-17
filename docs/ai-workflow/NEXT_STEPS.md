# Next Steps

> Last updated: 2026-06-17
> This file captures forward-looking ideas — things we might want to do next but have not yet committed to. When we commit to an item, promote it into `BACKLOG.md` with a priority.

Sections are intentionally left empty. Add ideas as they come up in discussions or during implementation; do not speculate. One-liners are fine; expand only when we are close to acting on an idea.

---

## How to add an idea

```
### <short title>

- **Category**: Engineering | Architecture | UI/UX | Security | Testing | Release | Other
- **Why now**: (optional) what triggered the thought
- **Sketch**: one or two lines on what the change would be
- **Open questions**: what we still need to decide before promoting it to the backlog
```

When an idea graduates to real work, move it to `BACKLOG.md` and remove it from here.

---

## Recommended Next Steps

1. **Owner action: upload v1.5.0+8 store binaries** — iOS: upload `build/ios/ipa/*.ipa` via Transporter or `xcrun altool`. Android: upload `build/app/outputs/bundle/release/app-release.aab` via Play Console. No Firebase deploy required for this release (no CF/rules/indexes changes).
2. **Chat Phase 2** — three sub-items in order: (a) Employees quick-action (S), (b) task-linked conversations (M, design round first), (c) group member management (M, design round first). See Features section below.

---

## Infrastructure / Platform

### ✅ FlutterFire upgrade → Shorebird iOS — CLOSED (2026-06-17)

Root cause: `FLTPipelineParser.m` in cloud_firestore 6.3.0 called `FIRCollectionSourceStageBridge initWithRef:firestore:` (2-arg), but firebase-ios-sdk 12.14.0 changed it to `initWithRef:firestore:forceIndex:` (3-arg). Shorebird's SPM resolved `from: "12.12.0"` to 12.14.0; CocoaPods pinned to exactly 12.12.0, so local builds worked and Shorebird builds failed.

Fix: upgraded all FlutterFire packages to their latest minor/patch within existing `^` constraints (cloud_firestore 6.5.0, firebase_core 4.10.0, firebase_auth 6.5.2, firebase_crashlytics 5.2.3, firebase_messaging 16.3.0, cloud_functions 6.3.2). Deleted `Podfile.lock` + ran `pod repo update` to re-resolve CocoaPods to Firebase 12.14.0. Both `shorebird release ios` and `shorebird release android` succeeded for v1.5.0+8. Branch: `chore/flutterfire-upgrade`.

### ✅ Shorebird asset/translation patching — CLOSED (2026-06-16)

Result: **NOT supported.** Shorebird explicitly excludes `assets/translations/*.json` from patches and prints a warning. Tested on v1.4.0+7 Android baseline. Result recorded in `docs/release-checklist.md`.

**Implication for all future work:** Any PR that adds or changes translation keys is a full binary store release, never a Shorebird patch. This includes Chat Phase 2, which will add ~10–15 new EN/AR keys — Chat Phase 2 requires a store binary regardless of Dart patch eligibility.

### Android Gradle / AGP / Kotlin version deprecation warnings

- **Category**: Engineering / Release
- **Why now**: `shorebird release android` for v1.5.0+8 printed deprecation warnings: Gradle 8.12.0 → needs 8.14.0+; AGP 8.9.1 → needs 8.11.1+; Kotlin 2.1.0 → needs 2.2.20+. These are warnings now but will become errors in a future Flutter version.
- **Sketch**: Update `android/gradle/wrapper/gradle-wrapper.properties` (Gradle), `android/settings.gradle` AGP plugin version, and KGP version. Flutter docs: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
- **Open questions**: Whether Chat Phase 2 is a good opportunity to bundle this (both require a full binary release anyway). No urgency — current builds succeed.

### Local Flutter version alignment with Shorebird

- **Category**: Engineering / Release
- **Why now**: Local Flutter is 3.35.7; Shorebird bundles 3.44.2. The version gap means SPM resolution behaves differently between local dev builds and Shorebird builds. After FlutterFire upgrade (which aligned Firebase to 12.14.0), local CocoaPods builds and Shorebird SPM builds now target the same Firebase SDK version, so the practical risk is lower.
- **Sketch**: Upgrade local Flutter to match Shorebird's bundled version after the next milestone.
- **Open questions**: Whether upgrading local Flutter also changes CocoaPods resolution for non-Shorebird builds. Test carefully.

---

## Features

### Chat Phase 2 — task thread + Employees quick-action + group member management

- **Category**: Feature
- **Why now**: Chat Phase 1 shipped in v1.4.0. Phase 2 scope from the architecture doc:
  - **Employees quick-action**: message icon on employee cards → opens/creates DM. Low complexity. Highest daily utility.
  - **Task-thread entry**: "Chat about this task" action on task details → opens conversation with task context. Moderate complexity.
  - **Group member management**: add/remove members after group creation. Moderate complexity, requires rules update.
- **Sketch**: Implement in order: Employees quick-action first, task-thread second, member management third.
- **Open questions**: (a) What tester feedback from v1.4.0 reveals about Phase 2 priority. (b) Whether task-thread links to a new dedicated task-scoped conversation or to an existing DM with context pre-filled.

### "Sign out of all other devices" — Settings action

- **Category**: Security / UX
- **Why now**: The automatic cross-device session invalidation (password change → `revokeUserSessions` → `authStateChanges` listener) is architecturally correct but practically non-deterministic — Firebase Auth ID-token refresh cadence is uncontrolled. A user-triggered explicit revocation is the deterministic alternative.
- **Sketch**: Settings → Account tile "Sign out of all other devices" → confirmation dialog → calls existing `revokeUserSessions` callable → Crashlytics on failure. No new Cloud Function.
- **Open questions**: Whether to surface "Other sessions will sign out within ~1h" as confirmation copy. Whether to add the same wording to the password-change success state.

### Attendance — surface `originalSessions` in admin correction UI

- **Category**: UI/UX
- **Why now**: `originalSessions` is preserved server-side on first correction (the audit baseline) but there is no UI to view it. Admin sees only the corrected state.
- **Sketch**: A "View original sessions" toggle or expand row within the correction sheet. No data model change — the field is already on the attendance document.
- **Open questions**: Whether testers actually need this, or whether the audit trail in `attendance_logs` is sufficient for the use case.

### Admin PDF — custom date-range export

- **Category**: UI/UX
- **Why now**: Current PDF reports are calendar-month scoped. Pay periods or review cycles may not align.
- **Sketch**: Replace the month picker with a date-range picker. Data is already queryable by date range in the repository.
- **Open questions**: Whether this is a real friction point from tester feedback, or speculative.

---

## Engineering

### functions/index.js modularization

- **Category**: Engineering
- **Why now**: File is now ~1,978 lines with 15 exported functions. Still manageable but the next meaningful addition is a good trigger to split by domain.
- **Sketch**: Split into `functions/tasks.js`, `functions/attendance.js`, `functions/chat.js`, `functions/notifications.js`, `functions/utils.js` with a thin `functions/index.js` re-exporting everything. Do this as the first step of the next Cloud Function change, not as a standalone refactor.
- **Open questions**: Whether Firebase's Node 22 runtime has any quirks with multi-file CommonJS modules that require testing.

### Offline write queue user expectation

- **Category**: UX / Engineering
- **Why now**: The v1.1.0 connectivity banner tells users they're offline but doesn't explain whether actions taken offline will sync. Firestore persistence queues writes silently — a user who completes a task offline and sees no confirmation may retry, creating double-writes or unexpected state.
- **Sketch**: After a write succeeds (Firestore local cache confirms), show a brief "Will sync when reconnected" indicator rather than full success. On reconnect, no extra UI needed — Firestore handles the sync.
- **Open questions**: Is this a real pattern testers hit, or speculative? Defer until stabilization triage confirms it's an actual friction point.

---

## Security

### Manual "Sign out of all other devices" Settings action

(See Features section above — same item, listed under Security because the motivation is account security.)

---

## Testing Priorities

_Empty._

## Release Readiness

_Empty._
