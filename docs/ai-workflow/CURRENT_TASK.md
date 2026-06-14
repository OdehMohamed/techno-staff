# Current Task

> No active task. v1.4.0+7 merged to `main` (2026-06-14). Owner actions required before store release — see below.

## Owner-required steps for v1.4.0

### 1. Push `main` to remote

```bash
git push origin main
```

### 2. Firebase deploy (run from repo root)

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Deploys:
- **`onNewChatMessage`** Cloud Function — FCM push + in-app notification + unread count per recipient on new chat message
- **Firestore rules** — `conversations` and `messages` collections with participant-only read/write, soft-delete, and read-count guard
- **Firestore indexes** — composite indexes for conversation list ordering and message pagination

### 3. Build and submit store release

v1.4.0 contains native iOS changes (`AppDelegate.swift` — `UNUserNotificationCenter` delegate + `UserNotifications` import). **Not Shorebird-patchable. Full binary required.**

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS — then archive + upload via Xcode
```

### 4. Post-deploy smoke test

- **Chat DM**: Send a DM from Device A to Device B → push notification appears on B; tap opens conversation
- **Foreground suppression**: Device A inside Conversation X; Device B sends to X → A sees no banner; Device B sends to Y → A does see banner
- **Background notification**: App killed on A; B sends → banner appears; tap opens correct conversation
- **Group chat**: Create a group, send a message → all members except sender receive push
- **Attendance correction**: Admin roster → expand row → Correct → edit sessions → submit → roster updates, audit preserved
- **PDF export**: Admin dashboard → PDF icon → report includes attendance roster and renders in correct language

---

## What shipped in v1.4.0

### Merged branches

| Branch | Merged | Contents |
|---|---|---|
| `feat/chat-messaging` | 2026-06-14 | Chat & Messaging module + attendance stabilization |
| `feat/improved-pdf-export` | 2026-06-14 | Professional dashboard + employee monthly PDF |

### New features

**Chat & Messaging**
- DM conversations (deterministic get-or-create ID)
- Group conversations (named, multi-member)
- Real-time streaming, pagination (50/page), soft-delete (sender-only), unread counts
- Unread badge on AppBar (`ChatBadgeButton`)
- FCM push + in-app notification per recipient on new message
- Per-conversation foreground suppression — iOS native (`AppDelegate.willPresent` + `UserDefaults`) and Android Dart (`activeConversationId`)
- 28 new EN/AR translation keys
- `conversations` + `messages` Firestore collections, security rules, composite indexes
- `onNewChatMessage` Cloud Function

**Attendance stabilization**
- Session-level admin corrections (add/remove/edit individual sessions)
- `originalSessions` audit baseline on first correction (server-preserved)
- Expandable `AttendanceRecordCard` (summary visible, session detail on tap)
- Employee monthly attendance screen
- `correctedByName` provenance field

**PDF reports redesign**
- Dashboard PDF now includes attendance roster, schedule-aware presence rate, bilingual output, active filter label
- New employee monthly attendance PDF with per-session detail and correction provenance

### Bugs fixed

- iOS foreground notification suppression never fired — `UNUserNotificationCenter` delegate owned by plugins; fixed by `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunching`
- Attendance blocking check-in failure (stabilization-pass regression)
- Attendance correction sheet double-pop on success
- Chat keyboard did not dismiss on tap-outside (added `onTapOutside` unfocus)
