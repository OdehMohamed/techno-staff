## 2026-06-17 — Claude Sonnet 4.6 — FlutterFire upgrade: firebase-ios-sdk 12.14.0 + v1.5.0+8 Shorebird release (iOS + Android)

- **Agent**: Claude Sonnet 4.6
- **Branch**: `chore/flutterfire-upgrade`
- **Goal**: Fix `shorebird release ios` failure (blocked since v1.4.0) by upgrading FlutterFire packages, then cut v1.5.0+8 Shorebird baselines for both platforms.
- **Outcome**: ✅ Both `shorebird release ios` and `shorebird release android` published for v1.5.0+8. Store binary uploads pending (owner action).

### Root cause (corrected from earlier diagnosis)

The original session (2026-06-16) incorrectly attributed the failure to a cloud_firestore 6.x / Firebase iOS SDK 11.x mismatch. The actual cause:

- `cloud_firestore 6.3.0`'s `FLTPipelineParser.m` called `[[FIRCollectionSourceStageBridge alloc] initWithRef:ref firestore:firestore]` (2-arg initializer)
- firebase-ios-sdk 12.14.0 changed this to `initWithRef:firestore:forceIndex:` (3-arg) — link-time selector mismatch
- Shorebird's SPM resolved `from: "12.12.0"` to 12.14.0; CocoaPods pinned to exactly 12.12.0, so local builds passed
- `cloud_firestore 6.5.0` changelog: "Fixed iOS collection source initialization with `forceIndex` parameter" — exact fix

### Packages upgraded (all same major version — no Dart API breaking changes)

| Package | Before | After |
|---|---|---|
| `firebase_core` | 4.7.0 | 4.10.0 |
| `cloud_firestore` | 6.3.0 | 6.5.0 |
| `firebase_auth` | 6.4.0 | 6.5.2 |
| `firebase_crashlytics` | 5.2.0 | 5.2.3 |
| `firebase_messaging` | 16.2.0 | 16.3.0 |
| `cloud_functions` | 6.2.0 | 6.3.2 |

### Validation results

1. `flutter pub upgrade` — all 6 packages resolved to targets ✅
2. `flutter analyze lib/ test/` — no issues ✅
3. `flutter build ios --no-codesign` — succeeded after: deleting stale `Podfile.lock` (pinned to Firebase 12.12.0) + running `pod repo update` (local CocoaPods spec cache lacked Firebase 12.14.0 podspec) ✅
4. Manual smoke test on real devices (owner): sign-in, task list, task creation, push notifications, chat, attendance — all passed ✅
5. `shorebird release ios` → Published Release 1.5.0+8 ✅ (IPA at `build/ios/ipa/`)
6. `shorebird release android` → Published Release 1.5.0+8 ✅ (AAB at `build/app/outputs/bundle/release/app-release.aab`)

### Notable warnings (non-blocking)

Android build printed deprecation warnings: Gradle 8.12.0 (needs 8.14.0+), AGP 8.9.1 (needs 8.11.1+), Kotlin 2.1.0 (needs 2.2.20+). Current builds succeed; these become errors in a future Flutter version. Added to NEXT_STEPS.md.

- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/NEXT_STEPS.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: (1) Owner: upload IPA + AAB to stores. (2) Chat Phase 2 implementation.

---

## 2026-06-16 — Owner — Shorebird asset patching verification: FAIL

- **Agent**: Owner (manual device test)
- **Branch**: `chore/shorebird-asset-patch-test` (created and deleted; never merged)
- **Goal**: Confirm whether `shorebird patch android` includes changed `assets/translations/*.json` files.
- **Outcome**: **NOT supported.** Shorebird CLI printed `[WARN] Your app contains asset changes, which will not be included in the patch` and listed `base/assets/flutter_assets/assets/translations/en.json`. Owner aborted the patch (`N`). Test branch reverted and deleted without merging.
- **Implication**: Any PR that adds or modifies translation keys is a full binary store release — never a Shorebird patch. This applies to all future feature work including Chat Phase 2.
- **Files touched (docs only)**: `docs/release-checklist.md` (patch-eligibility checklist updated; first-time setup item marked ✅), `docs/ai-workflow/NEXT_STEPS.md` (verification item closed), `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Proceed to FlutterFire upgrade (`chore/flutterfire-upgrade`) — the next item on the roadmap.

---

## 2026-06-16 — Claude Sonnet 4.6 — v1.4.0 post-release: Shorebird iOS diagnosis + full roadmap re-assessment

- **Agent**: Claude Sonnet 4.6
- **Branch**: `main` (no code changes — diagnosis + doc updates only)
- **Goal**: (1) Deliver the definitive root-cause and fix path for the Shorebird iOS build failure from the v1.4.0 release attempt. (2) Re-assess the project roadmap from scratch based on the current codebase state, not historical planning assumptions.
- **Outcome**: Root cause confirmed and documented. Full roadmap produced. Workflow docs updated to reflect v1.4.0 completion state.

### Shorebird iOS root cause (confirmed)

Three facts combine:
1. `Generated.xcconfig` has `FLUTTER_ROOT` pointing to Shorebird's Flutter 3.44.2 (not local 3.35.7), so `pod install` uses Shorebird's `podhelper.rb`.
2. Flutter 3.29+ lets plugins with a `Package.swift` skip CocoaPods. The FlutterFire packages (firebase_core 4.x, cloud_firestore 6.x) have SPM manifests, so Firebase is resolved entirely via SPM at `firebase-ios-sdk 12.14.0` — confirmed by `Package.resolved` (12.14.0) and `Podfile.lock` (no Firebase entries at all).
3. `cloud_firestore 6.x` was written against Firebase iOS SDK 11.x ObjC bridge API. `FIRCollectionSourceStageBridge.initWithRef:firestore:` and `FIRCollectionGroupSourceStageBridge.initWithCollectionId:` exist in 11.x but changed in 12.x → selector mismatch at link time.

Local Flutter 3.35.7 builds work because its `podhelper.rb` uses CocoaPods for Firebase (SPM opt-in behavior is different), so firebase-ios-sdk 12.14.0 via SPM is never invoked.

**Fix**: Upgrade FlutterFire stack to the versions whose `Package.swift` targets `firebase-ios-sdk ~> 12.0`. One clean path; no fragile workarounds. Branch: `chore/flutterfire-upgrade`.

### Roadmap decisions

- iOS v1.4.0 ships as plain Xcode archive (not Shorebird) until the FlutterFire upgrade is done.
- Android Shorebird release can be deployed to Play Console now.
- Chat Phase 2 (Employees quick-action → task thread → member management) is the next feature milestone after triage.
- functions/index.js (~1,978 lines, 15 exports) should be split by domain when the next CF is added — not as a standalone refactor.

- **Files touched**: `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/NEXT_STEPS.md`, `docs/ai-workflow/PROJECT_CONTEXT.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: FlutterFire upgrade (`chore/flutterfire-upgrade`) is the next code task. Then Firebase deploy + store binary submissions for v1.4.0.

---

## 2026-06-14 — Claude Sonnet 4.6 — iOS foreground notification suppression: fixed + validated on device

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/chat-messaging`
- **Goal**: Resolve the last open chat issue — iOS foreground per-conversation suppression that "never fired" (every banner shown).
- **Outcome**: Fixed and **validated on device**. Same-conversation message → `decision=SUPPRESSED`, no banner. Other-conversation message → `decision=SHOWN`, banner appears. iOS foreground behavior now matches the spec.

### Root cause (final, confirmed by native logs)

Our `AppDelegate.willPresent` override was **never being invoked** — `firebase_messaging`/`flutter_local_notifications` claim the `UNUserNotificationCenter` delegate during plugin registration, so the override was dead code. Every earlier logic-only fix had no effect for this reason. The investigation was derailed by two diagnostic traps: (1) the Dart `onMessage` diagnostic read its own **stale in-memory `SharedPreferences` cache**, which never sees values Swift writes after startup, making the native path look broken; (2) Swift `NSLog` does not appear in `flutter run` (only Xcode/Console.app), so the native logs that would have shown the truth were invisible.

### What was done

- **`AppDelegate.swift`** — Added `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunching` (the load-bearing fix). `willPresent` reads `conversationId` from the push `userInfo` and the active conversation from `UserDefaults` (`flutter.active_conversation_id`, with the unprefixed key as a fallback); calls `completionHandler([])` to suppress when they match, else `super` so firebase_messaging presents the banner.
- **`main.dart`** — Restored `setForegroundNotificationPresentationOptions(alert: true)` for iOS (Firebase presents natively; the Dart local-notification path can't be used on iOS because Firebase's foreground option swallows local notifications). iOS `onMessage` is a no-op; Android path unchanged.
- **`conversation_cubit.dart`** — iOS writes/removes `active_conversation_id` via `shared_preferences` on conversation enter/exit.

### Quality gates
- `flutter analyze` — clean
- Device validation — same-conversation suppressed, cross-conversation shown (owner-confirmed)

### Key learnings (see DECISIONS_LOG 2026-06-14)
- Verify native iOS notification behavior from **Xcode/Console.app**, never from `flutter run` alone.
- Cross-language diagnostics via `SharedPreferences` are unreliable without `reload()` — Dart caches in memory.
- Android and iOS use intentionally different foreground-suppression mechanisms.

---

## 2026-05-30 — Claude Sonnet 4.6 — iOS foreground notifications: native APNs approach on feat/chat-messaging

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/chat-messaging`
- **Goal**: Fix iOS foreground chat notifications not showing after the data-payload fallback proved insufficient.
- **Outcome**: Root cause confirmed via deep source-code analysis of `firebase_messaging` v16.2.0 and `flutter_local_notifications` v20.1.0. Fix implemented. Pending owner validation.

