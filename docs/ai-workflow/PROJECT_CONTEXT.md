# Project Context

> Last updated: 2026-06-17
> Owner: Mohamed Odeh
> Audience: every AI agent and human developer working on this repo.

This file is a factual snapshot of the project. Update it whenever a fact changes (new module, new collection, new dependency, new branch convention, etc.). Never put task progress or backlog items here — those live in `CURRENT_TASK.md` and `BACKLOG.md`.

---

## 1. Overview

**Techno Staff** is a Flutter + Firebase staff and task-management application with a role-based access model:

- **Admin** — creates users, assigns tasks, monitors team performance via dashboards, exports PDF reports, manages recurring task templates, reviews attendance, corrects attendance records.
- **Employee** — receives assigned tasks, creates and assigns tasks, updates their status, tracks their own attendance, reads notifications.

The app is bilingual (English + Arabic) with full RTL support and uses Firebase as the sole backend (Auth + Firestore + Cloud Functions + FCM).

Current status: closed testing (Google Play Closed Testing, TestFlight). v1.5.0+8 merged to `main` (2026-06-17) — FlutterFire infrastructure baseline; store binary uploads pending (owner). Chat Phase 2 in progress on `feat/chat-phase-2`: employee DM quick-action, task-linked conversations, admin broadcast channels implemented (2026-06-17). Next: owner smoke test → version bump to 1.6.0+9 → Shorebird releases → store submission.

## 2. Tech Stack

### Mobile / Client

| Concern             | Choice                                       |
| ------------------- | -------------------------------------------- |
| Framework           | Flutter (Dart SDK `^3.9.2`)                  |
| State management    | `flutter_bloc` `^9.1.1` — Cubit pattern only |
| Localization        | `easy_localization` `^3.0.8` (en, ar)        |
| Charts              | `fl_chart` `^1.2.0`                          |
| PDF                 | `pdf` `^3.12.0`, `printing` `^5.14.3`        |
| Local notifications | `flutter_local_notifications` `^20.1.0`      |
| Biometric auth      | `local_auth` `^3.0.1` (Android `USE_BIOMETRIC` + minSdk 23, iOS `NSFaceIDUsageDescription`) |
| Connectivity        | `connectivity_plus` `^6.0.0`                 |
| Utilities           | `uuid`, `intl`, `path_provider`, `shared_preferences`, `package_info_plus`, `url_launcher` |

### Backend (Firebase)

| Concern             | Choice                                       |
| ------------------- | -------------------------------------------- |
| Auth                | `firebase_auth` `^6.4.0` (resolved 6.5.2)    |
| Firestore           | `cloud_firestore` `^6.3.0` (resolved 6.5.0)  |
| Cloud Functions     | `cloud_functions` `^6.2.0` (resolved 6.3.2, Node 22 runtime) |
| Crash reporting     | `firebase_crashlytics` `^5.0.4` (resolved 5.2.3) |
| Push messaging      | `firebase_messaging` `^16.2.0` (resolved 16.3.0) |
| Firebase project id | `techno-staff`                               |

### Quality

- `flutter_lints` `^5.0.0` for the Flutter client.
- ESLint (Google config) for `functions/` — runs as Firebase `predeploy`.
- Release artifacts: root `CHANGELOG.md` and `docs/release-checklist.md`.
- Translation parity enforced: `365 365 []` as of Chat Phase 2 on `feat/chat-phase-2` (8 new keys: send_message, task_discussion, task_discussion_error, broadcast_channel, broadcast_channel_hint, admin_only_can_post, select_all).

## 3. Architecture

Feature-first clean architecture under `lib/features/<feature>/`:

