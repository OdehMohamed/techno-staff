# Current Task

> Last updated: 2026-05-15

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**BACKLOG #13 — UI/UX Improvements**
Branch: `feat/ui-ux-improvements` (created from `dev` 2026-05-15)

Targeted, no-redesign UI/UX pass across five screens based on a full audit of all
presentation-layer files. No backend changes, no data-model changes, no new routes,
no translation additions.

---

## Locked planning decisions

1. **Scope only** — Five Dart files. Zero changes to translation JSON, pubspec.yaml,
   firestore.rules, Cloud Functions, any cubit, any repository, any model.
2. **C1 — Debug test buttons removed from Reports screen** — The two ElevatedButtons
   calling `testTaskDeadlineReminders` and `testOverdueTaskEscalations` are development
   artifacts that must not be visible in production.
3. **W1 — Employee home task cards tappable + "View all" link** — Each preview card
   navigates to `RouteNames.taskDetails`. A "View all" link below the list navigates
   to the Tasks tab (drawer navigation or `RouteNames.tasks`). No new routes.
4. **W2 — Task description clamped to 2 lines in all list cards** — Applied to the
   task list in `tasks_screen.dart` and the preview cards in `employee_home_screen.dart`.
5. **W3 — Status dropdown hidden for completed tasks** — Add `task.status != 'completed'`
   guard to the assignee status-update section in `tasks_screen.dart`.
6. **D1 — Human-readable date formats** — Replace `yyyy-MM-dd` with
   `DateFormat.yMMMd(locale)` and `yyyy-MM` with `DateFormat.yMMMM(locale)` at all
   four display sites. Timestamps keep HH:mm. Use `context.locale.languageCode` for
   locale-aware output.
7. **L1 — Activity log status values localized** — Call `.tr()` on `previousStatus`
   and `newStatus` in `_buildLogDescription` in `task_details_screen.dart`. All required
   keys (`pending`, `in_progress`, `completed`) already exist in both locales.
8. **A1 — Medium-breakpoint LayoutBuilder dead code removed** — In
   `admin_dashboard_screen.dart` and `reports_screen.dart`, the `isMedium` (600–899 px)
   and `isWide` (≥900 px) branches are identical. Remove `isMedium` and lower the
   single row threshold to ≥ 500 px (covers landscape phones and tablets; leaves narrow
   portrait phones with the column layout).
9. **P1 — Activity log icon differentiation** — Map `action` → icon:
   `created` → `Icons.add_circle_outline`, `status_changed` → `Icons.swap_horiz`,
   `overdue_escalation` → `Icons.warning_amber_outlined`, default → `Icons.history`.
10. **P2 — Overdue stat card urgency color (admin dashboard only)** — `_DashboardStatCard`
    gains an optional `accentColor` param. The Open Overdue card passes
    `colorScheme.error` when `overdueOpenTasks > 0`, null otherwise. Employee home is
    unchanged.
11. **Translation delta: 0** — No new keys. The parity stays at 246/246.

---

## 1. `reports_screen.dart`

### 1.1 C1 — Remove debug test buttons

Delete both button blocks (lines ~481–547 in the current file). These are the two
`ElevatedButton.icon` widgets that call `testTaskDeadlineReminders` and
`testOverdueTaskEscalations`. Also remove the `cloud_functions` import at line 1 if
it is only used by these buttons (verify before removing).

After removal the "Delivery Performance" section is followed directly by the task list.

### 1.2 D1 — Human-readable month and date formats

Two call sites:

| Location | Before | After |
|---|---|---|
| Selected-month chip (line ~226) | `DateFormat('yyyy-MM').format(_selectedMonth)` | `DateFormat.yMMMM(context.locale.languageCode).format(_selectedMonth)` |
| Report subtitle (line ~253) | `DateFormat('yyyy-MM').format(_selectedMonth)` | `DateFormat.yMMMM(context.locale.languageCode).format(_selectedMonth)` |
| Task due-date in report list (line ~602) | `DateFormat('yyyy-MM-dd').format(task.dueDate)` | `DateFormat.yMMMd(context.locale.languageCode).format(task.dueDate)` |

`DateFormat` is already imported via `easy_localization` / `intl`. No new import needed
(confirm the import chain — `easy_localization` re-exports `DateFormat`; if not, add
`import 'package:intl/intl.dart';`).

### 1.3 A1 — Remove medium-breakpoint dead code

Two LayoutBuilder blocks in this file use the same `isWide`/`isMedium` pattern.

**Before:**
```dart
final isWide = constraints.maxWidth >= 900;
final isMedium = constraints.maxWidth >= 600;

if (isWide) { return Row(3 cards); }
if (isMedium) { return Row(3 cards); }   // ← identical to isWide, dead
return Column(3 cards);
```

**After:**
```dart
final isWide = constraints.maxWidth >= 500;

if (isWide) { return Row(3 cards); }
return Column(3 cards);
```

Apply to both LayoutBuilder instances in this file (stat cards around line ~285 and
delivery performance around line ~405). Leave the column content unchanged.

---

## 2. `employee_home_screen.dart`

