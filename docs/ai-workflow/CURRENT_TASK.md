# Current Task

> Last updated: 2026-05-08

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Supplemental fix for v1.1 PR #4 (`feat/account-settings`) — react to server-initiated session invalidation via `FirebaseAuth.authStateChanges()`.**

The PR is functionally complete for the locked spec, but real-device validation revealed a pre-existing architectural gap that PR #4's password-change feature surfaces: after a password change on Device A, Device B remains signed in and functional indefinitely because `AuthCubit` does **not** subscribe to any Firebase Auth stream. This supplemental fix closes the gap on the same branch (`feat/account-settings`) before merge.

Rationale for landing here vs. as a separate PR: the gap was always latent, but PR #4 is the first feature to actually depend on cross-device session invalidation working. Shipping the password-change feature without this fix would put a known cross-device flaw in front of testers. Coherent fix path is the same PR.

## Branch

`feat/account-settings` (already pushed). The implementing agent extends the existing PR with additional commits — does **not** create a new branch.

## Goal

Make `AuthCubit` react to server-initiated session invalidation (password change on another device, account deletion on another device, admin disabling user, token revocation) by subscribing to `FirebaseAuth.instance.authStateChanges()` and emitting `unauthenticated` whenever the stream emits `null` while the cubit currently believes it is authenticated.

