# Current Task

> Last updated: 2026-05-09

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

No active task. v1.1 is feature-complete. PR #29 (`feat/recurring-tasks`) carries the full F3.B implementation including the 2026-05-14 multi-assignee supplement and is ready for merge. Next step: squash-merge PR #29 into `dev`, then cut v1.1.0 release (dev → main PR, tag `v1.1.0`, store submission).

See `BACKLOG.md` for open items and `NEXT_STEPS.md` for deferred ideas.

Add a new admin-authored template object that produces a fresh task instance on a daily / weekly / monthly schedule. Templates live in a **separate `task_templates` collection** so the existing `tasks` collection stays semantically clean: `tasks` continues to represent only actionable runtime instances, and every existing consumer (dashboards, reports, FCM triggers, deadline reminders, overdue escalations, countdown chip, Firestore rules, task*logs) keeps working without per-type branches or template filters. Generation runs **server-only** in a new daily Cloud Function. Idempotency is layered: deterministic instance document IDs (`${templateId}*${YYYY-MM-DD}`) plus a `lastGeneratedAt` same-day guard on the template doc.

The architectural risk in this feature is **leakage** — if templates ever land in the `tasks` collection (or if a single scheduler tick double-generates), then dashboards over-count, FCM duplicates, deadline-reminder sweeps target template configs as if they were real tasks, and reports show ghost rows. The spec leads with the isolation + idempotency invariants; UI / formatting details follow as application of those rules.

## Branch

