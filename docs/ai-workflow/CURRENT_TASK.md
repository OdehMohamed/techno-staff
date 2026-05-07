# Current Task

> Last updated: 2026-05-07

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Fix: localize FCM push notifications by user language — v1.1 PR #2.**

The second of several v1.1 PRs that close out tester-facing issues found in the closed-testing build. See `BACKLOG.md` → "v1.1 — testing-phase fixes and improvements" for the series.

## Goal

Make FCM push notifications respect the recipient's chosen language. Cloud Functions read `users/{uid}.languageCode` and send already-localized `title` and `body` strings. **In-app notifications need no change** — they are already localized client-side via `easy_localization` `.tr()` with `namedArgs` against existing translation keys.

## Audit-derived insight (key finding)

In-app notifications stored in `notifications/{id}` carry only `type` + `data` (e.g., `taskTitle`, `assignedByName`). The notifications screen renders them client-side at [notifications_screen.dart:287-339](lib/features/notifications/presentation/screens/notifications_screen.dart#L287) using `easy_localization` named-arg interpolation. They already pick up the user's chosen language at render time.

The bug is purely on the **FCM push** side — `messaging.send(...)` in `functions/index.js` uses hardcoded English `title`/`body` strings. PR #2 scope narrows accordingly.

## Branch

`fix/notification-language`, branched from `dev` after PR #23 (`fix/auth-and-account-deletion-flow`) merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-05-07)

1. **Server-side localization, not client-side rendering of keys+args.** Cloud Functions read `users/{uid}.languageCode` and write fully localized strings into the FCM `notification.title` / `notification.body`. Trade-off: the server now owns translations for these ~5 string sets. Benefit: simpler FCM payloads, zero client-version coupling, and "what the user sees" is whatever the server sent (deterministic).
2. **Default fallback `'en'`** when `languageCode` is missing or invalid (e.g., a corrupt 'fr' value). Existing user docs without the field are unaffected — they default to `'en'` until the user signs in or changes language.
3. **Best-effort client writes.** Persisting `languageCode` on sign-in and on locale change is wrapped in try/catch with `FirebaseCrashlytics.recordError` on failure. Failures do **not** block sign-in / locale change.
4. **Single rules change.** The `users/{userId}` update rule extends from `hasOnly(['fcmToken'])` → `hasOnly(['fcmToken', 'languageCode'])`. `hasOnly` permits any subset including just one of the two — covers all combinations cleanly.
5. **No in-app notification changes.** Already localized correctly client-side.

## Affected files

### Client
| File | Change | Approx. size |
|---|---|---|
| `lib/core/constants/firebase_paths.dart` | Add `languageCode` constant | 1 line |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | After successful auth in `checkAuthStatus()` and `signIn()`, write `users/{uid}.languageCode` based on the current `easy_localization` locale (best-effort, try/catch + Crashlytics). The cubit needs access to the current locale — pass it as a method parameter from the caller (preferred) **or** read via `EasyLocalization.of(context)` at the call site and pipe through. The implementing agent picks the cleanest plumbing for the existing call sites. | ~15 lines |
| `lib/features/settings/presentation/screens/settings_screen.dart` | After each `await context.setLocale(...)`, write the new language code to `users/{currentUid}.languageCode` (best-effort). Read the current user via `context.read<AuthCubit>().state.user`. | ~10 lines |

### Server (`functions/index.js`)
| Section | Change | Approx. size |
|---|---|---|
| New `i18n` table at top of file (after `admin.initializeApp()`) | Translation strings + `localize(key, args, languageCode)` helper. See full table below. | ~50 lines |
| `sendTaskAssignedNotification` | Read recipient's `languageCode` before sending; replace hardcoded title/body with `localize(...)` calls. | ~5 lines changed |
| `sendTaskStatusNotification` (admin notifications on completion) | Read **each admin's** `languageCode` independently before sending; localize per recipient. The existing loop over admin uids must be updated. | ~5 lines changed |
| `sendTaskDeadlineReminders` cron | Read each task assignee's `languageCode`; pick today/tomorrow body. | ~5 lines changed |
| `sendOverdueTaskEscalations` cron | Read each recipient's `languageCode` (assignee for warning push, admin for escalation push); localize per recipient. | ~10 lines changed |
| `testTaskDeadlineReminders` / `testOverdueTaskEscalations` test callables | Same localization (so dry-run matches production). | ~5 lines |

### Firestore rules (`firestore.rules`)
| Section | Change |
|---|---|
| `users/{userId}` update rule | Extend `hasOnly(['fcmToken'])` → `hasOnly(['fcmToken', 'languageCode'])`. |

Exact diff:
```diff
   allow update: if isAdmin() || (
     isCurrentUser(userId) &&
-    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken'])
+    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken', 'languageCode'])
   );
```

## Server-side translation table (locked, ship verbatim)

Approved by project owner on 2026-05-07.

```javascript
const i18n = {
  en: {
    task_assigned_title: "New Task Assigned",
    task_assigned_body: "{by} assigned you: {task}",
    task_completed_title: "Task Completed ✅",
    task_completed_body: "{task}",
    task_deadline_title: "Task Reminder ⏰",
    task_deadline_today_body: "Your task is due today: {task}",
    task_deadline_tomorrow_body: "Your task is due tomorrow: {task}",
    task_overdue_title: "Overdue Task ⚠️",
    task_overdue_body: "Your task is overdue: {task}",
    task_overdue_escalation_title: "Overdue Task Escalation 🚨",
    task_overdue_escalation_body: "{employee}'s task is overdue: {task}",
  },
  ar: {
    task_assigned_title: "تم إسناد مهمة جديدة",
    task_assigned_body: "{by} أسند إليك: {task}",
    task_completed_title: "تم إنجاز المهمة ✅",
    task_completed_body: "{task}",
    task_deadline_title: "تذكير بالمهمة ⏰",
    task_deadline_today_body: "مهمتك مستحقة اليوم: {task}",
    task_deadline_tomorrow_body: "مهمتك مستحقة غداً: {task}",
    task_overdue_title: "مهمة متأخرة ⚠️",
    task_overdue_body: "مهمتك متأخرة: {task}",
    task_overdue_escalation_title: "تصعيد مهمة متأخرة 🚨",
    task_overdue_escalation_body: "مهمة {employee} متأخرة: {task}",
  },
};

function localize(key, args, languageCode) {
  const lang = languageCode === 'ar' ? i18n.ar : i18n.en; // default fallback to en
  const template = lang[key] ?? i18n.en[key] ?? '';
  return template.replace(/\{(\w+)\}/g, (_, k) => (args && args[k] != null) ? args[k] : '');
}
```

## Expected flow change (example: `sendTaskAssignedNotification`)

**Before:**
```javascript
const message = {
  token: assignedToToken,
  notification: {
    title: "New Task Assigned",
    body: assignedByName + " assigned you: " + taskTitle,
  },
  data: { taskId: event.params.taskId },
};
```

**After:**
```javascript
const recipientDoc = await db.collection("users").doc(assignedTo).get();
const langCode = recipientDoc.data()?.languageCode || 'en';

const message = {
  token: assignedToToken,
  notification: {
    title: localize('task_assigned_title', {}, langCode),
    body: localize('task_assigned_body', { by: assignedByName, task: taskTitle }, langCode),
  },
  data: { taskId: event.params.taskId },
};
```

Apply the same pattern to all 4 send sites + 2 test callables.

## Edge cases

| Case | Handling |
|---|---|
| User has no `languageCode` field (existing users) | Server defaults to `'en'`. Field appears on first language change or next sign-in. No migration needed. |
| Invalid `languageCode` value (e.g. `'fr'`, missing, null) | Server `localize()` falls through to `i18n.en`. |
| Client offline when language changes | Best-effort try/catch + Crashlytics. Sign-in / locale change still completes. |
| User changes language between assignment and notification send | Server reads `languageCode` at send time. Whatever's in Firestore wins. Acceptable race. |
| Multiple admins receive `task_completed` push with different languages | Server reads each recipient's `languageCode` independently inside the loop. |
| `recipientDoc.data()` is null (deleted user race) | `?.languageCode || 'en'` handles it. Notification still sends in English. |

## Smoke tests (real device, both platforms)

1. **Fresh user EN flow** — create new employee with English locale → admin assigns task → push title is "New Task Assigned".
2. **Switch to Arabic** — same user changes app language to Arabic in Settings → admin assigns task → push title is "تم إسناد مهمة جديدة".
3. **languageCode persistence** — change language → verify `users/{uid}.languageCode` updates in Firestore console within 5 seconds.
4. **Existing user (no languageCode field)** — sign in as a user that pre-dates this fix → admin assigns → push defaults to English. Sign-in writes `languageCode: 'en'`. Switch to Arabic → next push is Arabic.
5. **Cross-locale split** — User A (en) and User B (ar). Admin assigns to A → A receives English. Admin assigns to B → B receives Arabic.
6. **Task completion to admin** — employee marks task done → admin (whatever locale) receives push in their own locale.
7. **Deadline reminder cron** — task due tomorrow with employee in Arabic. Run `testTaskDeadlineReminders` callable → push body is Arabic.
8. **Overdue escalation cron** — same with `testOverdueTaskEscalations`.
9. **In-app notifications regression** — verify in-app feed still localizes correctly client-side; no doc-shape change.
10. **Rules regression** — `users/{uid}` admin updates still work; non-self-update still rejected.

## Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green.

## Rollback considerations

- **Client-side rollback** — pure additive: removing `languageCode` writes leaves the field in user docs as orphaned. Server falls back to 'en' if missing. No breakage.
- **Server-side rollback** — revert the `i18n` table + `localize()` calls back to hardcoded English. Existing `languageCode` field becomes a no-op until reintroduced.
- **Rules rollback** — clients lose self-service language updates; admin can still update via console. No data loss.
- **No migration needed** — server gracefully handles missing field.

## Definition of Done

- [ ] `firestore.rules` `users/{userId}` update rule extended to permit `languageCode` self-update (`hasOnly(['fcmToken', 'languageCode'])`).
- [ ] `firebase_paths.dart` has `languageCode` constant.
- [ ] `AuthCubit.checkAuthStatus()` and `AuthCubit.signIn()` write `users/{uid}.languageCode` after successful auth (best-effort, try/catch + Crashlytics).
- [ ] `settings_screen.dart` writes `users/{uid}.languageCode` after `context.setLocale(...)` (best-effort).
- [ ] `functions/index.js` has the `i18n` table + `localize` helper at the top.
- [ ] All 4 FCM send sites + 2 test callables read recipient's `languageCode` and use `localize(...)`.
- [ ] Quality gates green: `flutter analyze`, `flutter test`, `functions/` ESLint.
- [ ] All 10 smoke tests pass on at least one Android 13+ device and one iOS device with both `en` and `ar` locales.
- [ ] Workflow docs updated per "Workflow documentation" section below.
- [ ] PR opened to `dev` titled `fix(notifications): localize FCM push notifications by user language`.

## Workflow documentation (mandatory updates)

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This spec → reset to "No active task" by implementing agent | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | Move v1.1 PR #2 from "upcoming entries" list into a new tracked entry "In progress" → "Done" by agent on completion | Lead seeds; agent moves |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now; agent adds implementation entry on PR completion | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | New entry: "Server-side localization for FCM push notifications via users/{uid}.languageCode" recording the architecture choice and locked translation table | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §5 Firestore Data Model: add `languageCode` to the shape of `users/{uid}` (e.g., `{ email, name, role, isActive, fcmToken, languageCode, createdAt }`). §6 Cloud Functions: brief mention that FCM senders are now locale-aware. | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Add a `### Fixed` line under `## [Unreleased]`: "FCM push notifications now respect the recipient's chosen language (English / Arabic). In-app notifications were already localized; this fix covers the system-tray push payload." | Implementing agent |
| `docs/release-checklist.md` | No change |
| `docs/privacy-policy.md` | No change (no new data collected — `languageCode` is a UI preference, not personal data) |

## Out of scope

- In-app notifications (already localized client-side — no change).
- Languages beyond `en` and `ar`.
- Translation review by a third-party native speaker (the locked AR table was approved by the project owner; agent ships verbatim — anyone can revise on the PR review).
- Migrating existing user docs to add `languageCode` (unnecessary — server defaults to 'en' until next client write).
- `pubspec.yaml` version bump (build-number bumps happen at release-cut time).
- New translation keys in `en.json` / `ar.json` (no new client-facing strings; in-app keys already exist).
- Cloud Function performance optimization (the per-recipient Firestore read for `languageCode` is negligible at current admin/employee counts; revisit only at scale).
- Caching `languageCode` lookups across multiple sends in the same function invocation (premature optimization).

## Risks

- **Translation accuracy for Arabic** — the locked strings were drafted by the lead and approved by the project owner. Re-review during PR review is welcome but not required.
- **Per-recipient Firestore lookup cost** — `sendOverdueTaskEscalations` loops admins, which means 1 extra `users/{adminUid}` read per admin per cycle. With <10 admins this is negligible. Documented for future scale (caching can be added later if it ever matters).
- **Firestore rules change** — the only rules edit in v1.1. The smoke tests cover it (smoke #3 exercises self-update, smoke #10 verifies regressions).
- **Backward compatibility** — fully preserved. Existing users with no `languageCode` field continue working; first sign-in or locale change writes the field; until then they receive English (acceptable).
