# Current Task

> Last updated: 2026-05-08

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**v1.1 F3.A — Task countdown timer (adaptive screen-level ticker).**

Replace the static "Due date: yyyy-MM-dd" chip on the tasks list and task details screen with a live countdown that updates as time passes ("Due in 5h 32m", "Overdue by 2h", etc.). The countdown counts to **end-of-day of `dueDate`** so it stays consistent with the existing overdue logic across dashboard / reports / Cloud-Functions reminder paths. No data-model changes, no per-task time-of-day deadlines, no Cloud-Function changes.

The architectural risk in this feature is **rebuild churn**, not the countdown wording — a naïve implementation can rebuild N task cards every second on a list of 30+ tasks. The spec leads with the rebuild architecture below; UI / formatting details follow as application of those rules.

## Branch

`feat/task-countdown-timer` (created from `dev` after PR #26 merged on 2026-05-08).

## Locked planning decisions (audit round, 2026-05-08)

1. **Countdown semantics** — count to `endOfDay(dueDate)` (Option A from audit). Date-only model preserved. Aligns with `_endOfDay` usage in `dashboard_repository.dart`, `reports_screen.dart`, `pdf_report_service.dart`, and Cloud Functions reminder windows.
2. **Widget structure** — minimal-scope (Option B from audit). Introduce a private `CountdownChip` widget in the tasks feature; do **not** extract a `TaskCard` widget in v1.1. The existing inline `_buildTasksList` builder stays.
3. **Arabic numerals** — keep Hindu-Arabic digits (`1234`); do not switch to Eastern Arabic (`١٢٣٤`). Consistency with all existing dates / counters / charts.
4. **Ticker placement** — single adaptive screen-level ticker per consuming screen. No per-card `Timer.periodic`. No global app-wide ticker. No two-tier ticker.
5. **Rebuild scope** — ticker subscription bound to the `CountdownChip` leaf only. The parent `AppCard` / `InkWell` / `_buildTasksList` `itemBuilder` body must not rebuild on tick.
6. **Overdue visual** — error-color tint (red) on the chip when the task is overdue. Overdue stays a derived UI state. `StatusBadge` is **not** modified — overdue is the chip's job, not the status badge's.
7. **Task details parity** — `task_details_screen.dart` adopts the same `CountdownChip` widget. Each consuming screen owns its own ticker provider instance — no app-global ticker.

---

## 1. Architecture (locked — read this section before any UI work)

### 1.1 Components

```
┌──────────────────────────────────────────────────────────────────┐
│ TasksScreen (existing StatefulWidget — no behavior change here)  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ CountdownClockProvider (NEW StatefulWidget)                │  │
│  │   - Owns one Timer.periodic                                │  │
│  │   - Adaptive period (60s default, 1s when any visible task │  │
│  │     dueDate end-of-day is within 1h)                       │  │
│  │   - Pauses on AppLifecycleState.paused                     │  │
│  │   - Exposes ValueListenable<DateTime> currentTime          │  │
│  │                                                             │  │
│  │   ┌──────────────────────────────────────────────────────┐ │  │
│  │   │ ListView.separated (existing)                        │ │  │
│  │   │                                                       │ │  │
│  │   │   AppCard (existing)                                  │ │  │
│  │   │     ...                                               │ │  │
│  │   │     CountdownChip(dueDate: task.dueDate,             │ │  │
│  │   │                   isCompleted: task.status == 'completed') │
│  │   │       └─ ValueListenableBuilder<DateTime>            │ │  │
│  │   │           rebuilds ONLY this chip on tick             │ │  │
│  │   │     ...                                               │ │  │
│  │   └──────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 The clock provider — locked structure

`lib/features/tasks/presentation/widgets/countdown_clock_provider.dart` (new file, ~120 lines):

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Drives the per-screen adaptive countdown ticker. One instance per consuming
/// screen. NEVER instantiate at app-global level.
///
/// Architectural invariants (do not relax):
/// - Owns exactly one Timer.periodic.
/// - Period is 60s by default; switches to 1s only when at least one
///   `dueDates` entry has `endOfDay(dueDate) - now() < Duration(hours: 1)`
///   AND `> Duration.zero`.
/// - Pauses the timer on AppLifecycleState.paused/inactive/hidden;
///   resumes on resumed.
/// - Exposes `currentTime` as a ValueListenable<DateTime>.
/// - Subscribers rebuild via ValueListenableBuilder bound to the leaf chip.
class CountdownClockProvider extends StatefulWidget {
  final List<DateTime> dueDates;
  final Widget child;

  const CountdownClockProvider({
    super.key,
    required this.dueDates,
    required this.child,
  });

  static ValueListenable<DateTime> of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_CountdownClockScope>();
    assert(
      inherited != null,
      'No CountdownClockProvider found above CountdownChip in the tree.',
    );
    return inherited!.notifier;
  }

  @override
  State<CountdownClockProvider> createState() => _CountdownClockProviderState();
}

class _CountdownClockProviderState extends State<CountdownClockProvider>
    with WidgetsBindingObserver {
  late ValueNotifier<DateTime> _now;
  Timer? _timer;
  Duration _period = const Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _now = ValueNotifier<DateTime>(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _restartTicker();
  }

  @override
  void didUpdateWidget(covariant CountdownClockProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // dueDates list identity changes when the parent re-emits a new list.
    // Recompute period in case the closest-deadline bucket changed.
    _restartTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _now.value = DateTime.now();
      _restartTicker();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _restartTicker() {
    _timer?.cancel();
    _period = _resolvePeriod();
    _timer = Timer.periodic(_period, (_) {
      _now.value = DateTime.now();
      // If we crossed the 1h-to-deadline threshold while running at 60s,
      // upgrade to 1s on the next tick.
      final newPeriod = _resolvePeriod();
      if (newPeriod != _period) {
        _restartTicker();
      }
    });
  }

  Duration _resolvePeriod() {
    final now = DateTime.now();
    for (final dueDate in widget.dueDates) {
      final endOfDay = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        23,
        59,
        59,
      );
      final diff = endOfDay.difference(now);
      if (diff > Duration.zero && diff < const Duration(hours: 1)) {
        return const Duration(seconds: 1);
      }
    }
    return const Duration(seconds: 60);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CountdownClockScope(notifier: _now, child: widget.child);
  }
}

class _CountdownClockScope extends InheritedWidget {
  final ValueNotifier<DateTime> notifier;

  const _CountdownClockScope({required this.notifier, required super.child});

  @override
  bool updateShouldNotify(_CountdownClockScope oldWidget) =>
      notifier != oldWidget.notifier;
}
```

**Invariant guardrails — the implementing agent must not relax any of these:**

- ❌ **No `Timer.periodic` inside `CountdownChip` or any per-card widget.**
- ❌ **No `setState()` on `_TasksScreenState` or `_TaskDetailsScreenState` inside the tick callback** — the only thing that should change on tick is `ValueNotifier<DateTime>.value`, which `ValueListenableBuilder` consumes inside the chip.
- ❌ **No app-global `CountdownClockProvider`** in `app.dart` / `MultiBlocProvider`. One instance per consuming screen, mounted as a child of the `Scaffold` body.
- ❌ **No `BlocBuilder<TasksCubit, TasksState>` rebuild on tick.** The ticker is independent of the cubit; the cubit rebuilds happen on data change, the ticker rebuilds happen on time change. Don't merge them.
- ✅ **`dueDates` is recomputed once per cubit emission** (when `state.tasks` / `state.tasksAssignedToMe` / `state.tasksCreatedByMe` changes). Pass the relevant flat list down into the provider.
- ✅ **The chip subscribes via `ValueListenableBuilder<DateTime>`** scoped to the chip body only.

### 1.3 The chip — locked structure

`lib/features/tasks/presentation/widgets/countdown_chip.dart` (new file, ~150 lines):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'countdown_clock_provider.dart';

/// Pill chip that shows time-to-deadline (end-of-day of dueDate). Rebuilds
/// on every tick of the enclosing CountdownClockProvider, but the rebuild is
/// scoped to this widget only — parent AppCard/InkWell stay stable.
///
/// Hidden when isCompleted == true.
class CountdownChip extends StatelessWidget {
  final DateTime dueDate;
  final bool isCompleted;

  const CountdownChip({
    super.key,
    required this.dueDate,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) return const SizedBox.shrink();

    final clock = CountdownClockProvider.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: clock,
      builder: (context, now, _) {
        final endOfDay = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          23,
          59,
          59,
        );
        final remaining = endOfDay.difference(now);
        final visual = _resolveVisual(context, remaining);
        return _ChipBody(
          icon: visual.icon,
          label: _formatLabel(remaining, dueDate, now),
          background: visual.background,
          foreground: visual.foreground,
        );
      },
    );
  }

  String _formatLabel(Duration remaining, DateTime dueDate, DateTime now) {
    // See §2 (Formatting) for the locked label rules.
    // Implementation per buckets table; all wording goes through .tr() with
    // namedArgs — never concatenate translation strings with `+`.
  }

  _CountdownVisual _resolveVisual(BuildContext context, Duration remaining) {
    // See §3 (Visual states).
  }
}
```

**Implementing agent: fill `_formatLabel` and `_resolveVisual` per §2 and §3 below. Do not reorganize the architecture above.**

### 1.4 Wiring on consuming screens

#### `tasks_screen.dart`

The `Scaffold.body`'s `BlocBuilder<TasksCubit, TasksState>` already returns either `_buildAdminTabs(state, user)` or `_buildEmployeeTabs(state, user)`. Wrap that returned widget in `CountdownClockProvider`:

```dart
return BlocBuilder<TasksCubit, TasksState>(
  builder: (context, state) {
    // ... existing initial-load logic ...

    final visibleDueDates = _collectVisibleDueDates(state, isAdmin);

    return CountdownClockProvider(
      dueDates: visibleDueDates,
      child: isAdmin ? _buildAdminTabs(state, user) : _buildEmployeeTabs(state, user),
    );
  },
);
```

Helper to add to `_TasksScreenState`:

```dart
List<DateTime> _collectVisibleDueDates(TasksState state, bool isAdmin) {
  final lists = <List<TaskModel>>[
    state.tasks,
    state.tasksAssignedToMe,
    state.tasksCreatedByMe,
  ];
  return [
    for (final list in lists)
      for (final task in list)
        if (task.status != 'completed') task.dueDate,
  ];
}
```

Inside `_buildTasksList`'s `itemBuilder`, replace the existing `_InfoChip(icon: Icons.calendar_today_outlined, label: '${'due_date'.tr()}: ...')` with `CountdownChip(dueDate: task.dueDate, isCompleted: task.status == 'completed')`. Leave the rest of the card unchanged.

#### `task_details_screen.dart`

Wrap the `Scaffold.body` in `CountdownClockProvider(dueDates: [task.dueDate], child: ...)`. Replace the static `_DetailsRow(label: 'due_date'.tr(), value: DateFormat('yyyy-MM-dd').format(task.dueDate))` with a row that pairs the formatted date and the `CountdownChip`. Suggested layout:

```dart
Wrap(
  spacing: AppSizes.sm,
  runSpacing: AppSizes.sm,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text(
      '${'due_date'.tr()}: ${DateFormat('yyyy-MM-dd').format(task.dueDate)}',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    CountdownChip(dueDate: task.dueDate, isCompleted: task.status == 'completed'),
  ],
)
```

(Keep the existing `_DetailsRow` for other fields; only the due-date row changes.)

### 1.5 No-go list (do not change)

- `TaskModel` (no new fields, no migration).
- `TasksRepository`, `TasksCubit`, `TasksState` — no method or state changes.
- `firestore.rules` — no rule change.
- `functions/index.js` — no Cloud Function change.
- `dashboard_repository.dart`, `reports_repository.dart`, `pdf_report_service.dart` — no change to overdue computation; this PR only touches presentation.
- `add_task_screen.dart`, `edit_task_screen.dart` — no picker change (date-only stays).
- `StatusBadge`, `PriorityBadge`, `AppCard`, `EmptyStateWidget` — no change.
- The `_InfoChip` private widget at the bottom of `tasks_screen.dart` — leaves; remove only its single due-date usage. (If it becomes unused after the refactor, delete the class.)

---

## 2. Formatting (locked)

All wording goes through `.tr()` with `namedArgs`. No mid-string locale switches via `+` concatenation.

### 2.1 Buckets and keys

| Remaining (`endOfDay(dueDate) - now`)      | EN key (`namedArgs`)    | EN sample           | AR key                     | AR sample                  |
| ------------------------------------------ | ----------------------- | ------------------- | -------------------------- | -------------------------- |
| `> 7 days`                                 | `due_in_days`           | "Due in 12 days"    | `due_in_days`              | "خلال 12 يومًا"            |
| `1–7 days` (≥ 24h, ≤ 7d)                   | `due_in_days`           | "Due in 3 days"     | `due_in_days`              | "خلال 3 أيام"              |
| `< 24h, ≥ 1h`                              | `due_in_hours_minutes`  | "Due in 5h 32m"     | `due_in_hours_minutes`     | "خلال 5س 32د"              |
| `< 1h, > 0`                                | `due_in_minutes`        | "Due in 42m"        | `due_in_minutes`           | "خلال 42 دقيقة"            |
| `≤ 0` AND same calendar day as `dueDate`   | `due_today`             | "Due today"         | `due_today`                | "اليوم"                    |
| Overdue, `< 24h` past end-of-day           | `overdue_by_hours`      | "Overdue by 3h"     | `overdue_by_hours`         | "متأخرة بـ 3 ساعات"        |
| Overdue, `≥ 24h` past end-of-day           | `overdue_by_days`       | "Overdue by 2 days" | `overdue_by_days`          | "متأخرة بـ 2 يوم"          |
| `isCompleted == true`                      | _hide chip entirely_    | —                   | —                          | —                          |

**Pluralization**: use `easy_localization`'s plural feature for `due_in_days` and `overdue_by_days`. Singular vs other forms in English; in Arabic accept "متأخرة بـ {count} يوم" / "متأخرة بـ {count} أيام" — singular vs plural only (we are not handling Arabic dual / 3-10 / 11+ forms exhaustively for v1.1 to avoid translation churn; the agent should not introduce dual forms unless the user-visible result is wrong).

Translation key shape (en.json + ar.json):

```jsonc
// en.json
"due_in_days": "Due in {count} {count, plural, =1{day} other{days}}",
"due_in_hours_minutes": "Due in {hours}h {minutes}m",
"due_in_minutes": "Due in {minutes}m",
"due_today": "Due today",
"overdue_by_hours": "Overdue by {count}h",
"overdue_by_days": "Overdue by {count} {count, plural, =1{day} other{days}}",