### Root cause (confirmed)

`firebase_messaging`'s `FLTFirebaseMessagingPlugin` registers itself as a `FlutterAppDelegate` application delegate. `FlutterAppDelegate.willPresent:withCompletionHandler:` passes the **same** `completionHandler` block to every registered plugin delegate. `firebase_messaging`'s own `willPresent` implementation always calls `completionHandler([])` for any notification that lacks a `gcm.message_id` key — which covers ALL local notifications created by `flutter_local_notifications`. This second `completionHandler([])` call overrides the `completionHandler([.banner, .sound])` our `AppDelegate` already made, silently preventing the banner from appearing.

The previous architecture (`setForegroundNotificationPresentationOptions(alert: false) → onMessage → flutter_local_notifications.show() → willPresent`) was fundamentally incompatible with this firebase_messaging v16 plugin behavior.

### What was done

- **`AppDelegate.swift`** — Rewrote `willPresent`. Push notifications are now handled **directly** (no `super` call) to bypass the firebase_messaging plugin delegate chain. Active-conversation suppression reads `UserDefaults.standard.string(forKey: "flutter.active_conversation_id")` and calls `completionHandler([])` to suppress or `completionHandler([.banner, .sound])` to show. Local notifications still call `completionHandler([.banner, .list, .sound])` for iOS 14+ or `[.alert, .sound]` for iOS 13.
- **`conversation_cubit.dart`** — On iOS, `loadConversation` fire-and-forgets `SharedPreferences.setString('active_conversation_id', conversationId)` and `clearActiveConversation` fire-and-forgets `SharedPreferences.remove('active_conversation_id')`. `shared_preferences_foundation` stores these in `UserDefaults.standard` with the literal `flutter.` prefix.
- **`main.dart`** — Removed `setForegroundNotificationPresentationOptions` block (no longer needed). Added `if (Platform.isIOS) return;` guard in `onMessage` listener before `showForegroundNotification` — prevents duplicate banners in case firebase_messaging fires `onMessage` via the `GULAppDelegateSwizzler` `didReceiveRemoteNotification` path.

### Quality gates
- `flutter analyze` — clean (3 files)

### Owner-required steps
- Run `flutter run` on iOS device
- Validate: foreground app, outside target conversation → native APNs banner appears
- Validate: foreground app, inside target conversation → banner suppressed
- Validate: background/terminated → banner still works (unchanged path)
- Validate: Android notifications unaffected

---

## 2026-05-30 — Claude Sonnet 4.6 — iOS foreground chat notification fix on feat/chat-messaging

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/chat-messaging`
- **Goal**: Fix iOS foreground chat notifications not showing when the user is in the app but not in the target conversation.
- **Outcome**: Root cause confirmed and fixed. Pending owner validation on device.

### What was done

- **Root cause**: With `setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false)`, firebase_messaging on iOS delivers `onMessage` with `message.notification == null`. `showForegroundNotification` had an early-return guard `if (notification == null) return`, so `flutter_local_notifications.show()` was never called.
- **`functions/index.js`** — Added `notificationTitle` and `notificationBody` to the FCM `data` payload in `onNewChatMessage`, so the title/body are available even when firebase_messaging strips the `notification` field.
- **`notification_service.dart`** — Replaced `if (notification == null) return` with null-safe fallback: `title = notification?.title ?? message.data['notificationTitle']`; `body = notification?.body ?? message.data['notificationBody']`. Guard now checks `if (title == null && body == null)`. Notification ID changed from `notification.hashCode` (required non-null) to `message.hashCode`.

### Quality gates
- `flutter analyze lib/core/services/notification_service.dart` — clean

### Owner-required steps
- `firebase deploy --only functions` (deploys the updated `onNewChatMessage` with data-payload fields)
- Validate on iOS device: foreground app, not in target conversation → notification banner appears; active conversation → still suppressed

---

## 2026-05-30 — Claude Sonnet 4.6 — Chat Milestone 5: Cloud Functions, FCM routing, group creation on feat/chat-messaging

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/chat-messaging`
- **Goal**: Complete the final milestone of the chat MVP: `onNewChatMessage` Cloud Function, FCM notification routing, foreground suppression, and group conversation creation UI.
- **Outcome**: All Milestone 5 items implemented and quality gates green. Pending owner validation before PR merge.

### What was done

- **`onNewChatMessage` Cloud Function** — `onCreate` trigger on `conversations/{cId}/messages/{mId}`. Skips system messages. Atomically updates `lastMessage` + `lastMessageAt` + increments `unreadCounts` via `FieldValue.increment`. Fetches FCM tokens and user language codes in parallel. Sends localized push on `chat_messages` Android channel (DM: title=senderName, body=preview; Group/task: title=groupName, body=`sender: preview`). Writes in-app notification per recipient via `createInAppNotification` with `conversationId`. Added `chat_group_message_body` i18n string (EN + AR). Uses `Promise.allSettled` so one recipient failure doesn't block others.
- **`NotificationService`** — Added `_chatChannel` (`chat_messages`, high importance). Both channels registered in `initialize()`. `showForegroundNotification` selects channel from `message.data['conversationId']` and encodes payload as `conv:<id>` for chat or raw `taskId` for tasks.
- **`main.dart` FCM routing** — `ConversationCubit` instance pre-created before FCM listeners (before `runApp`) and passed via `BlocProvider.value`, so the `onMessage` suppression check (`conversationCubit.activeConversationId == conversationId`) needs no BuildContext. `onNotificationTap` parses `conv:` prefix → `RouteNames.conversation`; raw string → `RouteNames.taskDetails`. `onMessageOpenedApp` + `getInitialMessage` check `conversationId` then `taskId`.
- **`ConversationCubit`** — Added `String? get activeConversationId` public getter.
- **Group creation** — `ChatListCubit.createGroup()` delegates to repository. `NewConversationSheet` gains "Create Group" tile at top with `group_add_outlined` icon navigating to `RouteNames.newGroup`. `NewGroupScreen` (new file): group name `TextFormField` (max 50, required validator), multi-select `CheckboxListTile` employee list (excluding self), "Create" `TextButton` in AppBar, `members_count` indicator bar, error snackbar, `pushReplacementNamed` to new conversation on success.
- **`app_router.dart`** — `RouteNames.newGroup` → `NewGroupScreen` wired.
- **Translations** — 9 new keys × 2 locales: `create_group`, `create_group_hint`, `group_name_label`, `group_name_hint`, `group_name_required`, `add_members`, `no_members_selected`, `create_group_error`, `create`. Parity: 358/358.

### Quality gates
- `flutter analyze` — clean
- `cd functions && npm run lint` — clean (fixed operator-linebreak for ternary in `onNewChatMessage`)
- `flutter test test/features/` — 6/6 passed
- Translation parity — 358/358

### Owner-required steps
- Validate group creation, FCM push (DM + group), foreground suppression, notification tap routing, in-app notification (see `CURRENT_TASK.md` checklist)
- `firebase deploy --only functions` — deploys `onNewChatMessage`

---

## 2026-05-28 — Claude Sonnet 4.6 — v1.3.1 hotfix: two production bugs on fix/v1.3.1-production-issues

