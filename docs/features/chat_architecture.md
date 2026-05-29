# Chat / Messaging — Architecture & Design

> Status: **Design complete. Implementation not started.**
> Last updated: 2026-05-29
> Author: Mohamed Odeh (product decisions) + Claude Sonnet 4.6 (architecture)
> Branch for implementation: `feat/chat-messaging` (not yet created)

---

## 1. Product Context

Techno Staff is an operational work tool for a small team. The chat module serves **internal work communication** — task follow-ups, shift coordination, team announcements — not general-purpose messaging. This framing drives every scoping decision in this document.

---

## 2. Agreed Decisions (post-proposal)

These decisions were made after the original architecture proposal and take precedence where they differ from v1 scope notes in the original:

| # | Decision |
|---|----------|
| D1 | Employee-to-employee direct messaging is **enabled in v1**. |
| D2 | An **Announcements** conversation type must be supported by the architecture. Admin writes; employees read. Reply restrictions to be decided later. Does not have to be in MVP, but the data model must not require a redesign to add it. |
| D3 | Future message types (`text`, `image`, `file`, `voice`, `system`) must be modeled from day one — the schema must accommodate them without a collection rebuild. |
| D4 | Attachments are a **high-value future capability**. The Firestore message document must carry a nullable `attachment` field from v1 so adding attachments later is additive, not a migration. |
| D5 | Reactions are desirable. The message document must carry a nullable `reactions` map field. |
| D6 | Voice messages are deferred. |
| D7 | Typing indicators are deferred. |

---

## 3. Scope Summary

### MVP (Phase 1) — minimum shippable v1

- 1:1 direct messages between any two active users (admin ↔ employee, employee ↔ employee)
- Group conversations (any user can create; admin can manage members)
- Text messages
- Real-time message streaming
- Soft-delete own messages
- Conversation list with last-message preview and timestamp
- Unread count per conversation + global badge in drawer
- FCM push notification for new messages
- System messages (`"X created the group"`, `"Y was added"`)
- Message pagination (50 messages per page, load older on scroll-up)
- `chat_messages` Android notification channel
- Drawer entry with unread badge
- All translation keys (EN + AR)

### Production v1 (Phase 2) — hardening after initial usage

- Task discussion thread entry point from task details screen
- Employees screen "Message" quick-action (tapping an employee → opens or creates DM)
- Group member management (admin adds/removes)
- In-app notification entry for chat messages (extend notification model)
- Soft-delete display refinement

### Future Enhancements (Phase 3+)

- **Announcements channel** — admin-only write, all employees read; uses `writeRestriction: 'admin_only'` on the conversation document (data model already supports this)
- Reply / quote threading
- Per-message read receipts ("Read by 3")
- Mentions with notification routing
- Image attachments (Firebase Storage)
- File attachments
- Voice messages
- Reactions
- Message editing with edit history
- Message search (requires Algolia / Typesense — Firestore has no native full-text)
- Typing indicators (Firebase RTDB or ephemeral Firestore)
- Pinned messages
- Admin moderation (delete any message)

---

## 4. Conversation Types

### Type: DM (Direct Message)

- Deterministic document ID: `dm_${[uid1, uid2].sort().join('_')}` — prevents duplicate conversations.
- Any active user can start a DM with any other active user (admin ↔ employee, employee ↔ employee).
- Conversation name is derived from the other participant at render time — never stored.

### Type: Group

- Auto-generated Firestore ID.
- Any active user can create a group.
- Admin can add or remove members after creation.
- Explicit `name` stored on the conversation document.

### Type: Task Thread

- Auto-generated Firestore ID; linked via `taskId` field.
- Created on first user tap of "Open discussion" in task details — never auto-created server-side.
- Participants: task assignee + task creator; admin can join any task thread.
- AppBar shows the task title when inside the conversation.

### Type: Announcement *(deferred, architecture supported)*

- Admin-only write (`writeRestriction: 'admin_only'` on conversation doc); all active users are participants.
- Reply restriction TBD.
- Data model already supports this via the `writeRestriction` field and `type: 'announcement'` — no schema migration required when implemented.