```
lib/
├── app/                  # App bootstrap + top-level MultiBlocProvider wiring
├── core/                 # Routing, theme, constants, services (cross-cutting)
│   ├── constants/        # app_colors, app_sizes, app_strings, app_assets, firebase_paths
│   ├── routes/           # app_router.dart (onGenerateRoute switch), route_names.dart, app_navigator.dart
│   ├── services/         # app_update_service.dart, notification_service.dart
│   └── theme/            # AppTheme.lightTheme / darkTheme + ThemeCubit (persisted)
├── shared/widgets/       # Reusable UI components
├── features/
│   └── <feature>/
│       ├── data/         # Firestore DTOs + repositories
│       ├── domain/       # Plain domain types (only where needed)
│       └── presentation/ # cubit/ + screens/ + widgets/
├── firebase_options.dart # Generated — do not hand-edit
└── main.dart
```

All repositories and Cubits are constructed in `lib/app/app.dart` and injected into a single top-level `MultiBlocProvider`. Features consume them via `context.read<XCubit>()`.

Navigation goes through `AppRouter.onGenerateRoute` (see `lib/core/routes/`). A global `AppNavigator.navigatorKey` lets background FCM handlers route without a `BuildContext`.

**Firestore read discipline**: All repository reads use `GetOptions(source: Source.server)` to prevent stale Firestore cache from causing visible UX issues after mutations. Streams (`.snapshots()`) are always server-live and are unaffected.

## 4. Modules

| Feature         | Role(s)  | Purpose                                                                                                                                                                                         |
| --------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `splash`        | all      | Boot + mandatory version check (`AppUpdateService`) + initial auth-state routing                                                                                                               |
| `update`        | all      | Non-dismissible `UpdateRequiredScreen` shown when installed version is below `config/app_settings.minimumAndroidVersion` / `minimumIosVersion`                                                  |
| `auth`          | all      | Login, sign-out, FCM token registration on sign-in, FCM token cleanup on sign-out/account deletion, session revocation after password change, automatic unauthenticated-state emission when Firebase invalidates the session server-side |
| `admin`         | admin    | Admin home shell (dashboard, task list with all-tasks tab)                                                                                                                                      |
| `employee`      | employee | Employee home shell — live today-attendance card (status, time, duration; tappable), urgency-sorted task preview (5 cards, due-date labels), quick actions                                      |
| `employees`     | admin    | Staff CRUD (creation via `createEmployeeUser` callable; activate/deactivate) + per-employee weekly schedule edit sheet                                                                          |
| `tasks`         | all      | Task list with role-specific tabs (employee: assigned/created/completed, admin: assigned/all/completed); search + filter sheet + quick-filter chips (Overdue/Due Soon/High); live countdown chip; counter task type; recurring templates (admin); `hasDueTime` exact-time deadlines; task details with activity log; create/edit/delete by creator or admin; status updates (assignee) |
| `dashboard`     | admin    | Charts, filters (today/week/month), team performance, trend, top performer, recent activity log; `_AttendanceSummaryCard` (present+late headline, conditional late/absent chips, tappable); `_OverdueAlertCard` (errorContainer, shown when overdueOpenTasks > 0, tappable) |
| `attendance`    | all      | Employee biometric check-in/out; schedule-aware status resolution (present/late/off_day_work); multi-session daily records; session-level admin correction with audit trail (`originalSessions`); expandable attendance cards; employee personal history + monthly summary with schedule-aware rate bar; admin roster with date picker; schedule management (`schedules/{userId}`) |
| `reports`       | admin    | Task reporting by employee/month + attendance section, PDF export                                                                                                                               |
| `notifications` | all      | In-app notification feed (server-written, client toggles `isRead`), real-time stream + unread count badge                                                                                       |
| `chat`          | all      | DM and group conversations; real-time streaming; pagination (50/page); soft-delete (sender-only); unread counts per conversation; `ChatBadgeButton` in AppBar; FCM push per recipient via `onNewChatMessage` CF; per-conversation foreground suppression (iOS: `AppDelegate.willPresent` + `UserDefaults`; Android: Dart `onMessage` + `activeConversationId`). Phase 2 (2026-06-17): employee DM quick-action from EmployeesScreen; task-linked thread from TaskDetailsScreen (creator + assignee only; createdBy bug fixed); admin broadcast channels (`writeRestriction: 'admin_only'` — toggle in NewGroupScreen, read-only notice in ConversationScreen, megaphone icon in ConversationTile). Phase 3 (deferred): group member management (add/remove; requires rules change). |
| `settings`      | all      | Theme (persisted), language, sign out, About (version + privacy policy + licenses), delete account, edit profile (name), change password with session revocation                               |

