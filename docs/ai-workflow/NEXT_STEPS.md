# Next Steps

> Last updated: 2026-04-24
> This file captures forward-looking ideas — things we might want to do next but have not yet committed to. When we commit to an item, promote it into `BACKLOG.md` with a priority.

Sections are intentionally left empty. Add ideas as they come up in discussions or during implementation; do not speculate. One-liners are fine; expand only when we are close to acting on an idea.

---

## How to add an idea

```
### <short title>

- **Category**: Engineering | Architecture | UI/UX | Security | Testing | Release | Other
- **Why now**: (optional) what triggered the thought
- **Sketch**: one or two lines on what the change would be
- **Open questions**: what we still need to decide before promoting it to the backlog
```

When an idea graduates to real work, move it to `BACKLOG.md` and remove it from here.

---

## Recommended Next Steps

_To be discussed with the team._

## Engineering

_Empty._

## Architecture

_Empty._

## UI / UX Enhancements

_Empty._

## Security Improvements

### Manual "Sign out of all other devices" Settings action

- **Category**: Security
- **Why now**: PR #26 (account settings) added server-side `revokeUserSessions` + a client `authStateChanges` listener so password change attempts to invalidate other-device sessions. Real-device validation in v1.1 showed the automatic flow is reliably architecturally correct but not reliably deterministic in practice — Firebase Auth ID-token refresh cadence and SDK background-state policies make propagation timing user-visible (seconds → up to ~1h). We stopped iterating on the automatic flow for v1.1 (see `DECISIONS_LOG.md`, 2026-05-08). A user-triggered manual action is the deterministic counterpart if we ever need stronger session-management UX or get a compliance ask.
- **Sketch**: Settings → Account tile "Sign out of all other devices" → confirmation dialog → calls the existing `revokeUserSessions` callable → Crashlytics on failure. The current device's session continues normally because the revocation only invalidates *other* refresh tokens at the next refresh; the local ID token keeps working until natural expiry. No new Cloud Function — reuses what PR #26 already shipped.
- **Open questions**: (a) Do we surface confirmation feedback ("Other sessions will sign out within ~1 hour")? (b) Do we add the same wording to the password-change success state to set expectations there too? (c) Trigger an explicit local-token refresh after revocation so the current device immediately re-mints, reducing the worst-case lag for the OTHER devices that actively touch Firestore?

## Testing Priorities

_Empty._

## Release Readiness

_Empty._
