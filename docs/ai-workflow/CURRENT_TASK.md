# Current Task

> Last updated: 2026-05-08

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Feature: account settings (name editing + password change) — v1.1 PR #4 (F1).**

The fourth v1.1 PR. First feature item after the three tester-bug fixes. See `BACKLOG.md` → "v1.1 — testing-phase fixes and improvements" for the full series.

## Goal

Give every authenticated user the ability to:

1. Edit their **display name** (writes to `users/{uid}.name`).
2. Change their **password** (Firebase Auth, with current-password reauthentication).

Email change, profile photo, and Firebase Auth `displayName` sync are all explicitly out of scope. Single source of truth for the display name remains `users/{uid}.name`.

## Branch

`feat/account-settings`, branched from `dev` after PR #25 (`fix/theme-persistence`) merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-05-08)

1. **Two separate screens.** `EditProfileScreen` (name) and `ChangePasswordScreen` (current + new + confirm). Cleaner UX, better isolation between mundane profile edits and security-sensitive password changes. Settings → Account section gets two new tiles.
2. **Password minimum 8 characters.** Stricter than Firebase Auth's default 6. No complexity requirements (no symbols/numbers/cases) for v1.1.
3. **Name validation: 2–50 characters after trim.** Empty / whitespace-only / too short / too long all rejected client-side.
4. **No Firebase Auth `displayName` double-write.** Firestore `users/{uid}.name` is the single source of truth. The app reads from Firestore everywhere; Firebase Auth `displayName` is unused. Avoiding the double-write keeps the system simple and avoids consistency edge cases.
5. **Email change is deferred.** Out of v1.1 scope. The Firebase Auth flow (`verifyBeforeUpdateEmail` + reauth + email verification handshake) is non-trivial and not requested by testers.
6. **Always reauthenticate before `updatePassword`.** Avoids the fragile `requires-recent-login` Firebase Auth error path. The user supplies the current password as part of the change-password form; the cubit reauthenticates first, then updates.

## Editable vs admin-controlled fields

| Field | Self-edit (this PR) | Admin-edit (existing) | Notes |
|---|---|---|---|
| `name` | ✅ | ✅ | Self-update rule extended to include `name` |
| `password` | ✅ via Firebase Auth | ❌ admin uses Firebase console | Auth-side, not Firestore |
| `email` | ❌ deferred | ❌ deferred | Out of scope |
| `role` | ❌ | ✅ via existing employees admin UI | `hasOnly` mask prevents self-elevation |
| `isActive` | ❌ | ✅ admin only | Account suspension is admin-only |
| `fcmToken`, `languageCode`, `createdAt` | system-managed | system-managed | Already wired |

## Affected files

### Code

| File | Change | Approx. size |
|---|---|---|
| `lib/features/auth/data/repositories/auth_repository.dart` | Add `Future<void> reauthenticate(String currentPassword)` and `Future<void> updatePassword(String newPassword)`. Both rethrow `FirebaseAuthException` so the cubit can map error codes. | ~25 lines |
| `lib/features/auth/data/repositories/user_repository.dart` | Add `Future<void> updateName(String uid, String name)` — writes `{name: trimmed}` to `users/{uid}` | ~10 lines |
| `lib/features/auth/domain/models/app_user.dart` | Add `copyWith({String? name, ...})` if not already present. Other field copies optional but recommended for completeness. | ~15 lines |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Add `Future<void> updateName(String name)` that calls `UserRepository.updateName`, on success emits new state with updated `AppUser`. Add `Future<void> changePassword({required String currentPassword, required String newPassword})` that calls `AuthRepository.reauthenticate` then `updatePassword`, with error-code mapping (`wrong-password` → `current_password_incorrect`, `weak-password` → `password_too_short_min_8`, network → `network_error`, fallback → `failed_to_update_password`). State emits a transient `error` status with the localized key on failure; success returns normally without state mutation (UI shows snackbar + pops). | ~60 lines |
| `lib/features/auth/presentation/cubit/auth_state.dart` | Verify there's an error message state field (`errorMessage`); already wired from sign-in flow — should not need a change. Re-use it. | 0 lines (verify only) |
| **NEW** `lib/features/settings/presentation/screens/edit_profile_screen.dart` | Stateful screen. Pre-fills `TextFormField` with `state.user.name`. Submit button disabled until value differs from current AND validation passes. On submit: `cubit.updateName(...)`, snackbar `profile_updated`, `Navigator.pop()`. Error path: snackbar `failed_to_update_profile`. Use `if (!context.mounted) return;` after every `await`. | ~150 lines |
| **NEW** `lib/features/settings/presentation/screens/change_password_screen.dart` | Stateful screen. Three obscured `TextFormField`s: current, new, confirm. Form validation. Submit calls `cubit.changePassword(...)`. On success: snackbar `password_updated` + `Navigator.pop()`. On failure: localized error snackbar, stays on screen. Loading state on submit button. Use mounted guards. | ~200 lines |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Add two new `ListTile`s in the existing Account section (between About and Delete account): "Edit profile" → push `RouteNames.editProfile`, "Change password" → push `RouteNames.changePassword`. | ~20 lines |
| `lib/core/routes/route_names.dart` | Add `editProfile = '/edit-profile'` and `changePassword = '/change-password'` constants | 2 lines |
| `lib/core/routes/app_router.dart` | Add `case RouteNames.editProfile:` and `case RouteNames.changePassword:` returning `MaterialPageRoute` for the new screens | ~10 lines |

