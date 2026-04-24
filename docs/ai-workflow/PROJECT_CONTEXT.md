# Project Context

> Last updated: 2026-04-24
> Owner: Mohamed Odeh
> Audience: every AI agent and human developer working on this repo.

This file is a factual snapshot of the project. Update it whenever a fact changes (new module, new collection, new dependency, new branch convention, etc.). Never put task progress or backlog items here — those live in `CURRENT_TASK.md` and `BACKLOG.md`.

---

## 1. Overview

**Techno Staff** is a Flutter + Firebase staff and task-management application with a role-based access model:

- **Admin** — creates users, assigns tasks, monitors team performance via dashboards, exports PDF reports.
- **Employee** — receives assigned tasks, updates their status, reads notifications.

The app is bilingual (English + Arabic) with full RTL support and uses Firebase as the sole backend (Auth + Firestore + Cloud Functions + FCM).

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
| Utilities           | `uuid`, `intl`, `path_provider`              |

### Backend (Firebase)

| Concern             | Choice                                       |
| ------------------- | -------------------------------------------- |
| Auth                | `firebase_auth` `^6.3.0`                     |
| Firestore           | `cloud_firestore` `^6.2.0`                   |
| Cloud Functions     | `cloud_functions` `^6.1.0` (Node 22 runtime) |
| Push messaging      | `firebase_messaging` `^16.1.3`               |
| Firebase project id | `techno-staff`                               |

### Quality

- `flutter_lints` `^5.0.0` for the Flutter client.
- ESLint (Google config) for `functions/` — runs as Firebase `predeploy`.

## 3. Architecture

Feature-first clean architecture under `lib/features/<feature>/`:

```
lib/
├── app/                  # App bootstrap + top-level MultiBlocProvider wiring
├── core/                 # Routing, theme, constants, services (cross-cutting)
├── shared/widgets/       # Reusable UI components
├── features/
│   └── <feature>/
│       ├── data/         # Firestore DTOs + repositories
│       ├── domain/       # Plain domain types (only where needed)
│       └── presentation/ # cubit/ + screens/
├── firebase_options.dart # Generated — do not hand-edit
└── main.dart
```

All repositories and Cubits are constructed in `lib/app/app.dart` and injected into a single top-level `MultiBlocProvider`. Features consume them via `context.read<XCubit>()`.

Navigation goes through `AppRouter.onGenerateRoute` (see `lib/core/routes/`). A global `AppNavigator.navigatorKey` lets background FCM handlers route without a `BuildContext`.

## 4. Modules

| Feature         | Role(s)  | Purpose                                                                        |
| --------------- | -------- | ------------------------------------------------------------------------------ |
| `splash`        | all      | Boot + initial auth-state routing                                              |
| `auth`          | all      | Login, sign-out, FCM token registration                                        |
| `admin`         | admin    | Admin home shell                                                               |
| `employee`      | employee | Employee home shell                                                            |
| `employees`     | admin    | Staff CRUD (creation goes through `createEmployeeUser` callable)               |
| `tasks`         | all      | Task list, details, create/edit by creator or admin, status updates (assignee) |
| `dashboard`     | admin    | Charts, filters (today/week/month), team performance, trend                    |
| `reports`       | admin    | Reporting + PDF export                                                         |
| `notifications` | all      | In-app notification feed with swipe-to-read and grouping                       |
| `settings`      | all      | Theme, language, sign out                                                      |

## 5. Firestore Data Model

| Collection                       | Client write access                                                                                                                                              | Notes                                                                                                |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `users/{uid}`                    | admin: full; employee: own `fcmToken` only                                                                                                                       | Read access is any authenticated user; shape: `{ email, name, role, isActive, fcmToken, createdAt }` |
| `tasks/{taskId}`                 | any authenticated user can create when `assignedBy == auth.uid`; creator + admin: full update/delete (with immutable `assignedBy`); assignee: status fields only | Rules enforce `onlyAllowedTaskStatusFieldsChanged` and `assignedBy` immutability                     |
| `task_logs/{logId}`              | **none — server-only**                                                                                                                                           | Audit trail written by Cloud Functions                                                               |
| `notifications/{notificationId}` | server writes; client toggles `isRead`                                                                                                                           | Per-user in-app feed                                                                                 |

