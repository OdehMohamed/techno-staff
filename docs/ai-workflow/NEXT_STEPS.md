# Next Steps

> Last updated: 2026-06-22
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

1. **Collect tester feedback on v1.8.0** — Shorebird patch cycle or new features depend on tester response; no new commitments until then.
2. **v1.9.0 release** — currently in-progress on `feat/v1.9.0`; full store binary required (translation changes).

---

## Infrastructure / Platform

### Third-party plugin build warnings (tracked, not blocking)

- **Category**: Engineering
- **Why now**: Surfaced during v1.9.0 build smoke test.
- **Android — KGP API warnings**: `cloud_functions`, `firebase_storage`, `image_picker_android`, `local_auth_android`, `package_info_plus`, `shared_preferences_android` use deprecated Kotlin Gradle Plugin APIs. Flutter warns these may become build failures in a future Flutter version. No action possible on our side — upstream plugins must migrate. Monitor FlutterFire / plugin changelogs and upgrade when fixes are released.
- **iOS — `printing` / SPM**: The `printing` package does not support Swift Package Manager yet. No impact on builds today; will matter if we ever drop CocoaPods. Track upstream: `pub.dev/packages/printing`.
- **iOS — FirebaseAuth deprecated application API**: `FIRApp.configure()` / deprecated `UIApplication` hook in the FirebaseAuth plugin. This is a Firebase iOS SDK issue, not ours. Will resolve when FlutterFire updates its underlying Firebase iOS SDK dependency.
- **Open questions**: None blocking. Revisit when a Flutter upgrade causes an actual build failure.

### ✅ FlutterFire upgrade → Shorebird iOS — CLOSED (2026-06-17)

Root cause: `FLTPipelineParser.m` in cloud_firestore 6.3.0 called `FIRCollectionSourceStageBridge initWithRef:firestore:` (2-arg), but firebase-ios-sdk 12.14.0 changed it to `initWithRef:firestore:forceIndex:` (3-arg). Shorebird's SPM resolved `from: "12.12.0"` to 12.14.0; CocoaPods pinned to exactly 12.12.0, so local builds worked and Shorebird builds failed.

Fix: upgraded all FlutterFire packages to their latest minor/patch within existing `^` constraints (cloud_firestore 6.5.0, firebase_core 4.10.0, firebase_auth 6.5.2, firebase_crashlytics 5.2.3, firebase_messaging 16.3.0, cloud_functions 6.3.2). Deleted `Podfile.lock` + ran `pod repo update` to re-resolve CocoaPods to Firebase 12.14.0. Both `shorebird release ios` and `shorebird release android` succeeded for v1.5.0+8. Branch: `chore/flutterfire-upgrade`.

### ✅ Shorebird asset/translation patching — CLOSED (2026-06-16)

Result: **NOT supported.** Shorebird explicitly excludes `assets/translations/*.json` from patches and prints a warning. Tested on v1.4.0+7 Android baseline. Result recorded in `docs/release-checklist.md`.

**Implication for all future work:** Any PR that adds or changes translation keys is a full binary store release, never a Shorebird patch. This includes Chat Phase 2, which will add ~10–15 new EN/AR keys — Chat Phase 2 requires a store binary regardless of Dart patch eligibility.

### ✅ Android Gradle / AGP / Kotlin upgrade — CLOSED (2026-06-22, v1.9.0)

Upgraded: Gradle 8.12 → 8.14.1, AGP 8.9.1 → 8.11.1, Kotlin 2.1.0 → 2.2.20. APK build confirmed clean.

### ✅ Local Flutter version alignment with Shorebird — CLOSED (2026-06-22, v1.9.0)

Flutter upgraded to 3.44.2 (matches Shorebird stable).

---

## Features

### ✅ Chat Phase 2 — task thread + Employees quick-action + group member management — CLOSED (v1.8.0)

All three sub-items shipped: Employees DM quick-action, task-linked thread (creator + assignee), admin broadcast channels.

### Chat Phase 3 — group member management (add/remove after creation)

- **Category**: Feature
- **Why now**: Deferred from Phase 2; requires rules change for non-creator participants to add/remove members.
- **Sketch**: Settings gear in ConversationScreen → manage members sheet → add by user search / remove with confirm.
- **Open questions**: Tester feedback on whether this is actually needed.

### ✅ "Sign out of all other devices" — CLOSED (2026-06-22, v1.9.0)

Settings → Account tile → confirmation → `revokeUserSessions` callable. No new CF.

### ✅ Attendance — surface `originalSessions` in admin correction UI — CLOSED (2026-06-22, v1.9.0)

`originalSessions` parsed in `AttendanceModel.fromMap`; read-only display added to `_CorrectionSheet` when `isCorrected == true`.

### ✅ Reports — custom date-range export — CLOSED (2026-06-22, v1.9.0)

Month picker replaced with `showDateRangePicker`. State/cubit/repository use `startDate`/`endDate`.

---

## Engineering

### ✅ functions/index.js modularization — CLOSED (v1.8.0)

Split into 7 modules under `functions/lib/`; `index.js` is now a thin re-export.

### Offline write queue user expectation

- **Category**: UX / Engineering
- **Why now**: The v1.1.0 connectivity banner tells users they're offline but doesn't explain whether actions taken offline will sync. Firestore persistence queues writes silently — a user who completes a task offline and sees no confirmation may retry, creating double-writes or unexpected state.
- **Sketch**: After a write succeeds (Firestore local cache confirms), show a brief "Will sync when reconnected" indicator rather than full success. On reconnect, no extra UI needed — Firestore handles the sync.
- **Open questions**: Is this a real pattern testers hit, or speculative? Defer until stabilization triage confirms it's an actual friction point.

---

## Security

_Empty._

---

## Testing Priorities

_Empty._

## Release Readiness

_Empty._