`feat/recurring-tasks` (created from `dev` after PR #28 merged on 2026-05-09).

## Locked planning decisions (audit round, 2026-05-09)

1. **Schema**: Option B from audit — a separate top-level Firestore collection `task_templates/`. Templates store recurrence + assignment defaults + lifecycle state. The existing `tasks/` collection is **not** touched.
2. **Template ↔ instance relationship**: at generation time the scheduler **snapshots** template fields (title, description, assignedTo / Name, assignedBy / Name, priority, taskType, targetCount) into a new `tasks/{instanceId}` document. The instance carries `templateId` as a back-reference only. Instances do **not** live-reference template fields — once generated, an instance is fully self-contained and behaves like any client-created task.
3. **Generation ownership**: server-only via a new `onSchedule` Cloud Function. No client-side generation path in v1.1. No "generate now" callable in v1.1 (deferred).
4. **Scheduler cadence**: `0 6 * * *` Asia/Jerusalem — daily 6 am local, before the existing 9 am deadline-reminder sweep so newly-generated instances can be reminded the same day if appropriate.
5. **Idempotency** (layered): (a) deterministic instance document ID `${templateId}_${YYYY-MM-DD}` where YMD is computed in Asia/Jerusalem; (b) `lastGeneratedAt: Timestamp` on the template, written atomically with the instance create inside a Firestore transaction. Same-day check uses Asia/Jerusalem wall-clock.
6. **Recurrence types in v1.1**: `daily`, `weekly`, `monthly` — no other types, no `interval` multiplier (every-N-days etc deferred), no end-date / end-after-N-occurrences (deferred).
7. **Monthly day-of-month policy**: support 1..31. When the month has fewer days than `dayOfMonth`, **clamp** to the last valid day of that month (so `dayOfMonth: 31` generates on Feb 28 / 29, never skips a month).
8. **Timezone**: every recurrence calculation, deterministic-ID date string, and same-day `lastGeneratedAt` check uses **Asia/Jerusalem wall-clock semantics**. No raw UTC date math anywhere in the generator.
9. **Counter-task interaction**: counter templates are supported. Each generated instance starts fresh with `currentCount: 0`, `status: 'pending'`. F3.C derivation logic on the instance is unchanged and remains the authoritative status path for counter instances.
10. **Cross-feature interactions**: generated instances behave exactly like normal tasks. No special-casing for countdown, deadline reminders, overdue escalations, completion notifications, dashboards, reports, or PDF export. The whole point of Option B is that none of those consumers need changes.
11. **Template lifecycle**: soft pause / resume via `isActive: bool` (locked) and hard delete (locked). Hard-deleting a template **does not cascade-delete historical instances** — they remain with their snapshotted fields and a now-dangling `templateId` reference (acceptable per snapshot principle).
12. **Permissions**: template authoring is **admin-only** in v1.1. Rules enforce. UI entry point hidden for non-admins.
13. **UI scope**: dedicated template-management screens (list / add / edit). Regular task lists (`tasks_screen.dart`, `task_details_screen.dart`) remain instance-only and **are not modified by this PR**.
14. **Optional "Recurring" badge on instances**: deferred to v1.2 unless scope easily allows.

---

## 1. Architecture (locked — read this section before any code)

### 1.1 The collection-isolation invariant

**Templates live in `task_templates/`. Instances live in `tasks/`. These two collections never overlap.**

- A `task_templates/{templateId}` document is **never queryable from existing client tasks queries** (`getTasksAssignedTo`, `getTasksCreatedBy`, `getAllTasks`).
- Existing Cloud Function triggers (`sendTaskAssignedNotification` on `tasks/{taskId}` onCreate, `sendTaskStatusNotification` on `tasks/{taskId}` onUpdate, deadline-reminder + overdue-escalation sweeps that query `tasks` collection) **do not fire on template documents** because templates are in a different collection.
- Dashboard / reports / PDF queries against `tasks/` continue to return only instances. Zero filter changes required in any existing consumer.

This is the entire reason for choosing Option B. Do not collapse the two collections, do not add a `tasksOrTemplates` query helper, do not use a sub-collection layout — keep them top-level and separate.

### 1.2 The generation invariants

The scheduler is the **only** writer of recurring instances. Locked rules:

- ❌ **No client code writes to `tasks/{instanceId}` with a `templateId` field.** Instances with `templateId` come exclusively from the scheduler.
- ❌ **No client-side recurrence calculation, no client-side "next instance preview" that tries to generate ahead of the scheduler.**
- ❌ **No `FieldValue.increment` or read-then-write outside a transaction** for `lastGeneratedAt` on the template — the same-day check + write must be atomic.
- ❌ **No `add()` for instance documents** — must use `doc(deterministicId).set(...)` so the second concurrent run hits the existing-doc safety net.
- ❌ **No raw UTC date math in the scheduler** (`new Date().getUTCDate()`, etc) — always go through the Asia/Jerusalem helper. UTC math will silently misfire across DST and around midnight.
- ❌ **No template document is ever inserted into `tasks/` even temporarily** during edit / create flows. Wrong collection means wrong rules, wrong triggers, wrong queries.
- ✅ Generation runs inside `db.runTransaction(...)` so the lastGeneratedAt + instance-create pair is atomic.
- ✅ Every templates query in the scheduler is gated by `where('isActive', '==', true)`.
- ✅ Recovery path: if an instance doc with the deterministic ID already exists but the template's `lastGeneratedAt` is stale, the transaction backfills `lastGeneratedAt` and skips the create (idempotent recovery).

### 1.3 The snapshot invariant

When the scheduler generates an instance:

- It **copies** the following template fields into the new instance: `title`, `description`, `assignedTo`, `assignedToName`, `assignedBy`, `assignedByName`, `priority`, `taskType`, `targetCount` (only when counter).
- The instance also gets fresh runtime fields: `status: 'pending'`, `completedAt: null`, `currentCount: 0` (counter only), `dueDate: <today midnight Asia/Jerusalem>`, `createdAt: <now>`, `updatedAt: <now>`, `templateId: <templateId>`.
- If an admin later renames the template or changes `assignedTo`, **previously-generated instances keep their old values**. The new template state takes effect on the next generation (tomorrow's instance).

This matches the existing denormalization precedent (`assignedToName` / `assignedByName` are already snapshotted at create-time on standard tasks).

---

## 2. Schema

### 2.1 New collection — `task_templates/{templateId}`

```
task_templates/{templateId} {
  // Identity / assignment (snapshotted into instances at generation)
  title:           string                            // required, trim non-empty
  description:    string                             // required, trim non-empty
  assignedTo:     string  (uid)                      // required
  assignedToName: string                             // snapshotted at template create/edit time
  assignedBy:     string  (uid)                      // immutable after create
  assignedByName: string                             // immutable after create

  // Variant config
  priority:    'low' | 'medium' | 'high'             // required
  taskType:    'standard' | 'counter'                // immutable after create (matches F3.C)
  targetCount: int?                                  // required when taskType == 'counter'; 1..999

  // Recurrence rule
  recurrence: {
    type:        'daily' | 'weekly' | 'monthly'     // required
    daysOfWeek:  int[]?                              // weekly only: subset of [1..7], 1=Mon ... 7=Sun. Required and non-empty when type=='weekly'
    dayOfMonth:  int?                                // monthly only: 1..31. Required when type=='monthly'
  }

  // Lifecycle / scheduler state
  isActive:        bool                              // default true; soft pause via false
  lastGeneratedAt: Timestamp?                        // null until first generation; updated by scheduler atomically
  createdAt:       Timestamp                         // server-set
  updatedAt:       Timestamp                         // server-set or client-set on edit
}
```

### 2.2 Updated `TaskModel` (instance) — one new optional field only

Add to the existing `TaskModel`:

```dart
final String? templateId;   // null for normally-created tasks; set for instances generated from a template
```

`fromMap`: `templateId: data['templateId'] as String?`. `toMap`: `if (templateId != null) 'templateId': templateId`. `copyWith`: standard pass-through param. No `clearTemplateId` needed (instances don't migrate between recurring/non-recurring).

**No other fields** added to `TaskModel`. No `isInstance` flag. No `recurringFrom` shorthand. The presence of `templateId` is the only signal.

### 2.3 New Dart model — `TaskTemplateModel`

`lib/features/tasks/data/models/task_template_model.dart` (new file). Plain immutable Dart class with `fromMap` / `toMap` / `copyWith`, mirroring `TaskModel`'s style. Includes a nested `RecurrenceRule` value class:

```dart
class RecurrenceRule {
  final String type;             // 'daily' | 'weekly' | 'monthly'
  final List<int>? daysOfWeek;   // weekly: 1..7 (Mon..Sun)
  final int? dayOfMonth;         // monthly: 1..31

  const RecurrenceRule({
    required this.type,
    this.daysOfWeek,
    this.dayOfMonth,
  });

  factory RecurrenceRule.fromMap(Map<String, dynamic> data) { ... }
  Map<String, dynamic> toMap() { ... }
}
```

`TaskTemplateModel` exposes the recurrence as a typed `RecurrenceRule` (not raw map). Validation invariants (asserted in the model's named constructor):

- `type == 'weekly'` ⇒ `daysOfWeek != null && daysOfWeek.isNotEmpty && every weekday in 1..7`
- `type == 'monthly'` ⇒ `dayOfMonth != null && dayOfMonth in 1..31`
- `type == 'daily'` ⇒ both nullable fields are null

---

## 3. Cloud Function — the generator

### 3.1 New export `generateRecurringTaskInstances`

`functions/index.js`. Locked structure:

```javascript
exports.generateRecurringTaskInstances = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "Asia/Jerusalem",
  },
  async () => {
    try {
      const db = admin.firestore();
      const now = new Date();
      const todayYMD = ymdInJerusalem(now); // helper, see §3.3
      const todayDueDate = jerusalemMidnightAsUTC(now); // helper

      const snap = await db
        .collection("task_templates")
        .where("isActive", "==", true)
        .get();

      for (const templateDoc of snap.docs) {
        const template = templateDoc.data();
        if (!shouldGenerateOn(template.recurrence, now)) continue;

        const instanceId = `${templateDoc.id}_${todayYMD}`;
        const instanceRef = db.collection("tasks").doc(instanceId);

        await db.runTransaction(async (txn) => {
          const freshTemplate = await txn.get(templateDoc.ref);
          if (!freshTemplate.exists) return;
          const freshData = freshTemplate.data() || {};
          if (freshData.isActive !== true) return;

          const lastGen = freshData.lastGeneratedAt
            ? freshData.lastGeneratedAt.toDate()
            : null;
          if (lastGen && sameDayJerusalem(lastGen, now)) return; // already generated today

          const existingInstance = await txn.get(instanceRef);
          if (existingInstance.exists) {
            // Recovery: deterministic-ID instance exists from a previous partial run.
            // Backfill the template's lastGeneratedAt and skip the create.
            txn.update(templateDoc.ref, {
              lastGeneratedAt: admin.firestore.Timestamp.fromDate(now),
              updatedAt: admin.firestore.Timestamp.fromDate(now),
            });
            return;
          }

          const instance = {
            title: freshData.title || "",
            description: freshData.description || "",
            assignedTo: freshData.assignedTo || "",
            assignedToName: freshData.assignedToName || "",
            assignedBy: freshData.assignedBy || "",
            assignedByName: freshData.assignedByName || "",
            priority: freshData.priority || "medium",
            status: "pending",
            taskType: freshData.taskType || "standard",
            currentCount: 0,
            dueDate: admin.firestore.Timestamp.fromDate(todayDueDate),
            createdAt: admin.firestore.Timestamp.fromDate(now),
            updatedAt: admin.firestore.Timestamp.fromDate(now),
            completedAt: null,
            templateId: templateDoc.id,
          };
          if (freshData.taskType === "counter" && freshData.targetCount) {
            instance.targetCount = freshData.targetCount;
          }

          txn.set(instanceRef, instance);
          txn.update(templateDoc.ref, {
            lastGeneratedAt: admin.firestore.Timestamp.fromDate(now),
            updatedAt: admin.firestore.Timestamp.fromDate(now),
          });
        });
      }
    } catch (error) {
      console.error("Error generating recurring task instances:", error);
    }
  },
);
```

### 3.2 No FCM / task_logs writes from the generator

- The existing `sendTaskAssignedNotification` (`onDocumentCreated tasks/{taskId}`) **already fires** when `txn.set(instanceRef, instance)` lands. That trigger writes the `task_logs` `created` entry and sends FCM to the assignee. We get all of that for free.
- The generator **must not** write a `task_logs` entry directly or send FCM directly — that would duplicate the existing trigger's behavior.

### 3.3 Helpers (Asia/Jerusalem wall-clock)

Place these helpers near the top of `functions/index.js` next to the existing `localize(...)`:

```javascript
function ymdInJerusalem(date) {
  // Returns "YYYY-MM-DD" in Asia/Jerusalem wall-clock.
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date); // en-CA gives ISO-like YYYY-MM-DD
}

function jerusalemMidnightAsUTC(date) {
  // Returns the JS Date that represents 00:00 Asia/Jerusalem on date's calendar day,
  // expressed in absolute time (UTC under the hood). Used as instance.dueDate.
  const ymd = ymdInJerusalem(date); // "YYYY-MM-DD"
  // Build a string like "2026-05-09T00:00:00+03:00" or "+02:00" depending on DST.
  // The simplest reliable approach: use the offset from Intl.
  const offset = jerusalemOffsetForDate(date); // e.g. "+03:00"
  return new Date(`${ymd}T00:00:00${offset}`);
}

function jerusalemOffsetForDate(date) {
  // Compute Asia/Jerusalem UTC offset for the given date as ±HH:MM.
  const tzFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    timeZoneName: "longOffset",
  });
  const parts = tzFormatter.formatToParts(date);
  const tz = parts.find((p) => p.type === "timeZoneName").value; // e.g. "GMT+3" or "GMT+03:00"
  const match = tz.match(/GMT([+-])(\d{1,2})(?::?(\d{2}))?/);
  if (!match) return "+00:00";
  const sign = match[1];
  const hh = match[2].padStart(2, "0");
  const mm = (match[3] || "00").padStart(2, "0");
  return `${sign}${hh}:${mm}`;
}

function sameDayJerusalem(a, b) {
  return ymdInJerusalem(a) === ymdInJerusalem(b);
}

function jerusalemDayOfWeek(date) {
  // 1=Mon ... 7=Sun (matches Dart DateTime.weekday).
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    weekday: "short",
  });
  const map = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  return map[formatter.format(date)];
}

function jerusalemDayOfMonth(date) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    day: "numeric",
  });
  return parseInt(formatter.format(date), 10);
}

function jerusalemLastDayOfMonth(date) {
  // Last calendar day of the month containing `date` in Asia/Jerusalem.
  const ymd = ymdInJerusalem(date); // "YYYY-MM-DD"
  const [y, m] = ymd.split("-").map(Number);
  // JS Date with day=0 of the next month gives the last day of month m.
  // We can construct this in any timezone since we only need the day count.
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}
```

### 3.4 `shouldGenerateOn(recurrence, now)` — the recurrence matcher

```javascript
function shouldGenerateOn(recurrence, now) {
  if (!recurrence || typeof recurrence !== "object") return false;
  const type = recurrence.type;
  if (type === "daily") return true;

  if (type === "weekly") {
    const days = recurrence.daysOfWeek;
    if (!Array.isArray(days) || days.length === 0) return false;
    return days.includes(jerusalemDayOfWeek(now));
  }

  if (type === "monthly") {
    const dayOfMonth = recurrence.dayOfMonth;
    if (typeof dayOfMonth !== "number" || dayOfMonth < 1 || dayOfMonth > 31) {
      return false;
    }
    const lastDay = jerusalemLastDayOfMonth(now);
    const targetDay = Math.min(dayOfMonth, lastDay); // monthly clamp
    return jerusalemDayOfMonth(now) === targetDay;
  }

  return false;
}
```

The clamp is the locked monthly edge-case policy (decision #8).

---

## 4. Firestore rules

### 4.1 New rules block — `task_templates/{templateId}`

Add to `firestore.rules` after the `tasks/{taskId}` block:

```
match /task_templates/{templateId} {
  allow read: if isAdmin();
  allow create: if isAdmin() && request.resource.data.assignedBy == request.auth.uid;
  allow update: if isAdmin() && request.resource.data.assignedBy == resource.data.assignedBy;
  allow delete: if isAdmin();
}
```

Locked decisions baked in:

- Admin-only read (templates are a configuration surface; non-admins don't see them).
- Admin-only create with `assignedBy == auth.uid` so the template author is the admin who created it.
- Admin-only update with `assignedBy` immutability (matches the existing `tasks/` rule for `assignedBy`).
- Admin-only hard delete.
- The scheduler bypasses rules entirely via Admin SDK, so no special-case rule for "scheduler can write."

### 4.2 No changes to the `tasks/{taskId}` block

The existing rules apply unchanged to instances. Their `templateId` field is incidental — no rule references it. Specifically:

- The assignee self-update mask remains the F3.C-widened mask (`status / updatedAt / completedAt / updatedBy / updatedByName / currentCount`). `templateId` is not in the mask, so an assignee cannot mutate it. ✓
- Instance create comes from Admin SDK (server-only generation), so the existing `creatingOwnTask()` rule for client-created tasks doesn't gate it. ✓

### 4.3 Operational deploy step

After merge: `firebase deploy --only firestore:rules` AND `firebase deploy --only functions:generateRecurringTaskInstances` (or just `firebase deploy --only functions` to redeploy all). Both must land before any template is created.

---

## 5. Repositories

### 5.1 New repository — `TemplatesRepository`

`lib/features/tasks/data/repositories/templates_repository.dart` (new file, ~80 lines). Methods:

```dart
class TemplatesRepository {
  final FirebaseFirestore _firestore;

  TemplatesRepository(this._firestore);

  Future<List<TaskTemplateModel>> getAllTemplates() async { ... }       // admin home
  Future<TaskTemplateModel?> getTemplateById(String templateId) async { ... }
  Future<void> createTemplate(TaskTemplateModel template) async { ... }
  Future<void> updateTemplate(TaskTemplateModel template) async { ... } // admin/creator edit
  Future<void> setTemplateActive(String templateId, bool isActive) async { ... } // pause / resume toggle
  Future<void> deleteTemplate(String templateId) async { ... }          // hard delete
}
```

Use `FirebasePaths.taskTemplates` (new constant — `'task_templates'`).

### 5.2 No changes to `TasksRepository`

The existing repo stays untouched. Templates do not flow through it. Instances generated by the scheduler are read by the existing `getTasksAssignedTo` / `getAllTasks` / `getTasksCreatedBy` queries because they live in `tasks/` like any other task.

---

## 6. Cubits

### 6.1 New cubit — `TemplatesCubit` + `TemplatesState`

`lib/features/tasks/presentation/cubit/templates_cubit.dart` and `templates_state.dart` (new files). Same shape as the existing `TasksCubit`:

- `TemplatesState`: `status: TemplatesStatus { initial, loading, loaded, error }`, `templates: List<TaskTemplateModel>`, `errorMessage: String?`, `copyWith` with explicit `clearError`.
- `TemplatesCubit` methods: `fetchAll`, `createTemplate`, `updateTemplate`, `toggleActive(templateId, isActive)`, `deleteTemplate`. Each writes through the repo and refreshes the list (loading-emit refetch is fine here — the templates screen is admin-only and infrequently visited; the F3.C optimistic-patch optimization is not warranted).

### 6.2 Wire into `MultiBlocProvider`

Add `TemplatesCubit` to the global `MultiBlocProvider` in [app.dart](lib/app/app.dart) following the existing pattern (instantiate the repo, pass to the cubit, mount).

---

## 7. UI screens (new — admin-only)

### 7.1 `RecurringTasksScreen` — list of templates

`lib/features/tasks/presentation/screens/recurring_tasks_screen.dart`. New route `RouteNames.recurringTasks` (= `'/recurring-tasks'`).

- Reachable from `AppDrawer` (admin section only — gated by `currentUser.role == 'admin'`).
- `BlocBuilder<TemplatesCubit, TemplatesState>` with the same loading / empty / error state pattern as `TasksScreen`.
- Each list item: title, recurrence summary chip ("Daily" / "Weekly · Mon, Wed, Fri" / "Monthly · 31"), assigned-to name, `isActive` indicator (paused vs active), trailing menu with Edit / Pause-Resume / Delete (delete uses the same confirmation dialog pattern from `task_details_screen`).
- FAB: "Add Template" → pushes `add_template_screen`.
- No countdown chip on templates (they don't have a `dueDate`).

### 7.2 `AddTemplateScreen` and `EditTemplateScreen`

`lib/features/tasks/presentation/screens/add_template_screen.dart` and `.../edit_template_screen.dart`.

Form fields:

- Title (required, trim non-empty)
- Description (required, trim non-empty)
- Assigned to (employee dropdown, same source as `add_task_screen`)
- Priority (low / medium / high)
- Task type: standard / counter — **immutable on edit** (decision #4 immutability invariant from F3.C carries forward)
- Target count (when counter; 1..999, validated like F3.C)
- Recurrence picker:
  - Type dropdown: daily / weekly / monthly
  - Conditional on type:
    - `weekly`: a row of 7 toggle chips (Mon..Sun); validator requires at least one selected
    - `monthly`: numeric field 1..31; the help text shows the locked clamp policy ("Months with fewer days clamp to the last valid day, e.g. 31 → Feb 28/29")
    - `daily`: no extra fields
- `isActive` toggle (defaults true for add; editable for edit)

Save:

- Add: write a new template. Server fields (`createdAt`, `updatedAt`) set to `DateTime.now()`. `lastGeneratedAt: null`.
- Edit: write the full template doc via `updateTemplate`. `assignedBy`, `assignedByName`, `taskType`, `createdAt` pass through unchanged (immutability invariants).

### 7.3 No changes to `tasks_screen.dart` or `task_details_screen.dart` in this PR

Per decision #14 (recurring badge deferred). Instances render exactly like client-created tasks. The only client-visible signal that a task came from a template is the `templateId` field, which has no UI surfaces in v1.1.

---

## 8. Admin drawer entry

Add a new entry in [app_drawer.dart](lib/shared/widgets/app_drawer.dart) (admin-only branch) that navigates to `RouteNames.recurringTasks`. Use `Icons.repeat` for the icon. Match the existing drawer-entry style.

---

## 9. Translations

~18 new keys × 2 locales. Keep keys flat — no plurals (simpler than F3.C since recurrence labels don't need pluralization for v1.1).

```jsonc
// en.json
"recurring_tasks": "Recurring Tasks",
"recurring_template": "Template",
"add_template": "Add Template",
"edit_template": "Edit Template",
"recurrence": "Recurrence",
"recurrence_daily": "Daily",
"recurrence_weekly": "Weekly",
"recurrence_monthly": "Monthly",
"days_of_week": "Days of week",
"days_of_week_required": "Pick at least one day",
"day_of_month": "Day of month",
"day_of_month_invalid": "Day must be between 1 and 31",
"day_of_month_clamp_hint": "Months with fewer days clamp to the last valid day",
"template_active": "Active",
"template_paused": "Paused",
"pause": "Pause",
"resume": "Resume",
"delete_template_confirm_title": "Delete this template?",
"delete_template_confirm_message": "Existing tasks already generated from \"{}\" will not be deleted.",

// + the seven weekday keys IF they don't already exist:
"weekday_mon": "Mon",
"weekday_tue": "Tue",
"weekday_wed": "Wed",
"weekday_thu": "Thu",
"weekday_fri": "Fri",
"weekday_sat": "Sat",
"weekday_sun": "Sun",
```

**Implementing agent must grep for existing weekday keys before adding** — Arabic translations may already include shortened weekday names from `intl` formatters. Reuse if present.

Translation parity check after edits: `python3 -c "..."` → `<n> <n> []`.

---

## 10. Affected files

| File                                                                  | Change                                                                                                                                                                                                                    | Approx. size      |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `lib/features/tasks/data/models/task_template_model.dart`             | New file: `TaskTemplateModel` + `RecurrenceRule`.                                                                                                                                                                         | ~120 lines        |
| `lib/features/tasks/data/models/task_model.dart`                      | Add `templateId: String?` field + `fromMap` / `toMap` / `copyWith`.                                                                                                                                                       | ~10 line delta    |
| `lib/features/tasks/data/repositories/templates_repository.dart`      | New file: CRUD + `setTemplateActive`.                                                                                                                                                                                     | ~80 lines         |
| `lib/features/tasks/presentation/cubit/templates_cubit.dart`          | New file.                                                                                                                                                                                                                 | ~80 lines         |
| `lib/features/tasks/presentation/cubit/templates_state.dart`          | New file.                                                                                                                                                                                                                 | ~50 lines         |
| `lib/features/tasks/presentation/screens/recurring_tasks_screen.dart` | New file: list / pause / delete UI.                                                                                                                                                                                       | ~250 lines        |
| `lib/features/tasks/presentation/screens/add_template_screen.dart`    | New file: full add form including recurrence picker.                                                                                                                                                                      | ~280 lines        |
| `lib/features/tasks/presentation/screens/edit_template_screen.dart`   | New file: full edit form, immutable taskType.                                                                                                                                                                             | ~300 lines        |
| `lib/app/app.dart`                                                    | Register `TemplatesRepository` + `TemplatesCubit` in `MultiBlocProvider`.                                                                                                                                                 | ~6 line delta     |
| `lib/core/routes/route_names.dart`                                    | Add `recurringTasks`, `addTemplate`, `editTemplate`.                                                                                                                                                                      | ~3 lines          |
| `lib/core/routes/app_router.dart`                                     | Add three route cases.                                                                                                                                                                                                    | ~12 lines         |
| `lib/core/constants/firebase_paths.dart`                              | Add `taskTemplates = 'task_templates'`.                                                                                                                                                                                   | 1 line            |
| `lib/shared/widgets/app_drawer.dart`                                  | Admin-only entry for "Recurring Tasks".                                                                                                                                                                                   | ~6 line delta     |
| `firestore.rules`                                                     | New `task_templates/{templateId}` rules block per §4.1.                                                                                                                                                                   | ~6 lines          |
| `functions/index.js`                                                  | New `generateRecurringTaskInstances` `onSchedule` + helpers (`ymdInJerusalem`, `sameDayJerusalem`, `jerusalemDayOfWeek`, `jerusalemDayOfMonth`, `jerusalemLastDayOfMonth`, `jerusalemMidnightAsUTC`, `shouldGenerateOn`). | ~150 lines        |
| `assets/translations/en.json`                                         | New keys (§9).                                                                                                                                                                                                            | ~20 lines         |
| `assets/translations/ar.json`                                         | Same keys translated.                                                                                                                                                                                                     | ~20 lines         |
| `test/features/tasks/data/models/task_template_model_test.dart`       | Optional: pure-function tests for `RecurrenceRule.fromMap` round-trip + `shouldGenerateOn` matchers (if porting the JS matcher to Dart for parity testing isn't worth it, defer entirely).                                | ~50 lines or skip |

That's it. **Zero changes** to: `tasks_repository.dart`, `tasks_cubit.dart`, `tasks_state.dart`, `tasks_screen.dart`, `task_details_screen.dart`, `add_task_screen.dart`, `edit_task_screen.dart`, `task_filter_bottom_sheet.dart`, `dashboard_repository.dart`, `reports_repository.dart`, `pdf_report_service.dart`, `countdown_chip.dart`, `countdown_clock_provider.dart`, `status_badge.dart`, `priority_badge.dart`, any other shared widget, or any existing Cloud Function. The collection-isolation invariant is what enables this.

---

## 11. Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green.

---

## 12. Smoke tests

These are the tests that validate the F3.B-specific invariants. Real-device cases marked **(real)**.

1. **Daily template happy path** **(real)** — admin creates a daily template assigned to employee X. At 6am Asia/Jerusalem next morning, an instance `${templateId}_2026-05-10` lands in `tasks/`. Employee X receives FCM "Task assigned by …" via the existing trigger. `task_logs` shows a `created` entry. `lastGeneratedAt` on the template equals the generation time.

2. **Weekly template — only matching days fire** **(real)** — template recurrence `weekly` with `daysOfWeek: [1, 3, 5]` (Mon/Wed/Fri Asia/Jerusalem). Verify across one calendar week that instances are generated Mon/Wed/Fri only.

3. **Monthly template — clamp** **(real)** — template recurrence `monthly` with `dayOfMonth: 31`. In February (28 or 29 days), instance generates on the last day of February. In April (30 days), generates on April 30. In May (31 days), generates on May 31. Three calendar boundaries.

4. **Idempotency — same-day re-run** **(emulator-friendly)** — manually invoke the scheduled function twice within seconds (Firebase CLI: `firebase functions:shell` then call the function twice). Only one instance lands in `tasks/`, `lastGeneratedAt` is not double-incremented.

5. **Idempotency — recovery from partial run** **(emulator-friendly)** — manually create a doc at `tasks/${templateId}_${todayYMD}` (skipping the `lastGeneratedAt` update). Run the scheduler. Expect: scheduler detects the existing instance, backfills `lastGeneratedAt` on the template, does NOT overwrite the existing instance fields.

6. **Pause / resume** **(real)** — admin toggles `isActive: false` on a daily template. Next morning's run skips it (no instance generated). Toggle back to `true`, the morning after that an instance generates again.

7. **Hard delete preserves historical instances** **(real)** — admin deletes a template that has 5 historical instances. The 5 instances remain in `tasks/`, are still readable in dashboards / reports / employee task lists. `templateId` field on the instances is now dangling (points at a non-existent template) — acceptable.

8. **Counter template + recurrence** **(real)** — daily counter template with `targetCount: 5`. Each generated instance starts at `currentCount: 0`, `status: 'pending'`. Employee increments on the instance using the existing F3.C path; status flips to `completed` at 5/5; FCM completion notification fires. Tomorrow's generated instance is fresh again.

9. **Snapshot stability** **(real)** — admin creates a template "Send weekly report" assigned to Alice. After 3 instances generate, admin renames the template to "Submit weekly summary" and changes `assignedTo` to Bob. The 3 historical instances keep their original title and assignedTo / Name. Tomorrow's instance uses the new title and is assigned to Bob.

10. **DST boundary** **(time-sensitive)** — verify that across the DST transition (Israel: last Friday of March → DST on; last Sunday of October → DST off), a `weekly` template scheduled for "Friday" continues to fire on Friday wall-clock Asia/Jerusalem. Cloud Scheduler with `timeZone: 'Asia/Jerusalem'` handles this automatically; this test confirms our helper functions don't undo it.

11. **Existing trigger compatibility — FCM and task_logs** **(real)** — confirm the generated instance's `created` row in `task_logs` has the same shape as a client-created task's `created` row. Confirm `assignedBy / assignedByName` on the instance match the template's. Confirm FCM body localizes per the assignee's `users/{uid}.languageCode`.

12. **Dashboard / reports include generated instances naturally** **(real)** — generate 3 instances over 3 days, complete 2 of them. Dashboard shows them in `totalTasks / completedTasks / pendingTasks` counters. Reports' monthly-by-employee pulls them. Verify zero behavioral change required to those features.

13. **Existing standard / counter task flows unchanged** **(real)** — full add → edit → status flip → delete on a standard task and a counter task. Identical to today's behavior.

14. **Rules — non-admin cannot read or write templates** **(real)** — sign in as employee. Attempt to read `task_templates/{anyId}` and write a new template. Both fail.

15. **Translation parity** **(emulator)** — `python3 -c "..."` returns `<n> <n> []`.

Smoke tests #1–#3, #6–#9, #11–#14 require real-device + multi-day timing windows; project-owner-only. #4, #5, #15 the agent can run.

---

## 13. Definition of Done

- [ ] `task_templates/` collection rules block exists in `firestore.rules` per §4.1.
- [ ] `generateRecurringTaskInstances` exported from `functions/index.js` with the locked `onSchedule` config and the layered idempotency from §3.1.
- [ ] All seven Asia/Jerusalem helpers exist in `functions/index.js` per §3.3 — no raw UTC date math in the generator.
- [ ] `shouldGenerateOn` matcher per §3.4, including the monthly clamp.
- [ ] `TaskTemplateModel` + `RecurrenceRule` exist with the locked validation invariants.
- [ ] `TaskModel` gains `templateId: String?` (only) — no other fields.
- [ ] `TemplatesRepository` + `TemplatesCubit` + `TemplatesState` exist.
- [ ] Three new screens (list / add / edit) with the form fields locked in §7.
- [ ] Admin-only drawer entry + three new routes wired.
- [ ] `MultiBlocProvider` registers the new cubit.
- [ ] ~18 new translation keys × 2 locales with parity check passing.
- [ ] No changes outside the files listed in §10.
- [ ] All three quality gates green.
- [ ] Workflow docs updated (see §15).
- [ ] PR title: `feat(tasks): add recurring task templates with cron-driven instance generation`.
- [ ] PR body includes the persistence-contract restatement, 15 smoke tests with real-device cases marked deferred to project owner, and the operational deploy steps for both rules and the new function.

---

## 14. Risks

- **Collection leakage**: if a template ever lands in `tasks/`, dashboards over-count. Code review must specifically check that no client path writes to `tasks/{...}` from the templates UI. Templates UI uses `TemplatesRepository` only.
- **Idempotency drift**: if the deterministic ID format changes between deploys (e.g. someone changes the date separator), today's run thinks today's instance doesn't exist and double-generates. Lock the format `${templateId}_${YYYY-MM-DD}` and don't change it.
- **Timezone bugs**: raw UTC math in any helper would break around midnight Asia/Jerusalem. Spec mandates `Intl.DateTimeFormat` with `timeZone: 'Asia/Jerusalem'`. Code review specifically checks no `getUTCDate()` / `getUTCDay()` / `getUTCMonth()` slipped into the new helpers.
- **DST transitions**: Cloud Scheduler with `timeZone: 'Asia/Jerusalem'` fires correctly across DST. Our helpers also need to: `Intl.DateTimeFormat` handles it; manual offset arithmetic does not. Spec uses `Intl`.
- **Rules deploy ordering**: client templates UI must not be visible until `task_templates/` rules are live. Otherwise admin's create-template write fails silently. Mitigation: rules deploy is a documented operational step (§4.3); UI is admin-only and can be hidden if needed. Acceptable.
- **Counter-instance fairness**: a counter template generated mid-day at 6am gives the assignee from 6am to midnight to complete it (vs a client-created task which can be backdated). Acceptable — same-day deadlines are normal.
- **Accumulation of paused templates**: long-paused templates stay in the collection; querying with `where('isActive', '==', true)` skips them. No cleanup needed.
- **Snapshot stability after template edits**: documented at §1.3 as a feature, not a bug. If a tester reports "I changed the template but old instances still say the old name," the answer is "by design — old instances are immutable history."
- **Dangling `templateId`** after hard-delete: instances reference a non-existent template. Acceptable per decision #11; nothing in the codebase joins on `templateId` in v1.1.

---

## 15. Workflow doc updates required

| File                                  | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Who                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------- |
| `docs/ai-workflow/CURRENT_TASK.md`    | Reset to "No active task" or to next planned task on completion.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Implementing agent                |
| `docs/ai-workflow/BACKLOG.md`         | F3.B entry: change Status to `Done — YYYY-MM-DD`, add `**Completed**` line summarizing what shipped + automated quality-gate results + which smoke tests are deferred to project owner.                                                                                                                                                                                                                                                                                                                                                                | Implementing agent                |
| `docs/ai-workflow/SESSION_LOG.md`     | Append new implementation entry at the top. Don't edit prior entries.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Implementing agent                |
| `docs/ai-workflow/DECISIONS_LOG.md`   | Append: "Recurring tasks: separate `task_templates` collection with cron-driven server-only instance generation" — record the 14 locked planning decisions and the collection-isolation + idempotency invariants.                                                                                                                                                                                                                                                                                                                                      | Implementing agent                |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §4 Modules: extend the `tasks` row to mention "recurring task templates with cron-driven instance generation (admin-only)". §5 Firestore data model: add a `task_templates/{templateId}` row with admin-only access and a `cron-generated instances; templates configure the schedule` note. §6 Cloud Functions table: add `generateRecurringTaskInstances` (`onSchedule 0 6 * * *` Asia/Jerusalem, role: scheduler, purpose: "Daily idempotent generator that creates `tasks/{templateId}_{YYYY-MM-DD}` instances from active recurring templates."). | Implementing agent                |
| `CHANGELOG.md`                        | Under `## [Unreleased]` → `### Added`: "Recurring task templates — admins can author daily / weekly / monthly templates that auto-generate fresh task instances each morning at 6am Asia/Jerusalem. Templates support standard and counter task types, can be paused / resumed without losing history, and clamp month-end edge cases (e.g. day 31 generates on Feb 28/29)."                                                                                                                                                                           | Implementing agent                |
| `docs/release-checklist.md`           | Add: post-merge ops include `firebase deploy --only functions:generateRecurringTaskInstances` and `firebase deploy --only firestore:rules`.                                                                                                                                                                                                                                                                                                                                                                                                            | Implementing agent (small append) |
| `docs/ai-workflow/RULES.md`           | No change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | —                                 |
| `docs/ai-workflow/NEXT_STEPS.md`      | Add a "Manual generate-now callable" entry under Engineering and a "Recurring instance badge on task cards" entry under UI / UX (both deferred from F3.B v1.1 scope).                                                                                                                                                                                                                                                                                                                                                                                  | Implementing agent                |

---

## 16. Out of scope (do not pull in)

- Hourly recurrence.
- Custom intervals (every-N-days, every-N-weeks, every-N-months).
- End-date / end-after-N-occurrences.
- "Generate now" admin callable (defer to v1.2; capture in NEXT_STEPS).
- Recurring badge / icon on the task card (decision #14; capture in NEXT_STEPS).
- Cascade-delete of historical instances when a template is deleted.
- Template duplication / templating (creating a template from an existing instance).
- Multi-assignee templates (one template, multiple assignees per generated instance).
- Editable `taskType` on edit screen (immutable per F3.C precedent).
- Assignee-side template edit (admin-only per decision #12).
- A dedicated Cloud Function trigger for templates' onCreate / onUpdate (templates don't need FCM).
- Any change to `tasks_screen.dart`, `task_details_screen.dart`, `add_task_screen.dart`, `edit_task_screen.dart`, dashboard, reports, PDF, status badge, priority badge, countdown chip, or countdown clock provider.
- Equatable / freezed adoption.
- New dependencies.

---

## 17. Notes for the implementing agent

- **Read §1 (Architecture) start to finish before writing any code.** The collection-isolation invariant + idempotency invariants are the entire point of this PR. Templates land in `task_templates/`. Instances land in `tasks/`. They never overlap. Idempotency is layered: deterministic ID + `lastGeneratedAt` same-day check, both inside one transaction.
- **Don't touch existing instance-side files** (`tasks_screen.dart`, `task_details_screen.dart`, `tasks_repository.dart`, etc.) unless §10 lists them (it doesn't). The whole point of the architecture is that those files don't need to change.
- **No raw UTC date math in `functions/index.js`** for the new generator. Always go through the Asia/Jerusalem helpers in §3.3. Code review will look for `getUTCDate()` / `getUTCDay()` / `new Date(year, month, day)` (which uses local time of the runtime — also wrong since that's UTC inside Cloud Functions) — flag any of those.
- **`Intl.DateTimeFormat` with `timeZone: 'Asia/Jerusalem'`** is the only sanctioned way to extract YMD / day-of-week / day-of-month for the matcher and the deterministic ID.
- **Match `_CounterTypeBadge` / `StatusBadge` styling** for any new chips on the templates list (recurrence summary, active/paused indicator).
- **No new dependencies.** The existing stack is sufficient.
- **The implementing agent is allowed to verify weekday translation keys exist before adding the seven `weekday_*` keys in §9.** If `intl` already provides them via `DateFormat.E()`, reuse and remove from the locked translation list. Update parity count accordingly.
- **The optional Dart unit test in §10 is genuinely optional.** A pure-function test of `RecurrenceRule.fromMap` round-trip is fine; porting `shouldGenerateOn` to Dart for parity testing is overkill — the JS matcher is the authoritative one and runs server-side.