---

## 5. Message Types

All message types are modeled in the schema from day one. Only `text` and `system` are implemented in MVP.

| Type | MVP | Notes |
|------|-----|-------|
| `text` | ✅ | Core |
| `system` | ✅ | Join/leave/created events; rendered as centered muted text; no FCM push |
| `image` | Phase 3 | Requires Firebase Storage; thumbnail stored in `attachment.thumbnailUrl` |
| `file` | Phase 3 | Requires Firebase Storage; MIME handling, size limits |
| `voice` | Phase 3 | Requires Firebase Storage + audio recording UI |

---

## 6. Firestore Data Model

### `conversations/{conversationId}`

```
type:               'dm' | 'group' | 'task' | 'announcement'
participantIds:     string[]               // all member UIDs; used for array-contains queries
participantNames:   {uid: name}            // name snapshot; avoids extra reads in list UI
name:               string | null          // null for DMs (derived from other participant)
taskId:             string | null          // task-type only; links to tasks/{taskId}
createdBy:          string                 // UID of creator
createdAt:          Timestamp
lastMessage: {
  text:             string                 // preview text (may show [deleted])
  senderId:         string
  senderName:       string
  sentAt:           Timestamp
} | null
lastMessageAt:      Timestamp | null       // top-level field for compound index
memberLastRead:     {uid: Timestamp}       // when each member last read this conversation
unreadCounts:       {uid: number}          // per-member unread count; incremented by CF
writeRestriction:   'all' | 'admin_only' | null   // null = no restriction (DM, group, task)
```

**Deterministic DM ID**: `dm_${[uid1, uid2].sort().join('_')}` — prevents duplicate DMs. Groups and task threads use Firestore auto-IDs.

### `conversations/{conversationId}/messages/{messageId}`

```
senderId:           string
senderName:         string
text:               string | null          // null for non-text types (image, voice, etc.)
type:               'text' | 'image' | 'file' | 'voice' | 'system'
sentAt:             Timestamp              // serverTimestamp() from CF (preferred) or client
deletedAt:          Timestamp | null       // soft delete
deletedBy:          string | null

// Attachment — null in MVP; populated for image/file/voice in Phase 3
attachment: {
  url:              string                 // Firebase Storage download URL
  storagePath:      string                 // Storage path for management/deletion
  mimeType:         string
  fileName:         string
  fileSizeBytes:    number
  thumbnailUrl:     string | null          // images only
  durationSeconds:  number | null          // voice only
} | null

// Reply — null in MVP; populated in Phase 3
replyTo: {
  messageId:        string
  text:             string                 // snapshot of replied-to message text
  senderName:       string
  type:             string
} | null

// Reactions — empty/null in MVP; populated in Phase 3
// Map of emoji → array of UIDs who reacted
reactions:          {string: string[]} | null

// Mentions — empty in MVP; populated in Phase 3
mentions:           string[]

// Editing — null in MVP; populated in Phase 3
editedAt:           Timestamp | null
editedText:         string | null
```

**Design rationale for attachment/replyTo/reactions/mentions**: All four fields are nullable and absent from write validation in MVP Firestore rules. Their presence in the schema means Phase 3 additions are purely additive (`allow create` rules updated to permit the new fields; no collection migration needed). The Flutter model classes use `null` defaults for unimplemented fields and ignore unknown keys via `fromMap`.

### Firestore Indexes

One new compound index required (conversations query):

```json
{
  "collectionGroup": "conversations",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "participantIds", "arrayConfig": "CONTAINS"},
    {"fieldPath": "lastMessageAt", "order": "DESCENDING"}
  ]
}
```

Messages use `orderBy('sentAt', 'descending').limit(50)` — single-field index, auto-created by Firestore.

---

## 7. Unread Count Lifecycle

**On message send** (Cloud Function `onNewChatMessage`, Firestore `onCreate` trigger):
- For each participant except sender: `unreadCounts.{uid} += 1` (`FieldValue.increment`)
- Update `lastMessage` and `lastMessageAt` on conversation document
- Send FCM to each participant except sender (skip if `type == 'system'`)