### 2.1 W1 — Make task preview cards tappable + add "View all" link

**Import to add:**
```dart
import '../../../../core/routes/route_names.dart';
```

**Wrap each card in InkWell:**

The preview section builds cards from `tasks.take(3).map((task) { ... })`. Wrap the
existing `AppCard` with an `InkWell`:

```dart
InkWell(
  borderRadius: BorderRadius.circular(12),
  onTap: () {
    Navigator.pushNamed(
      context,
      RouteNames.taskDetails,
      arguments: task,
    );
  },
  child: AppCard(
    child: Column( ... ),
  ),
),
```

**Add "View all" link below the list:**

After the `Column(children: tasks.take(3)...)` block, add:

```dart
if (tasks.length > 3)
  Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton(
      onPressed: () {
        Navigator.pushNamed(context, RouteNames.tasks);
      },
      child: Text('all_tasks'.tr()),
    ),
  ),
```

`all_tasks` is an existing translation key. `RouteNames.tasks` is the existing route
for the tasks screen.

### 2.2 W2 — Clamp description to 2 lines

In the task preview card's description `Text`:

**Before:**
```dart
Text(task.description),
```

**After:**
```dart
Text(
  task.description,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
```

---

## 3. `tasks_screen.dart`

### 3.1 W2 — Clamp description to 2 lines in list cards

Same change as §2.2, in `_buildTasksList` (line ~517):

**Before:**
```dart
Text(task.description),
```

**After:**
```dart
Text(
  task.description,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
```

### 3.2 W3 — Hide status dropdown for completed tasks

In `_buildTasksList`, the status-update section condition:

**Before:**
```dart
if (currentUser != null && task.assignedTo == currentUser.id) ...[
```

**After:**
```dart
if (currentUser != null &&
    task.assignedTo == currentUser.id &&
    task.status != 'completed') ...[
```

This hides both the counter increment row and the status dropdown once a task is
marked completed. The completed task card still shows title, description, priority
badge, and the green completed CountdownChip (hidden when completed — check existing
`CountdownChip(isCompleted: task.status == 'completed')` behaviour and confirm the
chip is already hidden; the existing implementation hides it on completion so no
change needed there).

---

## 4. `task_details_screen.dart`

### 4.1 D1 — Human-readable date formats

Three call sites in the main `build` method:

| Location | Before | After |
|---|---|---|
| Due date (line ~225) | `DateFormat('yyyy-MM-dd').format(task.dueDate)` | `DateFormat.yMMMd(context.locale.languageCode).format(task.dueDate)` |
| Created at (line ~237) | `DateFormat('yyyy-MM-dd HH:mm').format(task.createdAt)` | `DateFormat('dd MMM yyyy • HH:mm').format(task.createdAt)` |
| Updated at (line ~244) | Same pattern | Same replacement |
| Completed at (line ~251) | Same pattern | Same replacement |

For the timestamp rows (created/updated/completed), the HH:mm part is kept.
`DateFormat.yMMMd` gives locale-aware format; the timestamp rows use a fixed
`'dd MMM yyyy • HH:mm'` format (simpler and still readable).

### 4.2 L1 — Localize status values in activity log description

In `_buildLogDescription`:

**Before:**
```dart
return '$performedByName • $previousStatus → $newStatus';
```

**After:**
```dart
return '$performedByName • ${previousStatus.tr()} → ${newStatus.tr()}';
```

All status strings (`pending`, `in_progress`, `completed`) are existing translation
keys in both locales.

### 4.3 P1 — Activity log icon differentiation

Add a private helper at the bottom of `_TaskDetailsScreenState` (or as a top-level
function):

```dart
IconData _logActionIcon(String action) {
  switch (action) {
    case 'created':
      return Icons.add_circle_outline;
    case 'status_changed':
      return Icons.swap_horiz;
    case 'overdue_escalation':
      return Icons.warning_amber_outlined;
    default:
      return Icons.history;
  }
}
```

In the log list builder, replace the hardcoded `Icons.history`:

**Before:**
```dart
child: const Icon(Icons.history),
```

**After:**
```dart
child: Icon(_logActionIcon(log.action)),
```

---

## 5. `admin_dashboard_screen.dart`

### 5.1 A1 — Remove medium-breakpoint dead code

Same pattern as §1.3. Three LayoutBuilder blocks in this file:
- KPI stat cards (employees / total tasks / completed tasks) — lines ~151–238
- Delivery performance cards (on time / late / open overdue) — lines ~280–336
- Team insights cards — lines ~360–428

Apply the single-threshold fix (`>= 500`) to all three. Remove the `isMedium` check.
Leave all card content unchanged.

### 5.2 D1 — Human-readable timestamp in activity log

Activity log item timestamp (line ~520):

**Before:**
```dart
DateFormat('yyyy-MM-dd • HH:mm').format(activityTime),
```

**After:**
```dart
DateFormat('dd MMM yyyy • HH:mm').format(activityTime),
```

### 5.3 P2 — Overdue stat card urgency color

**Modify `_DashboardStatCard`** to accept an optional accent color:

```dart
class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;  // new

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,        // new
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),   // explicit color on icon
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSizes.xs),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**At the call site for Open Overdue**, inside the delivery-performance LayoutBuilder,
pass the accent color:

```dart
_DashboardStatCard(
  title: 'open_overdue'.tr(),
  value: overdueOpenTasks.toString(),
  icon: Icons.warning_amber_outlined,
  accentColor: overdueOpenTasks > 0
      ? Theme.of(context).colorScheme.error
      : null,
),
```

Apply this to **both** the `isWide` Row branch and the Column fallback branch (both
call sites for the Open Overdue card). The other two delivery-performance cards
(`completed_on_time`, `completed_late`) receive no accent color.

---

## 6. Affected files

| File | Changes |
|---|---|
| `lib/features/reports/presentation/screens/reports_screen.dart` | C1 (remove debug buttons), D1 (date formats), A1 (breakpoint fix) |
| `lib/features/employee/presentation/screens/employee_home_screen.dart` | W1 (tappable cards + view all), W2 (description clamp) |
| `lib/features/tasks/presentation/screens/tasks_screen.dart` | W2 (description clamp), W3 (hide dropdown for completed) |
| `lib/features/tasks/presentation/screens/task_details_screen.dart` | D1 (date formats), L1 (localize status), P1 (log icons) |
| `lib/features/admin/presentation/screens/admin_dashboard_screen.dart` | A1 (breakpoint fix), D1 (timestamp format), P2 (overdue color) |

**Zero changes to:** translation JSON files, pubspec.yaml, firestore.rules,
functions/index.js, any cubit, any state, any repository, any model, any route name
constants, `AppDrawer`.

---

## 7. Quality gates

```bash
flutter analyze          # zero warnings
flutter test             # all green
python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"
# Expected: 246 246 []
```

---

## 8. Smoke tests

| # | Screen | Test |
|---|---|---|
| 1 | Reports (admin) | No "Test Reminder" or "Test Escalation" buttons visible anywhere |
| 2 | Reports (admin) | Month selector displays "May 2026" style instead of "2026-05" |
| 3 | Reports (admin) | Report subtitle and task due-date chips show human-readable dates |
| 4 | Employee Home | Tap a task preview card → navigates to task details screen |
| 5 | Employee Home | "All tasks" link visible when more than 3 tasks exist → taps to Tasks screen |
| 6 | Employee Home | Task description is clamped to 2 lines with ellipsis on long descriptions |
| 7 | Tasks (assignee) | Long description clamped to 2 lines in the task list card |
| 8 | Tasks (assignee) | Completed task cards show NO status dropdown or counter increment |
| 9 | Tasks (assignee) | In-progress / pending task cards still show the status dropdown |
| 10 | Task Details | Due date shows as "15 May 2026" style (en) / locale-appropriate (ar) |
| 11 | Task Details | Activity log shows "قيد الانتظار → مكتملة" in Arabic (not "pending → completed") |
| 12 | Task Details | Creation log entry shows `+` icon; status-change shows swap icon |
| 13 | Admin Dashboard | Open Overdue card icon/container is red when count > 0; neutral when 0 |
| 14 | Admin Dashboard | Activity log timestamps show "15 May 2026 • 09:00" style |
| 15 | Admin Dashboard (tablet/landscape) | Stat cards remain in 3-column row at ≥ 500 px wide |
| 16 | Admin Dashboard (narrow phone portrait) | Stat cards stack vertically at < 500 px |
| 17 | Arabic locale | Employee home, tasks, reports, task details all display correct Arabic date formats |

---

## 9. Definition of Done

- [ ] Reports screen: no debug test buttons; month format human-readable; `cloud_functions` import removed if unused.
- [ ] Employee home: task cards tappable; "View all" link shown when tasks > 3; description clamped.
- [ ] Tasks screen: description clamped; status dropdown/counter hidden for completed tasks.
- [ ] Task details: human-readable dates; activity log statuses localized; log icons differentiated.
- [ ] Admin dashboard: medium-breakpoint dead code removed; overdue card has urgency color; timestamp format updated.
- [ ] `flutter analyze` clean; `flutter test` green; translation parity `246 246 []`.
- [ ] No changes outside files listed in §6.
- [ ] Workflow docs updated (SESSION_LOG, BACKLOG #13 Done, CURRENT_TASK reset).
- [ ] PR title: `feat(ui): UI/UX usability improvements — task workflow, date formats, log polish`.

---

## 10. Out of scope

- Any new screens or navigation routes
- Redesign of dashboard, reports, or employee home layout
- New stat cards or data additions to any screen
- Changes to `AppDrawer`, `AppCard`, `StatusBadge`, `PriorityBadge`, or any shared widget
- Backend / Firestore / Cloud Functions changes
- Translation additions
- Employee home showing pending count or overdue data

---

## 11. Workflow doc updates required on completion

| File | Change |
|---|---|
| `CURRENT_TASK.md` | Reset to "No active task" |
| `BACKLOG.md` | Mark item #13 Done with completion date and quality gate results |
| `SESSION_LOG.md` | Append implementation entry at top |