The existing `BlocListener<AuthCubit>` (PR #23) then routes the affected device to login automatically — no UI changes needed.

## Locked design

```dart
import 'dart:async';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSub;

  AuthCubit({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        super(const AuthState()) {
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) {
    // Only react to server-initiated invalidation while we currently believe
    // we are authenticated. Explicit signOut() / deleteAccount() paths emit
    // unauthenticated themselves; double-emits with equal state are deduped
    // by Bloc and BlocListener, so this is idempotent.
    if (state.status != AuthStatus.authenticated) return;
    if (firebaseUser != null) return;

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearErrorMessage: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }

  // ... existing methods unchanged
}
```

### Why `authStateChanges()` and not `idTokenChanges()` / `userChanges()`

- `authStateChanges()` fires on sign-in, sign-out, and SDK-detected session invalidation (after refresh failure → user becomes null).
- `idTokenChanges()` fires on every token refresh (every ~1 hour). More events, no extra value for this fix.
- `userChanges()` adds metadata changes (display name, email). Not relevant — we don't double-write Firebase Auth `displayName`.

`authStateChanges()` is the simplest and avoids unnecessary listener churn.

### Why guard with `state.status != AuthStatus.authenticated`

- App start with no signed-in user: stream emits `null`. Without the guard we would emit `unauthenticated` from the unauthenticated initial state — harmless but spurious.
- `signOut()` flow: the stream fires `null` between `_authRepository.signOut()` and the explicit `emit(unauthenticated)`. The guard avoids the listener emitting first; if it did, Bloc + BlocListener dedupe makes it idempotent anyway.
- New sign-in: stream fires with a non-null user. The guard short-circuits via `firebaseUser != null` early-return.

### Subscription lifetime

- Subscription created in the constructor body (after `super` initializes state).
- Cancelled in the overridden `close()`. Clean and standard.
- `AuthCubit` is a top-level provider (`MultiBlocProvider` in `main.dart`) — its lifetime equals the app's, so the subscription stays alive for the life of the app. No leak.

## Affected files

| File | Change | Approx. size |
|---|---|---|
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Add `dart:async` import (if not present); add `StreamSubscription<User?>? _authSub` field; subscribe in constructor body; add `_onAuthStateChanged` private method; override `close()` to cancel the subscription | ~25 lines |

**No** changes anywhere else. No new screens, no rules, no functions, no translations, no pubspec.

## Edge cases (with handling)

| Case | Behavior |
|---|---|
| App cold start, user not signed in | Stream emits `null`. Guard `state.status != AuthStatus.authenticated` short-circuits. No emit. ✓ |
| App cold start, user signed in | `checkAuthStatus()` runs and emits authenticated. Stream emits the existing user (non-null). `firebaseUser != null` short-circuits. No emit. ✓ |
| Explicit sign-out on this device | `signOut()` calls `_authRepository.signOut()` → stream fires `null`. Listener sees `state.status == authenticated && firebaseUser == null` → emits unauthenticated. Then `signOut()` itself emits unauthenticated. Bloc dedupes; BlocListener routes once. ✓ |
| Explicit account deletion | Same flow as sign-out. Idempotent. ✓ |
| Password change on another device | Within ~1 hour (Firebase Auth ID token TTL), Device B's token refresh fails. Stream fires `null`. Listener emits unauthenticated. BlocListener routes to login. ✓ |
| Account deletion on another device | Same as password change. ✓ |
| Admin disables user via Firebase console | Same as password change. ✓ |
| Subscription not cancelled (cubit closed without `close()`) | Should not happen — Bloc framework calls `close()` on disposal. Even if it did, listener would no-op once the cubit is detached. ✓ |
| `authStateChanges()` emits while `signIn()` is mid-flight | `state.status` is `loading` during sign-in. Guard short-circuits. After `signIn()` emits authenticated, any further stream events apply normally. ✓ |

## Smoke tests for this supplement (real device, two devices required)

1. **Cross-device password change** — sign in as the same user on Device A and Device B. On Device A, change password. On Device B, perform a Firestore action (open a task, navigate to dashboard). Within ~1 hour (typically much sooner — within minutes after any Firestore-backed action that triggers token refresh), Device B routes to login automatically.
2. **Cross-device account deletion** — sign in on Device A and Device B. On Device A, delete account. On Device B, perform any action — should route to login.
3. **Same-device explicit sign-out regression** — sign in, then sign out on the same device. Routes to login. No double-routing or visible glitch.
4. **Same-device account deletion regression** — sign in, delete account on same device. Routes to login. (Existing PR #23 behavior preserved.)
5. **App start, signed-out** — kill app, relaunch with no current user. Goes to login. No spurious state transitions.
6. **App start, signed-in** — kill app, relaunch with current user. Goes to home. No spurious state transitions.

### Tester guidance for cross-device tests

Firebase Auth ID tokens are valid for up to 1 hour. Cross-device propagation is **not instant**. To force the test deterministically without waiting:

- After password change on Device A, on Device B: do something that triggers a Firestore call (e.g., pull-to-refresh on the task list). The Firestore call will request a fresh ID token; the refresh fails because the password changed; the SDK signs the user out; `authStateChanges()` fires `null`; the listener routes Device B to login.

This is the **expected and correct** Firebase behavior. Document the timing expectation in the PR body so the user understands "eventually routes to login" rather than "instantly".

## Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Definition of Done (supplement)

- [ ] `AuthCubit` subscribes to `FirebaseAuth.instance.authStateChanges()` in its constructor.
- [ ] `_onAuthStateChanged` short-circuits if `state.status != AuthStatus.authenticated` OR `firebaseUser != null`.
- [ ] On `(authenticated && null user)` transition, emits `unauthenticated` with `clearUser: true` and `clearErrorMessage: true`.
- [ ] `close()` is overridden to cancel the subscription and call `super.close()`.
- [ ] Quality gates green.
- [ ] All 6 supplemental smoke tests pass on real devices (3 cross-device tests require two devices signed in as the same user).
- [ ] Original 11 smoke tests for PR #4 still pass (no regression).
- [ ] Workflow docs updated (see "Workflow documentation" below).
- [ ] PR title remains `feat(account): add profile editing and password change` (no rename — the listener is a supplement to the same feature surface).
- [ ] PR body updated to describe the auth-listener fix as part of the same PR scope.

## Workflow documentation (additional updates required)

The implementing agent already reset `CURRENT_TASK.md` and updated other docs after the original PR #4 implementation. This supplement requires re-doing some of those updates to reflect the expanded scope:

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This supplement spec → re-reset to "No active task" by agent on completion | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | F1 entry status moved back to `In progress`; description extended to mention the auth listener fix; agent moves to Done on completion of the supplement | Lead seeds; agent moves |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now (this session). Agent adds a NEW implementation entry on completion (don't edit the prior one) | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | Add a new entry: "AuthCubit reacts to server-initiated session invalidation via authStateChanges" recording the architectural choice (subscribe in cubit constructor, guard with state.status check, dedup-tolerant) | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §4 Modules: small note on the `auth` row that AuthCubit reacts to Firebase-initiated session invalidation. | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Extend the existing `### Added` line under `## [Unreleased]` (or add a new line under `### Fixed`): "Account changes (password change, account deletion) made on one device now propagate to other devices logged into the same account — those devices route back to login when their session is server-invalidated." | Implementing agent |
| `docs/release-checklist.md` | No change |
| `docs/privacy-policy.md` | No change |

## Out of scope (still)

- iOS-specific aggressive token-refresh forcing (e.g., calling `currentUser.getIdToken(true)` on app foreground).
- Showing a localized "Your session ended on another device" banner before routing to login.
- Distinguishing between "password changed elsewhere", "account deleted", "admin disabled" — all route to login the same way; surfacing the cause is future polish.
- Equatable refactor of `AuthState` to make Bloc dedup tighter (current behavior is correct without it).
- Reacting to `idTokenChanges` / `userChanges` (chose `authStateChanges` for minimal surface).

## Risks (all minor)

- **Double-emit during signOut/deleteAccount** — listener fires `null` while the explicit emit also fires unauthenticated. Bloc dedupes via state equality (or BlocListener routing is idempotent if dedup misses). Manually verified to be benign in the smoke tests.
- **Stream timing on iOS in foreground** — sometimes Firebase iOS SDK delays token refresh until app is foregrounded. Cross-device propagation may take longer on iOS than Android. Acceptable; documented in the smoke-test guidance.
- **Listener fires before `checkAuthStatus()` completes** — possible race on cold start where the stream fires (with the existing user) before `checkAuthStatus()` runs. Guard `state.status != AuthStatus.authenticated` handles this — listener short-circuits because state is still initial. ✓
- **Subscription leak** — only happens if `close()` isn't called. Bloc framework guarantees `close()` on cubit disposal. Top-level cubit lives for the app's lifetime, so even without `close()` the subscription only leaks until process termination. Belt-and-suspenders coverage via the override.