**On conversation open** (client-side, immediate):
- `unreadCounts.{currentUserId} = 0`
- `memberLastRead.{currentUserId} = serverTimestamp()`

This two-field approach is reliable: `unreadCounts` gives the badge number; `memberLastRead` timestamps for future "scroll to first unread" use.

---

## 8. Security Rules

```javascript
match /conversations/{conversationId} {
  function isParticipant() {
    return signedIn() && request.auth.uid in resource.data.participantIds;
  }
  function willBeParticipant() {
    return signedIn() && request.auth.uid in request.resource.data.participantIds;
  }
  function onlyAllowedConvFields() {
    return request.resource.data.diff(resource.data).affectedKeys().hasOnly([
      'lastMessage', 'lastMessageAt', 'unreadCounts', 'memberLastRead'
    ]);
  }
  function canWrite() {
    return isParticipant() &&
      (resource.data.writeRestriction == null ||
       resource.data.writeRestriction == 'all' ||
       (resource.data.writeRestriction == 'admin_only' && isAdmin()));
  }

  allow read: if isParticipant();

  allow create: if signedIn() && willBeParticipant() &&
    request.resource.data.participantIds.size() >= 2 &&
    request.resource.data.createdBy == request.auth.uid;

  allow update: if (isParticipant() && onlyAllowedConvFields()) ||
    (isAdmin() && isParticipant());

  allow delete: if isAdmin();

  match /messages/{messageId} {
    function inConversation() {
      return signedIn() && request.auth.uid in
        get(/databases/$(database)/documents/conversations/$(conversationId))
          .data.participantIds;
    }
    function isSender() {
      return resource.data.senderId == request.auth.uid;
    }
    function conversationAllowsWrite() {
      let conv = get(/databases/$(database)/documents/conversations/$(conversationId)).data;
      return conv.writeRestriction == null ||
             conv.writeRestriction == 'all' ||
             (conv.writeRestriction == 'admin_only' && isAdmin());
    }

    allow read: if inConversation();

    allow create: if inConversation() && conversationAllowsWrite() &&
      request.resource.data.senderId == request.auth.uid &&
      request.resource.data.keys().hasAll(['senderId', 'senderName', 'text', 'type', 'sentAt']);

    // Only soft-delete allowed; only the sender
    allow update: if isSender() &&
      request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['deletedAt', 'deletedBy']);

    allow delete: if false; // always soft-delete
  }
}
```

---

## 9. Cloud Functions (additions to `functions/index.js`)

### `onNewChatMessage` (new)

- **Trigger**: Firestore `onCreate` on `conversations/{conversationId}/messages/{messageId}`
- **Responsibilities**:
  1. Skip if `type == 'system'` (no push for join/leave events)
  2. Read conversation document to get `participantIds`, `participantNames`, `name`, `type`
  3. Increment `unreadCounts.{uid}` for each participant except sender (`FieldValue.increment(1)`)
  4. Update `lastMessage` + `lastMessageAt` on conversation document
  5. Fetch FCM tokens for all participants except sender via existing `getFcmTokensBatch`
  6. Send localized FCM push on `chat_messages` channel: title = conversation name (or sender name for DMs), body = message preview truncated to ~80 chars
  7. Optionally: write an in-app notification entry via `createInAppNotification` with `conversationId` field
- **Reuses**: `getFcmTokensBatch`, `sendFCMNotification`, `createInAppNotification` — zero new helpers needed

---

## 10. Notification Strategy

- **Android channel**: `chat_messages` — separate from `task_notifications` (additive)
- **FCM payload**: includes `conversationId` (alongside existing `taskId` pattern)
- **main.dart routing**: `onMessageOpenedApp` and `getInitialMessage` extended to check for `conversationId` payload → navigate to `RouteNames.conversation`
- **Foreground suppression**: if the user already has the target conversation open, suppress the local notification
- **Localization**: push payloads use `users/{uid}.languageCode` — same pattern as task notifications
- **In-app notification**: `notifications` collection extended with nullable `conversationId` field; `taskId` stays nullable (already is)

