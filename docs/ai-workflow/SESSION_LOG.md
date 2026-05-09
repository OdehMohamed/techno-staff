## 2026-05-09 — GitHub Copilot (Claude Sonnet 4.6) — Implement v1.1 F3.B recurring task templates

- **Agent**: GitHub Copilot (Claude Sonnet 4.6) — implementing from the spec written in the planning session above.
- **Branch**: `feat/recurring-tasks`
- **Goal**: Implement all code for recurring task templates with cron-driven instance generation per the locked spec in `CURRENT_TASK.md`.
- **Outcome**: Full implementation shipped. `flutter analyze` clean, `flutter test` 6/6 passed, `npm run lint` clean, translation parity `241 241 []`. All 13 new + modified files completed.
- **Files touched**: `lib/features/tasks/data/models/task_template_model.dart` (new), `lib/features/tasks/data/models/task_model.dart` (+templateId), `lib/core/constants/firebase_paths.dart` (+taskTemplates), `lib/features/tasks/data/repositories/templates_repository.dart` (new), `lib/features/tasks/presentation/cubit/templates_state.dart` (new), `lib/features/tasks/presentation/cubit/templates_cubit.dart` (new), `lib/main.dart` (+TemplatesRepository+TemplatesCubit), `lib/core/routes/route_names.dart` (+3 routes), `lib/core/routes/app_router.dart` (+3 cases), `lib/shared/widgets/app_drawer.dart` (+recurring tasks admin entry), `lib/features/tasks/presentation/screens/recurring_tasks_screen.dart` (new), `lib/features/tasks/presentation/screens/add_template_screen.dart` (new), `lib/features/tasks/presentation/screens/edit_template_screen.dart` (new), `functions/index.js` (+7 Jerusalem helpers + shouldGenerateOn + generateRecurringTaskInstances), `firestore.rules` (+task_templates block), `assets/translations/en.json` (+27 keys → 241), `assets/translations/ar.json` (+27 keys → 241).
- **Follow-ups**: Deploy `firebase deploy --only firestore:rules,functions` before testing. Run smoke tests #1-#15 (device/ops-dependent). Deferred to NEXT_STEPS: manual "generate now" callable, recurring badge on task cards.

# AI Session Log

> Append-only log of AI-assisted work sessions. One entry per meaningful session, newest at the top.

The goal is a quick skim-friendly history so you can answer "what did we do last week?" without digging through git logs or chat transcripts.

---

## Template

```
### YYYY-MM-DD — <Agent> — <short title>

- **Agent**: Claude Code (Opus 4.7) | Cursor | ChatGPT | Gemini | other
- **Branch**: <branch-name>
- **Goal**: one-line summary of the intent
- **Outcome**: what shipped, what was decided, or what was learned
- **Files touched**: brief list or "see commit <sha>"
- **Follow-ups**: items added to BACKLOG.md / NEXT_STEPS.md / DECISIONS_LOG.md
```

---

## 2026-05-09 — Claude Code (Opus 4.7) — Plan v1.1 PR #7 (F3.B — recurring tasks with cron-driven instance generation)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/recurring-tasks` (created from `dev` after PR #28 merged).
- **Goal**: Lock scope, schema, scheduler architecture, and idempotency strategy for v1.1 F3.B — recurring task templates that auto-generate task instances on a daily / weekly / monthly cadence.
- **Outcome**: Ran a read-only audit covering 10 dimensions plus three explicit architectural questions (server-only generation, client-side generation, idempotency strategy). Surfaced the load-bearing finding: the original 2026-05-01 locked decision to use `isTemplate` flag inside the existing `tasks` collection has ~13 downstream consumer touchpoints (dashboards, reports, PDF, deadline-reminder sweeps, overdue-escalation sweeps, FCM onCreate / onUpdate triggers, countdown chip, employee task lists, top-performer ranking) that would each need an `isTemplate` filter — fragile, easy to miss, and silently breaks future contributors who add new queries without remembering the filter. User revisited the original decision and locked **Option B from the audit**: a separate top-level `task_templates/` collection so the existing `tasks/` collection stays semantically clean and zero existing consumers need changes. User locked 14 planning decisions: (1) separate `task_templates` collection; (2) instance-template snapshot semantics with `templateId` back-reference; (3) snapshot stability — historical instances unaffected by template edits; (4) generation entirely server-side via Cloud Function; (5) `0 6 * * *` Asia/Jerusalem scheduler (before the existing 9am reminder sweep); (6) layered idempotency — deterministic instance ID `${templateId}_${YYYY-MM-DD}` + `lastGeneratedAt` same-day guard inside one Firestore transaction; (7) recurrence types daily / weekly / monthly only — no interval multiplier, no end-date, no manual generate-now callable; (8) monthly clamp on overflow days (day-31 → Feb 28/29); (9) all date math via `Intl.DateTimeFormat` with `timeZone: 'Asia/Jerusalem'` — no raw UTC arithmetic; (10) counter-task templates supported with fresh `currentCount: 0` per generated instance; (11) generated instances behave identically to client-created tasks (no special-casing for countdown / reminders / reports / dashboards); (12) soft pause via `isActive` + hard delete; (13) admin-only template authoring (rules + UI); (14) deferred recurring-instance badge on cards and manual generate-now callable to v1.2 / NEXT_STEPS. Wrote complete `CURRENT_TASK.md` spec architecture-first: §1 collection-isolation invariant + generation invariants + snapshot invariant; §2 schema (template fields, recurrence rule shape, single `templateId` field added to `TaskModel`); §3 the `generateRecurringTaskInstances` Cloud Function with locked transaction code, locked Asia/Jerusalem helpers (`ymdInJerusalem`, `sameDayJerusalem`, `jerusalemDayOfWeek`, `jerusalemDayOfMonth`, `jerusalemLastDayOfMonth`, `jerusalemMidnightAsUTC`, `jerusalemOffsetForDate`), and locked `shouldGenerateOn(recurrence, now)` matcher with monthly clamp; §4 new `task_templates` rules block (admin-only); §5 / §6 new `TemplatesRepository` + `TemplatesCubit`; §7 three new admin screens (list / add / edit) with recurrence picker; §8 admin drawer entry; §9 ~18 new translation keys; §10 affected files (~13 new + 4 line-delta files, zero changes to existing instance-side files); §11 quality gates; §12 fifteen smoke tests including idempotency same-day re-run, recovery-from-partial-run, monthly clamp across leap year, DST transition, and dashboard / reports inclusion of generated instances; §13 DoD; §14 risks (collection leakage, idempotency drift, timezone bugs, DST, rules deploy ordering, dangling templateId after hard delete); §15 workflow doc updates; §16 explicit out-of-scope rails.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #7 from `CURRENT_TASK.md` on the existing `feat/recurring-tasks` branch. After this PR merges, all v1.1 features are complete and we cut v1.1.0. F2 (attendance MVP) remains deferred to v1.2.0 per the original v1.1 roadmap.