// ar.json
"due_in_days": "خلال {count} {count, plural, =1{يوم} other{أيام}}",
"due_in_hours_minutes": "خلال {hours}س {minutes}د",
"due_in_minutes": "خلال {minutes} دقيقة",
"due_today": "اليوم",
"overdue_by_hours": "متأخرة بـ {count} ساعات",
"overdue_by_days": "متأخرة بـ {count} {count, plural, =1{يوم} other{أيام}}",
```

(Total: 6 new keys × 2 locales = 12 net-new translation entries.)

### 2.2 Numerals

Use plain integer interpolation (`1234`-style). Do **not** apply `intl.NumberFormat.decimalPattern('ar')` — keeps consistency with the rest of the app's date / counter rendering.

### 2.3 Edge cases

- **Exactly 24h remaining**: counts as "1 day" (use `due_in_days` with `count: 1`).
- **Exactly 1h remaining**: counts as "1h 0m" (the `< 1h` bucket triggers at strictly `< 1h`, so 60m falls into `due_in_hours_minutes`). Acceptable.
- **Less than 1 minute remaining (still positive)**: use `due_in_minutes` with `count: 1` ("Due in 1m"). Never display "0m" — clamp to ≥ 1.
- **`remaining == 0` exactly (i.e. 23:59:59 of due day)**: show `due_today`.
- **Just past end-of-day (e.g. 00:01 next day)**: shows `overdue_by_hours` with `count: 1` (clamp to ≥ 1).
- **Negative `remaining` < 60s but already past end-of-day**: clamp to "Overdue by 1h".

---

## 3. Visual states (locked)

```dart
class _CountdownVisual {
  final IconData icon;
  final Color background;
  final Color foreground;
  const _CountdownVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });
}
```

| Condition                                  | Icon                            | Background                                               | Foreground                                |
| ------------------------------------------ | ------------------------------- | -------------------------------------------------------- | ----------------------------------------- |
| `remaining > 24h`                          | `Icons.schedule`                | `Theme.of(context).colorScheme.surfaceContainerHighest`  | `Theme.of(context).colorScheme.onSurface` |
| `remaining ≤ 24h && remaining > 0`         | `Icons.schedule`                | `Colors.orange.withValues(alpha: 0.12)`                  | `Colors.orange.shade700`                  |
| `remaining ≤ 0` (overdue)                  | `Icons.warning_amber_rounded`   | `Colors.red.withValues(alpha: 0.12)`                     | `Colors.red.shade700`                     |

The pill shape, padding, and font weight should match the existing `StatusBadge` pattern (`EdgeInsets.symmetric(horizontal: 12, vertical: 6)` for padding, `BorderRadius.circular(999)`, `bodyMedium` text style with `FontWeight.w600`). Body widget can be a thin wrapper around an `Icon` + `Text` row inside a `Container` — see existing `StatusBadge` at [`lib/shared/widgets/status_badge.dart`](lib/shared/widgets/status_badge.dart) as the visual template.

---

## 4. Affected files

| File                                                                          | Change                                                                                                                                                                                                       | Approx. size   |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------- |
| `lib/features/tasks/presentation/widgets/countdown_clock_provider.dart` (new) | Provider widget per §1.2.                                                                                                                                                                                    | ~120 lines     |
| `lib/features/tasks/presentation/widgets/countdown_chip.dart` (new)           | Chip widget per §1.3 + §2 + §3.                                                                                                                                                                              | ~150 lines     |
| `lib/features/tasks/presentation/screens/tasks_screen.dart`                   | Wrap returned tabs in `CountdownClockProvider`; replace `_InfoChip(due_date)` with `CountdownChip`; add `_collectVisibleDueDates` helper. If `_InfoChip` becomes unused after the swap, delete it.           | ~30 line delta |
| `lib/features/tasks/presentation/screens/task_details_screen.dart`            | Wrap body in `CountdownClockProvider(dueDates: [task.dueDate], ...)`; replace the `_DetailsRow(due_date)` with a `Wrap` showing the formatted date + `CountdownChip`.                                        | ~15 line delta |
| `assets/translations/en.json`                                                 | 6 new countdown keys.                                                                                                                                                                                        | ~6 lines       |
| `assets/translations/ar.json`                                                 | 6 new countdown keys.                                                                                                                                                                                        | ~6 lines       |

That's it. Two new widget files + two screens + two translation files.

**Translation parity check**: after the agent edits, key counts must match. Run `python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a]+[k for k in a if k not in e])"` and confirm `<n> <n> []`.

