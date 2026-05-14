# Current Task

> Last updated: 2026-05-14

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**BACKLOG #12 — Progressive Deadline Reminder Notifications**
Branch: `feat/progressive-reminders` (created from `dev` 2026-05-14)

Extend `sendTaskDeadlineReminders` from a single 24h reminder to a 72h + 24h progressive pattern. Fix the existing timezone bug in the same PR. Also fix the same-day check bug in `sendOverdueTaskEscalations`. Scope: `functions/index.js` + translation JSON files only.

---

## Locked planning decisions

1. **Thresholds** — 72h + 24h. No 48h threshold in this PR to avoid notification fatigue.
2. **Deduplication fields** — Two server-written Timestamp fields on the task doc: `reminderSent72hAt` and `reminderSent24hAt`. Mirrors the existing `lastOverdueReminderAt` / `lastOverdueEscalationAt` pattern on `sendOverdueTaskEscalations`.
3. **Timezone bug fix** — Fix in this PR. Both `sendTaskDeadlineReminders` query windows and the same-day guard on `sendOverdueTaskEscalations` must use the existing `ymdInJerusalem` / `jerusalemMidnightAsUTC` helpers, not raw `new Date()`.
4. **Notification targets** — Employee (assignee) only. Admins are not notified before the deadline.
5. **New i18n key** — `task_deadline_72h_body` added to: `functions/index.js` i18n table, `assets/translations/en.json`, `assets/translations/ar.json`. Reuse `task_deadline_title` and `task_deadline_tomorrow_body` (24h) unchanged.
6. **PR scope** — `functions/index.js` + translation JSON files only. No new Dart files, no `TaskModel` changes, no `pubspec.yaml` changes, no UI changes.
7. **Shorebird eligibility** — Not patch-eligible (functions change). Requires `firebase deploy --only functions` after merge.

---

## 1. Architecture (read this before any code)

### 1.1 Existing function landscape

Two daily Cloud Functions interact with `dueDate`:

| Function | Schedule | Covers | Dedup field |
|---|---|---|---|
| `sendTaskDeadlineReminders` | `0 9 * * *` Asia/Jerusalem | Pre-deadline: "due tomorrow" (24h) — **buggy timezone math** | None today |
| `sendOverdueTaskEscalations` | `0 10 * * *` Asia/Jerusalem | Post-deadline: overdue escalation | `lastOverdueReminderAt`, `lastOverdueEscalationAt` on task doc |

### 1.2 The timezone bug (must fix)

`sendTaskDeadlineReminders` computes the query window with raw JS `new Date()`:

```js
// BUGGY — runs in UTC Cloud Functions environment; NOT Asia/Jerusalem wall-clock
const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);
const tomorrowStart = tomorrow;
const tomorrowEnd = new Date(tomorrow.getTime() + 24 * 60 * 60 * 1000);
```

`ymdInJerusalem` and `jerusalemMidnightAsUTC` helpers already exist in the file (used by `generateRecurringTaskInstances`). The fix is to use them:

```js
// CORRECT — Jerusalem wall-clock window
const nowJer = ymdInJerusalem(now);
const tomorrowMidnightUtc = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 1);
const tomorrowEndUtc = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 2);
```

The same-day dedup check in `sendOverdueTaskEscalations` uses raw JS date methods:

```js
// BUGGY — raw UTC
const sameDay = (ts) => {
  const d = ts.toDate();
  return d.getFullYear() === now.getFullYear() &&
         d.getMonth() === now.getMonth() &&
         d.getDate() === now.getDate();
};
```

Fix: use `sameDayJerusalem(ts.toDate(), now)` — this helper also already exists in the file.

### 1.3 Deduplication invariant

Each threshold must fire at most once per task per calendar day (Jerusalem wall-clock). The guard is:

```js
// Before sending the 72h reminder:
if (task.reminderSent72hAt && sameDayJerusalem(task.reminderSent72hAt.toDate(), now)) {
  continue; // already sent today
}

// After sending, write back:
await db.collection('tasks').doc(taskId).update({ reminderSent72hAt: admin.firestore.FieldValue.serverTimestamp() });
```

Fields are absent on existing task docs (no migration needed — `undefined` / `null` → no same-day match → sends correctly on first trigger).

### 1.4 `dueDate` semantics

`TaskModel.dueDate` is semantically date-only. The app treats it as end-of-day in Asia/Jerusalem. A task with `dueDate = 2026-05-20` is considered due at 23:59:59 Jerusalem on that date.