## 2026-05-09 — GitHub Copilot (GPT-5.3-Codex) — Implement v1.1 PR #6 (F3.C — counter task type with derived completion)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feat/counter-tasks`
- **Goal**: Implement counter tasks with target/current progress while keeping persisted `status` authoritative for all downstream consumers.
- **Outcome**: Added flat counter fields to `TaskModel` (`taskType`, `targetCount`, `currentCount`) with backward-compatible defaults and centralized `deriveCounterStatus`. Implemented `TasksRepository.incrementTaskCounter` using `runTransaction` so every increment writes `currentCount` + derived `status` + `completedAt` + update metadata atomically. Added `TasksCubit.incrementTaskCounter` and wired counter-specific UI in add/edit/list/details screens (status dropdown hidden for counter tasks in edit, immutable task type on edit save, target/current validation and clamping, no decrement button in employee UI). Applied the locked one-line Firestore-rules mask widening (`currentCount` only). Added 10 EN + 10 AR translation keys and a new unit test for the three locked status transitions. Automated gates passed: `flutter analyze` clean, `flutter test` all passed, `cd functions && npm run lint` clean, parity check `214 214 []`.
- **Files touched**: `lib/features/tasks/data/models/task_model.dart`, `lib/features/tasks/data/repositories/tasks_repository.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/tasks/presentation/screens/add_task_screen.dart`, `lib/features/tasks/presentation/screens/edit_task_screen.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `firestore.rules`, `assets/translations/en.json`, `assets/translations/ar.json`, `test/features/tasks/data/models/task_model_test.dart`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Project owner runs smoke tests #4–#6, #8–#10, #13, #14 on real devices and runs `firebase deploy --only firestore:rules` after merge.

## 2026-05-09 — Claude Code (Opus 4.7) — Plan v1.1 PR #6 (F3.C — counter task type with derived completion)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/counter-tasks` (created from `dev` after PR #27 merged).
- **Goal**: Lock scope, persistence contract, and product decisions for v1.1 F3.C — a target / counter task variant alongside the existing standard task.
- **Outcome**: Ran a read-only audit across `TaskModel`, `TasksRepository`, `TasksCubit`, `firestore.rules`, `add_task_screen.dart`, `edit_task_screen.dart`, `tasks_screen.dart`, `task_details_screen.dart`, all `dashboard_repository.dart` / `reports_screen.dart` / `pdf_report_service.dart` counter sites, and every status touchpoint in `functions/index.js` (completion FCM, deadline-reminder sweeps, status-change `task_logs`). Surfaced the load-bearing observation: the entire downstream pipeline (dashboards, reports, FCM completion notifications, deadline-reminder filters, countdown-chip visibility, Firestore rules, `task_logs`) treats `status == 'completed'` as the authoritative completion signal — meaning F3.C must derive completion from counts AND persist the resulting status to the same field, so zero Cloud Function code and zero downstream consumer code needs to change. User locked 10 planning decisions: (1) flat optional fields on the existing `tasks` collection (`taskType`, `targetCount`, `currentCount`); (2) client-side derive + persist on every increment / edit save with the locked mapping `0 → pending`, `0 < n < target → in_progress`, `n >= target → completed`; (3) strict — counter-task status fully derived, no manual override path; (4) `taskType` immutable after create; (5) `targetCount` integer 1..999, `currentCount` integer 0..targetCount; (6) no decrement on the employee card UI — admin / creator only via edit screen; (7) simple Firestore rules mask widening (add `currentCount` to assignee self-update mask, no per-type guards); (8) subtle counter-type indicator chip on the task card; (9) status dropdown hidden entirely on the edit screen for counter tasks; (10) backward-compat — missing `taskType` reads as `'standard'`. Wrote complete `CURRENT_TASK.md` spec architecture-first: §1 persistence contract + locked increment-transaction code + edit-screen derivation rule + invariant guardrails (no naked `currentCount` writes, no plain `FieldValue.increment(1)` bypassing the read-and-derive cycle, no Cloud Function branching on `taskType`); §2 the single-line rules diff; §3 model fields with `isCounter` getter and static `deriveCounterStatus`; §4 / §5 repo + cubit additions; §6 / §7 add / edit screen changes including the counter-task target / current-count clamp on save; §8 / §9 list card and details screen renderings (`_CounterTypeBadge`, `_CounterProgressRow`); §10 operational `firebase deploy --only firestore:rules` step for the project owner; §11 affected files (10 files, ~330 line delta, 0 Cloud Function changes); §12 translation keys (10 new × 2 locales); §13 quality gates; §14 fifteen smoke tests including concurrent-tap race and rules-deploy-ordering regression; §15 DoD; §16 risks; §17 workflow doc updates; §18 explicit out-of-scope rails.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #6 from `CURRENT_TASK.md` on the existing `feat/counter-tasks` branch. After this PR merges, one v1.1 feature remains (F3.B recurring tasks) before we cut v1.1.0.

## 2026-05-09 — GitHub Copilot (GPT-5.4) — Implement v1.1 PR #5 (F3.A — adaptive task countdown timer)

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feat/task-countdown-timer`
- **Goal**: Replace the static due-date chip on the tasks list and task details screen with a live countdown, while keeping ticker-driven rebuilds isolated to the chip leaf.
- **Outcome**: Added `CountdownClockProvider` as a per-screen adaptive ticker owner (60s default, 1s when any visible deadline is under 1 hour, lifecycle pause/resume) and `CountdownChip` as the localized leaf renderer for default / warning / overdue states. Wired the provider into `tasks_screen.dart` and `task_details_screen.dart`, removed the old due-date `_InfoChip`, and added 6 countdown keys to both locales. Validation passed: `flutter analyze` clean, `flutter test` passed, `cd functions && npm run lint` clean, translation parity check returned `204 204 []`. Real-device smoke tests #1–#11 remain pending project-owner execution; smoke #12 was spot-checked from the agent environment by confirming the existing `dueDateSoonest` comparator path in `tasks_screen.dart` is unchanged.
- **Files touched**: `lib/features/tasks/presentation/widgets/countdown_clock_provider.dart`, `lib/features/tasks/presentation/widgets/countdown_chip.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/SESSION_LOG.md`, `CHANGELOG.md`.
- **Follow-ups**: Project owner runs the real-device smoke suite (#1–#11) and decides whether the next active v1.1 task is F3.C (target/counter task type) or F3.B (recurring tasks).

## 2026-05-08 — Claude Code (Opus 4.7) — Plan v1.1 PR #5 (F3.A — task countdown timer with adaptive screen-level ticker)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/task-countdown-timer` (created from `dev` after PR #26 merged as `6aeb30a`).
- **Goal**: Lock scope, architecture, and product decisions for v1.1 F3.A — replace the static due-date chip on the tasks list and task details screen with a live adaptive countdown.
- **Outcome**: Ran a read-only audit covering 8 dimensions (task-card rendering flow, ticker placement, rebuild/perf, formatting, expired states, RTL/i18n, adaptive cadence, task-details parity). Surfaced one critical finding ahead of locking: `dueDate` is selected via `showDatePicker` only in `add_task_screen.dart` so all stored values are at `00:00:00` of the picked day, and existing overdue logic across `dashboard_repository.dart`, `reports_screen.dart`, `pdf_report_service.dart`, and Cloud Functions reminders treats overdue as `now > endOfDay(dueDate)`. User locked 7 planning decisions: (1) count to `endOfDay(dueDate)` — preserves date-only model; (2) minimal-scope `CountdownChip` widget — no `TaskCard` extraction in v1.1; (3) keep Hindu-Arabic numerals (`1234`) in Arabic for consistency with rest of app; (4) single adaptive screen-level ticker per consuming screen — no per-card timers, no global ticker, no two-tier; (5) ticker subscription scoped to the leaf chip via `ValueListenableBuilder` — parent `AppCard` / `InkWell` stay stable on tick; (6) overdue is a derived UI state via red-tinted chip — `StatusBadge` is not modified; (7) `task_details_screen.dart` adopts the same chip with its own ticker provider instance. Wrote complete `CURRENT_TASK.md` spec architecture-first (clock provider lifecycle, adaptive period rule, scope-of-subscription invariant, app-lifecycle pause/resume, explicit "no per-card `Timer.periodic`" / "no `setState` per tick" guardrails) followed by formatting buckets (7 buckets, 6 translation keys × 2 locales), visual states (default/warning/overdue), affected files (2 new widgets + 2 screen edits + 2 translation files), 12 smoke tests (#1–#11 require real-device execution, #12 is a quick regression check), DoD, risks, out-of-scope rails, and workflow doc update plan.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #5 from `CURRENT_TASK.md` on the existing `feat/task-countdown-timer` branch. After this PR merges, two v1.1 features remain (F3.C target/counter task type, F3.B recurring tasks) before we cut v1.1.0.

## 2026-05-08 — GitHub Copilot (GPT-5.4) — Implement PR #26 second supplement (session revocation + iOS APNS race handling)

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feat/account-settings`
- **Goal**: Complete the second supplement for PR #26 by adding server-side refresh-token revocation after password change and tolerating the iOS first-launch APNS token race in the auth lifecycle.
- **Outcome**: Added `revokeUserSessions` to `functions/index.js` as a callable that revokes refresh tokens for `request.auth.uid` only. Extended `AuthCubit.changePassword()` with a best-effort `FirebaseFunctions.instance.httpsCallable('revokeUserSessions').call()` after `updatePassword` succeeds, logging failures to Crashlytics without surfacing them to the user. Wrapped `_setupFCM()` `getToken()` in the locked APNS-aware try/catch: `apns-token-not-set` is silently tolerated, other Firebase exceptions and non-Firebase errors still flow to Crashlytics. Automated quality gates passed: `flutter analyze` → no issues, `flutter test` → 2/2 passed, `cd functions && npm run lint` → clean. Real-device smoke tests #1, #2, and #6 remain pending project-owner execution; the rest were not run from this environment.
- **Files touched**: `functions/index.js`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`, `CHANGELOG.md`.
- **Follow-ups**: Project owner deploys `firebase deploy --only functions:revokeUserSessions` plus the earlier `firebase deploy --only firestore:rules` step after merge, then completes the pending real-device smoke tests before final approval.

## 2026-05-08 — Claude Code (Opus 4.7) — Plan second supplemental fix for v1.1 PR #4 (cross-device session invalidation via Cloud Function + iOS APNS race)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/account-settings` (continuation — no new branch).
- **Goal**: Plan a second supplement on PR #4 to actually close the cross-device session-invalidation gap, after the first supplement (authStateChanges listener) shipped but real-device validation showed it never fired.
- **Outcome**: Confirmed via Firebase Auth current behavior that **`FirebaseAuth.updatePassword` does NOT auto-revoke refresh tokens** — the previously-locked architectural assumption was wrong. The first supplement's `authStateChanges()` listener is correct in shape but had no event to listen for because Firebase wasn't actually signing other devices out. Captured this lesson explicitly in `CURRENT_TASK.md` for future planning rounds. Locked the new fix as a server-side revocation: a new `revokeUserSessions` callable Cloud Function that invokes `admin.auth().revokeRefreshTokens(request.auth.uid)`; called best-effort from `AuthCubit.changePassword` after `updatePassword` succeeds (failures don't undo the password change — Crashlytics-only). Locked propagation expectation: cross-device sign-out is eventual (seconds–minutes when Device B is active, up to ~1 hour worst case via natural ID-token expiry); Device A also routes to login within ~1 hour as it shares the revocation (acceptable post-password-change UX). Added an adjacent iOS-only fix on the same PR: wrap `getToken()` in `_setupFCM` with try/catch tolerating ONLY the `apns-token-not-set` code (other FirebaseExceptions still flow to Crashlytics) — observed during the same auth lifecycle on real-device testing. No `firestore.rules` change (Admin SDK bypasses rules); no new translation keys (revocation failure is silent to the user); no `pubspec.yaml` change. Wrote complete supplement spec in `CURRENT_TASK.md` with locked code blocks for the function, the cubit call site, and the APNS handler, plus 10 smoke tests (smokes #1, #2 require two devices; #6 requires a fresh iOS install), DoD, and additional workflow doc updates required because the prior supplement already reset CURRENT_TASK and other docs.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent extends PR #4 with the new Cloud Function (~15 lines in `functions/index.js`), the best-effort revocation call + APNS try/catch (~25 lines in `auth_cubit.dart`), and the `DECISIONS_LOG.md` / `PROJECT_CONTEXT.md` / `CHANGELOG.md` updates listed in the spec. Owner deploys the new function (`firebase deploy --only functions:revokeUserSessions`) post-merge; the prior `firestore.rules` deploy from the first round still applies. Real-device cross-device smoke tests #1, #2, and the iOS APNS regression check (#6) gate the merge.

## 2026-05-08 — GitHub Copilot (GPT-5.4) — Implement PR #26 supplemental authStateChanges listener

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feat/account-settings`
- **Goal**: Close the cross-device session-invalidation gap surfaced during real-device validation of PR #26 by making `AuthCubit` react to Firebase server-side session invalidation.
- **Outcome**: Applied the locked one-file supplement in `AuthCubit`: added `dart:async`, `StreamSubscription<User?>? _authSub`, a constructor subscription to `FirebaseAuth.instance.authStateChanges()`, `_onAuthStateChanged(User? firebaseUser)` with the locked `state.status` then `firebaseUser` guards, and a `close()` override that cancels the subscription before `super.close()`. No existing methods were modified. Automated quality gates passed: `flutter analyze` → no issues, `flutter test` → 2/2 passed, `cd functions && npm run lint` → clean. Real-device supplemental smoke tests could not be executed from the agent environment and remain pending owner validation.
- **Files touched**: `lib/features/auth/presentation/cubit/auth_cubit.dart`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`, `CHANGELOG.md`.
- **Follow-ups**: Project owner runs the 6 supplemental real-device smoke tests plus the original PR #4 regression subset, then updates / confirms PR #26 before merge.

## 2026-05-08 — Claude Code (Opus 4.7) — Plan supplemental fix for v1.1 PR #4 (cross-device session invalidation via authStateChanges)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/account-settings` (continuation — no new branch).
- **Goal**: Plan a supplemental fix on the in-flight PR #4 branch to close a cross-device session-invalidation gap surfaced during real-device validation of the password-change feature.
- **Outcome**: Audited the gap. Confirmed it is **not a regression introduced by PR #4** but a pre-existing architectural latent bug: `AuthCubit` does not subscribe to any Firebase Auth stream, so server-initiated session invalidation (password change on another device, account deletion on another device, admin disabling user, token revocation) is never propagated to the current process. The existing `BlocListener<AuthCubit>` from PR #23 only reacts to cubit emissions, and the cubit only emits `unauthenticated` on explicit `signOut()` / `deleteAccount()`. PR #4's cross-device password change is the first feature that exercises the gap. Locked the fix as a supplement on the same branch (rather than a follow-up PR) so PR #4 doesn't ship with a known cross-device flaw. Locked design: subscribe to `FirebaseAuth.instance.authStateChanges()` in `AuthCubit` constructor; `_onAuthStateChanged` short-circuits unless `state.status == authenticated && firebaseUser == null`; emits unauthenticated; `close()` cancels the subscription. Chose `authStateChanges` over `idTokenChanges`/`userChanges` for minimal listener surface. Documented the timing expectation: cross-device propagation is not instant (Firebase Auth ID token TTL is up to 1 hour) but lands within minutes after any Firestore-backed action triggers token refresh. Wrote complete supplement spec in `CURRENT_TASK.md` covering the locked code, edge cases (8 cases including same-device sign-out idempotence), 6 supplemental smoke tests (3 require two devices), DoD, and additional workflow doc updates required because the agent already reset CURRENT_TASK and other docs after the original implementation. Also confirmed denormalized `assignedByName`/`assignedToName` snapshot semantics remain unchanged for v1.1 (Option A — no backfill).
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent extends PR #4 with the auth-listener fix (~25 lines in `auth_cubit.dart`) plus updated workflow docs. Smoke tests #8 from the original PR #4 plus the 6 supplemental smoke tests must pass before merge.

## 2026-05-08 — GitHub Copilot (Claude Sonnet 4.6) — Implement v1.1 PR #4 account settings

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/account-settings`
- **Goal**: Implement account settings: name editing (`EditProfileScreen`) and password change (`ChangePasswordScreen`) reachable from Settings → Account.
- **Outcome**: Added `reauthenticate` + `updatePassword` to `AuthRepository`; `updateName` to `UserRepository`; `copyWith` to `AppUser`; `updateName` + `changePassword` (locked error-code mapping: `wrong-password`/`invalid-credential` → `current_password_incorrect`, `weak-password` → `password_too_short_min_8`, `network-request-failed` → `network_error`, fallback per operation type) to `AuthCubit`. Created `EditProfileScreen` (name pre-fill, Save disabled until valid AND changed, `use_build_context_synchronously`-clean) and `ChangePasswordScreen` (3 obscured fields, mandatory reauth before updatePassword). Wired two new Account section tiles + routes (`/edit-profile`, `/change-password`). Extended `firestore.rules` self-update mask to `['fcmToken', 'languageCode', 'name']`. Added 16 new translation keys to en.json + ar.json. Quality gates green: `flutter analyze` → No issues, `flutter test` → 2/2 passed, `cd functions && npm run lint` → clean.
- **Files touched**: `lib/features/auth/data/repositories/auth_repository.dart`, `lib/features/auth/data/repositories/user_repository.dart`, `lib/features/auth/domain/models/app_user.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/edit_profile_screen.dart` (new), `lib/features/settings/presentation/screens/change_password_screen.dart` (new), `lib/features/settings/presentation/screens/settings_screen.dart`, `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `firestore.rules`, `assets/translations/en.json`, `assets/translations/ar.json`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Owner deploys updated `firestore.rules` (`firebase deploy --only firestore:rules`) before merging or immediately after. Reviewer runs manual smoke tests (11 cases from `CURRENT_TASK.md`). After this PR merges: three v1.1 task-system features remain (F3.A countdown, F3.C target tasks, F3.B recurring tasks).

## 2026-05-08 — Claude Code (Opus 4.7) — Plan v1.1 PR #4 (account settings)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/account-settings`
- **Goal**: Lock scope, UI structure, and validation rules for v1.1 PR #4 (F1 — account settings: name editing + password change).
- **Outcome**: Audited current auth/account architecture: `AuthRepository` has only sign-in/sign-out (no password update or reauth helpers); `UserRepository` has only `getUserById` (no name update); `AppUser` model is clean and likely needs a `copyWith`; Firestore `users/{userId}` self-update mask is `hasOnly(['fcmToken', 'languageCode'])` and needs to extend to `['fcmToken', 'languageCode', 'name']`. Firebase Auth notes captured: `updatePassword` throws `requires-recent-login` if session is older than ~5 min, so always reauthenticate first via `EmailAuthProvider.credential(email, currentPassword)` then `User.reauthenticateWithCredential(...)`. Firebase Auth's default min password length is 6 chars; we'll be stricter at 8. Locked 5 product decisions: (1) two separate screens — `EditProfileScreen` and `ChangePasswordScreen`; (2) password minimum 8 chars; (3) name validation 2–50 chars after trim; (4) NO Firebase Auth `displayName` sync — Firestore `users/{uid}.name` is single source of truth; (5) email change deferred. Wrote complete `CURRENT_TASK.md` covering 9 affected files (2 new screens, 4 modified Dart files, 1 rules edit, 2 route additions, 17 new translation keys), 11 manual smoke tests including the cross-device sign-out regression check, rules deployment ordering note for the project owner, rollback considerations, DoD, and explicit workflow doc update plan.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #4 from `CURRENT_TASK.md` on the existing `feat/account-settings` branch. After this PR merges, three v1.1 task-system features remain (F3.A countdown, F3.C target tasks, F3.B recurring tasks) before we cut v1.1.0.

## 2026-05-08 — GitHub Copilot (GPT-5.3-Codex) — Implement v1.1 PR #3 theme persistence

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `fix/theme-persistence`
- **Goal**: Persist selected theme mode across app launches and hydrate it before first frame to eliminate cold-start theme flicker.
- **Outcome**: Added direct `shared_preferences` dependency. Refactored `ThemeCubit` to accept `SharedPreferences` + `initialMode`, persist mode changes (`system`/`light`/`dark`) after `emit`, and log persistence failures to Crashlytics without blocking UI updates. Updated `main.dart` to hydrate persisted mode before `runApp()` with defensive parsing and fallback to `AppThemeMode.system`. No changes to settings UI, routing, Firestore rules, or Cloud Functions.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `lib/core/theme/cubit/theme_cubit.dart`, `lib/main.dart`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Run and record required manual smoke tests on Android + iOS, then open PR to `dev` titled `fix(theme): persist theme preference across launches`.

## 2026-05-08 — Claude Code (Opus 4.7) — Plan v1.1 PR #3 (theme persistence)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `fix/theme-persistence`
- **Goal**: Lock scope and hydration strategy for v1.1 PR #3 (B4 — theme persistence across launches).
- **Outcome**: Audited theme stack: `ThemeCubit` is 11 lines and has zero persistence — defaults to `AppThemeMode.system` every launch; `main.dart` creates it synchronously with no async hydration; `app.dart`'s `BlocBuilder` maps state to `MaterialApp.themeMode` correctly. `shared_preferences` is not yet a dep. Locked decisions: (1) local-only persistence via `shared_preferences` — no Firestore sync for v1.1; (2) synchronous hydration before `runApp` — read prefs in `main()`, parse stored mode (default `system` on missing/invalid), pass into cubit constructor — eliminates first-frame flicker on cold start; (3) best-effort writes wrapped in try/catch + Crashlytics on failure; (4) no Settings screen UI changes. Wrote complete `CURRENT_TASK.md` with locked `ThemeCubit` design, locked `main.dart` hydration block, edge cases, 7 smoke tests including the no-flicker check, rollback considerations, DoD, and explicit workflow doc update plan.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #3 from `CURRENT_TASK.md` on the existing `fix/theme-persistence` branch. After this PR merges, four v1.1 features remain (F1 account settings, F3.A countdown, F3.C target tasks, F3.B recurring tasks).

## 2026-05-07 — GitHub Copilot (GPT-5.3-Codex) — Implement v1.1 PR #2 notification-language fix

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `fix/notification-language`
- **Goal**: Implement server-side localization for FCM push payloads by recipient language (`users/{uid}.languageCode`) while keeping in-app notifications unchanged.
- **Outcome**: Added `FirebasePaths.languageCode`; persisted `languageCode` after successful auth checks/sign-in and after locale changes in Settings (best-effort with Crashlytics logging). Extended `firestore.rules` user self-update mask from `['fcmToken']` to `['fcmToken', 'languageCode']`. Added locked EN/AR i18n table and `localize(...)` helper in `functions/index.js`; localized all four production FCM send sites (`sendTaskAssignedNotification`, `sendTaskStatusNotification`, `sendTaskDeadlineReminders`, `sendOverdueTaskEscalations`) plus both test callables. Quality gates passed: `flutter analyze`, `flutter test`, `cd functions && npm run lint`.
- **Files touched**: `lib/core/constants/firebase_paths.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/splash/presentation/screens/splash_screen.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `functions/index.js`, `firestore.rules`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Reviewer/owner runs full device + Firebase-console smoke battery (10 tests, en/ar coverage) and merges PR #2 to `dev` after validation.

## 2026-05-07 — Claude Code (Opus 4.7) — Plan v1.1 PR #2 (notification language)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `fix/notification-language`
- **Goal**: Lock scope and translation table for v1.1 PR #2 (server-side localization of FCM push notifications).
- **Outcome**: Audited the notification surface and discovered that **in-app notifications are already localized correctly client-side** (`notifications_screen.dart` uses `easy_localization` `.tr()` with `namedArgs` against existing keys). The bug is purely on the FCM push side where `messaging.send()` uses hardcoded English `title`/`body`. Scope narrowed accordingly. Locked: (1) server-side localization architecture; (2) `users/{uid}.languageCode` default fallback `'en'`; (3) best-effort client writes wrapped in try/catch + Crashlytics; (4) single rules change extending `hasOnly(['fcmToken'])` → `hasOnly(['fcmToken', 'languageCode'])`. Approved a 22-string Arabic translation table (11 keys × 2 locales) covering task assigned, task completed, deadline reminders (today/tomorrow), overdue warning, and overdue escalation. Wrote complete `CURRENT_TASK.md` with affected files, expected flow change example, edge cases, 10 smoke tests, rollback considerations, DoD, and explicit workflow doc update plan.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #2 from `CURRENT_TASK.md` on the existing `fix/notification-language` branch. Subsequent v1.1 PRs each get their own planning round before delegation.

## 2026-05-07 — GitHub Copilot (GPT-5.3-Codex) — Implement auth/account-deletion lifecycle fix (v1.1 PR #1)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `fix/auth-and-account-deletion-flow`
- **Goal**: Implement CURRENT_TASK scope for B1/B3: clear FCM token lifecycle on sign-out/deletion and ensure delete-account routes to login reliably.
- **Outcome**: Updated `AuthCubit.signOut()` to best-effort delete `users/{uid}.fcmToken` and call `FirebaseMessaging.deleteToken()` (both wrapped in try/catch with `FirebaseCrashlytics.recordError`). Updated `AuthCubit.deleteAccount()` to best-effort delete FCM token, clear Crashlytics user id, sign out, and emit `unauthenticated` on callable success. Updated Settings delete flow to remove success snackbar, add `BlocListener<AuthCubit, AuthState>` for unauthenticated routing to login, and defensively reset `_isDeleting` before navigation while preserving the `failed_to_delete_account` snackbar path. Verified top-level routing in `lib/app/app.dart` already existed; no change required. Quality gates passed.
- **Files touched**: `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, workflow docs, `CHANGELOG.md`.
- **Follow-ups**: Run/record full manual smoke tests on Android+iOS devices (Firebase-console checks for token removal/leakage), then merge PR after review.

## 2026-05-01 — Claude Code (Opus 4.7) — v1.1 roadmap + plan PR #1 (auth + account deletion flow)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `fix/auth-and-account-deletion-flow`
- **Goal**: Audit current state, lock the v1.1 architectural decisions, and write the spec for the first v1.1 PR (auth lifecycle + account deletion fixes).
- **Outcome**: Synthesized v1.1 roadmap covering 4 tester bugs (B1 FCM-after-logout, B2 notification language, B3 delete-account stuck, B4 theme persistence), 3 feature areas (F1 account settings, F2 attendance MVP, F3 task improvements with countdown/recurring/target sub-features). Locked 5 architectural decisions: (1) server-side notification localization driven by `users/{uid}.languageCode`; (2) account settings v1.1 scope = name + password only; (3) attendance MVP = timestamp + biometric (no location, defer privacy policy update); (4) recurring tasks via `isTemplate` boolean on existing `tasks` collection (not a separate collection); (5) adaptive screen-level countdown ticker (1Hz when any task <1h away, 1/min otherwise — no per-card timers). Audited `auth_cubit.dart` and `settings_screen.dart` for B1/B3 root causes: signOut() never clears FCM (Firestore + device); deleteAccount() relies on a passive auth listener that never explicitly fires + settings screen never resets `_isDeleting` on success. Wrote complete `CURRENT_TASK.md` spec (B1+B3 combined into PR #1) with affected files, expected flow changes, edge cases, 6 smoke tests, rollback considerations, DoD, and explicit workflow doc update plan. Seeded "v1.1 — testing-phase fixes and improvements" subsection in `BACKLOG.md` with PR #1 in progress and a list of upcoming entries.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over PR #1 from `CURRENT_TASK.md`. Subsequent v1.1 PRs each get their own planning round before delegation. v1.1.0 release tag after task improvements ship; attendance MVP ships in v1.2.0.

## 2026-05-01 — GitHub Copilot (Claude Sonnet 4.6) — Implement Android release signing (PR B)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `chore/android-release-signing`
- **Goal**: Configure strict release signing in `android/app/build.gradle.kts` via `android/key.properties` (gitignored); update `docs/release-checklist.md` with a copy-pasteable `keytool` + `key.properties` template.
- **Outcome**: Three structural edits applied to `build.gradle.kts`: (1) `import java.util.Properties` / `import java.io.FileInputStream` + `keystorePropertiesFile`/`keystoreProperties` block above `plugins {}`; (2) `signingConfigs { create("release") { ... } }` with `keystorePropertiesFile.exists()` guard, inside `android {}`; (3) `buildTypes.release` uses `signingConfigs.getByName("release")` — TODO comment removed, debug-key fallback removed. `docs/release-checklist.md` updated with `keytool` command, `key.properties` template, and `flutter build appbundle --release` verification step. All 4 quality gates green. All 4 smoke tests green (release fails without `key.properties` ✓; throwaway-keystore signed AAB + `jarsigner -verify` ✓; iOS no-codesign ✓ 54.9 MB; git status clean ✓).
- **Files touched**: `android/app/build.gradle.kts`, `docs/release-checklist.md`, workflow docs.
- **Follow-ups**: PR B (#20) merged to `dev`. Owner must create `~/upload-keystore.jks` + `android/key.properties` before first Play Console upload (see `docs/release-checklist.md`).

## 2026-05-01 — GitHub Copilot (GPT-5.3-Codex) — Implement app icons pre-build polish (PR A)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/app-icons`
- **Goal**: Implement PR A by adding launcher icon generation config and regenerating Android/iOS launcher assets from the committed square master icon.
- **Outcome**: Added `flutter_launcher_icons: ^0.14.4` to `dev_dependencies`, added launcher config in `pubspec.yaml`, ran `flutter pub get` and `dart run flutter_launcher_icons`, regenerated Android mipmap icons and iOS app icon assets, and verified required file dimensions/hash changes. Quality gates passed: `flutter analyze`, `flutter test`, and `cd functions && npm run lint`.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/res/mipmap-*/ic_launcher.png`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, workflow docs.
- **Follow-ups**: PR A (#19) merged to `dev` on 2026-05-01.

## 2026-04-30 — GitHub Copilot (GPT-5.3-Codex) — Implement release-prep PR #5 (Crashlytics + bumps + release docs)

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/release-readiness`
- **Goal**: Implement the final release-prep PR for v1.0.0 exactly as planned in `CURRENT_TASK.md`.
- **Outcome**: Added `firebase_crashlytics` and bumped the 5 Firebase Flutter packages by one minor each. Wired global Crashlytics handlers in `main.dart` and user identifier set/clear in `auth_cubit.dart`. Added `CHANGELOG.md` (Keep a Changelog format, v1.0.0 draft) and `docs/release-checklist.md`. Quality gates and verification commands passed. Manual smoke tests requiring real devices and Firebase console interaction were documented in the PR body.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `CHANGELOG.md`, `docs/release-checklist.md`, workflow docs.
- **Follow-ups**: Open PR to `dev`, reviewer to complete real-device smoke tests (including Crashlytics test-crash confirmation), then owner runs release flow (`dev -> main` PR, `v1.0.0` tag, operational checklist).

## 2026-04-30 — Claude Code (Opus 4.7) — Plan release-prep PR #5 (release readiness — Crashlytics + bumps + CHANGELOG)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/release-readiness`
- **Goal**: Lock scope for the final release-prep PR (Crashlytics, Firebase minor bumps, CHANGELOG, release checklist) before tagging v1.0.0.
- **Outcome**: Audited current error-handling surface (zero — no `FlutterError.onError`, no `PlatformDispatcher.onError`, no zoned guard), Firebase dep freshness (5 packages one minor behind, deltas confirmed), version (`1.0.0+1` — no bump needed for first build), absence of `CHANGELOG.md` and `docs/release-checklist.md`. Locked 6 product decisions: minimal Crashlytics (global handlers + user identifier only); exactly 5 Firebase Flutter minor bumps and nothing else; CHANGELOG drafted by implementing agent in Keep-a-Changelog format; standalone `docs/release-checklist.md`; version stays at `1.0.0+1`; iOS dSYM upload remains a documented manual Xcode step. Wrote `CURRENT_TASK.md` with file-by-file scope, exact dep-version deltas, exact main.dart/auth_cubit.dart additions, the CHANGELOG and release-checklist structures, 9 manual smoke tests (including the Crashlytics test crash), and risk + out-of-scope rails. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #5 from `CURRENT_TASK.md` on the existing `chore/release-readiness` branch. After PR #5 merges: open `dev → main` release PR (merge commit, not squash), tag `v1.0.0`, create GitHub Release, then run the operational items in the release checklist (Pages enablement, dSYM, signing, backups). Post-v1.0.0 product ideas explicitly deferred per the user.

## 2026-04-28 — Claude Code (Opus 4.7) — Plan release-prep PR #4 (account deletion + privacy)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/account-deletion-and-privacy`
- **Goal**: Lock scope for the largest release-prep PR (account deletion + privacy policy + About screen for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited Settings (93-line stateless screen, no Account section), routes (only `/settings` exists; need `/about`), Cloud Functions (7 existing exports; `createEmployeeUser` is the perfect template — admin SDK with auth check + HttpsError pattern), and dependencies (`cloud_functions` already wired; `package_info_plus` and `url_launcher` need to be added). Locked 6 product decisions: keep tasks of deleted users with `assignedByName`/`assignedToName` overwritten to `"Deleted user"`; simple AlertDialog confirmation; privacy policy drafted by implementing agent for user review on PR; About shows app name + version + privacy + licenses (no support email); approved both new dependencies; GitHub Pages from `main`/`/docs`. Wrote a comprehensive `CURRENT_TASK.md` covering 11 sections of file-by-file scope, exact translation values for 11 new keys (en + ar), 14 manual smoke tests, GitHub Pages enablement instructions for the user, and explicit risk + out-of-scope rails. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #4 from `CURRENT_TASK.md` on the existing `feat/account-deletion-and-privacy` branch. After merge: project owner enables GitHub Pages from `main`/`/docs` (one-time UI step) and replaces the placeholder support email in `docs/privacy-policy.md`.

## 2026-04-28 — GitHub Copilot (Claude Sonnet 4.6) — Implement account deletion, privacy policy, and About screen (PR #4)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/account-deletion-and-privacy`
- **Goal**: Implement the 5 surfaces in release-prep PR #4: Cloud Function `deleteUserAccount`, Settings Account section + delete flow, About screen, privacy policy, and 11 new translation keys.
- **Outcome**: All 5 surfaces implemented. `deleteUserAccount` callable atomically overwrites task display names, deletes notifications, deletes user doc, then deletes Auth account. Settings screen converted to StatefulWidget with Account section (About tile + Delete account tile with confirmation dialog). `AboutScreen` shows version via `package_info_plus` and opens privacy URL via `url_launcher`. `docs/privacy-policy.md` drafted with all 10 required sections. 11 translation keys added with parity (182 == 182 keys). All three quality gates green. Real-device smoke tests pending reviewer before merge.
- **Files touched**: `functions/index.js`, `pubspec.yaml`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `lib/features/settings/presentation/screens/about_screen.dart` (new), `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `docs/privacy-policy.md` (new), `assets/translations/en.json`, `assets/translations/ar.json`, workflow docs.
- **Follow-ups**: (1) Reviewer to run 14 manual smoke tests on real devices before merge. (2) Owner to enable GitHub Pages (repo Settings → Pages → `main` branch `/docs` folder) after PR #4 merges to `main`. (3) Owner to replace `support@example.com` in `docs/privacy-policy.md`.

## 2026-04-28 — GitHub Copilot (Claude Sonnet 4.6) — Implement notifications permission (PR #3)

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/notifications-permission`
- **Goal**: Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to `AndroidManifest.xml` to fix silent FCM permission suppression on Android 13+.
- **Outcome**: Single manifest line inserted as first child of `<manifest>` before `<application>`. All three quality gates passed: `flutter analyze` → No issues found, `flutter test` → All tests passed, `npm --prefix functions run lint` → clean. Real-device Android 13+ smoke tests are pending reviewer verification before merge. PR opened to `dev`: `feat(notifications): add POST_NOTIFICATIONS for Android 13+`.
- **Files touched**: `android/app/src/main/AndroidManifest.xml`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Reviewer to run 7 smoke tests on a real Android 13+ device (see `CURRENT_TASK.md` §5) before merging. Next: PR #4 account deletion + privacy policy.

## 2026-04-28 — Claude Code (Opus 4.7) — Plan release-prep PR #3 (notifications permission)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feat/notifications-permission`
- **Goal**: Lock scope for release-prep PR #3 of 5 (Android 13+ POST_NOTIFICATIONS for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited the FCM setup. Discovered the runtime `FirebaseMessaging.requestPermission(...)` call already exists at `auth_cubit.dart:125` (inside `_setupFCM`, called after successful sign-in) — meaning iOS permission has been working all along. The Android 13+ failure is purely a missing `<uses-permission>` manifest declaration. PR collapses to one line in `AndroidManifest.xml`. Locked 3 product decisions: minimal scope (manifest only, no UX scope creep), placement at top of `<manifest>` before `<application>` per Android convention, real-device Android 13+ verification gate before merge. Wrote `CURRENT_TASK.md` capturing the spec, 7 manual smoke tests (3 must run on a real device — Android 13+ fresh install, deny path, regression checks), and out-of-scope rails.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #3 from `CURRENT_TASK.md` on the existing `feat/notifications-permission` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement release metadata fixes

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/release-metadata`
- **Goal**: Execute the metadata-only release-prep PR #2 with exactly five scoped edits and no changes under `lib/` or `functions/` code paths.
- **Outcome**: Updated `pubspec.yaml` description, replaced starter `README.md` with a concise project README, changed Android launcher label to `Techno Staff`, changed iOS `CFBundleName` to `Techno Staff`, and renamed `in_pending_tasks` to `pending_tasks` in `assets/translations/en.json`. Verification passed (`grep` result `0`), translation key parity remained `171 171 []`, and quality gates passed (`flutter analyze`, `flutter test`, `npm --prefix functions run lint`).
- **Files touched**: `pubspec.yaml`, `README.md`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `assets/translations/en.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Open PR to `dev` titled `chore(release): metadata fixes — description, README, app label, translation typo`.

## 2026-04-27 — Claude Code (Opus 4.7) — Plan release-prep PR #2 (release metadata)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/release-metadata`
- **Goal**: Lock scope and product decisions for release-prep PR #2 of 5 (metadata fixes for v1.0.0), then hand off to the implementing agent.
- **Outcome**: Audited pubspec (default placeholder description), README (16 lines of Flutter starter content), `AndroidManifest.xml` (`android:label="techno_staff"` — visible on launcher), iOS `Info.plist` (`CFBundleName: techno_staff`, `CFBundleDisplayName: Techno Staff`), and the `in_pending_tasks` / `pending_tasks` translation key mismatch. Confirmed via grep that `in_pending_tasks` is orphaned in `en.json` — no code references it; `dashboard_pie_chart.dart` uses `pending_tasks` only. Locked 4 product decisions: concise README (~30 lines, no duplication of CLAUDE.md), iOS CFBundleName change to `Techno Staff` for consistency, real pubspec description, English key rename `in_pending_tasks` → `pending_tasks`. Wrote a complete file-by-file `CURRENT_TASK.md` with explicit "do NOT change" lines for `applicationId`, `PRODUCT_BUNDLE_IDENTIFIER`, `pubspec name`, and `version` (each easy to touch by accident with high blast radius). Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #2 from `CURRENT_TASK.md` on the existing `chore/release-metadata` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement strip debug logging

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `chore/strip-debug-logging`
- **Goal**: Execute the mechanical release-prep cleanup by deleting all `debugPrint` calls under `lib/` without changing behavior.
- **Outcome**: Removed all 20 `debugPrint` calls from the 6 scoped files, updated now-unused `catch (e)` bindings to `catch (_)`, and removed now-unused `flutter/foundation.dart` imports. Verification command `grep -rn "debugPrint" lib | wc -l` returned `0`; quality gates passed (`flutter analyze`, `flutter test`, `cd functions && npm run lint`).
- **Files touched**: `lib/main.dart`, `lib/features/auth/presentation/cubit/auth_cubit.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/reports/data/repositories/reports_repository.dart`, `lib/features/reports/presentation/cubit/reports_cubit.dart`, `lib/features/reports/presentation/screens/reports_screen.dart`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Open PR to `dev` titled `chore(logging): strip debug logging before v1.0.0`.

## 2026-04-27 — Claude Code (Opus 4.7) — Release-readiness sweep + plan PR #1 (strip debug logging)

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `chore/strip-debug-logging`
- **Goal**: Run a release-readiness sweep for v1.0.0, agree a 5-PR breakdown, then plan the first PR (debug-log strip).
- **Outcome**: Audited TODO/FIXME (zero), `debugPrint` census (20 calls leaking FCM token + user IDs + task IDs to release logs), Flutter & Functions dep freshness (minor versions behind, major bumps deferred), app metadata (default pubspec description, default README, Android label is lowercase internal name, iOS display correct), permissions (Android 13+ `POST_NOTIFICATIONS` missing — release blocker), privacy surface (no privacy policy / no account deletion — both required by Apple/Google), translation parity (1 typo: `in_pending_tasks` vs `pending_tasks`). User accepted the 5-PR breakdown, locked Cloud Function for account deletion, GitHub Pages for privacy policy, Crashlytics + minor dep bumps in v1.0.0, additional checks A1/A5/A6/A8/A9. Wrote a complete file-by-file `CURRENT_TASK.md` for PR #1, added a `Release v1.0.0 readiness` section to `BACKLOG.md` listing all 5 PRs (PR #1 In progress, others Open), and logged two `DECISIONS_LOG.md` entries.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over PR #1 from `CURRENT_TASK.md` on the existing `chore/strip-debug-logging` branch. PRs #2–#5 each get their own planning round before delegation.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement task search and filtering

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/task-search-and-filtering`
- **Goal**: Implement the approved client-side task search/filter/sort UX with global screen-level filter state and no cubit/state/repository changes.
- **Outcome**: Added the new `task_filter_bottom_sheet.dart` widget (`TaskFilters`, `TaskSortOption`, apply/cancel flow), integrated global local-state search/filter/sort in `tasks_screen.dart`, added active-filter indicators and distinct filtered-empty state, and added EN/AR localization keys. Quality gates passed (`flutter analyze`, `flutter test`, `functions` lint).
- **Files touched**: `lib/features/tasks/presentation/widgets/task_filter_bottom_sheet.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Execute full in-app manual smoke tests (16 scenarios) and review PR against `dev`.

## 2026-04-27 — Claude Code (Opus 4.7) — Plan task search and filtering

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/task-search-and-filtering`
- **Goal**: Lock scope, UX shape, and product decisions for the "Add task search and filtering" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited `TaskModel` (rich enough to filter on title, description, assignedToName, assignedByName, status, priority, dueDate, createdAt), `tasks_screen.dart` (346 lines — flagged extraction of a bottom-sheet widget as mandatory), `tasks_cubit.dart` / `tasks_state.dart` (no changes needed), and translation files (zero existing search/filter/sort keys). Pushed back on two BACKLOG defaults: filter state should be GLOBAL across tabs (not per-tab) for consistency, and the empty-results state should use a new `no_matching_tasks` key with a clear-filters hint (not reuse `no_tasks_found`). Locked 8 product decisions: search covers 4 fields including assignee names, filters limited to status + priority (assignee filter and date range deferred), 3 sort options, global filter state, local widget state (not in TasksState), bottom-sheet UI, badge dot indicator, distinct empty state. Wrote a complete file-by-file `CURRENT_TASK.md` spec with exact translation values for en + ar (13 new keys), 16 manual smoke tests, and DoD. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/task-search-and-filtering` branch.

## 2026-04-27 — GitHub Copilot (GPT-5.3-Codex) — Implement task delete UI

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/task-delete-ui`
- **Goal**: Implement the approved delete UX for task creators/admins without expanding scope beyond client repository/cubit/UI and localization.
- **Outcome**: Added `deleteTask` repository + cubit methods, added delete AppBar action on task details with confirmation and mounted-safe async flow, added EN/AR translation keys, and kept scope boundaries intact (no rules/functions/task-log cleanup changes). Ran all three quality gates successfully.
- **Files touched**: `lib/features/tasks/data/repositories/tasks_repository.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Execute manual runtime smoke tests in app and review PR against `dev`.

## 2026-04-26 — Claude Code (Opus 4.7) — Plan task delete UI

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/task-delete-ui`
- **Goal**: Lock scope and product decisions for the "Add task delete UI for admins and creators" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited `task_details_screen.dart`, `tasks_repository.dart`, and `tasks_cubit.dart`. Confirmed the existing edit-icon AppBar pattern is the right blueprint and the rules already permit creator + admin delete (shipped in PR #6). Locked 5 product decisions: AppBar icon location, same gate as edit, confirmation dialog with task title interpolation, no notifications on delete, no `task_logs/` cleanup. Wrote a complete file-by-file `CURRENT_TASK.md` spec with exact translation values for en + ar (using `easy_localization` positional `{}` args), 7 manual smoke tests, and DoD. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/task-delete-ui` branch.

## 2026-04-26 — GitHub Copilot (GPT-5.4) — Implement admin task tabs

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feature/admin-task-tabs`
- **Goal**: Implement the approved admin tasks UX so admins can switch between their own assigned tasks and the full team task list without changing the employee flow.
- **Outcome**: Updated the admin tasks screen to fetch and render two task streams (`Assigned to me`, `All tasks`) using the same tab pattern as the employee view, refreshed both streams after admin inline status updates, added the required locale keys, and ran all three quality gates successfully.
- **Files touched**: `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Follow-ups**: Manual in-app smoke tests and PR creation remain the only external steps.

## 2026-04-26 — Claude Code (Opus 4.7) — Plan admin task tabs

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/admin-task-tabs`
- **Goal**: Lock scope and product decisions for the "Add admin task tabs (Assigned to me + All tasks)" backlog item, then hand off to the implementing agent.
- **Outcome**: Audited current `tasks_screen.dart` admin path. Confirmed the cubit and state already expose everything needed (`fetchAllTasks`, `fetchTasksAssignedTo`, `state.tasks`, `state.tasksAssignedToMe`, per-tab status fields) — no state, repository, or rules changes required. Locked 3 product decisions (tab order, `all_tasks` label, `tasks_overview` subtitle). Wrote a complete file-by-file `CURRENT_TASK.md` spec with explicit Definition of Done, 7 manual smoke tests, and exact translation values for en + ar. Moved the backlog item to "In progress".
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md` on the existing `feature/admin-task-tabs` branch.

## 2026-04-24 — GitHub Copilot (GPT-5.3-Codex) — Implement employee task creation

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feature/employee-task-creation`
- **Goal**: Implement the approved scope to allow employees to create and assign tasks without changing architecture decisions.
- **Outcome**: Applied the approved `firestore.rules` diff, added `assignedBy` constants, extended task repository/cubit/state for assigned-vs-created task lists, added non-admin task tabs and universal task FAB, enabled any-user assignment (excluding self) in add-task flow, added localization keys in en/ar, and added state unit tests. Also resolved existing analyzer infos so quality gates are green.
- **Files touched**: `firestore.rules`, `lib/core/constants/firebase_paths.dart`, `lib/features/tasks/**`, `lib/features/employee/presentation/screens/employee_home_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `test/features/tasks/presentation/cubit/tasks_state_test.dart`, plus lint-only fixes in `lib/features/dashboard/**`, `lib/features/employees/**`, `lib/features/notifications/**`, and `lib/features/reports/**`.
- **Follow-ups**: Manual smoke tests from `CURRENT_TASK.md` still require runtime verification against Firebase users/devices.

## 2026-04-24 — Claude Code (Opus 4.7) — Plan employee task creation

- **Agent**: Claude Code (Opus 4.7) — acting as lead / architect (planning only, no code).
- **Branch**: `feature/employee-task-creation`
- **Goal**: Lock in scope, rules diff, and product decisions for the "Allow employees to create and assign tasks" backlog item, then hand off implementation to a separate agent.
- **Outcome**: Audited `firestore.rules`, `lib/features/tasks/`, `add_task_screen.dart`, and `functions/index.js`. Found the backend is ~80% already compatible with the feature. Locked in 5 product decisions (any-to-any assignment, relax `users` read, tabs for employee view, creator can delete, `assignedBy` immutable). Rewrote `CURRENT_TASK.md` as a full file-by-file implementation spec including the exact approved rules diff, scope, smoke tests, and DoD. Moved the `BACKLOG.md` item to "In progress". Implementation will be carried out by another agent against this branch.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementation agent takes over from `CURRENT_TASK.md`.

## 2026-04-24 — Claude Code (Opus 4.7) — Bootstrap AI workflow docs

- **Agent**: Claude Code (Opus 4.7)
- **Branch**: `chore/ai-workflow-docs`
- **Goal**: Create `/docs/ai-workflow/` as the shared source of truth across AI agents and human developers. Remove the unused Spec Kit setup.
- **Outcome**: Created 7 workflow files (`PROJECT_CONTEXT.md`, `CURRENT_TASK.md`, `BACKLOG.md`, `DECISIONS_LOG.md`, `RULES.md`, `NEXT_STEPS.md`, `SESSION_LOG.md`). Migrated the ratified constitution v1.0.0 into `RULES.md` and extended it with git/commit conventions and an "agents must not do X without asking" list. Deleted `specs/`, `.specify/`, and the `speckit-*` skills under `.claude/skills/`. Added a pointer from `CLAUDE.md` to the new workflow folder.
- **Files touched**: `docs/ai-workflow/*.md` (new), `CLAUDE.md` (small addition), `specs/` (deleted), `.specify/` (deleted), `.claude/skills/speckit-*` (deleted).
- **Follow-ups**: Next task to be picked by the team. `BACKLOG.md` and `NEXT_STEPS.md` are intentionally empty and ready to fill with real work.