---

## 5. Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green. (No new tests required; if the agent wants to add a unit test for the formatter, add to `test/features/tasks/presentation/widgets/countdown_chip_format_test.dart` — pure function on `Duration` → string given a fixed `now`.)
- `cd functions && npm run lint` — green (no Cloud Function changes; lint is just for parity).

---

## 6. Smoke tests (real device, where applicable)

1. **Default render** — open Tasks list with at least 5 tasks spanning >7d, 1–7d, <24h, <1h, and overdue states. Each chip shows the right wording + visual.
2. **Tick at 60s cadence** — with all visible tasks > 1h away, observe minute-by-minute updates on the closest chip ("Due in 5h 32m" → "Due in 5h 31m"). Other widgets in the card don't visually flash. Confirm via Flutter DevTools rebuild highlighting that only the chip rebuilds (not the parent card).
3. **Tick at 1s cadence** — set up a task with `dueDate` such that `endOfDay - now` is ~50 minutes, open the list, observe per-second decrement on its chip ("Due in 49m" tracks correctly). Other cards' chips (further away) tick once per minute.
4. **Crossing the 1h threshold** — start with all visible tasks ≥ 1h away, wait for one to cross under 1h. The provider upgrades from 60s to 1s on the next minute boundary; the affected chip starts ticking by seconds. (Alternatively, hot-reload with a fresh test task `endOfDay(dueDate) ≈ now + 55 min`.)
5. **Overdue render** — task whose `endOfDay(dueDate)` is in the past shows red-tinted "Overdue by Xh" / "Overdue by X days".
6. **Completed tasks** — tasks with `status == 'completed'` show no countdown chip on either screen. The `_InfoChip` removal must not leave a gap or break the `Wrap` row layout.
7. **App lifecycle** — backgrounded the app for >2 minutes, returned. Chip values updated on resume; no zombie ticks fired in the background (verify via debug logs that the timer was cancelled on `paused`).
8. **Arabic / RTL** — switch locale to Arabic. All wording renders Arabic; numerals stay `1234`; chip is right-aligned in the `Wrap` and reads correctly. No layout overflow on long phrases like "Overdue by 12 days" / "متأخرة بـ 12 يوم".
9. **Task details screen** — open a task. Both the date row and the `CountdownChip` render together. Same visual states (default/warning/overdue) apply. Ticker pauses when leaving the screen (`dispose` cancels `Timer`).
10. **Filter / search interaction** — apply a filter that hides currently-visible "<1h" tasks. The provider's `dueDates` list shrinks (cubit emits new state → `didUpdateWidget` recomputes period); ticker drops back to 60s. No leaks, no orphaned timers.
11. **No-tasks state** — open Tasks with empty list (or all completed). The provider receives an empty `dueDates` list; the timer runs at 60s but nothing visible reacts. Confirmed harmless.
12. **Filter sort by `dueDateSoonest` regression** — existing sort still works; first-in-list task has the most urgent chip.