## 5. Firestore Data Model

| Collection                       | Client write access                                                                                                                                              | Notes                                                                                                |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `users/{uid}`                    | admin: full; employee: own `fcmToken` + `languageCode` + `name` only                                                                                            | Read access is any authenticated user; shape: `{ email, name, role, isActive, fcmToken, languageCode, createdAt }`. `fcmToken` on this doc is a deprecated write path kept for backward compat — live tokens are now in `fcm_tokens/{uid}`. |
| `tasks/{taskId}`                 | any authenticated user can create when `assignedBy == auth.uid`; creator + admin: full update/delete (with immutable `assignedBy`); assignee: status fields + `currentCount` only | Rules enforce `onlyAllowedTaskStatusFieldsChanged` and `assignedBy` immutability; shape includes `taskType`, optional `targetCount`, `currentCount` for counter tasks; `templateId` for recurring instances |
| `task_logs/{logId}`              | **none — server-only**                                                                                                                                           | Audit trail written by Cloud Functions; readable by task creator, assignee, and admins               |
| `notifications/{notificationId}` | server writes; client toggles `isRead`                                                                                                                           | Per-user in-app feed; 30-item limit with real-time stream                                            |
| `task_templates/{templateId}`    | admin: full (create/update/delete/pause); server: generates instances                                                                                            | Recurring task templates; instances written to `tasks/` with deterministic ID `{templateId}_{assigneeId}_{YYYY-MM-DD}` |
| `attendance/{userId_YYYY-MM-DD}` | **none — server-only**                                                                                                                                           | Shape: `{ userId, userName, date, status, sessions[], totalDurationMinutes, isCorrected, originalSessions?, correctedBy?, correctedByName?, correctedAt?, notes? }` |
| `attendance_logs/{logId}`        | **none — server-only**                                                                                                                                           | Audit trail for check-in/out and corrections                                                         |
| `schedules/{userId}`             | admin: full; employee: own (read only)                                                                                                                           | Per-employee weekly work schedule; shape: `{ days: { "1"–"7": { isWorkingDay, expectedStartTime, expectedEndTime, graceMinutes? } }, defaultGraceMinutes }`. Used by `recordAttendance` to resolve `present`/`late`/`off_day_work` and by `sendDailyAbsenceMarker` to write `off_day` instead of `absent` for non-working days. Missing doc → treated as working every day (graceful default). |
| `fcm_tokens/{userId}`            | **none — server-only** (`allow read: if false`)                                                                                                                  | FCM push tokens isolated from `users` collection. Shape: `{ token: string }`. Clients can no longer read other users' tokens. Cloud Functions use admin SDK (`getFcmToken` / `getFcmTokensBatch` helpers). Cleaned up on account deletion. |
| `config/{configId}`              | admin only; **public read (unauthenticated)**                                                                                                                    | Only `config/app_settings` exists: `{ minimumAndroidVersion, minimumIosVersion, androidStoreUrl, iosStoreUrl }`. Public read is intentional — version check runs before auth gate. Never add sensitive data here. |
| `conversations/{cId}`            | participant read; any authenticated user can create; participants can update `lastMessage`/`lastMessageAt`/`unreadCounts`; **no direct delete** | DM shape: `{ type: 'dm', participantIds[], participantNames{}, createdAt, lastMessage?, lastMessageAt?, unreadCounts{} }`. Group adds `name`, `groupImage?`. Deterministic DM ID = sorted UIDs joined with `_`. |
| `conversations/{cId}/messages/{mId}` | participant: create + soft-delete own (set `isDeleted: true`); **no hard delete** | Shape: `{ senderId, senderName, text, createdAt, isDeleted, deletedAt? }`. Forward-compat nullable fields: `attachment`, `reactions`, `replyTo`, `mentions`, `editedAt`. Unread counts managed by `onNewChatMessage` CF via `FieldValue.increment`. |

