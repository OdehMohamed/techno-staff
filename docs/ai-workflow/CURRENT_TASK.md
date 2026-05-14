# Current Task

> Last updated: 2026-05-14

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**v1.1.0 stabilization: offline connectivity guard + pull-to-refresh**

Branch: `feat/connectivity-and-refresh` (created from `dev` after PR #29 squash-merge, 2026-05-14).

These are the two remaining v1.1.0 blockers before cutting the testing release:

1. **Offline guard** — a top banner that appears whenever the device has no network connection, so testers never silently interact with stale Firestore cache data.
2. **Pull-to-refresh** — manual refresh gesture on the four highest-traffic screens, implemented without full-screen loading flashes.

Both are client-only. Zero changes to Firestore rules, Cloud Functions, data models, routing, or existing cubit state shape (other than adding an optional `silent` parameter to fetch methods).

---

## Branch

`feat/connectivity-and-refresh` (created from `dev` 2026-05-14)

---

## Locked planning decisions

1. **Package:** `connectivity_plus ^6.x` (Flutter team official; no location permission needed). Reports network presence, not true internet reachability — sufficient for our Firebase use case.
2. **Overlay mechanism:** `MaterialApp.builder` Stack, NOT a route push. The overlay sits above all routes without touching the navigation stack.
3. **Overlay style:** top-anchored red banner with localized text. Lightweight — no modal, no blocking interaction.
4. **No auto-refresh on reconnect** in this PR. When the banner disappears, the user pulls to refresh manually.
5. **Silent refresh parameter:** `{bool silent = false}` added to all cubit fetch methods called from pull-to-refresh. When `silent: true`, the loading status emit is skipped — existing data stays visible during refresh.
6. **Empty/error states are wrapped in a single-item `ListView`** inside every `RefreshIndicator` so the drag gesture always activates (a non-scrollable widget blocks the indicator).
7. **Screens in scope:** `TasksScreen`, `EmployeeHomeScreen`, `AdminDashboardScreen`, `EmployeesScreen`.
8. **Screens out of scope:** `TaskDetailsScreen`, `TaskDetailsLoaderScreen`, all form screens, `ReportsScreen`, `NotificationsScreen` (already has it), `RecurringTasksScreen` (already has it), settings/auth/about screens.
9. **One translation key:** `no_internet_connection` × 2 locales.
10. **No backend changes** of any kind.

---

## 1. Architecture (read this before any code)

### 1.1 The connectivity invariant

The offline banner is **read-only context, not a gate**. It does not block navigation, disable buttons, or intercept writes. Firebase's offline write queue is left intact — Firestore will sync queued writes when connectivity returns. The banner's sole purpose is to inform the user that data may be stale and that network-dependent actions may fail.

**Do not:**
- Push a `NoInternetScreen` onto the navigation stack (breaks FCM deep links, AuthCubit routing, and form state)
- Disable any buttons or form fields while offline
- Intercept Firestore reads/writes
- Auto-refresh any cubit when connectivity restores

### 1.2 The silent-refresh invariant

`{bool silent = false}` is a purely cosmetic parameter. It controls whether the `loading` status is emitted before the fetch. **The fetch always runs.** On success, the new data replaces the old (whether or not the loading state was shown). On error, the error state is always emitted regardless of `silent` — there is no silent failure path.

```
silent = false (initial load):  emit(loading) → fetch → emit(loaded or error)
silent = true  (pull-to-refresh): [no emit]  → fetch → emit(loaded or error)
```

This means a failed silent refresh removes the existing list and shows the error state — correct, because the connectivity banner is visible and explains why.

### 1.3 The RefreshIndicator invariant

Every `RefreshIndicator` must have a **scrollable child at all times**, even when the content is empty or in an error state. The rule:

- If the screen currently shows a `ListView` of items → `RefreshIndicator` wraps the `ListView` directly.
- If the screen shows an empty state or error widget (non-scrollable) → wrap it in `ListView(children: [widget])` so the drag gesture reaches the indicator.
- **Never** wrap a `DefaultTabController` or `TabBarView` in a single `RefreshIndicator` — the tab controller consumes the horizontal swipe before the vertical drag reaches the indicator. Each tab content must have its own `RefreshIndicator`.

---

## 2. ConnectivityService

**File:** `lib/core/services/connectivity_service.dart` (new file, ~40 lines)

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  Stream<bool> get isConnectedStream => Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
}
```

Notes:
- `onConnectivityChanged` emits `List<ConnectivityResult>` in `connectivity_plus ^6.x` (changed from a single value in v5).
- The stream maps the list to `true` if any result is not `none` — handles multi-network devices (WiFi + cellular) correctly.
- No singleton state for current connectivity — the `StreamBuilder` in `app.dart` handles initial state from the stream's first event.
- No `Cubit` or `BLoC` for connectivity — a `StreamBuilder` is sufficient. Connectivity is UI-only context; it needs no business logic.

---

## 3. App-level overlay (`app.dart`)

**File:** `lib/app/app.dart` (delta: ~25 lines)

Add a `StreamBuilder<bool>` inside `MaterialApp.builder`. The builder wraps every screen with a `Stack`. When `isConnected == false`, a `Positioned` red banner appears at the top.

```dart
MaterialApp(
  // ... existing config unchanged ...
  builder: (context, child) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.isConnectedStream,
      initialData: true, // optimistic — banner hides until first offline event
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        return Stack(
          children: [
            child!,
            if (!isConnected)
              Positioned(
                top: MediaQuery.of(context).viewPadding.top,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.red.shade700,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: Text(
                      'no_internet_connection'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  },
)
```

Implementation notes:
- `initialData: true` so the banner is hidden on app start — it only appears after the first offline event from the stream.
- `MediaQuery.of(context).viewPadding.top` accounts for the status bar / notch so the banner starts below the OS status bar.
- `Material` widget is required for `Text` to render correctly outside a `Scaffold` context.
- The `!isConnected` guard means the `Positioned` widget is completely absent from the tree when online — no repaint cost when connected.
- `.tr()` works inside `builder` because `builder` runs below the `MaterialApp`'s localization delegates.
- RTL direction is inherited from `MaterialApp`'s `Directionality` — the banner renders correctly in Arabic.

**Import to add:** `import '../core/services/connectivity_service.dart';`

---

## 4. Cubit changes — silent parameter

### 4.1 `TasksCubit` (`lib/features/tasks/presentation/cubit/tasks_cubit.dart`)

Add `{bool silent = false}` to three fetch methods:

```dart
Future<void> fetchAllTasks({bool silent = false}) async {
  if (!silent) emit(state.copyWith(status: TasksStatus.loading, clearError: true));
  try {
    final tasks = await _tasksRepository.getAllTasks();
    emit(state.copyWith(status: TasksStatus.loaded, tasks: tasks));
  } catch (e) {
    emit(state.copyWith(status: TasksStatus.error, errorMessage: e.toString()));
  }
}

Future<void> fetchTasksAssignedTo(String userId, {bool silent = false}) async {
  if (!silent) emit(state.copyWith(tasksAssignedToMeStatus: TasksStatus.loading, clearAssignedError: true));
  try {
    final tasks = await _tasksRepository.getTasksAssignedTo(userId);
    emit(state.copyWith(tasksAssignedToMeStatus: TasksStatus.loaded, tasksAssignedToMe: tasks));
  } catch (e) {
    emit(state.copyWith(tasksAssignedToMeStatus: TasksStatus.error, tasksAssignedToMeErrorMessage: e.toString()));
  }
}

Future<void> fetchTasksCreatedBy(String userId, {bool silent = false}) async {
  if (!silent) emit(state.copyWith(tasksCreatedByMeStatus: TasksStatus.loading, clearCreatedError: true));
  try {
    final tasks = await _tasksRepository.getTasksCreatedBy(userId);
    emit(state.copyWith(tasksCreatedByMeStatus: TasksStatus.loaded, tasksCreatedByMe: tasks));
  } catch (e) {
    emit(state.copyWith(tasksCreatedByMeStatus: TasksStatus.error, tasksCreatedByMeErrorMessage: e.toString()));
  }
}
```

The exact `clearAssignedError` / `clearCreatedError` flag names should match whatever the existing `TasksState.copyWith` already supports — **read the actual cubit before implementing** to match the existing state API exactly.

### 4.2 `DashboardCubit` (`lib/features/dashboard/presentation/cubit/dashboard_cubit.dart`)

```dart
Future<void> loadAdminStats({bool silent = false}) async {
  if (!silent) emit(state.copyWith(status: DashboardStatus.loading));
  try {
    final stats = await _repo.getAdminStats();
    emit(state.copyWith(status: DashboardStatus.loaded, stats: stats));
  } catch (e) {
    emit(state.copyWith(status: DashboardStatus.error, errorMessage: e.toString()));
  }
}

Future<void> loadEmployeeStats(String userId, {bool silent = false}) async {
  if (!silent) emit(state.copyWith(status: DashboardStatus.loading));
  try {
    final stats = await _repo.getEmployeeStats(userId);
    emit(state.copyWith(status: DashboardStatus.loaded, stats: stats));
  } catch (e) {
    emit(state.copyWith(status: DashboardStatus.error, errorMessage: e.toString()));
  }
}
```

Again — **read the actual cubit** before implementing. The pseudocode above shows intent; exact field names must match the existing state.

### 4.3 `EmployeesCubit` (`lib/features/employees/presentation/cubit/employees_cubit.dart`)

```dart
Future<void> fetchEmployees({bool silent = false}) async {
  if (!silent) emit(state.copyWith(status: EmployeesStatus.loading));
  try {
    final employees = await _repo.getEmployees();
    emit(state.copyWith(status: EmployeesStatus.loaded, employees: employees));
  } catch (e) {
    emit(state.copyWith(status: EmployeesStatus.error, errorMessage: e.toString()));
  }
}
```

---

## 5. Screen changes

### 5.1 `TasksScreen` (`lib/features/tasks/presentation/screens/tasks_screen.dart`)

**`_loadTasks` helper** — add `{bool silent = false}` and pass it through:

```dart
void _loadTasks({bool silent = false}) {
  final user = context.read<AuthCubit>().state.user;
  if (user == null) return;
  if (user.role == 'admin') {
    context.read<TasksCubit>().fetchAllTasks(silent: silent);
    context.read<TasksCubit>().fetchTasksAssignedTo(user.id, silent: silent);
  } else {
    context.read<TasksCubit>().fetchTasksAssignedTo(user.id, silent: silent);
    context.read<TasksCubit>().fetchTasksCreatedBy(user.id, silent: silent);
  }
}
```

**`_buildTasksTabContent`** — wrap the return value in `RefreshIndicator`:

```dart
Widget _buildTasksTabContent({...}) {
  return RefreshIndicator(
    onRefresh: () async => _loadTasks(silent: true),
    child: _buildTasksTabBody(
      status: status,
      errorKey: errorKey,
      tasks: tasks,
      currentUser: currentUser,
      isAdmin: isAdmin,
    ),
  );
}

Widget _buildTasksTabBody({...}) {
  if (status == TasksStatus.loading && tasks.isEmpty) {
    // Initial load only — show spinner in a scrollable container so
    // RefreshIndicator drag still works.
    return ListView(
      children: const [
        SizedBox(height: 200),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
  if (status == TasksStatus.error) {
    return ListView(
      children: [EmptyStateWidget(icon: Icons.error_outline, titleKey: errorKey ?? '')],
    );
  }
  final filteredTasks = _applyFilters(tasks);
  if (filteredTasks.isEmpty) {
    return ListView(
      children: [
        EmptyStateWidget(
          icon: tasks.isNotEmpty ? Icons.search_off : Icons.task_alt_outlined,
          titleKey: tasks.isNotEmpty ? 'no_matching_tasks' : 'no_tasks_found',
        ),
      ],
    );
  }
  return ListView.separated(
    // existing item builder unchanged
  );
}
```

Key invariant: the `if (status == TasksStatus.loading && tasks.isEmpty)` guard on the loading check ensures silent refreshes (where `tasks` is already populated) skip the spinner and let the `RefreshIndicator`'s own indicator serve as the only visual.

### 5.2 `EmployeeHomeScreen` (`lib/features/employee/presentation/screens/employee_home_screen.dart`)

Extract a `_loadData({bool silent = false})` helper and call it from `initState` and from the `RefreshIndicator.onRefresh`:

```dart
Future<void> _loadData({bool silent = false}) async {
  final user = context.read<AuthCubit>().state.user;
  if (user == null) return;
  context.read<TasksCubit>().fetchTasksAssignedTo(user.id, silent: silent);
  context.read<DashboardCubit>().loadEmployeeStats(user.id, silent: silent);
}
```

The body `SingleChildScrollView` (or `ListView`) becomes the child of a `RefreshIndicator`. The existing nested `BlocBuilder` loading guard (`if (dashboardState.status == loading || tasksState.tasksAssignedToMeStatus == loading) return CircularProgressIndicator()`) must also respect silent: only show the full-screen spinner when both data sources are in initial load state (no data yet):

```dart
final isInitialLoad =
    (dashboardState.status == DashboardStatus.loading && dashboardState.stats == null) ||
    (tasksState.tasksAssignedToMeStatus == TasksStatus.loading && tasksState.tasksAssignedToMe.isEmpty);

if (isInitialLoad) {
  return const Center(child: CircularProgressIndicator());
}
```

**Read the actual screen first** to match the exact state field names.

### 5.3 `AdminDashboardScreen` (`lib/features/admin/presentation/screens/admin_dashboard_screen.dart`)

Same pattern: extract `_loadData({bool silent = false})`, wrap scrollable body in `RefreshIndicator`, guard full-screen spinner only on initial load (stats null / empty).

### 5.4 `EmployeesScreen` (`lib/features/employees/presentation/screens/employees_screen.dart`)

Straightforward — the screen already has a `ListView` of employees. Wrap it in `RefreshIndicator`:

```dart
RefreshIndicator(
  onRefresh: () async {
    context.read<EmployeesCubit>().fetchEmployees(silent: true);
  },
  child: ListView.separated(
    // existing items unchanged
  ),
)
```

The empty state (`EmptyStateWidget`) and error state must also be wrapped in a `ListView` for the same scrollability reason.

---

## 6. Translations

Add one key × 2 locales. Existing parity is 241/241; after this change: 242/242.

```json
// en.json — append after "weekday_sun"
"no_internet_connection": "No internet connection"

// ar.json — append after "weekday_sun"
"no_internet_connection": "لا يوجد اتصال بالإنترنت"
```

---

## 7. `pubspec.yaml`

Add under `dependencies`:

```yaml
connectivity_plus: ^6.0.0
```

Run `flutter pub get` after adding.

---

## 8. Affected files

| File | Change | Type |
|---|---|---|
| `pubspec.yaml` | Add `connectivity_plus: ^6.0.0` | +1 dep |
| `lib/core/services/connectivity_service.dart` | New singleton stream wrapper | New, ~25 lines |
| `lib/app/app.dart` | Add `StreamBuilder` + `MaterialApp.builder` overlay | ~25 line delta |
| `lib/features/tasks/presentation/cubit/tasks_cubit.dart` | `{bool silent = false}` on 3 fetch methods | ~6 line delta |
| `lib/features/dashboard/presentation/cubit/dashboard_cubit.dart` | `{bool silent = false}` on 2 methods | ~4 line delta |
| `lib/features/employees/presentation/cubit/employees_cubit.dart` | `{bool silent = false}` on `fetchEmployees` | ~2 line delta |
| `lib/features/tasks/presentation/screens/tasks_screen.dart` | `_loadTasks` silent param + `RefreshIndicator` per tab + `ListView`-wrap all states | ~50 line delta |
| `lib/features/employee/presentation/screens/employee_home_screen.dart` | `_loadData` helper + `RefreshIndicator` + initial-load guard | ~25 line delta |
| `lib/features/admin/presentation/screens/admin_dashboard_screen.dart` | `_loadData` helper + `RefreshIndicator` + initial-load guard | ~20 line delta |
| `lib/features/employees/presentation/screens/employees_screen.dart` | `RefreshIndicator` + `ListView`-wrap states | ~15 line delta |
| `assets/translations/en.json` | 1 new key | +1 line |
| `assets/translations/ar.json` | 1 new key | +1 line |

**Zero changes to:** Firestore rules, `functions/index.js`, any data model, any route, `TasksState`, `TaskDetailsScreen`, `ReportsScreen`, any form screen, any auth/settings screen.

---

## 9. Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all existing tests green. No new unit tests required (the `silent` parameter is a trivial boolean branch; `RefreshIndicator` changes are UI-only). **However**, if the implementing agent finds that the `TasksCubit` tests assert on the number of emitted states, those tests may need updating to account for the skipped `loading` emit when `silent: true`. Read the existing tests before implementing.
- `npm run lint` — N/A (no Cloud Function changes), but run it anyway to confirm no regressions.

---

## 10. Smoke tests

Annotated with whether the project owner or agent can run them.

1. **(real) Airplane mode — offline banner appears** — put device in airplane mode, open app. A red "No internet connection" banner appears at the top within a few seconds. Arabic locale: banner shows in Arabic. Banner disappears when airplane mode is turned off.

2. **(real) Banner does not block interaction** — while offline, navigate between screens, open a task, tap buttons. All navigation still works; only network-dependent fetches fail (which is expected and the banner explains).

3. **(real) TasksScreen pull-to-refresh — admin** — sign in as admin. Admin assigns a new task to employee on a second device. On the first device (TasksScreen, "All tasks" tab), pull down. The new task appears without a full-screen spinner flash.

4. **(real) TasksScreen pull-to-refresh — employee** — sign in as employee. Pull down on "Assigned to me" tab. Task list updates without loading flash.

5. **(real) EmployeeHomeScreen pull-to-refresh** — pull down on employee home. Stats and task list refresh silently.

6. **(real) AdminDashboardScreen pull-to-refresh** — pull down on admin dashboard. Stats refresh silently.

7. **(real) EmployeesScreen pull-to-refresh** — admin adds employee on another device/web. Pull down on employees list. New employee appears without loading flash.

8. **(emulator/CI) Empty state is still refreshable** — when there are no tasks (fresh account), pull down on the "All tasks" tab. The `RefreshIndicator` spinner appears and the refresh runs (no tasks, empty state again). Confirms the `ListView` wrapper is in place.

9. **(emulator/CI) Initial load still shows spinner** — open TasksScreen for the first time (initial fetch). Full-screen `CircularProgressIndicator` appears while loading. Confirms `silent = false` path is unchanged.

10. **(emulator/CI) Silent refresh error path** — put device offline, pull-to-refresh on TasksScreen. The refresh runs (network fails), an error state appears. Confirms error is still emitted even when `silent = true`.

11. **(emulator/CI) Translation parity** — `python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"` → `242 242 []`.

12. **(real) Arabic RTL layout** — switch to Arabic locale. Banner text is right-aligned and displays correctly. Pull-to-refresh gestures work in RTL.

---

## 11. Definition of Done

- [ ] `connectivity_plus` added to `pubspec.yaml` and `flutter pub get` run.
- [ ] `ConnectivityService` exists at `lib/core/services/connectivity_service.dart`.
- [ ] `app.dart` wires the `StreamBuilder` in `MaterialApp.builder`; red banner appears/disappears correctly.
- [ ] `initialData: true` on the `StreamBuilder` so banner is hidden on cold start.
- [ ] `{bool silent = false}` added to `fetchAllTasks`, `fetchTasksAssignedTo`, `fetchTasksCreatedBy` in `TasksCubit`.
- [ ] `{bool silent = false}` added to `loadAdminStats`, `loadEmployeeStats` in `DashboardCubit`.
- [ ] `{bool silent = false}` added to `fetchEmployees` in `EmployeesCubit`.
- [ ] `TasksScreen._loadTasks` passes `silent` through; each tab's content is wrapped in its own `RefreshIndicator`.
- [ ] Empty and error states in `TasksScreen` are `ListView`-wrapped.
- [ ] Loading spinner in `TasksScreen` only shows when data list is empty (initial load guard).
- [ ] `EmployeeHomeScreen` has `RefreshIndicator` + `_loadData` helper + initial-load guard.
- [ ] `AdminDashboardScreen` has `RefreshIndicator` + `_loadData` helper + initial-load guard.
- [ ] `EmployeesScreen` has `RefreshIndicator`; empty/error states are `ListView`-wrapped.
- [ ] `no_internet_connection` key added to both `en.json` and `ar.json`.
- [ ] Translation parity check: `242 242 []`.
- [ ] `flutter analyze` clean.
- [ ] `flutter test` all green.
- [ ] No changes outside the files listed in §8.
- [ ] Workflow docs updated (SESSION_LOG, BACKLOG, CURRENT_TASK reset).
- [ ] PR title: `feat(app): add offline connectivity banner and pull-to-refresh on key screens`.

---

## 12. Risks

- **`connectivity_plus` v6 API:** `onConnectivityChanged` now emits `List<ConnectivityResult>` (changed from `ConnectivityResult` in v5). The `ConnectivityService` maps this list using `.any((r) => r != ConnectivityResult.none)`. **Do not** use the v5 single-value API.
- **`initialData: true`:** Without this, `StreamBuilder` starts with `snapshot.data == null`, making `snapshot.data ?? true` evaluate as `true` (connected) — which is the correct initial state. Either `initialData: true` or the `?? true` fallback achieves the same result. Include both for clarity.
- **`MediaQuery` inside `builder`:** `builder` runs below `MaterialApp`, so `MediaQuery.of(context)` is available. However, on the very first frame before layout, `viewPadding` may be zero. This resolves on the next frame — acceptable.
- **Cubit state field names:** The pseudocode in §4 uses illustrative names. **The agent must read the actual cubit and state files** before implementing to match the exact existing API. A mismatch in field names will cause a compile error or a lost emit.
- **Existing `TasksCubit` tests:** Any test that asserts `expectLater(cubit.stream, emits([loading, loaded]))` will pass when `silent: false` (unchanged). Tests calling with `silent: true` will see only `[loaded]`. Check the test file before implementation.
- **`EmployeeHomeScreen` nested `BlocBuilder` loading guard:** The existing guard checks `tasksState.tasksAssignedToMeStatus == TasksStatus.loading` — this fires during silent refresh too, causing a flash. The fix is to also check that `tasksAssignedToMe.isEmpty` (initial load only). **Read the actual screen** to locate the exact guard condition.

---

## 13. Out of scope (do not pull in)

- `internet_connection_checker_plus` or HTTP-ping reachability (overkill; `connectivity_plus` is sufficient)
- Auto-refresh when connectivity restores
- Queued-write conflict resolution or offline write disabling
- Connectivity state as a `Cubit` or `BLoC`
- `RefreshIndicator` on `NotificationsScreen` (already has it)
- `RefreshIndicator` on `RecurringTasksScreen` (already has it)
- `RefreshIndicator` on `TaskDetailsScreen`, `ReportsScreen`, form screens
- Any visual change beyond the red top banner (no snackbar, no bottom sheet, no modal)
- Progressive deadline reminders (v1.1.1)
- UI/UX polish (v1.1.1)
- Attendance feature (v1.2.0)

---

## 14. Workflow doc updates required

| File | Change |
|---|---|
| `CURRENT_TASK.md` | Reset to "No active task — v1.1.0 ready for release cut" when PR merges |
| `BACKLOG.md` | Mark connectivity-and-refresh item Done with completion date and quality gate results |
| `SESSION_LOG.md` | Append implementation entry at the top |
| `DECISIONS_LOG.md` | Append: "`MaterialApp.builder` overlay chosen over route-push for offline guard — avoids FCM deep-link interference and form state loss" |