Smoke tests #1–#11 require manual execution on a real device. Test #12 is a quick regression check.

---

## 7. Definition of Done

- [ ] `countdown_clock_provider.dart` exists at the locked path with the locked structure (timer ownership, lifecycle observer, adaptive period, `ValueListenable<DateTime>` exposure).
- [ ] `countdown_chip.dart` exists at the locked path with the locked rendering (formatting buckets, visual states, `isCompleted` short-circuit).
- [ ] `tasks_screen.dart` wraps tabs in the provider and uses the chip; `_InfoChip` reference for due-date is removed.
- [ ] `task_details_screen.dart` wraps body in the provider and uses the chip alongside the formatted date.
- [ ] 6 EN + 6 AR translation keys added with parity check passing.
- [ ] No changes outside the files listed in §4.
- [ ] All three quality gates green (`flutter analyze`, `flutter test`, `cd functions && npm run lint`).
- [ ] Workflow docs updated (see §10).
- [ ] PR title: `feat(tasks): add adaptive countdown timer for task deadlines`.
- [ ] PR body covers the 12 smoke tests (#1–#11 deferred to project owner; #12 verifiable from the agent environment).

---

## 8. Risks

- **Timer leak on hot-reload during dev**: `WidgetsBindingObserver` + `Timer.periodic` should be cancelled in `dispose()`. The locked code does this; agent must not change it.
- **Screen rebuild via `BlocBuilder` reconstructs the provider**: this is intentional — `dueDates` recomputes per cubit emission. The provider's `didUpdateWidget` handles it. If the implementing agent moves the provider above the `BlocBuilder`, they must add their own data-change listener — don't.
- **Overdue red could clash with existing `inactive` red on `StatusBadge`**: minor; both surfaces appear in different chips, not stacked. Acceptable.
- **Arabic plural simplification**: we are not handling Arabic dual / 3–10 / 11+ forms. Wording will be slightly off for `count == 2` ("متأخرة بـ 2 يوم" reads as singular form) but is acceptable for v1.1. Capture as a NEXT_STEPS item if a tester complains.
- **Day-boundary off-by-one near midnight**: at exactly 00:00:00 of the day after `dueDate`, the chip flips from "Due today" to "Overdue by 1h" (clamped). This is expected per §2.3 edge cases — locked behavior, not a bug.

---

## 9. Out of scope (do not pull in)

- `TaskCard` widget extraction.
- Per-task time-of-day deadlines (`showDateTimePicker` in add/edit screens).
- Eastern Arabic numerals (`١٢٣٤`).
- Notification cadence changes / new push types based on hourly proximity.
- An "overdue" `StatusBadge` color path.
- Animations on chip state transitions.
- Settings toggle for showing / hiding the countdown.
- A reports-table countdown (the reports screen continues to render the static date).
- App-lifecycle integration with FCM token refresh, Firestore reconnect, etc.
- Tests for the entire `CountdownClockProvider` lifecycle (an optional pure-function `_formatLabel` test is fine; a full `WidgetTester` lifecycle test is not required).

---

## 10. Workflow doc updates required

| File                                  | Change                                                                                                                                                                      | Who                  |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `docs/ai-workflow/CURRENT_TASK.md`    | Reset to "No active task" or to next planned task on completion.                                                                                                            | Implementing agent   |
| `docs/ai-workflow/BACKLOG.md`         | F3.A entry: change Status to `Done — YYYY-MM-DD`, add `**Completed**` line.                                                                                                  | Implementing agent   |
| `docs/ai-workflow/SESSION_LOG.md`     | Append new implementation entry at the top. Don't edit prior entries.                                                                                                       | Implementing agent   |
| `docs/ai-workflow/DECISIONS_LOG.md`   | Append: "Adaptive screen-level countdown ticker for task deadlines" — record the 7 locked planning decisions and the rebuild-isolation invariants.                          | Implementing agent   |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §4 Modules: extend the `tasks` row with "live countdown chip on list and details (adaptive screen-level ticker)".                                                            | Implementing agent   |
| `CHANGELOG.md`                        | Under `## [Unreleased]` → `### Added`: "Live countdown timer chip on the tasks list and task details (adaptive 1s/60s ticker, end-of-day deadline semantics, RTL-friendly)." | Implementing agent   |
| `docs/ai-workflow/RULES.md`           | No change                                                                                                                                                                   | —                    |
| `docs/ai-workflow/NEXT_STEPS.md`      | No change unless Arabic plural quality complaint comes in (then add an entry).                                                                                              | —                    |

---

## Notes for the implementing agent

- **Read §1 (Architecture) start to finish before writing any code.** The rebuild-isolation invariants are the entire point of this PR; getting them wrong means we ship a feature that visually works but burns CPU and battery on every list.
- **Match the visual style of `StatusBadge`** for chip padding / border-radius / font weight — keeps the list visually coherent.
- **Don't add Equatable to anything**, don't introduce `freezed`, don't pull in new dependencies. `Duration` arithmetic + `ValueNotifier` is enough.
- **The `_InfoChip` private widget at the bottom of `tasks_screen.dart` should be removed if its only call site goes away** — verify with grep before deleting.
