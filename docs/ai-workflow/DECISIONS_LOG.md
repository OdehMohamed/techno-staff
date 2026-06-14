# Decisions Log

> Append-only log of non-trivial technical or product decisions. Newest at the top.

Decisions capture "why we did it" so that a future reader (human or AI) can tell whether a constraint is still load-bearing or safe to revisit.

---

## Template

```
### YYYY-MM-DD — <Short decision title>

- **Decision**: What did we decide?
- **Reason**: Why? What alternatives did we consider?
- **Impact**: What changes because of this decision? Who / what is affected?
- **Owner**: Who made the call?
- **Related**: Links to PRs, commits, backlog items, or other decisions.
```

---

## 2026-06-14 — iOS foreground chat-notification suppression: own the UNUserNotificationCenter delegate

- **Decision**: On iOS, per-conversation foreground suppression is done in a native `AppDelegate.userNotificationCenter(_:willPresent:)` override, and `AppDelegate` **explicitly claims the delegate** with `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunching`. Foreground banners are presented by Firebase natively (`setForegroundNotificationPresentationOptions(alert: true)`); `willPresent` suppresses only when the push `conversationId` equals the active conversation id read from `UserDefaults` (`flutter.active_conversation_id`, written by `ConversationCubit`), otherwise calls `super` to let firebase_messaging present. iOS `onMessage` is a no-op; the Dart `flutter_local_notifications` path stays Android-only.
- **Reason**: The suppression logic was correct from early on but never ran — `firebase_messaging`/`flutter_local_notifications` claim the `UNUserNotificationCenter` delegate during plugin registration, so our override was dead code. Explicitly setting the delegate after `GeneratedPluginRegistrant.register` is the load-bearing fix. The Dart-side approach (`alert:false` + re-show via a local notification, suppress in `onMessage`) was tried and abandoned: Firebase's foreground presentation option applies to *every* notification it sees and silently swallows the local one (`show()` succeeds, no banner appears). Two diagnostic traps cost the most time and are worth remembering: (a) Dart's in-memory `SharedPreferences` cache never sees values Swift writes after startup unless you call `reload()`, so cross-language diagnostics via SharedPreferences are misleading; (b) Swift `NSLog`/`print` does **not** appear in `flutter run` — only in Xcode's console or Console.app — so a working native path looked silent/broken.
- **Impact**: Android and iOS deliberately use **different** foreground-suppression mechanisms (Dart `onMessage` for Android, native `willPresent` for iOS) because iOS presents before Dart can intervene. Future notification work must not assume a single shared path. `AppDelegate.swift` now owns the notification-center delegate; anything else that needs `willPresent`/`didReceive` must cooperate via `super`. Verify native notification behavior from Xcode/Console.app, never from `flutter run` logs alone.
- **Owner**: Mohamed Odeh.
- **Related**: `feat/chat-messaging` branch, CURRENT_TASK.md Milestone 5 bug table, SESSION_LOG 2026-06-14.

## 2026-05-16 — Attendance UX/architecture refinement: session-level corrections, expandable cards, information hierarchy

- **Decision**: (1) Admin correction is now session-level, not day-level. `adminCorrectAttendance` callable accepts a `sessions` array; the correction sheet shows each session individually with add/remove/edit capability. (2) `originalSessions` is preserved on the attendance document on the first correction (server-side, not overwritten on subsequent corrections), providing a recoverable audit baseline without a separate audit collection. (3) `isCorrected` and `notes` are visually separated — distinct icons (`Icons.edit_outlined` vs `Icons.note_outlined`) convey independent semantics. (4) Both employee attendance cards and admin roster rows are expandable: summary zone always visible, session detail on tap. Admin "Correct" affordance moves inside the expanded row. (5) `fetchHistory` forces `Source.server` reads to prevent stale Firestore cache from showing outdated history immediately after check-in/out. (6) Session ordering is guaranteed at parse time (sort in `AttendanceModel.fromMap`) and at write time (sort in Cloud Function before persisting). (7) Duration is displayed as "Xh Ym" format throughout, not raw minutes.
- **Reason**: Session-level corrections are necessary once the model supports unlimited sessions per day — day-level overwrite destroys intermediate sessions silently. `originalSessions` on the doc (not in a log) is the simplest recoverable baseline that doesn't require a separate query. Separating correction and notes indicators avoids conflating "this was edited" with "this has an annotation". Expandable cards resolve the tension between summary richness (always visible) and session detail (rarely needed at a glance). `Source.server` is appropriate here because history freshness matters immediately after action, and this is a connected-only feature anyway (biometric gate blocks offline use).
- **Impact**: `adminCorrectAttendance` callable payload shape changes (adds top-level `sessions` array, keeps old `fields` path as backward compat). `_CorrectionSheet` fully redesigned. `AttendanceRecordCard` and `_RosterRow` become `StatefulWidget`. `adminCorrect` cubit/repository signatures change. 5 new translation keys (291 total). Requires `firebase deploy --only functions` after merge.
- **Owner**: Mohamed Odeh.
- **Related**: `feat/attendance-stabilization` branch, SESSION_LOG 2026-05-16.

## 2026-05-15 — Attendance system architecture: trust model, write path, data model

