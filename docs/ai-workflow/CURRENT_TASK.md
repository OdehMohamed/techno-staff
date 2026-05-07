# Current Task

> Last updated: 2026-05-01

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Fix: clear FCM token on signout and route to login after account deletion — v1.1 PR #1.**

The first of several v1.1 PRs that close out tester-facing issues found in the closed-testing build. See `BACKLOG.md` → "v1.1 — testing-phase fixes and improvements" for the series.

## Goal

Fix three coupled tester-facing bugs in the auth lifecycle:

- **B1** — `users/{uid}.fcmToken` and the device-side FCM token both persist after sign-out, so the device keeps receiving notifications addressed to the previous user.
- **B1.b** — when a different user signs in on the same device, the previous user's `fcmToken` may still linger in their Firestore doc until they next sign in.
- **B3** — the delete-account flow leaves the UI stuck on a loading spinner instead of routing to login after a successful Cloud Function deletion.

## Branch

`fix/auth-and-account-deletion-flow`, branched from `dev` after PR #22 (`1.0.1+2` build bump) merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-05-01)

1. **Best-effort FCM cleanup.** Firestore `fcmToken` deletion and `FirebaseMessaging.deleteToken()` are wrapped in try/catch and logged via `FirebaseCrashlytics.recordError()` on failure — they do **not** block sign-out or account deletion.
2. **Explicit state emission after account deletion.** The cubit no longer relies on a passive Auth state listener. After a successful Cloud Function call, the cubit calls `_authRepository.signOut()` and emits `unauthenticated`.
3. **App-level routing on `unauthenticated`.** A `BlocListener<AuthCubit, AuthState>` somewhere in the routing surface (verify whether one exists in `lib/app/app.dart`; if not, add it) handles the transition to login. Settings screen also has its own `BlocListener` for safety.
4. **Drop the success snackbar.** The `account_deleted` snackbar is removed entirely. The unauthenticated state transition and navigation back to the login screen are themselves the success signal — simpler UX, less state complexity.
5. **No Firestore rules / Cloud Functions changes.** Pure client-side fix. Existing `users/{uid}` update rule already permits `fcmToken`-only diffs (including deletions).

## Root-cause analysis (from audit)