---

## 11. Flutter Architecture

```
lib/features/chat/
  data/
    models/
      conversation_model.dart     // fromMap, participantNames helper, isDm getter,
                                  // otherParticipantName(currentUserId) helper
      message_model.dart          // fromMap, isDeleted getter, isSystem getter,
                                  // hasAttachment getter, isTextType getter
    repositories/
      chat_repository.dart        // streamConversations, streamMessages,
                                  // sendMessage, createDm, getOrCreateDm,
                                  // createGroup, createTaskThread,
                                  // markAsRead, softDeleteMessage
  presentation/
    cubit/
      chat_list_cubit.dart        // streams conversation list + total unread count
      chat_list_state.dart
      conversation_cubit.dart     // streams messages, send/delete, pagination
      conversation_state.dart
    screens/
      chat_list_screen.dart
      conversation_screen.dart
      new_group_screen.dart       // name + member picker
    widgets/
      conversation_tile.dart      // avatar, name, preview, unread badge, timestamp
      message_bubble.dart         // own (right, colored) vs other (left, grey) vs system (centered muted)
      chat_input_bar.dart         // TextField + send button
      new_conversation_sheet.dart // bottom sheet: "Direct message" | "Create group"
```

**Two cubit pattern**:
- `ChatListCubit` — global (registered in `main.dart` `MultiBlocProvider`); streams always active for unread badge in drawer. Disposed only on sign-out.
- `ConversationCubit` — screen-scoped; provided via `BlocProvider` when entering a conversation, disposed on exit.

---

## 12. Routing Changes

| Route name constant | Screen | Arguments |
|---|---|---|
| `RouteNames.chatList` | `ChatListScreen` | none |
| `RouteNames.conversation` | `ConversationScreen` | `String conversationId` (also accepts full `ConversationModel` for in-app navigation) |
| `RouteNames.newGroup` | `NewGroupScreen` | none |

`ConversationDetailsLoaderScreen` may be needed (mirrors `TaskDetailsLoaderScreen`) for FCM taps where only `conversationId` string is available.

---

## 13. Integration Points

| Area | Change |
|---|---|
| `AppDrawer` | Add "Messages" entry with `ChatListCubit` unread badge |
| `main.dart` providers | Add `ChatListCubit` to `MultiBlocProvider` |
| `main.dart` FCM handlers | Extend `onMessageOpenedApp` / `getInitialMessage` to check `conversationId` payload |
| `NotificationService` | Add `chat_messages` Android channel in `initialize()` |
| `in_app_notification_model.dart` | Add nullable `conversationId: String?` field |
| `createInAppNotification` (CF) | Add optional `conversationId` param; write to notification doc |
| `firestore.rules` | Add `conversations` + subcollection rules (no changes to existing rules) |
| `firestore.indexes.json` | One new compound index |
| `route_names.dart` | Three new constants |
| `app_router.dart` | Three new route cases |
| Translation files | ~25 new keys (EN + AR) |
| Task details screen *(Phase 2)* | "Open discussion" button → `getOrCreateTaskThread` |
| Employees screen *(Phase 2)* | "Message" quick-action per employee row |

---

## 14. UX Flows

### Chat List Screen

```
AppBar: "Messages"                    [compose FAB]
────────────────────────────────────
Search bar (local filter by name)
────────────────────────────────────
[Avatar] Task: Fix login bug          2m ago
         Ahmed: OK I'll check         [3]

[Avatar] Engineering Team             1h ago
         You: Team meeting at 10am

[Avatar] Sara Al-Rashid               Yesterday
         [Message deleted]
────────────────────────────────────
Empty: "No conversations yet. Tap + to start."
```

- Sorted by `lastMessageAt` descending.
- FAB opens `NewConversationSheet`: two options — "Direct message" (employee picker) and "Create group" (name + member picker).
- Pull-to-refresh supported.

### Conversation Screen