- **Agent**: Claude Sonnet 4.6
- **Branch**: `fix/v1.3.1-production-issues` → merged to `main` as PR #41
- **Goal**: Diagnose and fix two production regressions from v1.3.0; full release flow including tag and GitHub Release.
- **Outcome**: Both bugs diagnosed, fixed, merged, tagged `v1.3.1`, GitHub Release created. CF deploy + Shorebird patch remain as owner steps.

### What was done

- **Root cause analysis — Bug 1 (attendance correction)**: `adminCorrectAttendance` CF wrote `notes: nextValue.notes` into a nested Firestore map in the `attendance_logs` write. When the admin submits without notes, `nextValue.notes` is `undefined` (never assigned in that branch). Firebase Admin SDK v12 throws a sync `Error` for `undefined` in nested maps; Functions returns `internal`; Flutter maps `internal` → `network_error`. Fixed with a conditional spread `...(nextValue.notes !== undefined ? {notes: nextValue.notes} : {})`.
- **Root cause analysis — Bug 2 (employee filter)**: `_openFilterBottomSheet` snapshots `EmployeesCubit.state.employees` at open time; `fetchEmployees()` was only triggered by `EmployeesScreen.initState`. Fixed by calling `fetchEmployees(silent: true)` in `TasksScreen.initState` for admin users.
- **Release**: `pubspec.yaml` bumped to `1.3.1+6`, `CHANGELOG.md` updated (v1.3.1 added; v1.3.0 backfilled), annotated tag `v1.3.1` created and pushed, GitHub Release https://github.com/OdehMohamed/techno-staff/releases/tag/v1.3.1 created.

### Owner-required steps remaining
- `firebase deploy --only functions` — deploys the CF fix.
- `shorebird patch android` / `shorebird patch ios` — delivers the Dart fix without a store submission.

---

## 2026-05-27 — Claude Sonnet 4.6 — v1.3.0 cycle: 3 bugs + 5 features on feat/v1.3.0-improvements

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/v1.3.0-improvements` → merged to `main` as PR #40
- **Goal**: Implement 3 bug fixes and 5 features; open and merge PR; update workflow docs.
- **Outcome**: All 8 items implemented, validated by owner, and merged. One owner-side Firebase deploy step remains.

### What was done

- **Bug 1 — Employees screen FAB overlap**: `ListView.separated` padding `bottom: 80` so the schedule button on lower cards is never blocked by the extended FAB.
- **Bug 2 — Attendance correction error masking**: `adminCorrect` catch changed from `catch (_)` to `catch (e)`; `_mapAttendanceError` extended with `permission-denied` and `invalid-argument` codes; incorrect "network failure" fallback eliminated.
- **Bug 3 — Check-in/out button not refreshing immediately**: `_currentUserId` cached in `AttendanceCubit` from `startListeningToday`; `fetchTodayRecord` (server-forced `Source.server`) called after callable returns; button state updates without waiting for Firestore stream propagation.
- **Feature 4 — Assignee name on admin task cards**: admin "All Tasks" tab shows `task.assignedToName` inline below each card's description.
- **Feature 5+6 — Recurring task creation in Add Task flow**: "Repeat this task" toggle (admin-only) progressively reveals recurrence type (daily/weekly/monthly), weekday/day-of-month pickers, and "Create first task now" toggle; creates a `TaskTemplateModel` on save; first-instance creation wraps the normal task creation path.
- **Multi-assignee Option B fix**: when repeat mode is active, single-employee dropdown replaced by a multi-select `FilterChip` picker (`assign_to_recurring` label). Toggle ON carries existing single selection into the multi-set; toggle OFF restores from first chip. First-instance creation loops per selected employee. Admin-only guard (`isAdmin`) wraps the entire recurring section so employees see only the standard form.
- **Feature 7 — Admin task filter by assigned employee**: `TaskFilters.filterAssigneeId/Name` added; filter bottom sheet renders "Assigned To" chip row for admins; both active and completed task lists apply the filter client-side.
- **Feature 8 — Admin attendance day reset**: `adminResetAttendance` Cloud Function (callable, admin-only) reads `schedules/{userId}` to classify the reset day, uses a Firestore transaction to overwrite the attendance doc and write an audit entry to `attendance_logs` (action: `admin_reset`, includes `previousStatus` and `previousSessions`). Dart layer: `resetStatus`/`resetError` state fields, `adminResetDay` cubit method, `adminResetDay` repository wrapper. UI: "Reset Day" destructive button in roster expanded section, confirmation dialog, spinner during submit, success/error snackbar.
- **Workflow**: created `feat/v1.3.0-improvements` branch, all commits on branch, PR #40 opened and merged to `main` via merge commit.

### Owner-required steps remaining
- `firebase deploy --only functions,firestore:rules` (adds `adminResetAttendance`; no rules or index changes).

---

## 2026-05-17 — Claude Sonnet 4.6 — Release prep: CHANGELOG completion + checklist update on feat/attendance-stabilization

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/attendance-stabilization`
- **Goal**: Final documentation pass before merge — complete CHANGELOG v1.2.0 with stabilization work, update release checklist to be version-agnostic and current, confirm no agreed features were left unimplemented.
- **Outcome**: No unresolved feature/UX gaps found. CHANGELOG and release checklist updated.

### What was done

- **CHANGELOG.md v1.2.0** — added the stabilization/refinement additions that were missing from the earlier entry: `hasDueTime` exact-time deadlines, completed task tab, quick-filter chips, employee home attendance card, admin dashboard attendance summary and overdue alert cards, admin reports summary redesign, schedule-aware attendance rate. Also added the two Fixed entries for completed-tab ordering and task refresh consistency.
- **`docs/release-checklist.md`** — updated: (1) pre-merge section is now version-agnostic and adds an attendance-specific smoke test; (2) one-time configuration items marked ✅ for items already completed (Firestore config doc, rules, GitHub Pages, Crashlytics dSYM, Android keystore); (3) release flow section updated with prominent post-merge Firebase deploy step (`firebase deploy --only functions,firestore:rules,firestore:indexes`) and guidance on `minimumAndroidVersion` bump decision; (4) post-release verification section adds attendance end-to-end check and `sendDailyAbsenceMarker` cron verification; (5) store submission section clarifies Flutter-only vs Shorebird build path; (6) deferred items note updated to match current NEXT_STEPS.
- **Scope confirmation** — verified against BACKLOG, DECISIONS_LOG, and NEXT_STEPS: no agreed features or polish items are unimplemented. Deferred items (late status v2, offline queue UX, sign-out-all-devices) are intentionally post-release.

### Branch is merge-ready
- All validation complete (owner confirmed).
- `firestore:indexes` deployed.
- `flutter analyze` clean.
- No outstanding Cloud Function deploys required before merge.

---

## 2026-05-17 — Claude Sonnet 4.6 — Admin reports attendance refactor + rate semantic fix on feat/attendance-stabilization

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/attendance-stabilization`
- **Goal**: (1) Align the admin reports attendance summary card with the employee monthly summary design. (2) Fix the semantic inconsistency where the same employee showed 21% on the employee screen but 100% in the admin report.
- **Outcome**: Both surfaces now use the same schedule-aware attendance rate definition. Admin reports summary redesigned to match employee summary layout.

### Admin reports attendance summary refactor
- `reports_screen.dart` `_MonthlyAttendanceSummaryCard` rewritten from 4 params to 8: `daysPresent`, `daysLate`, `daysAbsent`, `daysOff`, `daysOffWork`, `totalHoursWorked`, `corrections`, `attendanceRate`.
- Structure mirrors `_MonthlySummaryCard` from `employee_monthly_attendance_screen.dart`: attendance rate `LinearProgressIndicator` at top (hidden when null), `_rateColor` helper (primary ≥80%, tertiary ≥60%, error below), `Divider`, worked group (present + late + off-work chips + total hours), not-worked group (absent + off chips), corrections row (shown only when > 0).
- `daysPresent` now includes `|| r.status == 'manual'` to match employee screen parity.
- `daysLate`, `daysOff`, `daysOffWork` computed from roster records.

### Attendance rate semantic unification
- **Root cause**: admin reports used `daysWorked / (daysWorked + daysAbsent)` (proxy); employee screen used `daysWorked / workingDays` (schedule-aware). Same employee, same month, different denominators → different percentages.
- **Fix**: added `import 'work_schedule_model.dart'` and top-level `_countWorkingDays(WorkScheduleModel, year, month)` function to `reports_screen.dart` (mirrors the same function in `employee_monthly_attendance_screen.dart`).
- Added `loadEmployeeSchedule(employeeId, employeeName)` call in `BlocListener` alongside `loadMonthlyAttendance`, so `editingSchedule` loads whenever the employee or month changes.
- Rate bar hidden until `editingSchedule != null` — prevents flash of incorrect intermediate percentage.
- `WorkScheduleModel.defaultFor()` is used server-side when no schedule doc exists; client-side, the rate bar stays hidden until the schedule is confirmed.

---

## 2026-05-17 — Claude Sonnet 4.6 — Task UX pass (T1–T4) + Dashboard restructuring on feat/attendance-stabilization

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/attendance-stabilization`
- **Goal**: Complete the four-part task UX improvement pass (T1–T4) and restructure both dashboard screens to surface attendance and overdue data without extra navigation.
- **Outcome**: All four task improvements shipped; both home screens restructured. No new Cloud Function changes. `flutter analyze` clean on all touched files.