Field-name constants live in `lib/core/constants/firebase_paths.dart`. String literals for Firestore collection paths are not allowed in feature code — use `FirebasePaths.*` constants.

## 6. Cloud Functions

Single file: `functions/index.js` (Node 22, ~1,978 lines, 15 exports). Consider splitting by domain when the next CF addition lands.

| Function                           | Trigger                              | Purpose                                                                             |
| ---------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------- |
| `createEmployeeUser`               | callable (admin only)                | Create Firebase Auth user + `users/{uid}` doc                                       |
| `revokeUserSessions`               | callable (authenticated user)        | Revoke all refresh tokens after password change; forces other-device re-auth         |
| `deleteUserAccount`                | callable (authenticated user)        | Delete caller's Firestore data + Firebase Auth account atomically (preserves task history with "Deleted user" name) |
| `sendTaskAssignedNotification`     | Firestore `onCreate` tasks           | FCM push + `task_logs` entry + in-app notification to assignee                      |
| `sendTaskStatusNotification`       | Firestore `onUpdate` tasks           | Notify admins + creator on completion; always write a `task_logs` entry             |
| `sendTaskDeadlineReminders`        | cron `0 9 * * *` (Asia/Jerusalem)    | Progressive 72h + 24h reminders; deduped via `reminderSent72hAt` / `reminderSent24hAt` per-task Timestamp fields |
| `testTaskDeadlineReminders`        | callable (admin only)                | Dry-run of the deadline reminder sweep                                               |
| `sendOverdueTaskEscalations`       | cron `0 10 * * *` (Asia/Jerusalem)   | Overdue escalation; deduped via `lastOverdueReminderAt` / `lastOverdueEscalationAt`; notifies assignee + admins |
| `testOverdueTaskEscalations`       | callable (admin only)                | Dry-run of the escalation sweep                                                      |
| `generateRecurringTaskInstances`   | cron `0 6 * * *` (Asia/Jerusalem)    | Generates daily/weekly/monthly task instances from active templates; layered idempotency (deterministic ID + transaction existence check); multi-assignee support; template errors are isolated per-template and surfaced as in-app notifications to all admins |
| `recordAttendance`                 | callable (authenticated user)        | Server-authoritative check-in/out; reads `schedules/{userId}` to resolve status (`present`/`late`/`off_day_work`); appends/closes sessions in a Firestore transaction; writes `attendance_logs` entry |
| `adminCorrectAttendance`           | callable (admin only)                | Replaces sessions array with admin-provided correction; preserves `originalSessions` on first correction (audit trail); sorts sessions, computes durations; writes `correctedByName` |
| `adminResetAttendance`             | callable (admin only)                | Clears all sessions for one employee on one date; reads `schedules/{userId}` to classify the reset as `absent` or `off_day`; transaction overwrites attendance doc and writes audit entry to `attendance_logs` (action: `admin_reset`, includes `previousStatus`, `previousSessions`) |
| `sendDailyAbsenceMarker`           | cron `0 23 * * *` (Asia/Jerusalem)   | Reads `schedules/{userId}` per employee; marks employees with no sessions as `absent` (working day) or `off_day` (non-working day); skips employees who already have sessions |
| `onNewChatMessage`                 | Firestore `onCreate` `conversations/{cId}/messages/{mId}` | Skips system messages; updates `lastMessage` + `lastMessageAt` + increments `unreadCounts` atomically; sends localized FCM push per recipient on `chat_messages` channel; writes in-app notification per recipient; uses `Promise.allSettled` so per-recipient failures don't block others |
| `createInAppNotification`          | internal helper                      | Writes to `notifications` collection; used by all FCM-send paths                   |

All FCM push senders localize `notification.title`/`notification.body` per recipient using `users/{uid}.languageCode` (`en`/`ar`, fallback `en`).

