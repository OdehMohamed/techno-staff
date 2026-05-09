# Current Task

> Last updated: 2026-05-09

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**v1.1 F3.C — Target / counter task type.**

Add a second task variant alongside the existing standard task: a *counter task* whose progress is tracked as `currentCount / targetCount`. Assignees increment the counter from the task list / task details; status (`pending` / `in_progress` / `completed`) is **derived from the counts and persisted into the existing `status` field** so every downstream consumer (dashboards, reports, FCM completion notifications, deadline-reminder filters, countdown chip, Firestore rules, `task_logs`) keeps working without per-type branches.

The architectural risk in this feature is **status drift** — if the client increments `currentCount` without persisting the derived status flip in the same write, FCM completion notifications never fire, dashboards under-count completions, deadline reminders keep targeting completed counter tasks, and the countdown chip stays visible on done work. The spec leads with the persistence invariant; UI / form details follow as application of that rule.

## Branch

`feat/counter-tasks` (created from `dev` after PR #27 merged on 2026-05-09).

## Locked planning decisions (audit round, 2026-05-09)

1. **Storage shape** — Option A: flat optional fields on the existing `tasks` collection (`taskType`, `targetCount`, `currentCount`). No subcollection, no nested map. Zero migration: missing `taskType` reads as `'standard'`.
2. **Completion derivation** — client derives status from counts AND persists the resulting `status` (and `completedAt`) in the same write. Mapping is locked: `currentCount == 0` → `'pending'`; `0 < currentCount < targetCount` → `'in_progress'`; `currentCount >= targetCount` → `'completed'`.
3. **Manual status override on counter tasks** — strict. Counter-task status is fully derived. No bypass via edit screen, no admin override flag.
4. **`taskType` mutability** — immutable after create.
5. **`targetCount` validation** — integer, `1 <= targetCount <= 999`. `currentCount` integer, `0 <= currentCount <= targetCount`.
6. **Decrement semantics** — no decrement action in the employee card UI. Admin / creator only via the edit screen.
7. **Firestore rules** — simple mask widening: extend the assignee self-update mask from `['status', 'updatedAt', 'completedAt', 'updatedBy', 'updatedByName']` to `['status', 'updatedAt', 'completedAt', 'updatedBy', 'updatedByName', 'currentCount']`. Per-type rule guards deferred.
8. **Counter-task visual indicator** — subtle: a small `Icons.numbers` icon (or similar lightweight chip) on the task card so admins can spot counter tasks while scanning. No major visual redesign.
9. **Edit screen status dropdown for counter tasks** — hidden entirely. Status is derived from counts; do not show a disabled control.
10. **Backward compatibility** — standard task flow stays untouched. Missing `taskType` defaults to `'standard'` on read.

---

## 1. Architecture (locked — read this section before any code)

### 1.1 The persistence contract (the single most important rule)

**On every write that mutates `currentCount`, the same write MUST also set the derived `status` (and `completedAt` when applicable).** No exceptions. Two writes — count then status — are forbidden because the period in between is a state where dashboards / reports / Cloud Functions read inconsistent data.

```
status mapping (locked):
  currentCount == 0                    → status = 'pending',     completedAt = null
  0 < currentCount < targetCount       → status = 'in_progress', completedAt = null
  currentCount >= targetCount          → status = 'completed',   completedAt = serverTimestamp / DateTime.now
```

The flip from `'in_progress'` → `'completed'` is what makes:
- `sendTaskStatusNotification` ([functions/index.js:234, 238](functions/index.js#L234)) fire its FCM + admin in-app notification.
- `task_logs` get a `status_changed` row written by the same Cloud Function.
- Deadline-reminder sweeps (`where("status", "!=", "completed")`) start excluding the task.
- Dashboard counters increment `completedTasks` and decrement `inProgressTasks`.
- The countdown chip's `isCompleted` short-circuit hide the chip.

**This contract is why F3.C touches zero Cloud Function code and zero downstream consumer code.** Don't break it.

### 1.2 The increment write must be a Firestore transaction

Concurrent increments from two devices (same employee on phone + tablet) would otherwise race: each reads `currentCount = 5`, each writes `currentCount = 6`, and the second write silently overwrites the first's increment. Use `FirebaseFirestore.instance.runTransaction((txn) async { ... })` so the read-modify-write cycle is atomic.

The transaction also lets us derive the new status from the *post-increment* count and write count + status atomically, satisfying §1.1.

```dart
// lib/features/tasks/data/repositories/tasks_repository.dart — new method
Future<void> incrementTaskCounter({
  required String taskId,
  required String currentUserId,
  required String currentUserName,
}) async {
  final ref = _firestore.collection(FirebasePaths.tasks).doc(taskId);
  await _firestore.runTransaction((txn) async {
    final snap = await txn.get(ref);
    if (!snap.exists) return;
    final data = snap.data() ?? <String, dynamic>{};

    final taskType = (data['taskType'] as String?) ?? 'standard';
    if (taskType != 'counter') return; // safety: never increment a standard task

    final target = (data['targetCount'] as int?) ?? 0;
    final current = (data['currentCount'] as int?) ?? 0;

    if (current >= target) return; // already complete; no-op

    final next = current + 1;

    final String newStatus;
    final Timestamp? completedAt;
    if (next >= target) {
      newStatus = 'completed';
      completedAt = Timestamp.now();
    } else {
      newStatus = 'in_progress';
      completedAt = null;
    }

    txn.update(ref, <String, dynamic>{
      'currentCount': next,
      'status': newStatus,
      'completedAt': completedAt,
      'updatedAt': Timestamp.now(),
      'updatedBy': currentUserId,
      'updatedByName': currentUserName,
    });
  });
}
```

The write touches exactly the six fields covered by the widened assignee mask (§2): `currentCount`, `status`, `completedAt`, `updatedAt`, `updatedBy`, `updatedByName`. No other fields.

### 1.3 The edit-screen save path must also derive status

Edit screen (admin / creator) writes the full task doc via `TasksRepository.updateTask`. For counter tasks, the save path must:

1. Validate `targetCount` (1..999) and `currentCount` (0..new `targetCount`); clamp `currentCount` to `targetCount` if the admin lowered the target below current progress.
2. Derive `status` from the final clamped `(currentCount, targetCount)` per §1.1.
3. Set `completedAt` accordingly (same rule as §1.1).
4. Write the full doc.

This is the **only** other path where status is set for counter tasks. The status dropdown is hidden on the edit screen for counter tasks (decision #9), so `_selectedStatus` is irrelevant for them.

### 1.4 Invariant guardrails

- ❌ **Never write `currentCount` without writing the derived `status`** in the same `update` / transaction.
- ❌ **Never derive completion only at read time** — UI must read from the persisted `status` field, same as standard tasks.
- ❌ **Never increment via a plain `update({'currentCount': FieldValue.increment(1)})`** — bypasses the read-and-derive cycle. Always go through `incrementTaskCounter` (transaction).
- ❌ **Never add `targetCount` to the assignee self-update mask.** Only admin / creator can edit the goalpost.
- ❌ **Never add `taskType` to the assignee self-update mask.** Type is set at create-time and never changes.
- ❌ **Never expose decrement on the employee task card UI.** Decrement (and direct count edits) happen only on the admin / creator edit screen.
- ❌ **Never branch Cloud Function code on `taskType`.** This whole feature works because the persistence contract keeps the `status` field authoritative — if you find yourself wanting to change a Cloud Function, you've broken the contract.
- ✅ Increment writes go through `runTransaction`.
- ✅ Edit-screen counter saves derive status from `(currentCount, targetCount)` before writing.
- ✅ `taskType` defaults to `'standard'` on read for backward-compat with existing docs.

---

## 2. Firestore rules diff (locked)

Single change in [firestore.rules:43-54](firestore.rules#L43-L54):

```diff
 function onlyAllowedTaskStatusFieldsChanged() {
   return request.resource.data
     .diff(resource.data)
     .affectedKeys()
     .hasOnly([
       'status',
       'updatedAt',
       'completedAt',
       'updatedBy',
       'updatedByName',
+      'currentCount',
     ]);
 }
```

No other rule changes. `targetCount` and `taskType` are NOT in the assignee mask — only the admin / creator update branch (line 86-89) can change them, which is the existing rule.

**Deploy ordering**: the rules deploy must land before any counter task is created on a phone running the new build. Otherwise the increment write fails. See §10 for the operational step.

---

## 3. Data model

### 3.1 `TaskModel` ([lib/features/tasks/data/models/task_model.dart](lib/features/tasks/data/models/task_model.dart))

Add three new fields with sensible defaults:

```dart
class TaskModel {
  // ...existing fields...
  final String taskType;          // 'standard' | 'counter'; default 'standard'
  final int? targetCount;         // null for standard; required (>=1) for counter
  final int currentCount;         // 0 for standard; 0..targetCount for counter

  TaskModel({
    // ...existing required params...
    this.taskType = 'standard',
    this.targetCount,
    this.currentCount = 0,
    // ...
  });
}
```

#### `fromMap` additions

```dart
taskType: (data['taskType'] as String?) ?? 'standard',
targetCount: data['targetCount'] is int ? data['targetCount'] as int : null,
currentCount: data['currentCount'] is int ? data['currentCount'] as int : 0,
```

#### `toMap` additions

```dart
'taskType': taskType,
if (targetCount != null) 'targetCount': targetCount,
'currentCount': currentCount,
```

For standard tasks, `targetCount` stays absent from the doc (cleaner Firestore docs); `currentCount` writes as `0` (harmless).

#### `copyWith` additions

Add `taskType`, `targetCount`, `currentCount` parameters following the existing pattern. Add an explicit `clearTargetCount: bool = false` flag if you ever need to null `targetCount` (probably never — `taskType` is immutable).

### 3.2 Helper getter

Add a derived helper on `TaskModel`:

```dart
bool get isCounter => taskType == 'counter';
```

Use it everywhere the UI branches on task type. Do **not** scatter `task.taskType == 'counter'` literals across the codebase.

### 3.3 Status derivation helper

Single source of truth for the status mapping. Add to `TaskModel` (or a small `lib/features/tasks/domain/counter_task_status.dart` if you prefer):

```dart
static String deriveCounterStatus(int currentCount, int targetCount) {
  if (currentCount <= 0) return 'pending';
  if (currentCount >= targetCount) return 'completed';
  return 'in_progress';
}
```

Both the increment transaction and the edit-screen save path call this helper. Don't reimplement the mapping anywhere else.

---

## 4. Repository

### 4.1 New method — `incrementTaskCounter`

See §1.2 for the locked code. Add to [tasks_repository.dart](lib/features/tasks/data/repositories/tasks_repository.dart).

### 4.2 No changes to existing methods

- `createTask` — already writes `task.toMap()`, which now includes the new fields automatically.
- `updateTask` — already writes the full map, including the new fields.
- `updateTaskStatus` — used by the existing standard-task dropdown; **do not call this for counter tasks** (counter status is derived, not user-picked).
- `getTasksAssignedTo` / `getTasksCreatedBy` / `getAllTasks` / `getTaskById` — unchanged; they already round-trip the full map.

---

## 5. Cubit

### 5.1 New method — `TasksCubit.incrementTaskCounter`

Mirrors the existing `updateTaskStatus` shape (refresh role-relevant lists after the write):

```dart
Future<void> incrementTaskCounter({
  required String taskId,
  required bool isAdmin,
  required String currentUserId,
  required String currentUserName,
}) async {
  await _tasksRepository.incrementTaskCounter(
    taskId: taskId,
    currentUserId: currentUserId,
    currentUserName: currentUserName,
  );

  if (isAdmin) {
    await fetchAllTasks();
    await fetchTasksAssignedTo(currentUserId);
  } else {
    await fetchTasksAssignedTo(currentUserId);
    await fetchTasksCreatedBy(currentUserId);
  }
}
```

Failure handling: same pattern as `updateTaskStatus` (errors surface via the next `fetch*` call's error path).

---

## 6. Add task screen ([add_task_screen.dart](lib/features/tasks/presentation/screens/add_task_screen.dart))

### 6.1 New form state

```dart
String _selectedTaskType = 'standard';   // 'standard' | 'counter'
final _targetCountController = TextEditingController();
```

Dispose the controller in `dispose()`.

### 6.2 New form fields (placed between `priority` and `dueDate`)

- A `DropdownButtonFormField<String>` for `task_type` with values `'standard'` / `'counter'`.
- Conditionally (only when `_selectedTaskType == 'counter'`) a `TextFormField` for `target_count` with:
  - `keyboardType: TextInputType.number`.
  - Validator: required, parseable int, `1 <= value <= 999`. Localized error keys: `target_count_required`, `target_count_invalid_range`.

### 6.3 `_saveTask` additions

```dart
final taskType = _selectedTaskType;
final int? targetCount = taskType == 'counter'
    ? int.tryParse(_targetCountController.text.trim())
    : null;

if (taskType == 'counter' && (targetCount == null || targetCount < 1 || targetCount > 999)) {
  return; // validator already showed the error
}

final task = TaskModel(
  // ...existing fields...
  status: 'pending',
  taskType: taskType,
  targetCount: targetCount,
  currentCount: 0,
);
```

`status` stays `'pending'` for new counter tasks because `currentCount == 0`; the derivation rule confirms this without a special case.

---

## 7. Edit task screen ([edit_task_screen.dart](lib/features/tasks/presentation/screens/edit_task_screen.dart))

### 7.1 Hidden status dropdown for counter tasks

Wrap the existing status `DropdownButtonFormField` ([edit_task_screen.dart:247-273](lib/features/tasks/presentation/screens/edit_task_screen.dart#L247)) in `if (!widget.task.isCounter) ...`. For counter tasks, the dropdown is not rendered.

### 7.2 New counter-only fields

When `widget.task.isCounter`:

- A read-only `_DetailsRow`-style label showing the task type ("Task Type: Counter"). Optionally a tooltip or small hint explaining the type is locked at create-time.
- An editable `target_count` `TextFormField` (initial value: `widget.task.targetCount.toString()`). Same validator as add screen (1..999).
- An editable `current_count` `TextFormField` (initial value: `widget.task.currentCount.toString()`). Validator: parseable int, `0 <= current <= newTargetCount` (run validator after target changes too — easiest is to re-run on save).

### 7.3 `_saveChanges` derivation for counter tasks

```dart
String resolvedStatus;
DateTime? resolvedCompletedAt;
int? resolvedTargetCount;
int resolvedCurrentCount;

if (widget.task.isCounter) {
  final newTarget = int.parse(_targetCountController.text.trim());
  final newCurrent = int.parse(_currentCountController.text.trim()).clamp(0, newTarget);
  resolvedTargetCount = newTarget;
  resolvedCurrentCount = newCurrent;
  resolvedStatus = TaskModel.deriveCounterStatus(newCurrent, newTarget);
  resolvedCompletedAt = resolvedStatus == 'completed'
      ? (widget.task.completedAt ?? DateTime.now())
      : null;
} else {
  resolvedStatus = _selectedStatus;
  resolvedCompletedAt = _selectedStatus == 'completed'
      ? (widget.task.completedAt ?? DateTime.now())
      : null;
  resolvedTargetCount = null;
  resolvedCurrentCount = 0;
}

final updatedTask = TaskModel(
  // ...existing fields...
  status: resolvedStatus,
  completedAt: resolvedCompletedAt,
  taskType: widget.task.taskType,            // immutable: pass through
  targetCount: widget.task.isCounter ? resolvedTargetCount : null,
  currentCount: widget.task.isCounter ? resolvedCurrentCount : 0,
);
```

Standard-task save path remains identical to today.

---

## 8. Task list card ([tasks_screen.dart](lib/features/tasks/presentation/screens/tasks_screen.dart))

### 8.1 Counter-type indicator

Inside the existing `Wrap` row that already holds `PriorityBadge` + `CountdownChip` ([tasks_screen.dart:468-478](lib/features/tasks/presentation/screens/tasks_screen.dart#L468)), add:

```dart
if (task.isCounter)
  const _CounterTypeBadge(),
```

Implementation as a small private widget at the bottom of `tasks_screen.dart`:

```dart
class _CounterTypeBadge extends StatelessWidget {
  const _CounterTypeBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.numbers, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'task_type_counter'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

Pill style matches `StatusBadge` / `CountdownChip` for consistency.

### 8.2 Counter progress + increment button

Replace the assignee status dropdown ([tasks_screen.dart:479-515](lib/features/tasks/presentation/screens/tasks_screen.dart#L479)) with a branched render:

```dart
if (currentUser != null && task.assignedTo == currentUser.id) ...[
  const SizedBox(height: AppSizes.lg),
  if (task.isCounter)
    _CounterProgressRow(
      task: task,
      onIncrement: task.currentCount >= (task.targetCount ?? 0)
          ? null
          : () {
              context.read<TasksCubit>().incrementTaskCounter(
                taskId: task.id,
                isAdmin: isAdmin,
                currentUserId: currentUser.id,
                currentUserName: currentUser.name,
              );
            },
    )
  else
    DropdownButtonFormField<String>(
      // ...existing dropdown unchanged...
    ),
],
```

`_CounterProgressRow` — private widget at the bottom of `tasks_screen.dart`:

```dart
class _CounterProgressRow extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onIncrement;

  const _CounterProgressRow({required this.task, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    final target = task.targetCount ?? 0;
    final current = task.currentCount.clamp(0, target);
    final ratio = target == 0 ? 0.0 : current / target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${'progress'.tr()}: $current / $target',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: onIncrement,
              tooltip: 'increment'.tr(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio, minHeight: 8),
        ),
      ],
    );
  }
}
```

Disabled `IconButton.filledTonal` when `onIncrement == null` (i.e. `currentCount >= targetCount`) automatically grays out — no extra style needed.

### 8.3 Status badge / countdown chip

No changes. Status is already derived → persisted, so `StatusBadge` and `CountdownChip` already render the right state for counter tasks.

---

## 9. Task details screen ([task_details_screen.dart](lib/features/tasks/presentation/screens/task_details_screen.dart))

### 9.1 Counter-type chip

Add `_CounterTypeBadge()` (same widget as on the list card, hoist it into a shared spot or duplicate — see §11 affected-files) to the `Wrap` next to `StatusBadge` + `PriorityBadge` ([task_details_screen.dart:151-158](lib/features/tasks/presentation/screens/task_details_screen.dart#L151)) when `task.isCounter`.

### 9.2 Progress section

Insert a new section above `_DetailsRow(label: 'assigned_to')` (visible only when `task.isCounter`):

```dart
if (task.isCounter) ...[
  const SizedBox(height: AppSizes.lg),
  Text('progress'.tr(), style: Theme.of(context).textTheme.titleLarge),
  const SizedBox(height: AppSizes.sm),
  _CounterProgressRow(
    task: task,
    onIncrement: (currentUser != null && task.assignedTo == currentUser.id &&
                  task.currentCount < (task.targetCount ?? 0))
        ? () {
            context.read<TasksCubit>().incrementTaskCounter(
              taskId: task.id,
              isAdmin: currentUser.role == 'admin',
              currentUserId: currentUser.id,
              currentUserName: currentUser.name,
            );
          }
        : null,
  ),
  const SizedBox(height: AppSizes.lg),
],
```

If admin / creator viewing a counter task they don't own: button is disabled. They edit via the edit screen instead.

### 9.3 No other changes

Date row, status badge, priority badge, activity log section, edit / delete actions — all unchanged.

---

## 10. Operational steps for the project owner (post-merge)

This PR ships a `firestore.rules` change. After merging to `dev`:

```bash
firebase deploy --only firestore:rules
```

The rules deploy must land before any counter task is created via the new build. Otherwise the assignee's increment write will be rejected.

No Cloud Functions changes — no `firebase deploy --only functions` step required.

---

## 11. Affected files

| File | Change | Approx. size |
|---|---|---|
| `lib/features/tasks/data/models/task_model.dart` | Add `taskType`, `targetCount`, `currentCount` fields + `fromMap` / `toMap` / `copyWith`. Add `isCounter` getter and static `deriveCounterStatus(current, target)`. | ~25 line delta |
| `lib/features/tasks/data/repositories/tasks_repository.dart` | Add `incrementTaskCounter` method using `runTransaction`. | ~40 lines new |
| `lib/features/tasks/presentation/cubit/tasks_cubit.dart` | Add `incrementTaskCounter` method that proxies to the repo and refreshes role-relevant lists. | ~25 lines new |
| `lib/features/tasks/presentation/screens/add_task_screen.dart` | Task-type dropdown + conditional `target_count` field; `_saveTask` populates new fields. | ~50 line delta |
| `lib/features/tasks/presentation/screens/edit_task_screen.dart` | Hide status dropdown for counter tasks; show `target_count` / `current_count` fields; `_saveChanges` derives status for counter tasks. | ~70 line delta |
| `lib/features/tasks/presentation/screens/tasks_screen.dart` | `_CounterTypeBadge` chip in the existing Wrap; `_CounterProgressRow` replaces the dropdown for counter tasks the user is assigned to. | ~80 line delta |
| `lib/features/tasks/presentation/screens/task_details_screen.dart` | Counter-type chip in the badge Wrap; new "Progress" section above `assigned_to` row. | ~30 line delta |
| `firestore.rules` | Add `'currentCount'` to the assignee self-update mask. | 1 line |
| `assets/translations/en.json` | New keys (see §12). | ~9 lines |
| `assets/translations/ar.json` | Same keys translated. | ~9 lines |

That's it. No Cloud Functions changes. No new dependencies.

---

## 12. Translations (locked)

12 new keys total (6 × 2 locales). Keep keys flat — no plurals needed for v1.1.

```jsonc
// en.json
"task_type": "Task type",
"task_type_standard": "Standard",
"task_type_counter": "Counter",
"target_count": "Target",
"current_count": "Current",
"progress": "Progress",
"increment": "Increment",
"target_count_required": "Target is required",
"target_count_invalid_range": "Target must be between 1 and 999",
"current_count_invalid_range": "Current must be between 0 and target",

// ar.json
"task_type": "نوع المهمة",
"task_type_standard": "قياسية",
"task_type_counter": "عدّاد",
"target_count": "الهدف",
"current_count": "الحالي",
"progress": "التقدم",
"increment": "إضافة",
"target_count_required": "الهدف مطلوب",
"target_count_invalid_range": "يجب أن يكون الهدف بين 1 و 999",
"current_count_invalid_range": "يجب أن يكون الحالي بين 0 والهدف"
```

(Total: **10** new keys × 2 locales = 20 net-new entries. The agent should verify each key isn't already defined — `progress` in particular may collide; if it does, reuse the existing translation and remove from this list.)

**Translation parity check** after the agent edits: `python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a]+[k for k in a if k not in e])"` → expect `<n> <n> []`.

---

## 13. Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no Cloud Functions changes; lint is just for parity).

If the agent wants to add unit tests, the cleanest target is `TaskModel.deriveCounterStatus(current, target)` — pure function with three locked transitions. Place at `test/features/tasks/data/models/task_model_test.dart`.

---

## 14. Smoke tests (real device, where applicable)

1. **Create a standard task** — existing flow. New fields default correctly. Add screen looks unchanged when `Task type = Standard`.
2. **Create a counter task** — pick `Counter`, target = 5. Save. Doc has `taskType: 'counter'`, `targetCount: 5`, `currentCount: 0`, `status: 'pending'`. Card shows `_CounterTypeBadge`. Status badge says `pending`.
3. **Validate target range on add** — try 0, -3, 1000, "abc". Each shows the right localized error and blocks save.
4. **Increment from list card** — assignee taps `+`. `currentCount` goes 0 → 1, status flips to `'in_progress'`, badge updates accordingly. Progress bar fills proportionally.
5. **Complete by increment** — assignee on a target=3 task taps `+` three times. Last tap: `currentCount` goes 2 → 3, status flips to `'completed'`, `completedAt` set, countdown chip disappears, status badge turns green, FCM completion notification fires to admins + creator (verify via second device or Firebase console), `task_logs` entry written with `previousStatus: 'in_progress'` / `newStatus: 'completed'`. Increment button now disabled (or hidden — implementation choice via `onIncrement: null`).
6. **Concurrent increment race** — sign in same employee on two devices, open the same counter task, tap `+` simultaneously. Both increments land (transaction is atomic); count doesn't go missing. Verify Firestore doc lands at expected count.
7. **Increment past target is impossible** — even with rapid taps, `currentCount` never exceeds `targetCount`. (Repo transaction returns early when already complete.)
8. **Edit counter task — adjust target** — admin / creator opens edit screen for a target=10, current=4 counter task. Status dropdown is NOT visible. Set target = 3. Save. The task's `currentCount` clamps to 3, `targetCount` becomes 3, status derives to `'completed'`, `completedAt` set. Verify dashboard counter increments.
9. **Edit counter task — adjust current** — admin / creator on a target=10, current=4 task lowers current to 0. Save. Status derives back to `'pending'`, `completedAt` cleared.
10. **Counter task overdue rendering** — set a counter task's `dueDate` to yesterday. Card shows red overdue countdown chip + counter-type badge + progress row. Nothing crashes. Status remains `'in_progress'` (overdue is a derived UI thing on the chip, not a stored status).
11. **Backward-compat with existing standard tasks** — open a task created before this PR. `taskType` is missing from the doc, reads as `'standard'`. Card renders without counter badge or progress row. Edit screen shows status dropdown as before. No errors.
12. **Standard-task path regression** — full add → edit → status flip → delete on a standard task. Identical to today.
13. **Firestore rules deploy regression** — before deploying the new rules, attempt an increment from a logged-in employee. Write fails (mask rejects `currentCount`). After deploy, retry succeeds. Confirms the rules-deploy ordering matters.
14. **Arabic / RTL** — switch locale to Arabic. New labels render. Progress row is right-aligned, "+" button is on the leading edge of the row (RTL flips). No layout overflow.
15. **Dashboard / reports counters** — confirm counter-task completions show up in the dashboard `completedTasks` and reports `completed`. Same path as standard completions because of the persistence contract.

Smoke tests #4–#6, #8–#10, #13, #14 require real-device execution. #1, #2, #11, #12, #15 are quick regression checks. #3 can be done in-emulator.

---

## 15. Definition of Done

- [ ] `TaskModel` has `taskType` / `targetCount` / `currentCount` with locked defaults; `isCounter` getter; static `deriveCounterStatus`.
- [ ] `TasksRepository.incrementTaskCounter` exists and uses `runTransaction` per §1.2.
- [ ] `TasksCubit.incrementTaskCounter` proxies to the repo and refreshes role-relevant lists.
- [ ] Add task screen has the type dropdown + conditional target field with the locked validators.
- [ ] Edit task screen hides the status dropdown for counter tasks and derives status from counts on save (clamps `currentCount` to new `targetCount` if lowered).
- [ ] List card and task details show the counter-type badge and progress row per §8 / §9.
- [ ] `firestore.rules` widens the assignee mask to include `currentCount` only.
- [ ] 10 new translation keys added with parity check passing.
- [ ] No changes outside the files listed in §11.
- [ ] All three quality gates green.
- [ ] Workflow docs updated (see §17).
- [ ] PR title: `feat(tasks): add counter task type with derived completion`.
- [ ] PR body includes the 15 smoke tests with real-device cases marked deferred to project owner, and the operational `firebase deploy --only firestore:rules` step.

---

## 16. Risks

- **Status drift** if any code path writes `currentCount` without writing the derived `status`. Mitigated by §1 and the guardrail callouts. Code review must specifically verify that every place that mutates `currentCount` also writes `status` + `completedAt`.
- **Rules deploy ordering**: assignee increment writes fail if the new build ships before the rules deploy. Documented in §10; project owner deploys rules at merge time.
- **Concurrent increments**: handled by `runTransaction`. Without the transaction, two simultaneous taps would lose one increment.
- **Currency of `currentCount` after admin lowers `targetCount`**: handled by clamp in §7.3. If admin sets `targetCount = 3` on a task already at `currentCount = 7`, save clamps `currentCount` to 3 and derives `status = 'completed'`.
- **Existing standard tasks reading null `targetCount`**: handled by `targetCount: null` in the model and `targetCount` absent from `toMap` for standard tasks.
- **`taskType` accidentally mutated on edit save**: edit screen passes `widget.task.taskType` through unchanged. Don't expose it as an editable form field.
- **Cloud Functions write `task_logs` regardless of task type** ([functions/index.js:295-304](functions/index.js#L295)) — counter-task completions get a normal `status_changed` log entry. Acceptable; no special handling needed.

---

## 17. Workflow doc updates required

| File | Change | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | Reset to "No active task" or to next planned task on completion. | Implementing agent |
| `docs/ai-workflow/BACKLOG.md` | F3.C entry: change Status to `Done — YYYY-MM-DD`, add `**Completed**` line. | Implementing agent |
| `docs/ai-workflow/SESSION_LOG.md` | Append new implementation entry at the top. Don't edit prior entries. | Implementing agent |
| `docs/ai-workflow/DECISIONS_LOG.md` | Append: "Counter task type with derived completion via persisted status field" — record the 10 locked planning decisions and the persistence contract from §1.1. | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §4 Modules: extend the `tasks` row description to mention "counter task type with target / current count progress". §5 Firestore data model: extend the `tasks` row to mention `taskType` / `targetCount` / `currentCount`. | Implementing agent |
| `CHANGELOG.md` | Under `## [Unreleased]` → `### Added`: "Counter task type — tasks with a target count and an increment button on the assignee's card; completion is derived from progress and persisted as the task's status so existing dashboards / reports / notifications continue to work unchanged." | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change | — |
| `docs/ai-workflow/NEXT_STEPS.md` | No change unless real-device validation surfaces something worth tracking. | — |

---

## 18. Out of scope (do not pull in)

- Decrement button on the employee task card.
- Per-counter-event audit log (every `+1` does NOT write a `task_logs` row; only the status flip at completion does, via the existing Cloud Function).
- Bulk increment (`+5` / custom step).
- Different progress visualizations (radial, multi-step bar with milestones).
- Counter-task notifications independent of status flip (e.g. "Halfway there!" at 50%).
- A separate badge color path for "counter" status.
- Cloud-Function-side derivation as a defense-in-depth (the persistence contract makes this unnecessary; revisit only if status drift is observed).
- Recurring + counter combination (deferred to F3.B planning round).
- Firestore rule that strictly validates `0 <= currentCount <= targetCount` (defer; client validates and the assignee mask limits the blast radius).
- Per-type rule guards (locked decision #7 picked the simpler mask widening for v1.1).
- Equatable / freezed adoption on `TaskModel`.

---

## Notes for the implementing agent

- **Read §1 (Architecture) start to finish before writing any code.** The persistence contract is the entire point of this PR; if you write `currentCount` without writing the derived `status` in the same transaction, downstream consumers silently break and you've shipped a regression that will only surface days later when an admin notices their dashboard counts are wrong.
- **Don't branch Cloud Function code on `taskType`.** If you find yourself wanting to, the persistence contract is broken on the client. Fix the client, not the server.
- **Match `_CounterTypeBadge` styling to existing `StatusBadge` / `CountdownChip`** for visual consistency — same pill geometry, same font weight.
- **Don't add Equatable, freezed, or any new dependency.** The existing immutable + `copyWith` pattern is enough.
- **Don't refactor the task card** into a `TaskCard` widget. Keep things minimal-scope, same as F3.A.
- **Verify each translation key** isn't already defined (`progress` is a likely collision). If a key already exists with the right semantics, reuse and remove from this list.