### T1 — Data layer
- `task_model.dart`: `hasDueTime: bool` wired into `fromMap` / `toMap` / `copyWith` (field + `dueDateEndOfDay` static helper were already present from previous session).
- `FirebasePaths.completedAt` constant added to `firebase_paths.dart`.
- `tasks_repository.dart`: three new methods — `getCompletedTasksAssignedTo`, `getCompletedTasksCreatedBy`, `getAllCompletedTasks` — each using `isEqualTo: 'completed'` + `orderBy(completedAt, descending: true)`. No Firestore index ordering conflict because status uses equality not inequality.
- `firestore.indexes.json`: 6 task indexes total (3 active-task with `createdAt DESC`, 3 completed-task with `completedAt DESC`).
- `tasks_state.dart`: `completedTasks`, `completedTasksStatus`, `completedTasksErrorMessage` + `clearCompletedTasksError` flag.
- `tasks_cubit.dart`: `fetchCompletedTasks({userId, isAdmin, silent})` — admin fetches all, employee unions assigned+created and deduplicates by ID via `Set<String>` then sorts by `completedAt DESC`. `updateTaskStatus` and `deleteTask` refresh completed list silently when `completedTasksStatus != initial`.

### T2 — Deadline-time UI
- `due_date_time_picker.dart` (new shared widget): date + optional time pick with 4 presets (09:00, 12:00, 17:00, 20:00) and a "Custom…" chip that shows the picked time. `firstDate` param gates future-only (add) vs allow-past (edit).
- `add_task_screen.dart` + `edit_task_screen.dart`: both use `DueDateTimePicker`; `hasDueTime=false` saves via `TaskModel.dueDateEndOfDay()` (UTC equivalent of 23:59:59 Jerusalem).
- `countdown_chip.dart`: `hasDueTime` param determines deadline (exact dueDate vs local 23:59:59). "Due today" label shown only for date-only tasks on the calendar due date; orange instead of red for that window.
- `tasks_screen.dart`: `_effectiveDeadline(TaskModel)` normalises midnight-stored old tasks and new end-of-day tasks to local 23:59:59 for urgency grouping. `CountdownChip` call updated.
- `task_details_screen.dart`: due date text conditionally shows time component when `hasDueTime=true`.

### T3 — Completed tab
- `tasks_screen.dart`: third tab added to both admin (length 3) and employee (length 3) tab controllers. `_buildCompletedTabContent` / `_buildCompletedTabBody` / `_buildCompletedTasksList` — lazy load on first visit, recency grouping (This Week / This Month / Older based on `completedAt`), search + priority filter reuse, sort preserves Firestore `completedAt DESC` order.
- After status change / delete / task details edit, completed list is refreshed silently via `fetchCompletedTasks(silent: true)`.
- New i18n keys: `completed_this_week`, `completed_this_month`, `completed_older`.

### T4 — Filter/Discovery UX
- `_QuickFilter` enum (`overdue`, `dueSoon`, `highPriority`) stored as `Set<_QuickFilter>` in screen state.
- `_buildQuickFiltersRow()` — always-visible chip row above search bar; chips toggle independent of the filter sheet.
- Group-collapse: urgency groups with no matching tasks under the active quick filter are hidden entirely (not dimmed).
- `_clearAllFilters()` — single reset path for search, sheet filters, and quick filters. All three clear affordances call it.
- `_applyCompletedFilters` — skips status filter, preserves Firestore ordering for `newestFirst` sort.
- `_priorityRank` helper; filter icon shows badge dot when any filter is active.
- New i18n keys: `no_time`, `custom_time`, `due_soon`.

### Phase 4 — Dashboard restructuring
- **`employee_home_screen.dart`**: `startListeningToday` called on init (guarded by `todayStatus == initial`). `_TodayAttendanceCard` renders between welcome header and stat cards — shows "Not checked in" / "Checked in: HH:mm" / "HH:mm → HH:mm · Xh Ym" depending on record state; loading placeholder (spinner in card shell) prevents layout shift; tappable → attendance screen. `_urgencySorted` method floats overdue tasks to top then sorts by nearest deadline. Task preview cap raised 3 → 5. `_TaskDueLabel` widget on each task card: red + warning icon for overdue, orange + clock icon for due-today, subtle grey otherwise.
- **`admin_dashboard_screen.dart`**: `_AttendanceSummaryCard` replaces single `_DashboardStatCard` — headline shows present+late combined count, `_AttendanceChip` badges for late and absent (only rendered when non-zero), chevron + tappable → `RouteNames.adminAttendance`. `_OverdueAlertCard` uses `errorContainer`/`onErrorContainer` Material 3 color roles, renders between filter chips and stat row when `overdueOpenTasks > 0`, taps → `RouteNames.tasks`.
- `RouteNames` import added to `admin_dashboard_screen.dart`.
- `task_model.dart` import added to `employee_home_screen.dart` (needed for explicit `List<TaskModel>` return type on `_urgencySorted`).

**Quality gates**: `flutter analyze` clean on all modified files. No Cloud Function changes. Firestore indexes pending deployment.

## 2026-05-17 — Claude Sonnet 4.6 — Employee work schedules (schedule-aware attendance) on fix/release-hardening

- **Agent**: Claude Sonnet 4.6
- **Branch**: `fix/release-hardening`
- **Goal**: Implement per-employee weekly work schedules so that attendance status (present / late / absent / off_day / off_day_work) is driven by each employee's personal schedule rather than a blanket assumption that all employees work every day at the same hours.
- **Outcome**: Full feature shipped and deployed — Firestore rules, Cloud Functions, and Flutter client all updated.
- **Architecture**: `schedules/{userId}` Firestore collection. Each doc holds a `days` map with string keys "1"–"7" (Mon=1 … Sun=7 matching Dart `DateTime.weekday`), each day having `isWorkingDay`, `expectedStartTime` ("HH:mm"), `expectedEndTime` ("HH:mm"), optional `graceMinutes` override. Top-level `defaultGraceMinutes` (default 15). Employees with no schedule doc are treated as working every day with no lateness check (graceful default preserving existing behaviour).
- **New statuses**: `late` (on-time check-in missed grace window), `off_day` (auto-created by cron on non-working days with no sessions), `off_day_work` (employee checked in on a scheduled day off).
- **Cloud Functions changes**: (1) `recordAttendance` — reads `schedules/{userId}` before the transaction; `checkInStatusForSchedule` helper resolves present/late/off_day_work based on schedule and Jerusalem wall-clock time; all set/update paths use the computed status. (2) `sendDailyAbsenceMarker` — reads `schedules/{userId}` per employee; writes `status: "off_day"` instead of `"absent"` for non-working days.
- **New helpers in index.js**: `jerusalemHHMMMinutes(date)` (returns Jerusalem wall-clock minutes since midnight), `checkInStatusForSchedule(scheduleData, now, dayOfWeek)`.
- **Firestore rules**: added `match /schedules/{userId} { allow read: if isAdmin() || isCurrentUser(userId); allow write: if isAdmin(); }`.
- **Flutter client**: new `ScheduleDay` and `WorkScheduleModel` models; `ScheduleRepository` (fetchSchedule, fetchAllSchedules, saveSchedule — all `Source.server`); `AttendanceState` extended with schedule fields (`mySchedule`, `editingSchedule`, `scheduleStatus`, `editingScheduleStatus`, `scheduleSaveStatus`, etc.); `AttendanceCubit` extended with `loadMySchedule`, `loadEmployeeSchedule`, `saveSchedule`, `clearScheduleSaveFeedback`; `ScheduleRepository` wired in `main.dart`. Employees screen gets a schedule `IconButton` per tile opening `_ScheduleEditSheet` (DraggableScrollableSheet with 7-day toggle, time pickers, grace period dropdown). Attendance screen loads own schedule on init and shows off-day confirmation dialog before biometric. `AttendanceRecordCard._StatusChip` handles `late`, `off_day`, `off_day_work` with distinct color tokens. Monthly attendance summary adds `daysLate`, `daysOff`, `daysOffWork` chips (shown only when non-zero). Translation parity: 19 new keys added to en.json and ar.json.
- **FirebasePaths**: added `schedules` constant.
- **Quality gates**: `flutter analyze` clean. `npm run lint` clean (one `operator-linebreak` auto-fixed). Deployed: `firestore:rules` then `functions` — all 13 functions updated cleanly.