### Firestore rules (`firestore.rules`)

| Section | Change |
|---|---|
| `users/{userId}` update rule | Extend self-update mask to include `name` |

Exact diff:
```diff
   allow update: if isAdmin() || (
     isCurrentUser(userId) &&
-    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken', 'languageCode'])
+    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken', 'languageCode', 'name'])
   );
```

`hasOnly` continues to permit any subset, so existing single-field self-updates still pass.

### Translations (`assets/translations/en.json` + `ar.json`) — 16 new keys

Verify each does not already exist before adding.

| Key | EN | AR |
|---|---|---|
| `account_settings` | "Account settings" | "إعدادات الحساب" |
| `edit_profile` | "Edit profile" | "تعديل الملف الشخصي" |
| `change_password` | "Change password" | "تغيير كلمة المرور" |
| `name` | "Name" | "الاسم" |
| `name_required` | "Name is required" | "الاسم مطلوب" |
| `name_too_short` | "Name must be at least 2 characters" | "يجب أن يتكون الاسم من حرفين على الأقل" |
| `name_too_long` | "Name must be 50 characters or fewer" | "يجب ألا يزيد الاسم عن 50 حرفاً" |
| `current_password` | "Current password" | "كلمة المرور الحالية" |
| `new_password` | "New password" | "كلمة المرور الجديدة" |
| `confirm_new_password` | "Confirm new password" | "تأكيد كلمة المرور الجديدة" |
| `passwords_do_not_match` | "Passwords do not match" | "كلمات المرور غير متطابقة" |
| `password_too_short_min_8` | "Password must be at least 8 characters" | "يجب أن تتكون كلمة المرور من 8 أحرف على الأقل" |
| `current_password_incorrect` | "Current password is incorrect" | "كلمة المرور الحالية غير صحيحة" |
| `password_updated` | "Password updated" | "تم تحديث كلمة المرور" |
| `profile_updated` | "Profile updated" | "تم تحديث الملف الشخصي" |
| `failed_to_update_password` | "Failed to update password" | "فشل تحديث كلمة المرور" |
| `failed_to_update_profile` | "Failed to update profile" | "فشل تحديث الملف الشخصي" |