```
AppBar: [back] "Engineering Team"    [3 members]
────────────────────────────────────────────────
Ahmed Al-Mansouri  10:04
┌────────────────────────┐
│ Can everyone check     │
│ the task list today?   │
└────────────────────────┘

               ┌───────────────┐ 10:06
               │ Sure, will do │ ✓
               └───────────────┘

[System: Sara was added to the group]
────────────────────────────────────────────────
[  Type a message...         ] [Send ▶]
```

- Own messages: right-aligned, themed color, no sender name.
- Others' messages: left-aligned, grey, sender name above (group conversations only).
- System messages: centered, muted italic.
- Long-press own message → "Delete" action sheet.
- Deleted messages: `[Message deleted]` in muted style (not hidden — prevents confusion about missing content).
- Scroll-to-bottom FAB when scrolled up.
- Load older messages on scroll to top (pagination, 50 at a time).

### New DM Flow

1. Tap FAB → "Direct message"
2. Single-select employee list (excluding self, excluding inactive users)
3. If DM already exists (deterministic ID check via `getOrCreateDm`) → navigate to it
4. If not → create and navigate

### New Group Flow

1. Tap FAB → "Create group"
2. Enter group name (non-empty, max 50 chars)
3. Multi-select member list
4. "Create" → navigate to new conversation
5. System message `"Group created by [name]"` auto-inserted

---

## 15. Empty States

| Location | Message |
|---|---|
| Chat list (no conversations) | "No conversations yet. Tap + to start a message." |
| Conversation (no messages) | "No messages yet. Say hello!" |
| New group (just created) | System message: "Group created by [name]" |

---

## 16. Delivery Plan

| Phase | Scope | Gate |
|---|---|---|
| **Phase 1 (MVP)** | Full feature: DMs, groups, text messages, real-time streaming, soft delete, unread tracking, FCM push, `onNewChatMessage` CF, rules + index, routing, drawer entry, all translations | Single PR, end-to-end validation before merge |
| **Phase 2 (v1 hardening)** | Task thread entry point, Employees screen quick-action, group member management, in-app notification for chat, pagination refinement | After initial usage feedback |
| **Phase 3+** | Announcements, reply/quote, reactions, attachments, per-message receipts, mentions, message search, typing indicators | Based on tester feedback and roadmap priority |

**Phase 1 is a self-contained deliverable** — the full v1 feature including groups, notifications, and unread tracking. Ship in a single PR after end-to-end validation.

---

## 17. Architecture Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| Unread count storage | `unreadCounts: {uid: int}` on conversation doc | Per-user collection | Single write path; avoids an extra collection; sufficient at team scale |
| Conversation-level read tracking | `memberLastRead: {uid: Timestamp}` on conversation doc | Per-message `readBy` | Much cheaper; per-message receipts deferred to Phase 3 |
| DM deduplication | Deterministic `dm_${sorted_uids}` ID | Query for existing DM | Zero-read creation; no race condition |
| Unread increment authority | Cloud Function `onNewChatMessage` | Client-side increment | Atomic server-side; clients are untrusted |
| Conversation list query | `participantIds array-contains` + `orderBy lastMessageAt DESC` | Separate per-user conversation index | Standard Firestore pattern; one compound index |
| Message type extensibility | `type` enum field + nullable `attachment`/`reactions`/`replyTo` | Separate subcollections per type | Additive evolution without migration; Phase 3 additions are `null` defaults in v1 |
| Announcements write restriction | `writeRestriction: 'admin_only'` field on conversation doc | Separate collection | Reuses all existing chat infrastructure; single code path for read/display |
| `sentAt` authority | Server (CF `serverTimestamp()`) preferred; client fallback | Client only | Prevents clock skew ordering issues; CF triggers run before display |

---

## 18. What is Explicitly Out of Scope (v1 and Phase 2)

- Attachments / file sharing (Firebase Storage integration)
- Voice messages
- Message editing with history
- Message replies / threading
- Mentions
- Reactions
- Pin messages
- Message search
- Typing indicators
- Per-message read receipts
- Admin moderation (deleting other users' messages)
- Announcement-only channel (architecture supports it; implementation deferred)
- Department / team auto-channels (no department concept in data model)
