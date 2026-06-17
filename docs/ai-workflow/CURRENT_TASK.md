# Current Task

## Released — v1.6.0+9 (2026-06-17)

**Branch**: `feat/chat-phase-2` → merged to `main` via PR #42  
**Tag**: `v1.6.0`  
**GitHub release**: https://github.com/OdehMohamed/techno-staff/releases/tag/v1.6.0  
**Status**: Awaiting Firebase deploy + Shorebird binary generation + store upload

---

## Pending release steps

### 1. Deploy Cloud Functions (required before store binary)
```
cd functions && npm run deploy
```
Deploys `onNewChatMessage` fix (chat messages no longer write to notifications collection).

### 2. Generate Shorebird production binaries
```
shorebird release ios
shorebird release android
```

### 3. Upload store binaries
- **iOS**: Export IPA from Shorebird output → upload via Transporter → submit in App Store Connect
- **Android**: Download AAB from Shorebird output → upload to Google Play Console (Closed Testing → promote or new release)

---

## What shipped in v1.6.0+9

| # | Feature | Commits |
|---|---------|---------|
| 1 | Employee DM quick-action — chat icon on each employee card | `4561262` |
| 2 | Task-linked conversations — chat bubble in TaskDetails (creator + assignee); PERMISSION_DENIED fix | `4561262`, `e225dc6` |
| 3 | Admin broadcast channels — toggle in NewGroupScreen, read-only notice, megaphone icon, Select All | `4561262` |
| 4 | Translation keys — 8 new keys × EN + AR (365/365 parity) | `4561262` |
| 5 | Rich task description — SelectableLinkify, URL/email/phone detection, tap-to-call, copy toolbar | `77f0d0b`, `4661962` |
| 6 | Remove chat from notification center — `createInAppNotification` removed from `onNewChatMessage` CF | `77f0d0b` |
| 7 | Version bump 1.5.0+8 → 1.6.0+9, CHANGELOG, iOS/Android toolchain files | `5ac57cb` |

Quality gates passed: `flutter analyze lib/` clean; `flutter test` 6/6; `npm run lint` clean.  
New dependency: `flutter_linkify: ^6.0.0`.

---

## Next feature cycle

See `BACKLOG.md` for the v1.7.0 candidates (task completion evidence, rich description was completed in this cycle).
