# Current Task

> Last updated: 2026-05-08

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Second supplemental fix for v1.1 PR #4 (`feat/account-settings`) — server-side refresh-token revocation + iOS APNS race-condition handling.**

The first supplement (`authStateChanges()` listener) shipped correctly but real-device validation revealed it doesn't fire after a password change because **`FirebaseAuth.updatePassword` does NOT auto-revoke refresh tokens** in current Firebase Auth (v6+). To make cross-device invalidation actually work, the server must explicitly call `admin.auth().revokeRefreshTokens(uid)`. The previously-shipped listener is still correct as the client-side reaction layer — it now needs a server-side revocation event to actually fire.

A separate iOS race condition surfaced in the same auth lifecycle: `getToken()` throws `apns-token-not-set` on first launch when called before APNS registration completes. Fixed in the same PR since it's adjacent and small.

## Branch

`feat/account-settings` (already pushed). The implementing agent extends the existing PR with additional commits — does **not** create a new branch.

## Why this is the SECOND supplement (transparency)

The original lead-locked spec assumed Firebase Auth invalidates other-device sessions on password change. That assumption was wrong for current Firebase Auth — `updatePassword` only updates the password; refresh tokens for other sessions remain valid until explicitly revoked or until they expire (effectively never for the refresh token; ~1 hour for the ID token, but the refresh produces a new one). The first supplement (listener) was correct in shape but had no event to listen for. This second supplement adds the missing server-side revocation call.

Lesson captured for future planning rounds: verify Firebase Auth semantics against current docs before locking cross-device session-invalidation expectations.

## Scope

### 1. New Cloud Function callable `revokeUserSessions` in `functions/index.js`

- Authentication: reject if `request.auth` is null with `HttpsError("unauthenticated", ...)`.
- Operation: `await admin.auth().revokeRefreshTokens(request.auth.uid)`.
- Returns `{ success: true }`.
- Error path: catch unexpected exceptions, log via `console.error`, throw `HttpsError("internal", ...)`.
- Region: default (matches existing functions).
- **Authorization is implicit**: the function uses `request.auth.uid` only. A user can only revoke their OWN sessions. No input parameters.

Pattern matches the existing `deleteUserAccount` callable structure.

### 2. `AuthCubit.changePassword` extension

After the existing `_authRepository.updatePassword(newPassword)` call succeeds, before returning:

```dart
try {
  await FirebaseFunctions.instance.httpsCallable('revokeUserSessions').call();
} catch (e, stack) {
  // Best-effort. The password change has already succeeded; a revocation
  // failure should NOT undo it or surface as an error to the user. Log to
  // Crashlytics and let the caller proceed. Other devices may take up to
  // ~1 hour to invalidate naturally via ID-token expiry.
  await FirebaseCrashlytics.instance.recordError(e, stack);
}
```

**Best-effort policy** is critical here:
- The user's primary intent (change password) has already succeeded.
- A revocation failure (network blip, function timeout) shouldn't undo it.
- Without revocation, cross-device cleanup falls back to natural ID-token expiry (~1 hour) — degraded but not broken.

### 3. iOS APNS token race-condition handling in `AuthCubit._setupFCM`

Wrap the `getToken()` call in try/catch and tolerate the `apns-token-not-set` error specifically:

```dart
Future<void> _setupFCM(String userId) async {
  await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  String? token;
  try {
    token = await messaging.getToken();
  } on FirebaseException catch (e, stack) {
    if (e.code == 'apns-token-not-set') {
      // iOS-only race: APNS hasn't registered the device yet. The token
      // will be obtained on the next sign-in attempt or via the FCM
      // onTokenRefresh stream. This is benign; do NOT log to Crashlytics
      // (it floods on every iOS first launch).
    } else {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  } catch (e, stack) {
    await FirebaseCrashlytics.instance.recordError(e, stack);
  }

  if (token != null) {
    await FirebaseFirestore.instance
        .collection(FirebasePaths.users)
        .doc(userId)
        .update({'fcmToken': token});
  }
}
```

Behavior change: if `getToken()` fails with `apns-token-not-set`, the function silently skips the Firestore write for this session. The token will be obtained on next sign-in or via FCM token-refresh callback (not currently wired; could be a v1.1.1 follow-up). Other errors still flow to Crashlytics.