### B1 — `AuthCubit.signOut()` is incomplete
[auth_cubit.dart:112-123](lib/features/auth/presentation/cubit/auth_cubit.dart#L112-L123) currently only clears Crashlytics, calls `_authRepository.signOut()`, and emits unauthenticated. It does **not** clear `users/{uid}.fcmToken` in Firestore or call `FirebaseMessaging.instance.deleteToken()`. As a result the FCM senders in `functions/index.js` (`sendTaskAssignedNotification`, `sendTaskStatusNotification`, the cron senders) read the still-present token and push to the device.

### B3 — `AuthCubit.deleteAccount()` relies on a passive listener
[auth_cubit.dart:125-150](lib/features/auth/presentation/cubit/auth_cubit.dart#L125-L150) calls the `deleteUserAccount` Cloud Function and assumes "Auth state listener fires when account is deleted and routes to login." There is no explicit listener wired up — the cubit doesn't emit `unauthenticated` after a successful delete, and `[settings_screen.dart:20-62](lib/features/settings/presentation/screens/settings_screen.dart#L20-L62)` keeps `_isDeleting = true` forever on the success path because `setState(() => _isDeleting = false)` only runs in the catch block.

## Affected files

| File | Change | Approx. size |
|---|---|---|
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Add FCM cleanup to `signOut()`; restructure `deleteAccount()` to explicitly sign out + emit unauthenticated on success | ~30 lines added |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Drop `account_deleted` snackbar; add `BlocListener<AuthCubit, AuthState>` that routes to login when `state.status == unauthenticated`; reset `_isDeleting` defensively on success path | ~15 lines added/changed |
| `lib/app/app.dart` (verify, possibly modify) | Confirm an existing `BlocListener` or routing wrapper handles `unauthenticated` → login. If absent, add one. | 0–10 lines |

## Expected flow changes

### Sign-out flow (NEW)
```
1. User taps "Sign out"
2. AuthCubit.signOut() runs:
   a. Read currentFirebaseUser (may be null — skip 2b/2c if so)
   b. (Best-effort, try/catch + Crashlytics on failure)
      FirebaseFirestore.users(uid).update({'fcmToken': FieldValue.delete()})
   c. (Best-effort, try/catch + Crashlytics on failure)
      FirebaseMessaging.instance.deleteToken()
   d. FirebaseCrashlytics.setUserIdentifier('')
   e. _authRepository.signOut()
   f. emit(state.copyWith(status: unauthenticated, clearUser: true, ...))
3. App-level BlocListener (or settings-level) routes to login screen
```

### Delete-account flow (NEW)
```
1. User taps "Delete account" → confirmation dialog → confirms
2. settings_screen sets _isDeleting = true
3. AuthCubit.deleteAccount() runs:
   a. Call deleteUserAccount Cloud Function
   b. On success:
      i.   (Best-effort) FirebaseMessaging.deleteToken()
      ii.  FirebaseCrashlytics.setUserIdentifier('')
      iii. _authRepository.signOut()
      iv.  emit(unauthenticated)
   c. On failure: emit error state, rethrow (existing behavior preserved)
4. settings_screen BlocListener detects unauthenticated → pop / replace to login
5. settings_screen resets _isDeleting = false on success path (defensive)
6. NO success snackbar — auth state transition is the success signal
```

## Firestore changes

**None to rules.** No schema changes. No new collections.

The only Firestore write change is using `FieldValue.delete()` on `users/{uid}.fcmToken` during sign-out. The existing rule
```
allow update: if isAdmin() || (
  isCurrentUser(userId) &&
  request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken'])
);
```
already permits this — `affectedKeys()` reports `{fcmToken}` regardless of whether the new value is a string or `FieldValue.delete()`.

## Edge cases

| Case | Handling |
|---|---|
| User offline during sign-out | Firestore write may be queued or fail. Wrapped in try/catch + Crashlytics. Sign-out continues. |
| `currentFirebaseUser == null` (already signed out) | Skip Firestore-write block; still call `deleteToken()` + `signOut()` for safety. |
| Same user signs back in (same device) | `_setupFCM()` runs and writes a fresh token to `users/{uid}.fcmToken`. |
| Different user signs in on same device | Old user's `users/{oldUid}.fcmToken` already cleared. New user's `_setupFCM()` writes their token. Clean. |
| `deleteToken()` throws (network, FCM error) | Wrapped in try/catch, logged via `FirebaseCrashlytics.recordError(e, stack)`. Sign-out continues. |
| Account already deleted server-side; client retries `deleteAccount()` | Cloud Function returns error (user not found). Existing catch path triggers `failed_to_delete_account` snackbar. User can refresh / restart. |
| User backgrounds the app mid-deletion | Cloud Function completes server-side. On next foreground, `checkAuthStatus()` reads `currentFirebaseUser == null` → unauthenticated → login. |

## Smoke tests (real device, both platforms unless noted)

1. **Sign-out clears FCM in Firestore**
   - Sign in as employee A. Note `users/{A_uid}.fcmToken` value in Firebase console.
   - Sign out.
   - Refresh Firebase console → field should be **gone** (deleted) within 5 seconds.

2. **Sign-out stops notification leakage**
   - Sign in as employee A on Device 1.
   - As admin, assign a task to A → Device 1 receives push ✓.
   - On Device 1, sign out.
   - As admin, assign another task to A.
   - Device 1 should **NOT** receive a push notification.

3. **Cross-user sign-in cleanliness**
   - Sign in as A on Device 1, sign out.
   - Sign in as employee B on the same Device 1.
   - As admin, assign a task to B → Device 1 receives push ✓.
   - As admin, assign a task to A → Device 1 should **NOT** receive push.

4. **Delete-account routes to login**
   - Sign in as a throwaway employee. Tap Delete account → confirm.
   - Within ~3 seconds, app should navigate to the login screen.
   - **No success snackbar should appear** — auth state transition is the signal.
   - Spinner must not persist.

5. **Delete-account failure path still works**
   - Simulate failure (e.g., temporarily revoke Cloud Function permission, or use airplane mode mid-call).
   - `failed_to_delete_account` snackbar shown. Spinner stops. User remains on Settings. Retry on reconnection works.

6. **No regressions**: sign-in, task list, FCM on fresh sign-in, About screen, theme/language settings, push deep-link to task details.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Rollback considerations

- **Pure client-side** changes; no Firestore rules or Cloud Functions changes.
- **Reverting** the PR fully restores prior behavior. Bugs return but no data is corrupted.
- **No migration needed.** Existing users with stuck `fcmToken` from before the fix are harmless: the next sign-in → sign-out cycle post-merge clears the field. Admin can manually delete a stale field for a single user via Firebase console if needed.
- **No `pubspec.yaml` version bump** in this PR — build-number bumps happen at release-cut time.

## Definition of Done

- [ ] `AuthCubit.signOut()` clears `users/{uid}.fcmToken` (best-effort) and calls `FirebaseMessaging.deleteToken()` before `_authRepository.signOut()`.
- [ ] `AuthCubit.deleteAccount()` on success: deletes token, clears Crashlytics ID, calls `_authRepository.signOut()`, emits `unauthenticated`.
- [ ] All Firestore/Messaging cleanup wrapped in try/catch with `FirebaseCrashlytics.recordError(e, stack)` on failure (do NOT block sign-out / deletion on these).
- [ ] Settings screen has a `BlocListener<AuthCubit, AuthState>` that routes to login when state becomes `unauthenticated`.
- [ ] Settings screen `_isDeleting = false` is reset on the success path (defensive).
- [ ] `account_deleted` snackbar removed; `failed_to_delete_account` snackbar preserved on failure.
- [ ] Verified `lib/app/app.dart` (or wherever appropriate) routes to login on `unauthenticated`. If missing, add a top-level `BlocListener`.
- [ ] All 6 smoke tests pass on at least one Android 13+ device and one iOS device.
- [ ] Quality gates green: `flutter analyze`, `flutter test`, `functions/` ESLint.
- [ ] Workflow docs updated per "Workflow documentation" section below.
- [ ] PR opened to `dev` titled `fix(auth): clear FCM token on signout and route to login after account deletion`.

## Workflow documentation (mandatory updates)

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This spec → reset to "No active task" by implementing agent on completion | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | Lead seeded "v1.1 — testing-phase fixes and improvements" subsection with this PR "In progress"; agent moves to Done within the same subsection | Lead seeds; agent moves |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now; implementing agent adds implementation entry on PR completion | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | New entry: "FCM token lifecycle — cleared on signout and account deletion"; record the best-effort cleanup decision and that recovery is automatic on next sign-in | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | Tiny update to the `auth` module row in §4 Modules: clarify "FCM token registered on sign-in, cleared on sign-out and account deletion" | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Add a `### Fixed` line under `## [Unreleased]` capturing the FCM/signout fix and the delete-account routing fix. The release-cut PR will reformat `[Unreleased]` to `[1.1.0] - YYYY-MM-DD`. | Implementing agent |
| `docs/release-checklist.md` | No change |
| `docs/privacy-policy.md` | No change (no new data collection) |

## Out of scope

- **B2** (notification language) — separate PR (`fix/notification-language`).
- **B4** (theme persistence) — separate PR (`fix/theme-persistence`).
- Any other auth surface (sign-in, password reset, profile update) — F1 territory (`feat/account-settings`).
- Cloud Functions changes — none needed.
- Firestore rules changes — none needed.
- `pubspec.yaml` `name`, `version`, or `description` changes.
- New translation keys (no new user-facing strings; the dropped `account_deleted` snackbar key may stay in `en.json` / `ar.json` to preserve translation parity — do **not** delete the key).
- Native splash screen, accessibility audit, app size analysis — all deferred per the v1.1 roadmap.

## Risks

- **Verifying app-level routing on `unauthenticated`**: spec leaves this to the implementing agent — they must check `lib/app/app.dart` and any `TechnoStaffApp` widget for an existing `BlocListener` or routing wrapper. If found, no change. If absent, the agent adds the smallest possible top-level listener.
- **Best-effort vs guaranteed cleanup**: choosing best-effort over hard requirements means the rare offline-during-signout case can leave a stale token. Mitigation: next sign-in → sign-out clears it. Acceptable.
- **Backward compatibility**: existing users with stale `fcmToken` from before the fix continue to receive notifications until they cycle through one sign-in / sign-out post-merge. This is benign and self-healing.
