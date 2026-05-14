# Next Steps

> Last updated: 2026-05-14
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

_See `BACKLOG.md` v1.2 section for the locked ordered roadmap._

## Engineering

### Admin alert on recurring task generation failure

- **Category**: Engineering
- **Why now**: `generateRecurringTaskInstances` has per-template try-catch with `console.error` only. Silent data gaps are not visible to admins.
- **Sketch**: On Cloud Function template error, write to a Firestore `errors` collection or emit an in-app notification to admin users. Could reuse `createInAppNotification` helper.
- **Open questions**: What severity threshold triggers an alert? Should it aggregate (one alert per failed run, not per template)? Does it require a new Firestore collection or can it write to `notifications`?

### Firebase deploy step in release checklist

- **Category**: Release
- **Why now**: `firebase deploy --only functions,firestore:rules` is required after any release touching Cloud Functions or Firestore rules, but it is not prominently tracked in `docs/release-checklist.md`. Missing this step means recurring task generation and notification functions run on stale code in production.
- **Sketch**: Add a mandatory post-merge step to `docs/release-checklist.md` with the exact deploy command and a note on which PRs require it (functions or rules changes).
- **Open questions**: Should we add a CI check that fails if `functions/index.js` or `firestore.rules` changed but no deploy confirmation is present?

### Offline write queue user expectation

- **Category**: UX / Engineering
- **Why now**: The v1.1.0 connectivity banner tells users they're offline but doesn't explain whether actions taken offline will sync. Firestore persistence queues writes silently — a user who completes a task offline and sees no confirmation may retry, creating double-writes or unexpected state.
- **Sketch**: After a write succeeds (Firestore local cache confirms), show a brief "Will sync when reconnected" indicator rather than full success. On reconnect, no extra UI needed — Firestore handles the sync.
- **Open questions**: Is this a real pattern testers hit, or speculative? Defer until stabilization triage confirms it's an actual friction point.

### CHANGELOG.md — v1.1.0 entry

- **Category**: Release
- **Why now**: The GitHub Release for v1.1.0 has full release notes, but `CHANGELOG.md` in the repo may not have a matching v1.1.0 section.
- **Sketch**: Add a `## [1.1.0] — 2026-05-14` section to `CHANGELOG.md` mirroring the GitHub Release notes.
- **Open questions**: None. Small documentation task.

## Architecture

### Shorebird — verify asset/translation patching behaviour

- **Category**: Architecture / Release
- **Why now**: BACKLOG #10 audit (2026-05-14) could not confirm whether Shorebird patches include asset file changes (e.g. `assets/translations/*.json`). If assets cannot be patched, any translation key addition or change requires a full store binary even if the Dart code is otherwise unchanged.
- **Sketch**: On the first Shorebird-enabled build: create a patch that modifies one translation value only (no Dart code change). Verify the change reaches a device without a store update. Record the result in `docs/release-checklist.md`.
- **Open questions**: None — this is a one-time empirical test, not a design decision.

## UI / UX Enhancements

_Scope to be defined from v1.1.0 tester feedback. See BACKLOG item #13._

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
