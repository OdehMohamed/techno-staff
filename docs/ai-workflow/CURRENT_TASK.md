# Current Task

> Active: feat/chat-messaging — Milestone 5 complete. iOS foreground notification suppression validated on device (2026-06-14). Ready for PR merge.

## Chat / Messaging — Milestone 5: Cloud Functions, FCM routing, Group creation

### What was implemented

**Cloud Function `onNewChatMessage`** (`functions/index.js`):
- Firestore `onCreate` trigger on `conversations/{conversationId}/messages/{messageId}`
- Skips system messages (`type == 'system'`) — no push for join/created events
- Atomically updates `lastMessage`, `lastMessageAt`, and increments `unreadCounts.{uid}` for all non-sender participants
- Fetches FCM tokens and user language codes in parallel via `getFcmTokensBatch`
- Sends localized FCM push on `chat_messages` Android channel per recipient:
  - DM: title = sender name, body = message preview (max 80 chars)
  - Group/task thread: title = group name, body = `senderName: preview`
- Writes in-app notification per recipient via `createInAppNotification` with `conversationId`
- Added `chat_group_message_body` to the `i18n` object (EN + AR)

**NotificationService** (`lib/core/services/notification_service.dart`):
- Added `_chatChannel` (`chat_messages`, high importance)
- Registers both `_taskChannel` and `_chatChannel` in `initialize()`
- `showForegroundNotification` selects the correct channel from `message.data`, encodes payload as `conv:<id>` for chat or raw `taskId` for tasks

**main.dart FCM routing**:
- `onNotificationTap`: parses `conv:` prefix → navigates to `RouteNames.conversation`; otherwise `RouteNames.taskDetails`
- `onMessage` listener: suppresses local notification when `conversationCubit.activeConversationId` matches the incoming `conversationId`
- `onMessageOpenedApp` + `getInitialMessage`: both check `conversationId` first, then `taskId`
- `ConversationCubit` pre-created before listeners so suppression works without BuildContext

**ConversationCubit** (`lib/features/chat/presentation/cubit/conversation_cubit.dart`):
- Added `String? get activeConversationId` public getter

**Group conversation creation**:
- `ChatListCubit.createGroup(...)` — delegates to `ChatRepository.createGroup`
- `NewConversationSheet` — "Create Group" tile at top of sheet navigates to `RouteNames.newGroup`; "Direct Message" section header remains below
- `NewGroupScreen` (new) — group name field (max 50 chars, required), multi-select employee checkbox list (excluding self), "Create" button in AppBar, `members_count` indicator bar, error snackbar
- `app_router.dart` — `RouteNames.newGroup` → `NewGroupScreen` case wired

**Translation keys** (9 new × 2 locales → 349 → 358 / 358 parity):
- `create_group`, `create_group_hint`, `group_name_label`, `group_name_hint`
- `group_name_required`, `add_members`, `no_members_selected`, `create_group_error`, `create`

### Quality gates
- `flutter analyze` — clean (No issues found)
- `cd functions && npm run lint` — clean
- `flutter test test/features/` — 6/6 passed
- Translation parity — 358 EN / 358 AR

### Bugs fixed (post-Milestone-5 validation)

| # | Root cause | Fix |
|---|---|---|
| Group creation fails | `createGroup` used a Firestore batch to create conversation + system message together. The message's security rule calls `inConversation()` → `get(conversation_doc)`, but the conversation isn't in committed state during batch evaluation → permission-denied | Two sequential writes: conversation first, system message second |
| Foreground notifications suppressed even when not in conversation | `ConversationCubit` is global; after navigating away from a conversation its message stream stayed active and `_activeConversationId` stayed set. `_onMessagesReceived` kept calling `markAsRead()` and the FCM suppression fired indefinitely | Added `clearActiveConversation()` to `ConversationCubit`; `ConversationScreen.dispose()` stores cubit ref and calls it |
| Unread count stuck at 1 | Same root cause: stale stream called `markAsRead()` (→ 0) on every incoming message, then CF incremented to 1, net result always 1 | Same fix as above |
| Group navigation didn't open `NewGroupScreen` | `NewConversationSheet` called `pop()` then `pushNamed(newGroup)` on its own context — unreliable after pop | Sheet now returns `RouteNames.newGroup` as a sentinel; `ChatListScreen` handles the push after the sheet is fully dismissed |
| iOS foreground per-conversation suppression never fired (every banner shown) | **Root cause (final):** the `UNUserNotificationCenter` delegate was never our `AppDelegate`. During plugin registration `firebase_messaging`/`flutter_local_notifications` claim the delegate, so our `willPresent` override was never invoked — it was dead code, which is why every earlier logic-only fix had zero effect. A long detour chased a phantom "UserDefaults read failure" that was actually a measurement artifact: the Dart `onMessage` diagnostic read its own stale in-memory `SharedPreferences` cache (never sees values written by Swift after startup), and Swift `NSLog` does not surface in `flutter run` (only Xcode/Console.app), so the working native path looked broken. | **Final fix:** (1) `AppDelegate.didFinishLaunching` explicitly sets `UNUserNotificationCenter.current().delegate = self` so our `willPresent` is the method iOS calls; `FlutterAppDelegate`'s own delegate methods still forward to plugins via `super`, preserving firebase_messaging foreground/tap handling. (2) iOS uses Firebase **native** foreground presentation (`setForegroundNotificationPresentationOptions(alert: true)`) — the Dart local-notification path cannot be used because Firebase's `alert:false` option suppresses *all* foreground notifications it sees, including our own local one (confirmed: `_localNotifications.show()` completes but no banner). (3) `willPresent` suppresses only when the push `conversationId` equals the active conversation read from `UserDefaults` (`flutter.active_conversation_id`, written by `ConversationCubit`; unprefixed key read as a defensive fallback); otherwise calls `super` so Firebase presents the banner. (4) iOS `onMessage` is a no-op; `showForegroundNotification`/local-notification path remains Android-only. Validated on device: same-conversation → `SUPPRESSED` (no banner); other conversation → `SHOWN` (banner). |

### Owner validation checklist

1. **Group creation**: FAB → "Create Group" → enter name → select members → Create → lands in new group conversation with system message
2. **FCM push (DM)**: Send a message in a DM from Device A → Device B receives push notification on `chat_messages` channel; tapping opens that conversation
3. **FCM push (group)**: Same test in a group conversation — notification title is the group name, body includes sender name
4. **Foreground suppression**: With Device A actively viewing Conversation X, send a message in X from Device B → Device A does NOT show a local notification
5. **Foreground notification (different conversation)**: With Device A in Conversation X, send to Conversation Y — Device A DOES see the local notification; tapping navigates correctly
6. **Notification tap from terminated state**: Kill app → receive FCM → tap notification → app opens directly to the conversation
7. **In-app notification**: After receiving a chat message, the notifications bell shows a new entry with the sender/conversation info

### Post-merge owner steps (when ready to merge PR)

```bash
firebase deploy --only functions
```

This deploys `onNewChatMessage`. No Firestore rules or index changes beyond what was deployed in Milestone 1.