## 2026-05-17 — Claude Sonnet 4.6 — Release-hardening cycle (Phases 1–3) on fix/release-hardening

- **Agent**: Claude Sonnet 4.6
- **Branch**: `fix/release-hardening`
- **Goal**: Full pre-release hardening pass before the 1.2.0+4 binary store submission, covering: Firestore read discipline, security architecture, Cloud Functions quality, and version/changelog hygiene.
- **Outcome**: Three phases shipped and committed. Phase 4 (Shorebird asset-patching verification) is a manual device test pending the owner.
- **Phase 1** — `GetOptions(source: Source.server)` applied to every Firestore `.get()` across all repositories (tasks, dashboard, attendance, employees, reports, notifications, app update config, user role at auth); all Firestore collection path string literals replaced with `FirebasePaths.*` constants (5 new constants added: `taskLogs`, `notifications`, `attendance`, `attendanceLogs`, `fcmTokens`); `PROJECT_CONTEXT.md` fully rewritten to v1.2.0 state (14 Cloud Functions documented, all collections documented, Shorebird eligibility table).
- **Phase 2** — FCM token storage moved from `users/{uid}.fcmToken` to `fcm_tokens/{uid}.token` collection (`allow read: if false`). `getFcmToken` / `getFcmTokensBatch` helper functions added to Cloud Functions. All 6 FCM-reading paths in `functions/index.js` updated to use admin SDK via the new helpers. `deleteUserAccount` cleans up `fcm_tokens/{uid}`. `createEmployeeUser` now rejects any `role` value outside `admin | employee`. `generateRecurringTaskInstances` surfaces template errors to all admins via in-app notification instead of only Cloud Functions logs. Blanket `/* eslint-disable */` suppressor removed; `require-jsdoc: off` and `max-len: 120` added to `.eslintrc.js`; `eslint --fix` auto-corrected all formatting violations; two `no-inner-declarations` errors (helpers inside `try` block) fixed manually. Deployed in order: `firestore:rules` then `functions` — all 13 functions updated cleanly. Global `firebase-tools` install was corrupted (missing `lib/templates/`); resolved by installing `firebase-tools@13.35.1` locally and patching its `universal-analytics/uuid` ESM/CJS conflict with a Node-native `crypto.randomUUID()` shim.
- **Phase 3** — `pubspec.yaml` bumped from `1.1.0+3` to `1.2.0+4`. `CHANGELOG.md`: v1.1.0 entry written (counters, countdown, account settings, auth/FCM fixes, theme persistence); v1.2.0 entry written (attendance system, FCM isolation, Source.server audit, ESLint enforcement, role validation, template error alerting); comparison links corrected for all versions.
- **Commits**: `7713d51` (Phase 1), `59d36c6` (Phase 2), `7ba5411` (Phase 3).
- **Quality gates**: `flutter analyze` clean (No issues found). `npm run lint` clean (real enforcement via predeploy pipeline). `firebase deploy` succeeded for both `firestore:rules` and `functions`.
- **Phase 4 pending**: Shorebird translation-asset patching — manual device test required by owner. Result determines whether translation-only patches are eligible for Shorebird or require a full binary.

## 2026-05-16 — Claude Sonnet 4.6 — PR #38 merge + final release-prep (attendance complete)

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/attendance-stabilization` → merged to `main` (PR #38, squash commit `cfd5879`)
- **Goal**: Ship the final commit covering two post-deploy runtime fixes (correctedByName readable display, RTL time-range arrow), update workflow docs, and merge PR #38 to main.
- **Outcome**: Committed 18 files (the full stabilization + runtime-fix changeset), pushed, opened PR #38, and squash-merged to `main`. BACKLOG #14 closed as Done 2026-05-16. `main` is now at `cfd5879`. Firebase functions were deployed by owner before merge. Attendance subsystem is production-ready for the next binary store release. Key architectural decisions that were locked in this cycle: sessions-based attendance (not single-session), session-level correction with `originalSessions` audit trail, `correctedByName` server-written for provenance, `Source.server` on history fetches, session ordering at parse time, `hide TextDirection` to resolve `intl`/`dart:ui` class shadow.
- **Files touched**: All 18 files from the stabilization pass (see previous session entry) plus `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/CURRENT_TASK.md`.
- **Quality gates**: `flutter analyze` clean (No issues found). `firebase deploy --only functions` completed by owner.
- **Release note**: `local_auth` is a native plugin — attendance requires a binary store release, not a Shorebird patch. No further Firebase deploy steps outstanding.

## 2026-05-16 — Claude Sonnet 4.6 — Attendance UX/architecture refinement pass (post-stabilization)

- **Agent**: Claude Sonnet 4.6
- **Branch**: `feat/attendance-stabilization`
- **Goal**: Address 6 structural UX/architecture findings surfaced during runtime validation after the stabilization deploy. Treat all findings as architectural decisions, not cosmetic polish.
- **Outcome**: All 6 findings resolved plus 3 additional improvements found during code review. (F1) `fetchHistory` now forces server-side reads via `GetOptions(source: Source.server)` to prevent stale Firestore cache from showing outdated history after check-in/out. (F2+C) Admin correction semantics are now fully session-level: `adminCorrectAttendance` Cloud Function accepts a `sessions` array (sorted, durations computed, `originalSessions` preserved on first correction for audit trail); `_CorrectionSheet` redesigned to show per-session editing with add/remove session affordances; `adminCorrect` cubit + repository signatures updated. (F3) Notes and correction are now visually separated: `Icons.edit_outlined` for `isCorrected`, `Icons.note_outlined` for `notes != null`. (F4) Admin roster `_RosterRow` now shows duration, session count, and both indicators — matching employee card richness. (F5/F6) Both `AttendanceRecordCard` and `_RosterRow` are now expandable `StatefulWidget`s with `AnimatedSize`: summary zone (status chip, indicators, first-in → last-out, formatted duration, session count) always visible; detail zone (per-session rows, notes, correction provenance) shown on tap. Admin correction is now accessed via a "Correct" `TextButton` inside the expanded `_RosterRow`. (A) Duration display is now formatted as "Xh Ym" via a shared `_formatDuration` helper in each file. (B) Admin roster empty state now uses `no_attendance_records_yet` with a time-of-day hint about absence markers. Session ordering is guaranteed at parse time via sort on `checkInAt` in `AttendanceModel.fromMap`, and at write time in the Cloud Function. Translation parity: 291/291.
- **Files touched**: `functions/index.js`, `lib/features/attendance/data/models/attendance_session.dart`, `lib/features/attendance/data/models/attendance_model.dart`, `lib/features/attendance/data/repositories/attendance_repository.dart`, `lib/features/attendance/presentation/cubit/attendance_cubit.dart`, `lib/features/attendance/presentation/widgets/attendance_record_card.dart`, `lib/features/admin/presentation/screens/admin_attendance_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`.
- **Quality gates**: `flutter analyze` clean (No issues found). `functions/index.js` hint is CommonJS module info only — not an error.
- **Deploy required**: `firebase deploy --only functions` for the updated `adminCorrectAttendance` callable.
- **Follow-ups**: Merge `feat/attendance-stabilization` to `dev`; deploy functions; runtime validate correction flow end-to-end (single session, multi-session, absent→present, note-only correction).

## 2026-05-16 — GitHub Copilot (GPT-5.4-mini) — Attendance architecture stabilization pass

- **Agent**: GitHub Copilot (GPT-5.4-mini)
- **Branch**: `feat/attendance-stabilization`
- **Goal**: Implement the attendance stabilization pass from the locked handoff: sessions-based attendance documents, monthly reporting, corrected attendance semantics, index wiring, and workflow doc updates.
- **Outcome**: Stabilized the attendance architecture end-to-end. Added `firestore.indexes.json` wiring to `firebase.json` and the new `(userId ASC, date ASC)` composite. Rewrote `functions/index.js` attendance flows for sessions arrays (`recordAttendance` check-in/out appends/closes sessions and recomputes `totalDurationMinutes`), corrected admin semantics (`isCorrected`, `correctedBy`, `correctedAt`, sessions replacement, no caller-set `status`), and updated daily absence docs to the new structure. Added `AttendanceSession`, upgraded `AttendanceModel` with computed session getters and backward compatibility for manual docs, extended repository/state/cubit for monthly attendance queries, and updated attendance UI to use `hasOpenSession`, show correction indicators, surface history errors, and add the new employee monthly attendance screen. Refactored Reports to show monthly attendance instead of daily roster, wired the new route/drawer entry, and added the remaining translation keys to reach parity `286 286 []`. Quality gates passed: `cd functions && npm run lint`, `flutter analyze`, `flutter test`, and translation parity. `Podfile.lock` was kept in the PR as expected for the native iOS plugin lockfile.
- **Files touched**: `firebase.json`, `firestore.indexes.json`, `functions/index.js`, `lib/features/attendance/data/models/attendance_session.dart`, `lib/features/attendance/data/models/attendance_model.dart`, `lib/features/attendance/data/repositories/attendance_repository.dart`, `lib/features/attendance/presentation/cubit/attendance_state.dart`, `lib/features/attendance/presentation/cubit/attendance_cubit.dart`, `lib/features/attendance/presentation/widgets/attendance_check_button.dart`, `lib/features/attendance/presentation/widgets/attendance_record_card.dart`, `lib/features/attendance/presentation/screens/attendance_screen.dart`, `lib/features/attendance/presentation/screens/employee_monthly_attendance_screen.dart`, `lib/features/admin/presentation/screens/admin_attendance_screen.dart`, `lib/features/reports/presentation/screens/reports_screen.dart`, `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `lib/shared/widgets/app_drawer.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/SESSION_LOG.md`, `ios/Podfile.lock`.
- **Follow-ups**: Merge the PR, then deploy Firebase indexes/functions/rules as directed by the task handoff. P4 polish remains the only open phase in BACKLOG #14.