- **72h window**: `dueDate` falls in the Jerusalem calendar day that is exactly 3 days from today: `[dayAfterTomorrow midnight UTC, day+3 midnight UTC)`.
- **24h window**: `dueDate` falls in the Jerusalem calendar day that is exactly 1 day from today (tomorrow): `[tomorrow midnight UTC, day+2 midnight UTC)`.

Both windows must use Jerusalem midnight boundaries computed via `jerusalemMidnightAsUTC`.

---

## 2. `sendTaskDeadlineReminders` — full rewrite spec

**File:** `functions/index.js` — replace the existing `sendTaskDeadlineReminders` function body.

### 2.1 Schedule

Unchanged: `schedule: "0 9 * * *"`, `timeZone: "Asia/Jerusalem"`.

### 2.2 Query windows (two separate Firestore queries)

```js
const now = new Date();
const nowJer = ymdInJerusalem(now);

// 72h window: tasks due in exactly 3 days (Jerusalem calendar day)
const in72hStart = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 3);
const in72hEnd   = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 4);

// 24h window: tasks due in exactly 1 day (Jerusalem calendar day)
const in24hStart = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 1);
const in24hEnd   = jerusalemMidnightAsUTC(nowJer.year, nowJer.month, nowJer.day + 2);
```

Run both Firestore queries in parallel:

```js
const [snap72h, snap24h] = await Promise.all([
  db.collection('tasks')
    .where('status', '!=', 'completed')
    .where('dueDate', '>=', in72hStart)
    .where('dueDate', '<', in72hEnd)
    .get(),
  db.collection('tasks')
    .where('status', '!=', 'completed')
    .where('dueDate', '>=', in24hStart)
    .where('dueDate', '<', in24hEnd)
    .get(),
]);
```

### 2.3 Processing loop for each threshold

Process the two result sets independently. For each task in each set:

1. **Dedup guard** — check `reminderSent72hAt` (or `reminderSent24hAt`) for same-day Jerusalem match via `sameDayJerusalem`. If already sent today, skip.
2. **Fetch assignee** — `db.collection('users').doc(task.assignedTo).get()`. If doc missing or user inactive, skip.
3. **Send FCM** — reuse existing `sendFCMNotification` helper with appropriate i18n string (`task_deadline_72h_body` or `task_deadline_tomorrow_body`).
4. **Write in-app notification** — reuse `createInAppNotification` helper.
5. **Update dedup field** — `db.collection('tasks').doc(taskId).update({ reminderSent72hAt: admin.firestore.FieldValue.serverTimestamp() })`.

Wrap the per-task logic in try/catch so a single failure does not abort the rest of the batch.

### 2.4 i18n strings to use

| Key | Threshold | Usage |
|---|---|---|
| `task_deadline_title` | both | Reuse existing — no change |
| `task_deadline_72h_body` | 72h | **New** — e.g. "Your task '{taskTitle}' is due in 3 days" |
| `task_deadline_tomorrow_body` | 24h | Reuse existing — no change |

---

## 3. `sendOverdueTaskEscalations` — same-day check fix

**File:** `functions/index.js` — targeted fix only; no logic change.

Find the existing same-day check that uses raw JS date methods and replace with `sameDayJerusalem`:

```js
// BEFORE (buggy):
const isSameDayReminderSent = task.lastOverdueReminderAt &&
  task.lastOverdueReminderAt.toDate().getFullYear() === now.getFullYear() &&
  task.lastOverdueReminderAt.toDate().getMonth() === now.getMonth() &&
  task.lastOverdueReminderAt.toDate().getDate() === now.getDate();

// AFTER (correct):
const isSameDayReminderSent = task.lastOverdueReminderAt &&
  sameDayJerusalem(task.lastOverdueReminderAt.toDate(), now);
```

Apply the same fix to `lastOverdueEscalationAt` same-day check.

---

## 4. New translation key

### `functions/index.js` i18n table

Add under the existing deadline keys:

```js
task_deadline_72h_body: {
  en: "Your task '{taskTitle}' is due in 3 days.",
  ar: "مهمتك '{taskTitle}' تستحق خلال 3 أيام.",
},
```

### `assets/translations/en.json`

Add:

```json
"task_deadline_72h_body": "Your task '{taskTitle}' is due in 3 days."
```

### `assets/translations/ar.json`

Add:

```json
"task_deadline_72h_body": "مهمتك '{taskTitle}' تستحق خلال 3 أيام."
```

