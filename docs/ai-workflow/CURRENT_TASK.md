# Current Task

## Chat Phase 2 — v1.6.0+9

**Branch**: `feat/chat-phase-2`
**Status**: Implementation complete — awaiting owner smoke test

### What was implemented (2026-06-17)

| # | Feature | Files changed |
|---|---------|---------------|
| 1 | **Employee DM quick-action** — chat icon on each employee card in EmployeesScreen; tapping opens or creates a DM and navigates to the conversation | `employees_screen.dart` |
| 2 | **Task-linked conversations** — chat bubble in TaskDetailsScreen AppBar (visible to task creator and assignee only); `getOrCreateTaskThread` `createdBy` bug fixed (`initiatorUid` replaces hardcoded `creatorUid`) | `task_details_screen.dart`, `chat_repository.dart`, `chat_list_cubit.dart` |
| 3 | **Admin broadcast channels** — "Broadcast Channel" toggle in NewGroupScreen (admin-only); sets `writeRestriction: 'admin_only'`; "Select All" member shortcut; AppBar title adapts; ConversationScreen shows read-only notice bar for non-admin participants; ConversationTile shows megaphone icon for broadcast conversations | `new_group_screen.dart`, `conversation_screen.dart`, `conversation_tile.dart`, `chat_repository.dart`, `chat_list_cubit.dart` |
| 4 | **Translation keys** — 8 new keys × EN + AR (365/365 parity) | `en.json`, `ar.json` |

Quality gates: `flutter analyze lib/` — no issues; `flutter test` — 6/6 green.

No changes to: `firestore.rules`, `functions/index.js`, `AppRouter`, `ConversationModel`, `MessageModel`. The existing `conversationAllowsWrite()` rule already enforces `writeRestriction: 'admin_only'`.

### Owner smoke test checklist

- [ ] **Employee DM quick-action**: Admin on EmployeesScreen → tap chat icon on any employee card → DM conversation opens; spinner shows while loading
- [ ] **DM navigation**: Tap chat icon on same employee card again → same conversation reopens (no duplicate created)
- [ ] **Task thread — creator initiates**: Admin/creator opens a task detail → tap chat bubble → thread opens with system message; assignee sees the conversation in their chat list
- [ ] **Task thread — assignee initiates**: Assignee opens same task detail → tap chat bubble → same thread reopens (not a new one); no Firestore permission error
- [ ] **Task thread button visibility**: A user who is neither creator nor assignee should NOT see the chat bubble on task details
- [ ] **Broadcast channel — create**: Admin → Messages → New Group → toggle "Broadcast Channel" on → name it → add members (or Select All) → Create → lands in channel conversation
- [ ] **Broadcast channel — employee view**: Employee opens the broadcast channel → sees messages, but input bar is replaced by "Only admins can post in this channel" notice
- [ ] **Broadcast channel — admin posts**: Admin sends a message in broadcast channel → employee receives FCM notification; tap opens channel; message is visible
- [ ] **Broadcast icon in chat list**: Broadcast channel shows megaphone icon instead of letter avatar in the conversations list
- [ ] **Select All**: In NewGroupScreen with broadcast toggle on → tap "Select All" → all active employees are selected at once
- [ ] **Regular group unaffected**: Create a normal group (no broadcast toggle) → input bar still appears for all members

### After owner validation

1. Bump version: `pubspec.yaml` → `1.6.0+9`
2. Add CHANGELOG entry for v1.6.0
3. Commit version bump
4. `shorebird release ios` + `shorebird release android`
5. Upload IPA (Transporter) + AAB (Play Console)
6. Firebase deploy not required (no rules/functions/index changes)
7. Merge `feat/chat-phase-2` → `main`