## 2026-05-15 — GitHub Copilot (Claude Sonnet 4.6) — Implement BACKLOG #14 Phase 3 admin attendance management

- **Agent**: GitHub Copilot (Claude Sonnet 4.6)
- **Branch**: `feat/attendance-p3-admin`
- **Goal**: Implement admin attendance management (roster view, date picker, correction bottom sheet, Reports attendance section, dashboard summary card, routing and drawer wiring) per locked `CURRENT_TASK.md` Phase 3 scope. Pure Dart — no native config, no pubspec changes, no Cloud Function changes.
- **Outcome**: Extended `AttendanceModel` with `userName`, `biometricVerified`, `notes`, `correctedBy` (fromMap only). Extended `AttendanceRepository` with `fetchRosterForDate` (Firestore query) and `adminCorrect` (callable). Extended `AttendanceState` with `rosterStatus`, `roster`, `rosterError`, `correctionStatus`, `correctionError`, `selectedDate` + matching `copyWith` flags. Extended `AttendanceCubit` with `loadRoster`, `adminCorrect`, `clearCorrectionFeedback`. Created `AdminAttendanceScreen` with Jerusalem-date default, 90-day date picker, roster list with status chips, and correction bottom sheet (check-in/out time pickers, status dropdown, notes field, callable-backed Save). Added read-only Attendance section (date picker + roster list) to `ReportsScreen`. Added today's attendance `_DashboardStatCard` (present count) to `AdminDashboardScreen` with roster load in `initState`. Added `RouteNames.adminAttendance`, router case, and admin drawer entry for "Attendance Management".
- **Files touched**: `lib/features/attendance/data/models/attendance_model.dart`, `lib/features/attendance/data/repositories/attendance_repository.dart`, `lib/features/attendance/presentation/cubit/attendance_state.dart`, `lib/features/attendance/presentation/cubit/attendance_cubit.dart`, `lib/features/admin/presentation/screens/admin_attendance_screen.dart` (new), `lib/features/reports/presentation/screens/reports_screen.dart`, `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`, `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `lib/shared/widgets/app_drawer.dart`, workflow docs.
- **Quality gates**: `flutter analyze` clean (No issues found), `flutter test` green (6/6), `npm run lint` clean, translation parity `273 273 []`.
- **Follow-ups**: Open PR to `dev` titled `feat(attendance): P3 admin management — roster, corrections, reports tab, dashboard card`. Patch-eligible via Shorebird (pure Dart).

## 2026-05-15 — GitHub Copilot (GPT-5.3-Codex) — Implement BACKLOG #14 Phase 2 employee attendance flow

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feat/attendance-p2-employee`
- **Goal**: Implement attendance employee flow only (biometric gate, check-in/check-out, history screen, routing and drawer wiring) per locked `CURRENT_TASK.md` Phase 2 scope.
- **Outcome**: Added the full Phase 2 attendance feature slice under `lib/features/attendance/` (`AttendanceModel`, `AttendanceRepository`, `AttendanceCubit` + `AttendanceState`, `AttendanceScreen`, `AttendanceCheckButton`, `AttendanceRecordCard`). Wired `AttendanceRepository` + `AttendanceCubit` into the existing global provider setup in `main.dart`. Added route constant and router mapping for `RouteNames.attendance` and added employee drawer navigation entry (`my_attendance`). Implemented biometric-gated check-in/check-out using `local_auth` with offline blocking via `connectivity_plus` and translated snackbar feedback. Added native requirements for biometrics: `local_auth ^3.0.1`, Android `USE_BIOMETRIC`, iOS `NSFaceIDUsageDescription`, and Android minSdk guard `maxOf(flutter.minSdkVersion, 23)`. Kept scope strictly Phase 2 (no Cloud Functions/rules/indexes/translation additions).
- **Files touched**: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `lib/main.dart`, `lib/core/routes/route_names.dart`, `lib/core/routes/app_router.dart`, `lib/shared/widgets/app_drawer.dart`, `lib/features/attendance/data/models/attendance_model.dart`, `lib/features/attendance/data/repositories/attendance_repository.dart`, `lib/features/attendance/presentation/cubit/attendance_cubit.dart`, `lib/features/attendance/presentation/cubit/attendance_state.dart`, `lib/features/attendance/presentation/screens/attendance_screen.dart`, `lib/features/attendance/presentation/widgets/attendance_check_button.dart`, `lib/features/attendance/presentation/widgets/attendance_record_card.dart`, workflow docs.
- **Follow-ups**: Open PR to `dev` titled `feat(attendance): P2 employee flow — biometric check-in/check-out + history screen`.