Current translation parity: 245/245. Target after this PR: 246/246.

Verify:
```bash
python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"
# Expected: 246 246 []
```

---

## 5. Firestore rules

No change needed. `reminderSent72hAt` and `reminderSent24hAt` are written by Cloud Functions (admin SDK, bypasses rules). The existing `onlyAllowedTaskStatusFieldsChanged` guard on client writes already blocks clients from writing unknown fields — no update required.

---

## 6. Affected files

| File | Change |
|---|---|
| `functions/index.js` | Rewrite `sendTaskDeadlineReminders` (72h + 24h, timezone fix, dedup fields); fix same-day check in `sendOverdueTaskEscalations`; add `task_deadline_72h_body` to i18n table |
| `assets/translations/en.json` | +1 key (`task_deadline_72h_body`) |
| `assets/translations/ar.json` | +1 key (`task_deadline_72h_body`) |

**Zero changes to:** any `.dart` file, `pubspec.yaml`, `firestore.rules`, `main.dart`, any cubit, any screen, any model, any test.

---

## 7. Quality gates

```bash
cd functions && npm run lint          # zero warnings
python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"
# Expected: 246 246 []
flutter analyze                       # zero warnings (no Dart changes; confirm no regression)
flutter test                          # all green (no Dart changes; confirm no regression)
```

Post-merge deployment (not a quality gate, but required):
```bash
firebase deploy --only functions
```

---

## 8. Smoke tests

| # | Test | Expected |
|---|---|---|
| 1 | Task due 3 days from now, function runs → FCM sent to assignee | Notification received; `reminderSent72hAt` written on task doc |
| 2 | Same task, function runs again same day → no duplicate FCM | No second notification; `reminderSent72hAt` already set |
| 3 | Task due tomorrow, function runs → FCM sent to assignee | Notification received; `reminderSent24hAt` written on task doc |
| 4 | Same task, function runs again same day → no duplicate | No second notification |
| 5 | Task due in 3 days AND due tomorrow (two separate tasks) → both FCM sent | Two notifications; each task's dedup field set independently |
| 6 | Task already completed → no reminder sent | No notification for either threshold |
| 7 | Task due in 3 days, assignee user doc missing → function continues without crash | Remaining tasks processed normally |
| 8 | Overdue task, `lastOverdueReminderAt` set to today (Jerusalem) → no duplicate escalation | Escalation skipped; Jerusalem-aware same-day check correct |
| 9 | Arabic-locale assignee → 72h notification body in Arabic | `task_deadline_72h_body` Arabic string used |

---

## 9. Definition of Done

- [ ] `sendTaskDeadlineReminders` rewritten with 72h + 24h threshold windows using `jerusalemMidnightAsUTC`.
- [ ] `reminderSent72hAt` and `reminderSent24hAt` dedup fields written to task doc after each send; same-day Jerusalem guard prevents duplicates.
- [ ] Timezone bug in `sendTaskDeadlineReminders` query windows fixed (uses `ymdInJerusalem` + `jerusalemMidnightAsUTC`, not raw `new Date()`).
- [ ] Same-day check bug in `sendOverdueTaskEscalations` fixed (`sameDayJerusalem` used for both `lastOverdueReminderAt` and `lastOverdueEscalationAt`).
- [ ] `task_deadline_72h_body` added to `functions/index.js` i18n table (en + ar).
- [ ] `task_deadline_72h_body` added to `assets/translations/en.json` and `assets/translations/ar.json`; parity `246 246 []`.
- [ ] `cd functions && npm run lint` clean.
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] No changes outside files listed in §6.
- [ ] Workflow docs updated (SESSION_LOG, BACKLOG #12 Done, CURRENT_TASK reset).
- [ ] PR title: `feat(notifications): add 72h progressive deadline reminder and fix timezone bug`.
- [ ] `firebase deploy --only functions` executed post-merge (not a CI gate, but required).

---

## 10. Out of scope

- 48h threshold (explicitly deferred to avoid notification fatigue)
- Admin pre-deadline notifications
- Flutter UI changes of any kind
- Shorebird patch (functions change → ineligible)
- `firestore.rules` changes
- `pubspec.yaml` changes

---

## 11. Workflow doc updates required on completion

| File | Change |
|---|---|
| `CURRENT_TASK.md` | Reset to "No active task" |
| `BACKLOG.md` | Mark item #12 Done with completion date and quality gate results |
| `SESSION_LOG.md` | Append implementation entry at top |