### 4. NOT changing

- The `authStateChanges()` listener from the previous supplement — it remains correct.
- `EditProfileScreen`, `ChangePasswordScreen`, settings screen — already correct.
- Repos (`AuthRepository`, `UserRepository`) — already correct for the password-change feature itself.
- `firestore.rules` — no rule change needed; the function uses Admin SDK which bypasses rules.
- Translation keys — no new user-visible strings (revocation failure is silent to the user).
- `pubspec.yaml` — no dep changes.
- `deleteUserAccount` Cloud Function — already invalidates sessions implicitly via `admin.auth().deleteUser(uid)`. No change needed.

## Affected files

| File | Change | Approx. size |
|---|---|---|
| `functions/index.js` | Add `revokeUserSessions` callable export. | ~15 lines |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | (a) Add best-effort `revokeUserSessions` call to `changePassword` after `updatePassword` succeeds. (b) Wrap `getToken()` in try/catch in `_setupFCM` for `apns-token-not-set`. | ~25 lines |

That's it. Two files.

## Cross-device propagation expectation (locked)

After this lands, cross-device invalidation **still is not instant**. Realistic timing:

| Scenario | Expected timing |
|---|---|
| Device B is foregrounded and actively using Firestore | Within seconds–minutes (next Firestore call triggers token refresh, refresh fails server-side because tokens are revoked, SDK signs out, listener fires, BlocListener routes to login) |
| Device B is backgrounded | When the user next foregrounds the app and any Firestore action runs |
| Device B is offline | When the device next has connectivity and any Firestore action runs |
| Worst case (all of the above happen but no Firestore action triggers refresh) | Up to ~1 hour as the ID token expires naturally |

This is a **Firebase Auth limitation**, not a bug in our code. Document the expectation in the PR body.

### Side effect on Device A (the device that just changed the password)

`revokeRefreshTokens` revokes ALL refresh tokens for the uid, **including Device A's**. Device A keeps its current ID token until it expires (~1 hour); the next refresh fails; Device A also routes to login. The user just changed their password successfully and would intuitively expect to need to re-sign in. Acceptable trade-off.

## Smoke tests (real device, two devices for cross-device tests)

1. **Cross-device password change happy path** (CRITICAL) — sign in same user on Device A and Device B. Change password on A. On Device B, perform a Firestore action (open task, pull-to-refresh dashboard). Within minutes, B routes to login. Sign in on B with the NEW password — succeeds.
2. **Cross-device timing tolerance** — same scenario but B is idle (no Firestore actions). B routes to login within ~1 hour as ID token expires.
3. **Same-device password change** (regression check) — Device A's session also invalidates within ~1 hour. Acceptable; user re-signs in.
4. **Wrong current password** (regression check) — error path unchanged; no spurious revocation.
5. **`revokeUserSessions` failure tolerance** — simulate a function failure (e.g., temporarily revoke deploy permissions). Password change still succeeds locally; Crashlytics records the revoke failure; user is not blocked. Cross-device cleanup falls back to natural token expiry.
6. **APNS race regression on iOS** — fresh install on iOS device → sign in. The `apns-token-not-set` error must NOT propagate to the UI or appear in Crashlytics. The first sign-in proceeds without crash; FCM token may be missing for this session but is obtained on next sign-in.
7. **APNS happy path on iOS** — second sign-in / subsequent launches → `getToken()` succeeds → `fcmToken` written to Firestore as before.
8. **APNS regression on Android** — Android sign-in unchanged (no APNS involvement); FCM token obtained as before.
9. **Account deletion (regression)** — confirm `deleteUserAccount` flow still routes Device B to login. (Already worked because `admin.auth().deleteUser` revokes implicitly. No code change should affect this.)
10. **Original PR #4 flows** — Edit profile, name validation, save-button enable/disable, change password, Arabic/RTL — all still work.

## Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green.

## Operational steps for the project owner (post-merge)

This PR adds a new Cloud Function. After merging to `dev`:

```bash
firebase deploy --only functions:revokeUserSessions
# OR (also acceptable, redeploys everything)
firebase deploy --only functions
```

The previously-needed `firebase deploy --only firestore:rules` step from the original PR #4 supplement still applies for the rules change (extending the self-update mask to include `name`). Both deploys should land before the next test build is uploaded.

## Definition of Done (this supplement)

- [ ] `functions/index.js` exports `revokeUserSessions` matching the locked structure.
- [ ] `AuthCubit.changePassword` calls `revokeUserSessions` (best-effort) after `updatePassword` succeeds.
- [ ] `AuthCubit._setupFCM` wraps `getToken()` in try/catch tolerating `apns-token-not-set` silently.
- [ ] Quality gates green.
- [ ] All 10 smoke tests pass on real devices (smokes #1, #2 require two devices; #6 requires fresh iOS install).
- [ ] Workflow docs updated (see "Workflow documentation" below).
- [ ] PR body updated with: (a) the cross-device timing expectation, (b) the operational deploy step for the new function.
- [ ] PR title remains `feat(account): add profile editing and password change` (no rename — supplements consolidate into the same feature).

## Workflow documentation (additional updates)

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This spec → reset to "No active task" by agent | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | F1 entry status moved back to `In progress` until cross-device smoke tests pass; description extended to mention server-side revocation; agent moves to Done with a third `Completed` line | Lead seeds; agent finalizes |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now (this session). Agent adds a new implementation entry on completion (don't edit prior entries) | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | Append: "Cross-device session invalidation via Cloud Function `admin.revokeRefreshTokens`" — record (a) the corrected understanding of Firebase Auth's `updatePassword` behavior, (b) why server-side revocation is required, (c) the best-effort client call policy, (d) the iOS APNS race tolerance | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §6 Cloud Functions: add `revokeUserSessions` row with trigger=callable, role=any signed-in user, purpose="Revokes all refresh tokens for the caller; used after password change to force other devices to re-authenticate." | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Extend the `## [Unreleased]` PR #4 entry: bullet under `### Added` — "Password change now revokes refresh tokens for all of the user's sessions, so other signed-in devices route back to login on their next token refresh (eventual, up to ~1 hour)." Bullet under `### Fixed` — "iOS first-launch `apns-token-not-set` race no longer logs spuriously; FCM token is obtained on subsequent sign-in." | Implementing agent |
| `docs/release-checklist.md` | No change in this PR. (Future v1.x: consider adding `firebase deploy --only functions:revokeUserSessions` to the post-merge ops checklist.) | — |
| `docs/privacy-policy.md` | No change | — |

## Out of scope

- Subscribing to `FirebaseMessaging.onTokenRefresh` to catch the iOS APNS-late case automatically (small future PR; not blocking).
- Notifying the user with a banner before routing to login on Device B ("Your session ended on another device"). Polish; defer.
- Distinguishing the cause of session invalidation (password change vs admin disable vs deletion). All route to login the same way; surfacing the cause is future polish.
- `idTokenChanges` / `userChanges` listeners — `authStateChanges` covers what we need.
- `revokeUserSessions` accepting a target uid (admin force-logout). Defer; `request.auth.uid` only is the secure default.
- Equatable refactor on `AuthState`. Behavior is correct without it.
- Adding a settings screen toggle for "Sign out of all other devices" as a separate user action. Defer.

## Risks

- **Best-effort revocation can leave other devices signed in** for up to ~1 hour even after a successful password change. Documented; acceptable for v1.1.
- **Device A also routes to login** within ~1 hour of changing password (because it shares the revocation). User would intuitively expect to re-sign in after a password change anyway. Acceptable.
- **Cross-device propagation timing on iOS** can be slower than Android because iOS Firebase SDK delays token refresh in some background states. Documented.
- **APNS error swallowing on iOS** could mask other genuine `FirebaseException`s if the agent uses too-broad a try/catch. The locked code matches ONLY `apns-token-not-set` and rethrows other codes to Crashlytics. Verify in code review.
- **`revokeUserSessions` rate limiting** — Firebase Admin SDK doesn't rate-limit revocation; our function doesn't either. A user spamming the password-change flow would generate one revocation per change. Negligible at our scale.