## 2026-05-15 — GitHub Copilot (GPT-5.3-Codex) — Implement BACKLOG #14 Phase 1 backend foundation

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feat/attendance-p1-backend`
- **Goal**: Implement attendance backend foundation only (Cloud Functions + rules + indexes + i18n) per locked `CURRENT_TASK.md` Phase 1 scope.
- **Outcome**: Added three new Cloud Function exports in `functions/index.js` without modifying existing task-related functions: `recordAttendance` (employee check-in/check-out with unauthenticated guard, Jerusalem-day doc id via existing `ymdInJerusalem`, same-day guardrails, duration computation on check-out, and transactional write of attendance + attendance_logs), `adminCorrectAttendance` (server-side admin verification, correction metadata fields, create-if-missing behavior, duration recomputation, and transactional attendance_logs write), and `sendDailyAbsenceMarker` (`onSchedule` at `0 23 * * *` Asia/Jerusalem, marks active employees absent when missing/no check-in). Added Firestore security blocks for `attendance` and `attendance_logs` with server-only writes. Added `firestore.indexes.json` with both required attendance composites (`date ASC + status ASC`, `userId ASC + date DESC`). Added the 26 new attendance translation keys in EN/AR, preserving parity at `272 272 []`.
- **Files touched**: `functions/index.js`, `firestore.rules`, `firestore.indexes.json`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Open PR to `dev` titled `feat(attendance): P1 backend foundation — callables, rules, indexes, i18n`. After merge, run `firebase deploy --only functions,firestore` (not Shorebird patch-eligible).

## 2026-05-15 — Claude Code (Sonnet 4.6) — Attendance architecture planning round + phased implementation plan (BACKLOG #14)

- **Agent**: Claude Code (Sonnet 4.6) — lead / architect (read-only planning, no implementation).
- **Branch**: N/A (planning only; workflow docs only).
- **Goal**: Complete the architecture-first planning round for BACKLOG #14 (attendance system) and lock a phased implementation strategy before any code is written.
- **Outcome**: Full architecture locked across all dimensions — trust model (biometric gate + server timestamps; WiFi/geofencing explicitly rejected), write path (Cloud Function callables only; `allow write: if false` on `attendance`), data model (flat `attendance/{userId}_{YYYY-MM-DD}`; Jerusalem date server-computed; v1 statuses `present|absent|manual`; `late` deferred to schedule-aware v2), absence cron (`sendDailyAbsenceMarker` at 23:00 Asia/Jerusalem), biometric policy (`biometricOnly: false` — OS PIN/pattern fallback), online-only gate, reporting placement (Reports screen tab + employee drawer self-view). Feature split into 4 phased PRs: P1 backend-only (Cloud Functions + rules + indexes + 26 translation keys, parity target 272/272); P2 employee flow (local_auth native integration — full binary release boundary); P3 admin management (pure Dart, patch-eligible); P4 polish (defined from real-device testing). Key reuse note: `sendDailyAbsenceMarker` and `recordAttendance` must both use existing `ymdInJerusalem` helper for consistent Jerusalem-date semantics across doc IDs, absence cron, and reporting queries.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md` (full locked spec + phased plan), `docs/ai-workflow/BACKLOG.md` (#14 status updated to "In progress"), `docs/ai-workflow/DECISIONS_LOG.md` (attendance architecture entry + BACKLOG #13 UI/UX entry), `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Hand `CURRENT_TASK.md` Phase 1 scope to implementing agent with instruction to branch `feat/attendance-p1-backend` from `dev` and reuse `ymdInJerusalem`. No scope widening beyond P1 checklist.

## 2026-05-15 — GitHub Copilot (GPT-5.3-Codex) — Implement UI/UX improvements across reports, tasks, details, and dashboards

- **Agent**: GitHub Copilot (GPT-5.3-Codex)
- **Branch**: `feat/ui-ux-improvements`
- **Goal**: Implement BACKLOG #13 with a strictly scoped UI polish pass across five presentation files (no backend/translation/model changes).
- **Outcome**: Completed all locked changes in the five scoped files. `reports_screen.dart`: removed the two debug callable buttons and the `cloud_functions` import, switched month display to `DateFormat.yMMMM(context.locale.languageCode)`, switched due-date chips to `DateFormat.yMMMd(context.locale.languageCode)`, and simplified both responsive LayoutBuilders to a single `isWide >= 500` branch. `employee_home_screen.dart`: added `RouteNames` import, made each preview card tappable to task details via `InkWell`, clamped description text to 2 lines with ellipsis, and added a conditional `all_tasks` TextButton to open the tasks screen when more than 3 tasks exist. `tasks_screen.dart`: clamped card descriptions and hid assignee status/counter controls for completed tasks by extending the existing guard with `task.status != 'completed'`. `task_details_screen.dart`: switched due-date/timestamp formats to the locked readable patterns, localized status values in log descriptions with `.tr()`, and added action-specific log icons via `_logActionIcon`. `admin_dashboard_screen.dart`: removed dead medium-breakpoint branches and unified three LayoutBuilder thresholds to `>= 500`, updated recent-activity timestamps to `dd MMM yyyy • HH:mm`, and added optional `accentColor` support to `_DashboardStatCard` with error highlighting on open overdue cards when count > 0.
- **Files touched**: `lib/features/reports/presentation/screens/reports_screen.dart`, `lib/features/employee/presentation/screens/employee_home_screen.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/tasks/presentation/screens/task_details_screen.dart`, `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Open PR with title `feat(ui): UI/UX usability improvements — task workflow, date formats, log polish`.

## 2026-05-14 — GitHub Copilot (GPT-5.4) — Implement progressive 72h + 24h deadline reminders

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feat/progressive-reminders`
- **Goal**: Implement BACKLOG #12 by adding progressive pre-deadline reminders (72h + 24h), fixing timezone bugs, and keeping scope limited to Cloud Functions + translations.
- **Outcome**: Rewrote `sendTaskDeadlineReminders` using Jerusalem-wall-clock day windows (`ymdInJerusalem` + `jerusalemMidnightAsUTC`) and parallel `Promise.all` queries for 72h and 24h thresholds. Added per-threshold dedup checks/updates (`reminderSent72hAt`, `reminderSent24hAt`) with same-day Jerusalem logic, per-task try/catch isolation, and assignee-only FCM + in-app reminders. Fixed overdue same-day checks in `sendOverdueTaskEscalations` to use `sameDayJerusalem(...)` for both reminder and escalation timestamps. Added new i18n key `task_deadline_72h_body` in functions table and EN/AR translation files. Quality gates all green: `cd functions && npm run lint`, translation parity `246 246 []`, `flutter analyze`, `flutter test`.
- **Files touched**: `functions/index.js`, `assets/translations/en.json`, `assets/translations/ar.json`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Merge PR, then run `firebase deploy --only functions` (required post-merge; not Shorebird patch-eligible).

## 2026-05-14 — Claude Code (Sonnet 4.6) — Shorebird feasibility audit (BACKLOG #10)

- **Agent**: Claude Code (Sonnet 4.6) — lead / architect (read-only audit, no implementation).
- **Branch**: N/A (audit only; no code changes).
- **Goal**: Determine whether Shorebird code push is viable for this project and, if so, under what constraints.
- **Outcome**: Decision: **conditional adoption**. Shorebird adopted as supplemental Dart-only patch channel on the free tier. Store releases remain the primary release path. Key findings: free tier = 5,000 patch installs/month (sufficient for testing-phase group); FCM ANR issue (Shorebird #695) confirmed fixed; Crashlytics works via custom patch-number key; iOS App Store compliant (guideline 3.3.1b); iOS obfuscation requires Flutter 3.41.2+ (current 3.35.7 — acceptable for testing phase); private repo CI excluded from free tier (manual CLI workflow); longevity risk acknowledged. Two systems confirmed complementary: mandatory update gate = binary required; Shorebird = Dart-only silent fix. Patch-eligibility checklist and Shorebird release flows written into `docs/release-checklist.md`. Decision and constraints recorded in `DECISIONS_LOG.md`. BACKLOG #10 marked Done.
- **Files touched**: `docs/ai-workflow/DECISIONS_LOG.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/NEXT_STEPS.md`, `docs/release-checklist.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Stabilization triage pass (BACKLOG #11) — first formal triage of v1.1.0 tester feedback. Then progressive reminders + UI/UX (BACKLOG #12–#13). Shorebird adoption itself requires a new store binary (initial setup PR) before first patch can be shipped.

## 2026-05-14 — Claude Code (Sonnet 4.6) — Merge PR #31 feat/mandatory-app-update

- **Agent**: Claude Code (Sonnet 4.6).
- **Branch**: `dev` (squash-merge of `feat/mandatory-app-update`).
- **Goal**: Squash-merge PR #31 after runtime validation, update workflow docs, clean up branch.
- **Outcome**: Squash-merged at `b15e86a`. Remote branch deleted. BACKLOG #9 marked Done. CURRENT_TASK reset. `dev` pushed to remote.
- **Files touched**: `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Owner decides: Shorebird feasibility audit (BACKLOG #10) or stabilization/reminder/UI cycle (BACKLOG #11–#13) next.

## 2026-05-14 — Claude Code (Sonnet 4.6) — Plan feat/mandatory-app-update (BACKLOG #9)

- **Agent**: Claude Code (Sonnet 4.6) — lead / architect (planning only, no implementation code).
- **Branch**: `feat/mandatory-app-update` (created from `dev` post-v1.1.0 sync, 2026-05-14).
- **Goal**: Lock architecture-first spec for the mandatory app-update gate — production safety valve that blocks users on outdated builds via Firestore-driven version config.
- **Outcome**: Ran code audit (splash flow, existing `package_info_plus` / `url_launcher` usage, Firestore rules, `FirebasePaths` pattern). Locked 12 planning decisions: no new packages; Firestore `config/app_settings` doc with `minimumAndroidVersion` / `minimumIosVersion` / `androidStoreUrl` / `iosStoreUrl`; fail-open on any infrastructure error; check in `SplashScreen` before `checkAuthStatus()`; no Cubit (plain `AppUpdateService` singleton); `UpdateRequiredScreen` non-dismissible (`PopScope(canPop: false)`); `launchUrl` failure leaves screen blocked, retry only, no bypass; public read rule for `config/`; semver tuple comparison; 3 translation keys → 245/245 parity; `config/app_settings` manual creation documented in release checklist; soft-update out of scope. Wrote complete `CURRENT_TASK.md` spec (16 sections): service pseudocode, Firestore doc shape, splash delta pseudocode, screen pseudocode, routing, rules delta, constants, translations, affected files table, quality gates, 11 smoke tests, DoD checklist, risks, out-of-scope list, workflow doc update table.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over on `feat/mandatory-app-update` from `CURRENT_TASK.md`. After merge: admin creates `config/app_settings` doc in Firestore console, runs `firebase deploy --only firestore:rules`, updates `docs/release-checklist.md`. Next planning round: BACKLOG #10 Shorebird feasibility audit.

## 2026-05-14 — Claude Code (Sonnet 4.6) — v1.1.0 release cut + next cycle roadmap planning

- **Agent**: Claude Code (Sonnet 4.6) — lead / architect.
- **Branch**: `main` (release cut); `dev` (roadmap planning).
- **Goal**: Complete v1.1.0 release publication and lock the next development cycle roadmap.
- **Outcome**: v1.1.0 fully published — `main` pushed to remote (`24713a8`), tag `v1.1.0` pushed, GitHub Release object created, Android Closed Testing and iOS TestFlight builds deployed and runtime-validated on both platforms. Remote `feat/connectivity-and-refresh` branch deleted. Next cycle roadmap locked: v1.1.1 / v1.2.0 split collapsed into a unified v1.2 cycle. Sequence locked: mandatory update system first (BACKLOG #9), Shorebird feasibility audit second (BACKLOG #10), stabilization triage ongoing (BACKLOG #11), progressive reminders + UI/UX in parallel (BACKLOG #12–#13), attendance architecture planning last (BACKLOG #14). Key architectural decisions recorded: Firestore `config/app_settings` doc over Firebase Remote Config for version gating; mandatory update as production safety valve before further native integrations. Production gaps captured in NEXT_STEPS: recurring task failure visibility, firebase deploy discipline in release checklist, offline write queue UX expectations, CHANGELOG parity.
- **Files touched**: `docs/ai-workflow/BACKLOG.md` (items #9–#14 added under v1.2 group), `docs/ai-workflow/NEXT_STEPS.md` (populated with 5 engineering/architecture ideas), `docs/ai-workflow/DECISIONS_LOG.md` (2 new entries: roadmap consolidation + Firestore config decision), `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Move directly into mandatory update system planning round (architecture-first spec for BACKLOG #9). Branch: `feat/mandatory-app-update` from `dev`.

## 2026-05-14 — GitHub Copilot (GPT-5.4) — Implement connectivity banner and pull-to-refresh

- **Agent**: GitHub Copilot (GPT-5.4)
- **Branch**: `feat/connectivity-and-refresh`
- **Goal**: Implement the locked v1.1.0 stabilization spec: offline connectivity banner plus pull-to-refresh on the four highest-traffic screens without loading flashes.
- **Outcome**: Added `connectivity_plus` and `ConnectivityService`, wired an app-wide `MaterialApp.builder` red offline banner overlay, added silent refresh parameters to `TasksCubit`, `DashboardCubit`, and `EmployeesCubit`, and shipped pull-to-refresh on `TasksScreen`, `EmployeeHomeScreen`, `AdminDashboardScreen`, and `EmployeesScreen` with proper initial-load guards and scrollable empty/error states. Quality gates passed: `flutter analyze` clean, `flutter test` 6/6 passed, `cd functions && npm run lint` clean, translation parity `242 242 []`.
- **Files touched**: `pubspec.yaml`, `pubspec.lock`, `lib/core/services/connectivity_service.dart`, `lib/app/app.dart`, `lib/features/tasks/presentation/cubit/tasks_cubit.dart`, `lib/features/dashboard/presentation/cubit/dashboard_cubit.dart`, `lib/features/employees/presentation/cubit/employees_cubit.dart`, `lib/features/tasks/presentation/screens/tasks_screen.dart`, `lib/features/employee/presentation/screens/employee_home_screen.dart`, `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`, `lib/features/employees/presentation/screens/employees_screen.dart`, `assets/translations/en.json`, `assets/translations/ar.json`, workflow docs.
- **Follow-ups**: Push branch when GitHub connectivity is available, open PR with the locked title, then cut the v1.1.0 testing release after merge.

## 2026-05-14 — Claude Code (Sonnet 4.6) — Plan feat/connectivity-and-refresh (offline guard + pull-to-refresh)

- **Agent**: Claude Code (Sonnet 4.6) — acting as lead / architect (planning only, no implementation code).
- **Branch**: `feat/connectivity-and-refresh` (created from `dev` after PR #29 squash-merge).
- **Goal**: Lock scope, architecture, and implementation spec for v1.1.0 stabilization items: offline connectivity banner and pull-to-refresh on the four highest-traffic screens.
- **Outcome**: Ran a read-only audit covering connectivity libraries, overlay mechanisms, cubit silent-refresh pattern, `RefreshIndicator` constraints, and backward-compat risks. Surfaced the load-bearing constraint: `RefreshIndicator` cannot wrap `TabBarView` (horizontal swipe consumed by tab controller) — each tab content must have its own indicator. Locked 10 planning decisions: `connectivity_plus ^6.x` (emits `List<ConnectivityResult>` in v6 — not v5's scalar); `MaterialApp.builder` Stack overlay over route-push (avoids FCM deep-link and form state interference); `initialData: true` for optimistic start; no auto-refresh on reconnect; `{bool silent = false}` on cubit fetches with "skip loading emit, always run fetch, always emit error"; `ListView`-wrap all non-scrollable states inside `RefreshIndicator`; per-tab `RefreshIndicator` in `TasksScreen`; initial-load spinner guard (`tasks.isEmpty && status == loading`); 4 screens in scope (Tasks, EmployeeHome, AdminDashboard, Employees); 1 translation key (`no_internet_connection`) → 242/242 parity. Wrote complete `CURRENT_TASK.md` spec (14 sections): `ConnectivityService` singleton, `app.dart` overlay with pseudocode, cubit silent-param pseudocode with exact-API warning, per-screen `RefreshIndicator` + `_loadData` helper + initial-load guard patterns, affected files table, quality gates, 12 smoke tests, DoD checklist, risks, out-of-scope rails, workflow doc update table.
- **Files touched**: `docs/ai-workflow/CURRENT_TASK.md`, `docs/ai-workflow/BACKLOG.md`, `docs/ai-workflow/SESSION_LOG.md`.
- **Follow-ups**: Implementing agent takes over on `feat/connectivity-and-refresh` from `CURRENT_TASK.md`. After PR merges: cut v1.1.0 testing release. v1.1.1 items deferred: progressive reminders + UI/UX polish. v1.2.0: attendance MVP.

## 2026-05-14 — Claude Code (Sonnet 4.6) — Multi-assignee supplement for PR #29 (F3.B)

- **Agent**: Claude Code (Sonnet 4.6) — lead audit + implementation on `feat/recurring-tasks`.
- **Branch**: `feat/recurring-tasks`
- **Goal**: Extend recurring task templates from single-assignee to multi-assignee. Each selected employee gets an independent task instance per generation cycle.
- **Outcome**: Supplement committed on the same branch before PR #29 merge. Locked decisions: `assignedToIds: List<String>` + `assignedToNames: List<String>` replace the scalar fields; deterministic instance ID becomes `${templateId}_${assigneeId}_${YYYY-MM-DD}`; `lastGeneratedAt` demoted to metadata-only (no longer the generation gate); deterministic instance existence is the sole idempotency gate; backward compat via `_parseStringList` fallback to legacy scalar fields; notifications, dashboards, reports, reminders, and Firestore rules unchanged. `flutter analyze` clean, `flutter test` 6/6, `npm run lint` clean.
- **Files touched**: `lib/features/tasks/data/models/task_template_model.dart` (fields renamed to arrays + `_parseStringList` compat helper), `lib/features/tasks/presentation/screens/add_template_screen.dart` (single dropdown → `_EmployeeMultiPicker` chip picker), `lib/features/tasks/presentation/screens/edit_template_screen.dart` (same, plus deactivated-employee name preservation via `displayMap`), `lib/features/tasks/presentation/screens/recurring_tasks_screen.dart` (subtitle: `assignedToNames.join(', ')`), `functions/index.js` (`generateRecurringTaskInstances`: outer assignee loop, per-assignee transaction, `lastGeneratedAt` after-loop metadata write, per-template error isolation).
- **Follow-ups**: PR #29 ready for merge. After merge: cut v1.1.0 release. Smoke tests #1-#15 from CURRENT_TASK.md require project owner on real device.

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
