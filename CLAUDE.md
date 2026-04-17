# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Flutter app (run from repo root):
- `flutter pub get` — install Dart deps
- `flutter run` — run on the connected device/emulator
- `flutter analyze` — static analysis (lints from `flutter_lints`)
- `flutter test` — run Dart/widget tests
- `flutter test test/path/to/file_test.dart --plain-name "<name>"` — run a single test
- `flutter build apk` / `flutter build ios` / `flutter build web` — platform builds

Firebase Cloud Functions (run from `functions/`):
- `npm run lint` — ESLint (Google config); also runs as Firebase `predeploy`
- `npm run serve` — local emulator for functions
- `npm run deploy` — `firebase deploy --only functions`
- `npm run logs` — tail function logs

Firebase project id: `techno-staff` (see `.firebaserc`, `lib/firebase_options.dart`).

## Architecture

Flutter + Firebase staff/task-management app with two user roles (`admin`, `employee`) gated by Firestore rules.

### App bootstrap (`lib/main.dart` → `lib/app/app.dart`)
`main()` initializes Firebase, EasyLocalization (en/ar, assets in `assets/translations/`), and the local/FCM notification pipeline, then constructs all repositories and wires them into a single top-level `MultiBlocProvider`. Every `Cubit` is provided globally — features read them via `context.read<XCubit>()` rather than creating their own. `TechnoStaffApp` drives navigation with a global `AppNavigator.navigatorKey` (used from background FCM handlers) and `AppRouter.onGenerateRoute`.

### Feature layout (`lib/features/<feature>/`)
Each feature follows a clean-architecture-ish split:
- `data/` — `models/` (Firestore DTOs with `fromMap`/`toMap`) and `repositories/` (wrap `FirebaseFirestore`/`FirebaseAuth`/`FirebaseFunctions`)
- `domain/models/` — plain domain types (only where needed, e.g. `auth/domain/models/app_user.dart`)
- `presentation/` — `cubit/` (Bloc `Cubit` + state class) and `screens/` (widgets that consume cubits)

Features: `auth`, `admin`, `employee`, `employees`, `tasks`, `dashboard`, `reports`, `notifications`, `settings`, `splash`. `admin` and `employee` are role-specific home shells; `employees` is the admin CRUD for staff.

State management is **flutter_bloc Cubit** (no `Bloc` event classes). State classes are immutable with `copyWith` + explicit `clear*` flags (see `AuthState` pattern in `lib/features/auth/presentation/cubit/auth_cubit.dart`). Copy this pattern when adding new state.

### Routing (`lib/core/routes/`)
- `route_names.dart` — route name constants
- `app_router.dart` — single `onGenerateRoute` switch, passes typed `arguments` (e.g. `TaskModel` for `editTask`, `String taskId` for `taskDetails` when coming from an FCM payload)
- `app_navigator.dart` — global `navigatorKey` so background isolates / notification taps can navigate without a `BuildContext`

`TaskDetailsLoaderScreen` exists because FCM payloads carry a task id (string) while in-app navigation can pass a full `TaskModel` — the loader fetches by id when needed.

### Firestore data model
Collections (see `firestore.rules` for the authoritative access matrix):
- `users/{uid}` — `{ email, name, role: 'admin'|'employee', isActive, fcmToken, createdAt }`. Employees may only update their own `fcmToken`; admins are full CRUD.
- `tasks/{taskId}` — assignee can only patch `status/updatedAt/completedAt/updatedBy/updatedByName` (enforced by `onlyAllowedTaskStatusFieldsChanged` in rules); the creator (`assignedBy`) and admins can edit freely.
- `task_logs/{logId}` — **server-written only** (`allow write: if false`). All entries come from Cloud Functions; do not write to this collection from the Flutter client.
- `notifications/{notificationId}` — per-user in-app notifications, server-created; the client can only flip `isRead`.

Field-name constants live in `lib/core/constants/firebase_paths.dart`. Prefer these over string literals when touching Firestore.

### Cloud Functions (`functions/index.js`)
All server-side automation lives here (single JS file, Node 22). Responsibilities:
- `createEmployeeUser` — admin-only callable that creates Firebase Auth user + `users/{uid}` doc (the client cannot create Auth users directly, so employee onboarding must go through this)
- `sendTaskAssignedNotification` (onCreate tasks) — FCM + task_log + in-app notification
- `sendTaskStatusNotification` (onUpdate tasks) — notifies admins + creator on completion, always writes a `task_logs` entry
- `sendTaskDeadlineReminders` (cron `0 9 * * *` Asia/Jerusalem) — 24h-before reminders; `testTaskDeadlineReminders` is the admin-triggered dry run
- `sendOverdueTaskEscalations` (cron `0 10 * * *` Asia/Jerusalem) — dedupes via `lastOverdueReminderAt` / `lastOverdueEscalationAt` fields on the task doc; `testOverdueTaskEscalations` is the dry-run variant
- `createInAppNotification` — shared helper that writes to the `notifications` collection

When adding a task-status transition or a new task-lifecycle event, both the FCM push **and** the `task_logs` / `notifications` writes live here — the client does not duplicate them.

### Notifications (`lib/core/services/notification_service.dart`)
Wraps `flutter_local_notifications` for foreground display and deep-links via `AppNavigator.navigatorKey` on tap. `main.dart` also wires `FirebaseMessaging.onBackgroundMessage`, `onMessage`, `onMessageOpenedApp`, and `getInitialMessage` — all of them route to `RouteNames.taskDetails` with the FCM `taskId` payload. The FCM token is written to `users/{uid}.fcmToken` inside `AuthCubit._setupFCM` after a successful sign-in / auth check.

### Theming & shared UI
- `lib/core/theme/` — `AppTheme.lightTheme` / `darkTheme` + `ThemeCubit` (persisted theme mode)
- `lib/core/constants/` — `app_colors.dart`, `app_sizes.dart`, `app_strings.dart`, `app_assets.dart`, `firebase_paths.dart`
- `lib/shared/widgets/` — reusable UI (`AppCard`, `AppDrawer`, `AppPieChart`, `ChartLegend`, `EmptyStateWidget`, `PriorityBadge`, `SectionHeader`, `StatusBadge`). Prefer these over re-rolling status/priority chips or empty states.

### Localization
`easy_localization` with JSON files in `assets/translations/` (en, ar). Supported locales are hard-coded in `main.dart`. Use translation keys (e.g. `'not_authorized'`, `'invalid_login_credentials'`) as error message identifiers in state — the UI layer calls `.tr()` on them.