(That's 17 keys; the agent should grep first and reuse `password`, `password_required`, `save`, `cancel`, `network_error` if any of those already exist.)

## Expected flows

### Edit profile
1. User taps "Edit profile" tile in Settings → Account section.
2. `EditProfileScreen` opens. `TextFormField` pre-filled with `state.user.name`.
3. User edits name. Save button enabled iff (a) value is different AND (b) validation passes (2–50 chars after trim).
4. Submit → `cubit.updateName(trimmedName)` → repository writes `{name: trimmedName}` to `users/{uid}` → cubit emits new state with updated `AppUser`.
5. On success: snackbar `profile_updated`, `Navigator.pop()`.
6. On failure: snackbar `failed_to_update_profile`, stay on screen.

### Change password
1. User taps "Change password" tile.
2. `ChangePasswordScreen` opens. Three obscured `TextFormField`s (current / new / confirm).
3. Form validation:
   - Current: required, non-empty.
   - New: required, ≥8 chars.
   - Confirm: required, equals new.
4. Submit (validation passes) → loading state → `cubit.changePassword(current, new)`.
5. Cubit:
   - `AuthRepository.reauthenticate(currentPassword)` → on failure with `wrong-password` → emit error state with `current_password_incorrect`; on other failure → emit `failed_to_update_password`.
   - On reauth success → `AuthRepository.updatePassword(newPassword)` → on failure with `weak-password` (shouldn't fire — we enforce 8+ chars client-side) → emit `password_too_short_min_8`; on other failure → emit `failed_to_update_password`.
   - On both success: do not emit anything; UI handles success.
6. UI on success: snackbar `password_updated`, `Navigator.pop()`.
7. UI on failure: snackbar with the localized error key, stay on screen for retry.

## Edge cases

| Case | Handling |
|---|---|
| User offline during name change | Firestore queues write; UI shows optimistic snackbar. Acceptable best-effort. |
| User offline during password change | Reauth requires network → snackbar `network_error`; user retries online. |
| Wrong current password | `wrong-password` → snackbar `current_password_incorrect`; stay on screen. |
| Weak new password (< 8 chars) | Client-side form validation prevents submit. Defense in depth: Firebase rejects < 6 with `weak-password`. |
| New password same as current | Firebase doesn't reject; we don't either. Acceptable — user may have a legitimate reason. |
| Empty / whitespace-only name | Trim → check 2–50 char range. Form validation rejects. |
| Name with 51 chars | Form validation rejects with `name_too_long`. |
| User tries to elevate role via name update | `hasOnly([...])` rule blocks any field outside the mask. Defense in depth. |
| Tasks have stale `assignedByName` | Tasks store a snapshot at creation time. Old tasks keep old name. NOT updating denormalized historical names. Acceptable. |
| User changes password on Device A, Device B is open | Firebase Auth invalidates Device B's session. Device B's next Firestore action fails with auth error. The existing `BlocListener<AuthCubit>` from PR #23 routes Device B to login. **No new code required for this flow** — verify it still works in smoke test. |
| User taps Save with name unchanged | Save button disabled (no-op). |
| Form submitted twice rapidly | Loading state on submit button prevents double-submit. |

## Smoke tests (real device, both platforms unless noted)

1. **Edit profile happy path** — open Edit profile → change name → Save → snackbar `profile_updated` → pop. Verify `users/{uid}.name` updated in Firebase console within 5s. Verify the name appears in admin's user list.
2. **Edit profile validation** — empty name → "Name is required". 1-char name → "too short". 51-char name → "too long". Save button only enabled when valid AND different.
3. **Edit profile no-change** — open with current name, don't change anything → Save button disabled.
4. **Change password happy path** — enter valid current + valid new (8+ chars) + matching confirm → Submit → snackbar `password_updated` → pop. Sign out → sign in with NEW password → succeeds.
5. **Change password wrong current** — enter wrong current password → snackbar `current_password_incorrect`, stay on screen.
6. **Change password mismatch** — new and confirm differ → form validation rejects with `passwords_do_not_match`.
7. **Change password too short** — 6-char new password → form validation rejects with `password_too_short_min_8`.
8. **Cross-device sign-out regression** — change password on Device A → on Device B (still signed in), tap any task → Device B should route to login (Firebase Auth invalidates session; existing `BlocListener` from PR #23 handles).
9. **Localization** — toggle to Arabic, verify all 17 new strings render correctly + RTL layout reads correctly.
10. **Rules regression** — admin updates a user's name in employees admin UI → still works. Self-update of any non-mask field (e.g., role) → still rejected.
11. **Theme + locale combined regression** — verify Arabic + Dark + edited profile all coexist correctly across kill/relaunch.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Rules deployment ordering

The Firestore rules update is deployed via `firebase deploy --only firestore:rules` and is **not part of the merged code** — it's a separate operational step. Recommend:

1. Implementing agent merges the PR which includes the `firestore.rules` change in the repo.
2. After merge to `dev`, the project owner runs `firebase deploy --only firestore:rules` to push the new rules to the live `techno-staff` project before the build is uploaded for closed testing.

If the client ships before rules are deployed: name self-updates fail with permission error (graceful — UI shows `failed_to_update_profile`). If rules deploy before client: zero impact (the new permission isn't exercised by old clients).

Document this in the PR body for the project owner.

## Rollback considerations

- **Pure client + rules** changes; no Cloud Functions, no schema migrations.
- Reverting the PR removes the two screens + two Settings tiles + the rules extension. Existing `users/{uid}` docs with self-changed `name` keep their values; admin-flow continues to work. Translation keys become orphaned (harmless; can be cleaned up in a follow-up).
- **No `pubspec.yaml` version bump** in this PR — build-number bumps happen at release-cut time.

## Definition of Done

- [ ] `AuthRepository` has `reauthenticate(currentPassword)` and `updatePassword(newPassword)`. Both rethrow `FirebaseAuthException`.
- [ ] `UserRepository` has `updateName(uid, name)` writing `{name: trimmed}` to `users/{uid}`.
- [ ] `AppUser` has a `copyWith({String? name, ...})` method.
- [ ] `AuthCubit` has `updateName(name)` and `changePassword({currentPassword, newPassword})` with error-code mapping to translation keys.
- [ ] `EditProfileScreen` exists with form validation and the locked UX flow.
- [ ] `ChangePasswordScreen` exists with three fields, form validation, and the locked UX flow.
- [ ] `SettingsScreen` has two new tiles in the Account section, ordered: About → Edit profile → Change password → Delete account.
- [ ] `RouteNames.editProfile` and `RouteNames.changePassword` exist; `AppRouter.onGenerateRoute` handles both.
- [ ] `firestore.rules` `users/{userId}` update mask is `hasOnly(['fcmToken', 'languageCode', 'name'])`.
- [ ] All 17 new translation keys exist in both `en.json` and `ar.json`. Translation parity preserved.
- [ ] Quality gates green.
- [ ] All 11 manual smoke tests pass on at least one Android 13+ device and one iOS device.
- [ ] Workflow docs updated per "Workflow documentation" section below.
- [ ] PR opened to `dev` titled `feat(account): add profile editing and password change`. PR body documents the `firebase deploy --only firestore:rules` step for the project owner to run after merge to `dev`.

## Workflow documentation (mandatory updates)

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This spec → reset to "No active task" by implementing agent | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | Lead seeds new "v1.1 PR #4 — Account settings" entry "In progress"; agent moves to Done on completion. Move F1 out of the upcoming-entries list. | Lead seeds; agent moves |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now; implementing agent adds implementation entry on PR completion | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | New entry: "Account settings — name editing + password change with mandatory reauth" recording the 2-screen split, the 8-char minimum, the no-displayName-sync choice, and the email-change deferral | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §4 Modules: update the `settings` row to mention "edit profile (name), change password (with reauth)" alongside existing items. §5 Firestore Data Model: optionally note that `users/{uid}.name` is now self-editable. | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Add `### Added` line under `## [Unreleased]`: "Account settings — users can now edit their display name and change their password from Settings → Account. Password change requires the current password (mandatory reauthentication)." | Implementing agent |
| `docs/release-checklist.md` | No change |
| `docs/privacy-policy.md` | No change (no new personal data collected) |

## Out of scope

- **Email change** — deferred; needs `verifyBeforeUpdateEmail` flow + reauth + email-verification handshake.
- **Profile photo** — deferred; needs Firebase Storage.
- **Firebase Auth `displayName` sync** — explicitly rejected; Firestore is the single source of truth.
- **Password strength meter / complexity rules** — minimum 8 chars only; no symbols/numbers/cases.
- **Account activity log** ("password last changed on ...", recent sign-ins) — future enhancement.
- **Two-factor authentication** — major security feature; out of v1.1.
- **Updating denormalized `assignedByName` / `assignedToName` on existing tasks** — they snapshot at creation time; old tasks keep old name. Acceptable.
- **`pubspec.yaml`** name/version/description changes.

## Risks (all manageable)

- **Firebase Auth error-code coverage** — we handle `wrong-password`, `weak-password`, `network-request-failed`, and a generic fallback. Other codes (`too-many-requests`, `user-disabled`, etc.) fall through to `failed_to_update_password`. Acceptable for v1.1; can refine later if testers hit edge cases.
- **Cross-device sign-out** — change password on Device A invalidates other sessions. Verified by smoke test #8 — relies on existing PR #23 routing.
- **Rules deploy ordering** — see the "Rules deployment ordering" section. Operationally simple; documented for the owner.
- **Translation accuracy** — Arabic strings drafted by lead; user can review on the PR. Same precedent as PR #2.
- **Backward compatibility** — fully preserved. Existing users without a stale `name` see no change; new field-write path is additive only.