Field-name constants live in `lib/core/constants/firebase_paths.dart`. String literals for Firestore paths are not allowed in feature code (see `RULES.md`).

## 6. Cloud Functions

Single file: `functions/index.js` (Node 22).

| Function                       | Trigger                            | Purpose                                                                             |
| ------------------------------ | ---------------------------------- | ----------------------------------------------------------------------------------- |
| `createEmployeeUser`           | callable (admin only)              | Create Firebase Auth user + `users/{uid}` doc                                       |
| `sendTaskAssignedNotification` | Firestore `onCreate` tasks         | FCM push + log + in-app notification                                                |
| `sendTaskStatusNotification`   | Firestore `onUpdate` tasks         | Notify admins + creator on completion; always log                                   |
| `sendTaskDeadlineReminders`    | cron `0 9 * * *` (Asia/Jerusalem)  | 24h-before reminders                                                                |
| `testTaskDeadlineReminders`    | admin-triggered callable           | Dry-run of the deadline reminder                                                    |
| `sendOverdueTaskEscalations`   | cron `0 10 * * *` (Asia/Jerusalem) | Overdue escalation, deduped via `lastOverdueReminderAt` / `lastOverdueEscalationAt` |
| `testOverdueTaskEscalations`   | admin-triggered callable           | Dry-run of the escalation                                                           |
| `createInAppNotification`      | helper                             | Writes to `notifications` collection                                                |

## 7. Notifications Pipeline

`lib/core/services/notification_service.dart` wraps `flutter_local_notifications` for foreground display. `main.dart` wires:

- `FirebaseMessaging.onBackgroundMessage`
- `FirebaseMessaging.onMessage`
- `FirebaseMessaging.onMessageOpenedApp`
- `FirebaseMessaging.getInitialMessage`

All four deep-link to `RouteNames.taskDetails` using the FCM payload's `taskId`. The FCM token is written to `users/{uid}.fcmToken` inside `AuthCubit._setupFCM` after a successful sign-in / auth check.

## 8. Theming, Constants, Shared Widgets

- `lib/core/theme/` — `AppTheme.lightTheme`, `AppTheme.darkTheme`, `ThemeCubit` (persisted mode).
- `lib/core/constants/` — `app_colors.dart`, `app_sizes.dart`, `app_strings.dart`, `app_assets.dart`, `firebase_paths.dart`.
- `lib/shared/widgets/` — `AppCard`, `AppDrawer`, `AppPieChart`, `ChartLegend`, `EmptyStateWidget`, `PriorityBadge`, `SectionHeader`, `StatusBadge`.

Reach for these before rolling anything bespoke.

## 9. Localization

- JSON files in `assets/translations/` (`en.json`, `ar.json`).
- Supported locales hard-coded in `main.dart`.
- UI strings are always `'key'.tr()`. Error/state identifiers (e.g. `'not_authorized'`) are stored as translation keys too and resolved at the UI layer.

## 10. Version & Branching

- **App version**: `1.0.0+1` (pre-release).
- **Production branch**: `main`.
- **Integration branch**: `dev` — all feature work merges here first.
- **Feature branches**: `feature/<short-name>` (many already merged).
- **Chore / docs branches**: `chore/<short-name>`.

See `RULES.md` for the full git / commit policy.

## 11. Links to Other Workflow Docs

- [CURRENT_TASK.md](./CURRENT_TASK.md) — what we are working on right now.
- [BACKLOG.md](./BACKLOG.md) — prioritized work queue.
- [DECISIONS_LOG.md](./DECISIONS_LOG.md) — append-only log of non-trivial decisions.
- [RULES.md](./RULES.md) — coding rules, conventions, agent rules.
- [NEXT_STEPS.md](./NEXT_STEPS.md) — forward-looking ideas (not yet committed).
- [SESSION_LOG.md](./SESSION_LOG.md) — one entry per meaningful AI session.
