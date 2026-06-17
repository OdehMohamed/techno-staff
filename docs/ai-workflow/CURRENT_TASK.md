# Current Task

## Chat Phase 2 + Release Polish — v1.6.0+9

**Branch**: `feat/chat-phase-2`
**Status**: Implementation complete — ready for owner smoke test + release

### What was implemented

| # | Feature | Commit | Files changed |
|---|---------|--------|---------------|
| 1 | **Employee DM quick-action** — chat icon on each employee card in EmployeesScreen | — | `employees_screen.dart` |
| 2 | **Task-linked conversations** — chat bubble in TaskDetailsScreen AppBar (creator + assignee only); `createdBy` bug fixed | — | `task_details_screen.dart`, `chat_repository.dart`, `chat_list_cubit.dart` |
| 3 | **Admin broadcast channels** — toggle in NewGroupScreen; read-only notice for non-admins; megaphone icon in conversation list | — | `new_group_screen.dart`, `conversation_screen.dart`, `conversation_tile.dart`, `chat_repository.dart`, `chat_list_cubit.dart` |
| 4 | **Translation keys** — 8 new keys × EN + AR (365/365 parity) | — | `en.json`, `ar.json` |
| 5 | **Task thread PERMISSION_DENIED fix** — replaced `get()` + batch with `set()` + catch + sequential message write | `e225dc6` | `chat_repository.dart` |
| 6 | **Remove chat in-app notifications** — removed `createInAppNotification` call from `onNewChatMessage`; FCM push + unread badge are the correct surfaces | `77f0d0b` | `functions/index.js` |
| 7 | **Rich task description** — `SelectableLinkify` replaces plain `Text`; URL/email/phone detection; tap-to-call/open via `url_launcher` | `77f0d0b` | `task_details_screen.dart`, `pubspec.yaml` |

Quality gates: `flutter analyze lib/` — no issues; `flutter test` — 6/6 green; `npm run lint` — clean.

New Flutter dependency: `flutter_linkify: ^6.0.0` (linkify 5.0.0 as transitive).

### Owner smoke test checklist

**Chat Phase 2:**
- [ ] Employee DM quick-action: Admin on EmployeesScreen → tap chat icon on any employee card → DM conversation opens; spinner shows while loading
- [ ] DM idempotence: Tap chat icon on same employee card again → same conversation reopens (no duplicate)
- [ ] Task thread — creator initiates: Admin/creator opens a task detail → tap chat bubble → thread opens with system message; assignee sees it in their chat list
- [ ] Task thread — assignee initiates: Assignee opens same task → tap chat bubble → same thread reopens (not a new one)
- [ ] Task thread button visibility: A user who is neither creator nor assignee should NOT see the chat bubble
- [ ] Broadcast channel — create: Admin → Messages → New Group → toggle "Broadcast Channel" → name → add members (or Select All) → Create
- [ ] Broadcast channel — employee view: Employee opens broadcast channel → input bar replaced by read-only notice
- [ ] Broadcast channel — admin posts: Admin sends message → employee receives FCM; tap opens channel
- [ ] Broadcast icon in chat list: Megaphone icon instead of letter avatar for broadcast conversations
- [ ] Regular group unaffected: Normal group still shows input bar for all members

**Release polish (new):**
- [ ] Chat notifications: After sending a chat message, confirm NO new entry appears in the in-app Notifications screen
- [ ] Existing task notifications still appear normally (assigned, deadline, overdue)
- [ ] Rich description — selectable: Long-press a task description → selection handles appear; text can be copied
- [ ] Rich description — URL: Tap a URL in a description → opens browser
- [ ] Rich description — phone: Tap a phone number in a description → native dialer opens with number pre-filled
- [ ] Rich description — email: Tap an email in a description → mail client opens with address pre-filled
- [ ] Descriptions with no links render normally (no visual change for plain text)

### Deploy steps

Firebase Cloud Functions must be deployed before the store binary:
```
cd functions && npm run deploy
```

Then the store release:
1. Bump version: `pubspec.yaml` → `1.6.0+9`
2. Add CHANGELOG entry for v1.6.0
3. Commit version bump
4. `shorebird release ios` + `shorebird release android`
5. Upload IPA (Transporter) + AAB (Play Console)
6. Merge `feat/chat-phase-2` → `main`