All Asia/Jerusalem date math uses `ymdInJerusalem` / `jerusalemMidnightAsUTC` / `sameDayJerusalem` helpers — no raw UTC math.

## 7. Notifications Pipeline

`lib/core/services/notification_service.dart` wraps `flutter_local_notifications` for foreground display. `main.dart` wires:

- `FirebaseMessaging.onBackgroundMessage`
- `FirebaseMessaging.onMessage`
- `FirebaseMessaging.onMessageOpenedApp`
- `FirebaseMessaging.getInitialMessage`

All four deep-link to `RouteNames.taskDetails` using the FCM payload's `taskId`. The FCM token is written to `users/{uid}.fcmToken` inside `AuthCubit._setupFCM` after a successful sign-in / auth check. (FCM token isolation to a dedicated `fcm_tokens` collection is planned for the next release cycle.)

## 8. Theming, Constants, Shared Widgets

- `lib/core/theme/` — `AppTheme.lightTheme`, `AppTheme.darkTheme`, `ThemeCubit` (persisted via `shared_preferences`).
- `lib/core/constants/` — `app_colors.dart`, `app_sizes.dart`, `app_strings.dart`, `app_assets.dart`, `firebase_paths.dart`.
- `lib/shared/widgets/` — `AppCard`, `AppDrawer`, `AppPieChart`, `ChartLegend`, `EmptyStateWidget`, `PriorityBadge`, `SectionHeader`, `StatusBadge`.

Reach for these before rolling anything bespoke.

## 9. Localization

- JSON files in `assets/translations/` (`en.json`, `ar.json`).
- Supported locales hard-coded in `main.dart`.
- UI strings are always `'key'.tr()`. Error/state identifiers (e.g. `'not_authorized'`) are stored as translation keys too and resolved at the UI layer.
- **Known**: `easy_localization` re-exports `package:intl/intl.dart` which defines its own `TextDirection` class, shadowing Flutter's `dart:ui` `TextDirection` enum. Files that use both `easy_localization` and `Directionality` must add `hide TextDirection` to the `easy_localization` import.

## 10. Shorebird Patch Eligibility

| Surface | Patch-eligible |
| ------- | -------------- |
| Task status / counter / edit / templates UI | ✅ Pure Dart |
| Attendance UI (screens, cards, correction sheet) | ❌ `local_auth` native plugin in feature tree |
| FCM setup (background isolate) | ❌ Native |
| `flutter_local_notifications` channel config | ❌ Native |
| Translation JSON assets (`assets/translations/`) | ❌ **NOT supported** — confirmed 2026-06-16 on v1.4.0+7 Android. Shorebird excludes asset changes. Any translation change requires a full store binary. |

See `docs/release-checklist.md` for the complete patch-eligibility checklist.

## 11. Version & Branching

- **App version**: `1.5.0+8` in `pubspec.yaml` (next store release will be bumped to `1.6.0+9` before Shorebird release on `feat/chat-phase-2`). FlutterFire upgrade (firebase-ios-sdk 12.14.0) on `main`; Chat Phase 2 feature work in progress on `feat/chat-phase-2`.
- **Production branch**: `main`.
- **Feature branches**: `feat/<short-name>` or `fix/<short-name>`.
- **Chore / docs branches**: `chore/<short-name>`.

See `RULES.md` for the full git / commit policy.

## 12. Links to Other Workflow Docs

- [CURRENT_TASK.md](./CURRENT_TASK.md) — what we are working on right now.
- [BACKLOG.md](./BACKLOG.md) — prioritized work queue.
- [DECISIONS_LOG.md](./DECISIONS_LOG.md) — append-only log of non-trivial decisions.
- [RULES.md](./RULES.md) — coding rules, conventions, agent rules.
- [NEXT_STEPS.md](./NEXT_STEPS.md) — forward-looking ideas (not yet committed).
- [SESSION_LOG.md](./SESSION_LOG.md) — one entry per meaningful AI session.
- [docs/release-checklist.md](../release-checklist.md) — pre-release verification steps.