- **Decision**: (1) Trust model: biometric gate (`local_auth`, `biometricOnly: false`) + server-authoritative timestamps. No WiFi/SSID validation, no geofencing. (2) Write path: all attendance writes go through Cloud Function callables (`recordAttendance`, `adminCorrectAttendance`) — client never writes to `attendance` collection directly. Firestore rules: `allow write: if false`. (3) Data model: flat `attendance/{userId}_{YYYY-MM-DD}` (Jerusalem date computed server-side), not subcollection. One session per employee per day. `attendance_logs` is server-only (same `allow write: if false` pattern as `task_logs`). (4) v1 statuses: `present | absent | manual` only — no `late` status until a scheduling model exists. `status` field is string so `late` can be added later without a schema change. (5) Absence tracking: `sendDailyAbsenceMarker` cron at 23:00 Asia/Jerusalem creates `status: 'absent'` docs for employees with no check-in, making absence queryable. (6) Online-only: check-in/out blocked when device offline; never rely on Firestore offline cache for attendance. (7) Reporting/UX: Attendance tab in existing Reports screen (admin); employee self-view via drawer (`AttendanceScreen`); today's summary card on admin dashboard. No separate attendance drawer destination for admin.
- **Reason**: WiFi/SSID validation requires `ACCESS_FINE_LOCATION` on Android 10+ and a special Apple entitlement on iOS, while being trivially spoofable (any employee can create a hotspot named the company SSID). Geofencing adds location-permission friction disproportionate to the benefit at 20–50 employees. Cloud Function write path is chosen over direct Firestore write + rules because the Jerusalem date for the deterministic doc ID must be server-computed, and the `attendance_logs` audit entry must be written atomically in the same transaction. `biometricOnly: false` chosen for operational practicality (fewer support issues, consistent with device-security trust model). `late` deferred because a fixed 09:00 threshold is too simplistic — lateness should derive from per-employee schedules, which are out of scope for v1. Absence cron at 23:00 gives margin for late shifts and connectivity issues without prematurely marking employees absent.
- **Impact**: Adds `local_auth` package (permanently outside Shorebird patch surface — full binary release required). New collections: `attendance`, `attendance_logs`. New Cloud Functions: `recordAttendance`, `adminCorrectAttendance`, `sendDailyAbsenceMarker`. New feature directory `lib/features/attendance/`. 26 new translation keys (parity 246 → 272). Native manifest changes: `USE_BIOMETRIC` permission on Android, `NSFaceIDUsageDescription` on iOS. `connectivity_plus` needed for offline check (may already be present from BACKLOG #9).
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` item #14, `CURRENT_TASK.md` (locked spec), `DECISIONS_LOG.md` 2026-05-01 (original attendance MVP decision), Shorebird decision 2026-05-14 (patch-eligibility matrix).

## 2026-05-15 — UI/UX Improvements pass (BACKLOG #13)

- **Decision**: Apply a scoped presentation-layer improvement pass across five screens: remove debug callable buttons from Reports, make employee-home task cards tappable, clamp task descriptions to 2 lines, hide status controls for completed tasks, use localized human-readable date formats, translate activity log status transitions, simplify dead medium-breakpoint LayoutBuilder branches, differentiate log icons by action type, add overdue urgency accent color on admin dashboard stat card. Zero new features, zero backend changes, zero new routes, zero new translation keys.
- **Reason**: Audit of 21 presentation files identified 10 concrete friction points: unreachable debug buttons in production UI, non-tappable task preview cards, unlocalized dates, untranslated status strings, and redundant LayoutBuilder complexity. All fixes are presentation-layer only — safe to scope tightly and ship as a standalone pass.
- **Impact**: Five modified files: `reports_screen.dart`, `employee_home_screen.dart`, `tasks_screen.dart`, `task_details_screen.dart`, `admin_dashboard_screen.dart`. Translation parity unchanged (246/246). No backend changes.
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` item #13, PR #33.

## 2026-05-14 — Shorebird: conditional adoption as supplemental Dart-only patch channel

- **Decision**: Adopt Shorebird on the free tier as a supplemental patch channel for Dart-only fixes only. Store releases (Google Play / TestFlight binary) remain the source of truth for full app versions and are the normal release path for any change that touches native code, packages, or platform configuration. Mandatory update gate (`config/app_settings`) remains the safety valve for forcing users onto a new binary. Shorebird patches apply exclusively to confirmed patch-eligible changes.
- **Reason**: The testing/stabilization phase produces frequent small Dart-layer fixes (UI adjustments, cubit/logic fixes, validation, screen behavior). Shorebird eliminates store submission overhead for this class of change. The free tier (5,000 patch installs/month) is sufficient for the current testing group. The mandatory update system and Shorebird are complementary: mandatory update forces a binary upgrade; Shorebird delivers Dart-only fixes on top of an already-installed binary. Audit findings: (1) FCM ANR issue (Shorebird GitHub #695) is fixed in engine; (2) Crashlytics integrates via `shorebird_code_push` custom key — adequate for testing phase; (3) iOS App Store compliant under interpreted code exception (guideline 3.3.1b); (4) iOS obfuscation requires Flutter 3.41.2+ — current install is 3.35.7, acceptable for testing phase; (5) private repo CI excluded from free tier — manual CLI workflow accepted; (6) longevity risk (small company) acknowledged and accepted.
- **Impact**: (a) Build toolchain: `shorebird release android/ios` replaces `flutter build` for store releases; `shorebird patch android/ios` for Dart-only fixes. (b) Patch-eligibility checklist added to `docs/release-checklist.md` — every patch must pass it before shipping. (c) Xcode iOS releases: "Manage Version and Build Number" must be unchecked permanently. (d) Initial adoption requires a new store binary (`shorebird_code_push` added to `pubspec.yaml`). (e) FCM background isolate smoke test required on first Shorebird-enabled build. (f) Asset/translation patching must be explicitly verified before relying on it. (g) Never patch-eligible: new packages, native code changes, `firestore.rules`, `functions/index.js`, attendance biometric, `pubspec.yaml` changes.
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` item #10, `docs/release-checklist.md` (Shorebird sections), Shorebird #695 (FCM ANR fix), mandatory-update-system decision (2026-05-14).

## 2026-05-14 — Next cycle roadmap: unified release + mandatory-update-first ordering

- **Decision**: (1) Collapse the previously planned v1.1.1 and v1.2.0 into a single unified next cycle (v1.2.0). (2) Lock the implementation sequence: mandatory update system first, Shorebird feasibility audit second, then progressive reminders + UI/UX improvements in parallel, attendance architecture planning last. (3) No new features start before the mandatory update system is live.
- **Reason**: v1.1.0 deployment revealed that users in Closed Testing / TestFlight do not naturally discover updates without manual prompting. A mandatory update system is a production safety valve — if a bad build reaches users, the minimum version can be bumped in Firestore without a code push to force users off it. This protection should exist before any further native integrations (attendance biometric) or complex features ship. Shorebird must be audited before it affects release strategy decisions. Attendance is the most complex feature (native integrations, trust semantics, reporting structure) and must start with an architecture-first planning round regardless of Shorebird outcome. The v1.1.1 / v1.2.0 split added no useful constraint given the consolidated backlog.
- **Impact**: BACKLOG restructured under a single v1.2 group (items #9–#14). Items #9 (mandatory update) and #10 (Shorebird audit) are gates for subsequent work. No features from items #12–#14 are specced or implemented until #9 is live and #10 is resolved.
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` items #9–#14, `NEXT_STEPS.md`.

## 2026-05-14 — Firestore config doc for mandatory version gating (over Firebase Remote Config)

- **Decision**: Store minimum supported version fields (`minimumAndroidVersion`, `minimumIosVersion`) in a Firestore `config/app_settings` document, not Firebase Remote Config.
- **Reason**: Firebase Remote Config would add a new Firebase service dependency and a new async initialization path at startup. The Firestore stack is already fully initialized at startup (`Firebase.initializeApp` → `FirebaseFirestore.instance`), the rules pattern is established, and the doc is editable from the Firestore console without a code deploy. Version gating is two string fields — Remote Config adds no capability that justifies the additional service.
- **Impact**: `config/app_settings` Firestore doc must exist before the feature can gate anything. Firestore rules must allow unauthenticated or pre-auth reads of this doc so the gate fires before the login screen. Version comparison uses tuple semver logic on the three numeric segments (not string comparison).
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` item #9.

## 2026-05-14 — MaterialApp.builder overlay for offline connectivity state

- **Decision**: Show offline state with a `MaterialApp.builder` `Stack` overlay banner instead of pushing a dedicated offline route.
- **Reason**: A route-push approach would interfere with FCM deep links, auth-driven navigation, and in-progress form state. The offline requirement is informational only, so it should not take over navigation or block interaction.
- **Impact**: Connectivity state is now a lightweight top-of-app UI layer that preserves existing routes, button behavior, and Firestore offline queue behavior. Users can continue navigating and acting while the banner indicates that data may be stale.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: `lib/app/app.dart`, `lib/core/services/connectivity_service.dart`, `docs/ai-workflow/BACKLOG.md` item 8, PR `feat/connectivity-and-refresh`.

## 2026-05-09 — Counter task type with derived completion via persisted status field

- **Decision**: Introduce a second task variant (`taskType: 'counter'`) with flat optional fields on `tasks` documents (`targetCount`, `currentCount`), and enforce a strict persistence contract: every write that changes `currentCount` must atomically persist derived `status` and matching `completedAt` in the same write/transaction.
- **Reason**: The existing downstream pipeline (dashboard/report aggregates, deadline filters, countdown visibility, completion notifications, and `task_logs`) already treats persisted `status` as the completion truth. Keeping `status` authoritative avoids branching Cloud Functions and all downstream consumers by task type.
- **Locked decisions**: (1) flat fields on the existing collection (no nested map/subcollection); (2) locked mapping `0 -> pending`, `0<n<target -> in_progress`, `n>=target -> completed`; (3) no manual status override for counter tasks; (4) `taskType` immutable after create; (5) `targetCount` in 1..999 and `currentCount` in 0..target; (6) no decrement action on employee cards; (7) simple Firestore rules mask widening only (`currentCount` added for assignee status updates); (8) subtle counter-type visual indicator chip; (9) hide edit-screen status dropdown for counter tasks; (10) backward compatibility defaults missing `taskType` to `standard`.
- **Persistence contract**: Count writes and status writes are inseparable. Transaction path derives from post-increment count and writes `currentCount`, derived `status`, `completedAt`, `updatedAt`, `updatedBy`, and `updatedByName` together. Edit-screen counter saves clamp `currentCount` to target, derive status with the same helper, and persist status/completedAt in the same full update.
- **Impact**: Counter progress and completion now flow through the same status-based behavior as standard tasks with no Cloud Function changes, no dashboard/report refactors, and no new dependencies. Firestore rules changed by one key in the assignee mask; operationally, rules must be deployed before using increment in production.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `lib/features/tasks/data/models/task_model.dart`, `lib/features/tasks/data/repositories/tasks_repository.dart`, `lib/features/tasks/presentation/screens/edit_task_screen.dart`, `firestore.rules`, `docs/ai-workflow/BACKLOG.md` item 6, PR #6 (`feat/counter-tasks`).

## 2026-05-09 — Adaptive screen-level countdown ticker for task deadlines

- **Decision**: Implement task-deadline countdowns with one `CountdownClockProvider` per consuming screen (`TasksScreen`, `TaskDetailsScreen`) and a leaf-only `CountdownChip` subscriber. Countdowns target `endOfDay(dueDate)`, not the stored midnight timestamp and not a new time-of-day field.
- **Reason**: The feature's main risk is rebuild churn, not label formatting. A per-card timer or a screen-level `setState()` on every tick would scale poorly on long task lists. Reusing the date-only model also keeps countdown semantics aligned with the existing overdue logic in dashboard, reports, and Cloud Functions reminder paths.
- **Locked rules**: (1) count to `endOfDay(dueDate)`; (2) keep a minimal `CountdownChip` widget instead of extracting a `TaskCard`; (3) keep Hindu-Arabic numerals (`1234`) in Arabic for v1.1 consistency; (4) use a single adaptive screen-level ticker per consuming screen, never per-card and never global; (5) bind ticking rebuilds to the `CountdownChip` leaf via `ValueListenableBuilder`, leaving parent `AppCard` / `InkWell` / list builders stable; (6) treat overdue as a derived red-tinted chip state, without changing `StatusBadge`; (7) give `task_details_screen.dart` the same chip with its own provider instance.
- **Impact**: The tasks list and task details screen now show live countdown chips with three visual states (default, warning, overdue). The provider owns exactly one `Timer.periodic`, recomputes cadence when visible due dates change, pauses on app background states, resumes on foreground, and exposes the current time through a `ValueListenable`. No repository, model, rule, or Cloud Function changes were required.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: `lib/features/tasks/presentation/widgets/countdown_clock_provider.dart`, `lib/features/tasks/presentation/widgets/countdown_chip.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `docs/ai-workflow/BACKLOG.md` item 5, PR #5 (`feat/task-countdown-timer`).

## 2026-05-08 — Stop iterating on automatic cross-device session invalidation in v1.1

- **Decision**: Treat the current PR #26 implementation (server-side `revokeUserSessions` + client `authStateChanges` listener) as the final v1.1 state for cross-device session invalidation. Do not add Firestore-tickle, custom token-refresh listeners, polling heuristics, or any further timing workarounds. Document the behavior as best-effort eventual invalidation (seconds → up to ~1h worst case) rather than chase deterministic immediate invalidation.
- **Reason**: Real-device validation showed the implementation is architecturally correct — refresh tokens are revoked server-side, the client listener is wired, the lifecycle is sound — but practical UX timing is governed by Firebase Auth ID-token refresh cadence and Firebase SDK background-state policies that we do not control. Further iterations would mean adding speculative complexity to compensate for platform-internal behavior, which is the kind of code that ages badly. We are still in Closed Testing / TestFlight, password change itself works correctly, the larger v1.1 roadmap (F3.A countdown, F3.C target tasks, F3.B recurring tasks) is the higher-leverage spend, and a future user-triggered "Sign out of all other devices" Settings action (deterministic by construction) is a much cleaner surface if we ever need stronger session-management UX or get a compliance ask.
- **Impact**: PR #26 ships and merges with the current implementation. The PR body and v1.1 release notes describe the behavior as best-effort eventual cross-device invalidation. The "Sign out of all other devices" idea is captured in `NEXT_STEPS.md` for a future release. No further engineering cycles on this in v1.1.
- **Trigger to revisit**: A real user complaint about the timing, an Apple/Google compliance requirement, or a security incident. Until then this decision stands.
- **Owner**: Project owner (Mohamed) + Claude Code (Opus 4.7) lead.
- **Related**: `NEXT_STEPS.md` (Security Improvements), 2026-05-08 decision "Cross-device session invalidation via Cloud Function admin.revokeRefreshTokens", 2026-05-08 decision "AuthCubit reacts to server-initiated session invalidation via authStateChanges", PR #26 (`feat/account-settings`).

## 2026-05-08 — Cross-device session invalidation via Cloud Function admin.revokeRefreshTokens

- **Decision**: Add a callable Cloud Function `revokeUserSessions` that invokes `admin.auth().revokeRefreshTokens(request.auth.uid)` after a successful password change, and keep the client-side `authStateChanges()` listener as the reaction layer. Also tolerate the iOS-only `apns-token-not-set` race in `AuthCubit._setupFCM` without logging it to Crashlytics.
- **Reason**: Real-device validation corrected an earlier assumption: current Firebase Auth `updatePassword` does not revoke refresh tokens for other active sessions, so the first supplement's listener had no revocation event to observe. Server-side revocation is therefore required to force eventual re-authentication on other devices. The APNS race is benign on first iOS launch and would otherwise flood Crashlytics.
- **Impact**: After password change, all refresh tokens for the caller are revoked and other signed-in devices route back to login on their next token refresh or Firestore-triggered refresh attempt. The client call is best-effort only: revocation failures are logged to Crashlytics and do not undo a successful password change. iOS first-launch APNS registration races no longer generate noisy Crashlytics events while other Firebase exceptions still do.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: PR #26 (`feat/account-settings`), `functions/index.js`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `docs/ai-workflow/CURRENT_TASK.md`, `BACKLOG.md` → v1.1 PR #4.

## 2026-05-08 — AuthCubit reacts to server-initiated session invalidation via authStateChanges

- **Decision**: Subscribe `AuthCubit` to `FirebaseAuth.instance.authStateChanges()` in the cubit constructor, guard the listener with `state.status != AuthStatus.authenticated` then `firebaseUser != null`, and emit `unauthenticated` only when the SDK reports `null` while the cubit currently believes it is authenticated.
- **Reason**: Real-device validation of PR #26 exposed a latent architectural gap: cross-device password change, account deletion, admin disable, or token revocation never reached UI state because `AuthCubit` only emitted `unauthenticated` on explicit local sign-out / deletion paths. `authStateChanges()` is the narrowest stream that covers sign-in, sign-out, and SDK-detected session invalidation without the extra churn of `idTokenChanges()` or `userChanges()`.
- **Impact**: Devices logged into the same account now route back to login after a server-initiated session invalidation is detected during token refresh. Same-device explicit sign-out and delete-account remain correct and idempotent because duplicate `unauthenticated` emissions are benign.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: PR #26 (`feat/account-settings`), `lib/features/auth/presentation/cubit/auth_cubit.dart`, `docs/ai-workflow/CURRENT_TASK.md`, `BACKLOG.md` → v1.1 PR #4.

## 2026-05-08 — Theme persistence is local-only and hydrated before first frame

- **Decision**: Persist `ThemeCubit` mode (`system`/`light`/`dark`) locally via `shared_preferences` and hydrate it in `main()` before `runApp()`. `ThemeCubit` writes are best-effort and non-blocking: emit first, then persist, logging failures to Crashlytics.
- **Reason**: Testers reported theme reset on every launch. Hydrating before app bootstrap avoids cold-start flicker and keeps UX deterministic. Firestore sync was deferred because cross-device theme sync is not required for v1.1 and would add backend/schema/rules complexity.
- **Impact**: `ThemeCubit` now receives `prefs` + `initialMode`; startup resolves persisted mode defensively (missing/invalid values fall back to `system`); persistence failures do not block visible theme toggling.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `lib/core/theme/cubit/theme_cubit.dart`, `lib/main.dart`, `pubspec.yaml`, `BACKLOG.md` → v1.1 PR #3.

## 2026-05-07 — Server-side localization for FCM push notifications via users/{uid}.languageCode

- **Decision**: Localize FCM push `notification.title` and `notification.body` in Cloud Functions using a server-side translation table keyed by each recipient's `users/{uid}.languageCode` (`en`/`ar`, fallback `en`). This was applied to all task push senders and both reminder/escalation test callables.
- **Reason**: In-app notifications were already localized client-side, but system-tray push payloads were hardcoded English. Server-side localization keeps payload behavior deterministic and avoids coupling push rendering to client app version/state.
- **Locked table**: The approved EN/AR translation table in `CURRENT_TASK.md` was shipped verbatim with no key or wording changes.
- **Impact**: Recipients now receive push text in their chosen language once `languageCode` is present; missing/invalid values safely default to English. Client persists `languageCode` on sign-in/auth-check and locale changes (best-effort with Crashlytics logging), and rules now allow self-updating `languageCode` alongside `fcmToken`.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `functions/index.js`, `firestore.rules`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `lib/core/constants/firebase_paths.dart`, `BACKLOG.md` → v1.1 PR #2.

## 2026-05-07 — FCM token lifecycle — cleared on signout and account deletion

- **Decision**: Clear FCM tokens on both sign-out and successful account deletion in the client auth lifecycle. `AuthCubit.signOut()` now best-effort deletes `users/{uid}.fcmToken` and calls `FirebaseMessaging.deleteToken()` before signing out. `AuthCubit.deleteAccount()` now best-effort deletes the device token, then explicitly signs out and emits `unauthenticated` after callable success.
- **Reason**: Closed-testing reports showed notification leakage after logout (stale Firestore/device token) and a stuck delete-account spinner caused by relying on passive auth-listener behavior without explicit unauthenticated emission.
- **Impact**: Sign-out and delete-account now self-heal notification targeting on shared devices and reliably route users back to login via unauthenticated state. Cleanup remains best-effort and non-blocking: failures are logged via `FirebaseCrashlytics.recordError(e, stack)` and do not block sign-out/deletion success.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `docs/ai-workflow/CURRENT_TASK.md`, `BACKLOG.md` → v1.1 PR #1.

## 2026-05-01 — Android release signing — strict, key.properties-driven (no debug fallback)

- **Decision**: Configure `android/app/build.gradle.kts` to require a real signing keystore for every release build. `signingConfigs.create("release")` reads credentials from `android/key.properties` (gitignored). If the file is absent, `flutter build apk --release` / `flutter build appbundle --release` fails hard — no silent fallback to debug keys.
- **Reason**: The Flutter scaffolding left a TODO comment and a `signingConfig = signingConfigs.getByName("debug")` fallback in `buildTypes.release`. Google Play Console rejects APKs/AABs signed with Android's debug key on every track (internal, closed, open). Silently succeeding with a debug key would produce an upload that Play Console rejects, which is worse than a clear build-time failure.
- **Alternatives rejected**: (1) Keeping debug-key fallback for CI convenience — rejected because no CI pipeline exists yet; risk outweighs convenience. (2) Hardcoding keystore path in `build.gradle.kts` — rejected because it would require committing credentials or embedding a machine-specific path.
- **Impact**: `flutter build apk --release` and `flutter build appbundle --release` fail with a clear Gradle error when `android/key.properties` is absent. Debug builds (`flutter run`, `flutter build apk --debug`) are entirely unaffected. Project owner must create `~/upload-keystore.jks` and `android/key.properties` once before their first Play Console upload (instructions in `docs/release-checklist.md`).
- **iOS out of scope**: iOS distribution signing is configured in Xcode UI — no change to Xcode signing settings in this PR.
- **Owner**: GitHub Copilot (Claude Sonnet 4.6).
- **Related**: `android/app/build.gradle.kts`, `docs/release-checklist.md`, `BACKLOG.md` → Pre-build polish (v1.0.1 stores).

## 2026-05-01 — Pre-build app icons via flutter_launcher_icons

- **Decision**: Generate launcher icons from `assets/icon/app_icon.png` using `flutter_launcher_icons` (`flutter_launcher_icons: ^0.14.4`) with `android: true`, `ios: true`, `image_path: "assets/icon/app_icon.png"`, and `remove_alpha_ios: true`.
- **Reason**: This is the standard, low-risk way to regenerate all required Android mipmap icons and the iOS `AppIcon.appiconset` from a single source asset while keeping output deterministic.
- **Impact**: Android launcher mipmaps and iOS AppIcon assets are regenerated for v1.0.1 store polish; no adaptive icon customization is introduced in v1.0.x.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `BACKLOG.md` → Pre-build polish (v1.0.1 stores), `pubspec.yaml`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `android/app/src/main/res/mipmap-*/ic_launcher.png`.

## 2026-04-30 — Crashlytics + Firebase minor bumps + release artifacts for v1.0.0

- **Decision**: Keep Crashlytics integration intentionally minimal for v1.0.0: global handlers in `main.dart` (`FlutterError.onError`, `PlatformDispatcher.instance.onError`) plus `setUserIdentifier` on auth sign-in/sign-out. No `runZonedGuarded`, no per-catch `recordError`, no custom keys in cubits.
- **Reason**: This delivers immediate production observability with low integration risk in the final release-prep PR, while avoiding invasive instrumentation changes right before tagging.
- **Dependency policy**: Bump exactly five Firebase Flutter packages by one minor (`cloud_firestore` 6.3, `cloud_functions` 6.2, `firebase_auth` 6.4, `firebase_core` 4.7, `firebase_messaging` 16.2) and add `firebase_crashlytics` only. No non-Firebase bumps and no major-version upgrades.
- **Release artifacts**: Add `CHANGELOG.md` (Keep a Changelog format) and `docs/release-checklist.md` as required v1.0.0 release assets.
- **Operational split**: Keep GitHub Pages enablement, iOS dSYM upload script setup, signing configuration, and Firestore backup enablement as manual owner-run checklist steps, not in-repo automation.
- **Impact**: Final release-prep scope is complete; v1.0.0 is ready for the `dev -> main` release PR and tag flow after this PR merges.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md` (release-prep PR #5), `BACKLOG.md` item 5, `CHANGELOG.md`, `docs/release-checklist.md`.

## 2026-04-28 — Account deletion + privacy policy for v1.0.0

- **Decision**: Implement account deletion as a Cloud Function callable (`deleteUserAccount`) that the authenticated user calls directly — not as a client-side Firestore operation — so the admin SDK can delete the Auth account atomically.
- **Task-name overwrite vs delete**: Tasks the deleted user created or was assigned to are **kept** with display names overwritten to `"Deleted user"` (English literal for v1). UIDs stay intact for traceability. Task deletion was rejected because it would erase the team's business record.
- **Confirmation strength**: Simple `AlertDialog` with Cancel + destructive-styled Delete. Type-to-confirm was rejected as over-engineered for v1.
- **GitHub Pages source**: `main` branch, `/docs` folder. Privacy policy lives at `docs/privacy-policy.md`. URL: `https://odehmohamed.github.io/techno-staff/privacy-policy/`. The repo toggle is a manual one-time step documented in the PR body.
- **Placeholder support email**: `support@example.com` used in `docs/privacy-policy.md` and flagged in the PR body for the owner to replace before publishing Pages.
- **Owner**: GitHub Copilot (Claude Sonnet 4.6).
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness" → 4.

## 2026-04-28 — Add POST_NOTIFICATIONS for Android 13+

- **Decision**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` as the single first child of `<manifest>` in `android/app/src/main/AndroidManifest.xml`. No other files changed.
- **Reason**: Android 13+ requires an explicit `POST_NOTIFICATIONS` manifest declaration before the runtime `requestPermission()` call can surface the system dialog. The runtime call (`FirebaseMessaging.requestPermission(alert: true, badge: true, sound: true)`) was already present in `auth_cubit.dart` `_setupFCM` — the prompt was simply silently suppressed on Android 13+ because the manifest declaration was absent.
- **Impact**: After this change, Android 13+ users will see the OS notification-permission prompt on first sign-in. Denied-state UX (graceful degradation, Settings deep-link nudge) is intentionally deferred to post-v1.0.0 as out-of-scope for this PR.
- **Owner**: GitHub Copilot (Claude Sonnet 4.6).
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness" → 3.

## 2026-04-27 — Release metadata fixes for v1.0.0

- **Decision**: Complete release-prep metadata PR #2 with exactly five edits: `pubspec.yaml` description update, `README.md` rewrite, Android launcher label change to `Techno Staff`, iOS `CFBundleName` change to `Techno Staff`, and English translation key rename `in_pending_tasks` → `pending_tasks`.
- **Reason**: v1.0.0 needs coherent store-facing and user-facing metadata, and the translation typo caused English dashboard legend fallback to show a literal key.
- **Impact**: App identity is now consistent across Android/iOS metadata surfaces, the README reflects the actual project, and en/ar translation parity remains intact after the key rename.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness".

## 2026-04-27 — Strip debug logging before v1.0.0

- **Decision**: Completed the mechanical cleanup by deleting all 20 `debugPrint` calls under `lib/` with no replacement logging in this PR.
- **Reason**: `debugPrint` statements ship in Flutter release builds and were leaking sensitive and operational metadata (including FCM token and user/task identifiers) to device logs.
- **Impact**: `grep -rn "debugPrint" lib | wc -l` now returns `0`; analyzer/test/functions-lint gates are green; structured error reporting remains deferred to release-prep PR #5 (Crashlytics).
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness".

## 2026-04-27 — Release-readiness sweep for v1.0.0

- **Decision**: Ship v1.0.0 via 5 sequential, small PRs that close out the release-readiness audit findings: (1) strip debug logging, (2) release metadata fixes, (3) Android 13+ notifications permission, (4) account deletion + privacy policy, (5) Crashlytics + minor dep bumps + CHANGELOG. Account deletion uses a Cloud Function callable for atomicity. Privacy policy is hosted on GitHub Pages. Release flow: all PRs merge into `dev`, then a `release: v1.0.0` PR fast-forwards `main` from `dev`, and `v1.0.0` is tagged with annotated `git tag` and a GitHub Release.
- **Reason**: The audit found six release-blocking issues (debug log leakage of FCM tokens and user IDs; missing Android 13+ notifications permission; no privacy policy; no account deletion; default pubspec description; default README) plus four should-fix items (app name inconsistencies, one translation key typo, no Crashlytics, minor deps behind). Small sequential PRs keep each change reviewable and make it easy to gate or roll back individually.
- **Impact**: A `Release v1.0.0 readiness` section is added to `BACKLOG.md` listing the 5 PRs. Major dependency bumps (`firebase-admin`, `firebase-functions`, `eslint`, `flutter_local_notifications`) are deferred to v1.1. Operational follow-ups (CI/CD, staging Firebase project, full offline UX, performance tuning, dark mode QA, store metadata) are deferred but tracked.
- **Owner**: Mohamed Odeh.
- **Related**: `BACKLOG.md` → "Release v1.0.0 readiness", `CURRENT_TASK.md`.

## 2026-04-27 — Strip debug logging before v1.0.0

- **Decision**: Delete all 20 `debugPrint` calls in `lib/` outright (not wrap them in `if (kDebugMode) ...`). Structured error reporting will be reintroduced via Firebase Crashlytics in release-prep PR #5.
- **Reason**: `debugPrint` is not stripped from release builds in Flutter, so calls like `auth_cubit.dart` printing the user's FCM token leak sensitive data to device logs. Wrapping each call in `kDebugMode` preserves visual clutter and tempts future agents to add more such calls. A clean delete plus Crashlytics is the right pattern.
- **Impact**: `lib/main.dart`, `auth_cubit.dart`, `tasks_cubit.dart`, `reports_repository.dart`, `reports_cubit.dart`, and `reports_screen.dart` are touched. A handful of `catch (e)` blocks become `catch (_)` to keep `flutter analyze` clean. No behavior changes.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, `BACKLOG.md` → "Release v1.0.0 readiness" → 1.

## 2026-04-27 — Task search and filtering — global state, client-side, bottom sheet UX

- **Decision**: Implement task search and filtering entirely on the client over already-fetched tab lists, with one global filter state shared across tabs in `TasksScreen`, and a `showModalBottomSheet` apply-flow for status/priority/sort controls.
- **Reason**: Expected list size is small enough for local filtering, and global cross-tab state gives a consistent user mental model while keeping scope limited to UI logic.
- **Impact**: `tasks_screen.dart` now applies search on title/description/assigned-to/assigned-by names plus status/priority/sort, shows active-filter affordances (badge, count, clear action), and uses a dedicated `task_filter_bottom_sheet.dart` widget with a `TaskFilters` value object.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, backlog item "Add task search and filtering".

## 2026-04-27 — Add task delete UI for admins and creators

- **Decision**: Implement task deletion from `task_details_screen.dart` as an AppBar action (`Icons.delete_outline`) using the same visibility gate as edit (`admin` or task creator), with a required confirmation dialog that interpolates the task title.
- **Reason**: Reusing the existing details-screen action pattern keeps permissions and UX consistent while minimizing scope and regression risk.
- **Impact**: Client now supports delete for authorized users through `TasksRepository.deleteTask`, `TasksCubit.deleteTask`, and localized confirmation/success/failure copy. This PR intentionally does not emit delete notifications and does not clean up `task_logs/`.
- **Owner**: GitHub Copilot (GPT-5.3-Codex).
- **Related**: `CURRENT_TASK.md`, backlog item "Add task delete UI for admins and creators".

## 2026-04-26 — Admin task tabs (Assigned to me + All tasks)

- **Decision**: The admin tasks screen now mirrors the employee tab pattern with two locked tabs in this order: `Assigned to me` first and `All tasks` second, with the admin subtitle using `tasks_overview`.
- **Reason**: Admins need both a personal work queue and a global team view, and reusing the employee tab pattern keeps the tasks experience consistent across roles.
- **Impact**: `TasksScreen` now fetches both admin task streams on load, renders `_buildAdminTabs()` instead of a single list, and `TasksCubit.updateTaskStatus()` refreshes both `fetchAllTasks()` and `fetchTasksAssignedTo(currentUserId)` after an admin status change so both tabs stay synchronized.
- **Owner**: GitHub Copilot (GPT-5.4).
- **Related**: `CURRENT_TASK.md`, backlog item "Add admin task tabs (Assigned to me + All tasks)".

## 2026-04-24 — Self-assignment is allowed (reversal of earlier scope detail)

- **Decision**: A user may assign a task to themselves. The current user MUST remain visible in the assignee dropdown on the add-task screen.
- **Reason**: During the initial planning round for the employee-task-creation feature, the scope called for excluding the current user from the assignee dropdown. On review, the team decided self-assignment is a legitimate use case (e.g. a user tracking their own work item as a formal task) and restricting it adds no security or UX value — `assignedBy` and `assignedTo` being the same uid is harmless.
- **Impact**: `CURRENT_TASK.md §6` and manual smoke test #7 updated to reflect this. Implementation in `add_task_screen.dart` intentionally does NOT filter out the current user. Any future agent reading the old "exclude self" instruction should ignore it.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, PR #6.

## 2026-04-24 — Allow employee task creation + relax users read rule

- **Decision**: Implement employee task creation with any-to-any assignment by updating `firestore.rules` so any signed-in user can read `users/`, any task creator can create/update/delete their own tasks, and `assignedBy` remains immutable after task creation.
- **Reason**: Employees must be able to choose any assignee (employee or admin), view assignee choices in-app, and manage tasks they originated without requiring admin-only task creation.
- **Impact**: Non-admin task screens now show split views (`assigned_to_me` and `created_by_me`), task creation is available to all users, and security rules enforce ownership boundaries while preserving assignee status-only edits.
- **Owner**: Mohamed Odeh.
- **Related**: `CURRENT_TASK.md`, backlog item "Allow employees to create and assign tasks".

## 2026-04-24 — Adopt `/docs/ai-workflow/` as the single shared source of truth

- **Decision**: All cross-session project context, rules, decisions, backlog, and forward-looking ideas live under `/docs/ai-workflow/` as plain markdown. Every AI agent and human developer reads these files before starting a task and updates them after finishing.
- **Reason**: We work with multiple AI agents that do not share memory across sessions. A file-based source of truth prevents drift, reduces hallucinations, and survives changes to the specific models or tools we use.
- **Impact**: New mandatory workflow — see `RULES.md` for the "Workflow for every task" section. `CLAUDE.md` now points here as the entry point.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md`, `PROJECT_CONTEXT.md`.

## 2026-04-24 — Remove Spec Kit; migrate the constitution into `RULES.md`

- **Decision**: Delete `specs/`, `.specify/`, and the `speckit-*` skills under `.claude/skills/`. The ratified constitution v1.0.0 (previously in `.specify/memory/constitution.md`) moves into `/docs/ai-workflow/RULES.md`. Spec Kit slash commands are no longer the workflow.
- **Reason**: The team prefers one lightweight markdown-based workflow over two overlapping systems. Spec Kit introduced `/specs/` folders, templates, and slash commands that duplicated what `/docs/ai-workflow/` will cover. Keeping both would split context across two systems and increase the chance of stale docs.
- **Impact**: Fewer concepts to keep in sync. All project rules live in one file. No more `/speckit.*` commands; new features are documented via `CURRENT_TASK.md` + `BACKLOG.md` + (optionally) a short design note inside the PR description.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md` (contains the migrated constitution content).
