# Current Task

> Last updated: 2026-05-08

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Fix: persist theme preference across launches — v1.1 PR #3.**

The third v1.1 PR. Closes out tester bug B4. See `BACKLOG.md` → "v1.1 — testing-phase fixes and improvements" for the full series.

## Goal

The user-selected theme mode (system / light / dark) currently resets to `system` every time the app launches, because `ThemeCubit` is created fresh each time with no persistence. Persist the user's choice locally via `shared_preferences` and hydrate the cubit **before** `runApp()` so the very first frame paints in the correct theme — zero flicker on cold start.

## Audit-derived insight

`ThemeCubit` ([lib/core/theme/cubit/theme_cubit.dart](lib/core/theme/cubit/theme_cubit.dart)) is 11 lines: `Cubit<AppThemeMode>` defaulting to `system`, with three setters that emit each mode. **No persistence is wired.** `main.dart` creates `ThemeCubit()` synchronously inside `MultiBlocProvider` with no async hydration. `app.dart`'s `BlocBuilder<ThemeCubit, AppThemeMode>` maps state to `MaterialApp.themeMode`. `shared_preferences` is **not** in `pubspec.yaml` yet.

## Branch

`fix/theme-persistence`, branched from `dev` after PR #24 (`fix/notification-language`) merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-05-08)

1. **Local-only persistence** via `shared_preferences`. No Firestore sync for `themeMode` in v1.1. Cross-device theme sync can land in a later version if it becomes a real ask.
2. **Synchronous hydration before `runApp`.** Read prefs in `main()`, parse the stored mode, pass `initialMode` into `ThemeCubit`'s constructor. The very first frame paints with the correct theme — no flicker on cold start. Cost: ~10–30ms added to cold start, in line with existing `EasyLocalization.ensureInitialized()` and `Firebase.initializeApp()` waits.
3. **Best-effort writes.** Setter writes to `SharedPreferences` are wrapped in try/catch with `FirebaseCrashlytics.recordError(e, stack)` on failure — failure to persist must not block the in-memory toggle (which is what the user sees immediately).
4. **No Settings-screen UI changes.** The screen still calls `cubit.setSystemTheme() / setLightTheme() / setDarkTheme()`. Persistence is internal to the cubit.
5. **Defensive parsing.** Unknown / corrupt / null stored values fall back to `AppThemeMode.system`.

## Affected files

| File | Change | Approx. size |
|---|---|---|
| `pubspec.yaml` | Add `shared_preferences: ^2.x.x` (latest stable on pub.dev — agent picks exact `^x.y` via `flutter pub add shared_preferences`) | 1 line |
| `lib/core/theme/cubit/theme_cubit.dart` | Take `prefs` + `initialMode` constructor params; setters become `Future<void>` and write the new mode to prefs after `emit`, wrapped in try/catch + Crashlytics on failure | grows from 11 → ~30 lines |
| `lib/main.dart` | Load `SharedPreferences` after `EasyLocalization.ensureInitialized()` and `Firebase.initializeApp()`. Parse stored theme name (defaulting to `AppThemeMode.system` on missing/invalid). Pass into `ThemeCubit(prefs: prefs, initialMode: ...)` in `MultiBlocProvider`. | ~10 lines |

**Out of scope**: `lib/app/app.dart` (untouched), `lib/features/settings/presentation/screens/settings_screen.dart` (untouched), `theme_state.dart` (untouched), `app_theme.dart` (untouched).

## Proposed `ThemeCubit` shape (locked design — ship verbatim)

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<AppThemeMode> {
  static const _prefsKey = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeCubit({
    required SharedPreferences prefs,
    required AppThemeMode initialMode,
  })  : _prefs = prefs,
        super(initialMode);

  Future<void> setSystemTheme() => _setMode(AppThemeMode.system);
  Future<void> setLightTheme() => _setMode(AppThemeMode.light);
  Future<void> setDarkTheme() => _setMode(AppThemeMode.dark);

  Future<void> _setMode(AppThemeMode mode) async {
    emit(mode);
    try {
      await _prefs.setString(_prefsKey, mode.name);
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }
}
```

## Proposed `main.dart` hydration block (locked — ship structurally)

After `await Firebase.initializeApp(...)` and any existing Crashlytics handler wiring, before the rest of repo/cubit assembly:

```dart
// Hydrate theme preference synchronously so the first frame paints correctly.
final prefs = await SharedPreferences.getInstance();
final storedThemeName = prefs.getString('theme_mode');
final initialThemeMode = AppThemeMode.values.firstWhere(
  (m) => m.name == storedThemeName,
  orElse: () => AppThemeMode.system,
);
```

Then in the existing `MultiBlocProvider`:

```dart
BlocProvider(create: (_) => ThemeCubit(prefs: prefs, initialMode: initialThemeMode)),
```

If `SharedPreferences.getInstance()` throws (rare — would indicate platform misconfig), wrap in try/catch and fall back to `initialThemeMode = AppThemeMode.system`. The agent must also handle the case where `prefs` is unavailable inside the cubit — but if `getInstance()` succeeded once, the resulting `prefs` instance is stable. Defensive layering is in the parser, not in repeated null checks.

## Edge cases

| Case | Handling |
|---|---|
| `prefs.getString('theme_mode')` returns `null` (first launch) | `firstWhere(orElse: ...)` returns `AppThemeMode.system` |
| Stored value is unknown (e.g., `"blue"` from a future version downgrade) | Same — `firstWhere(orElse: ...)` returns `AppThemeMode.system` |
| `SharedPreferences.getInstance()` throws | Wrap in try/catch in `main()`; fall back to `AppThemeMode.system`; log via `FirebaseCrashlytics.recordError` |
| Setter `prefs.setString` fails (rare — disk full, etc.) | Best-effort try/catch in `_setMode`; in-memory toggle still happens; logged to Crashlytics |
| User upgrades from older app version (no key in prefs) | Defaults to `AppThemeMode.system`. No migration needed. |
| Rapid toggle (light → dark → light in 2 seconds) | All three writes are queued by `SharedPreferences`; last one wins on disk. Acceptable. |

## Smoke tests

Real device, both platforms unless noted.

1. **Light persists** — Settings → Light → kill app → relaunch → still Light.
2. **Dark persists** — Settings → Dark → kill app → relaunch → still Dark.
3. **System persists** — Settings → System → kill app → relaunch → still System.
4. **No flicker on cold start** — Set to Dark, kill app fully, relaunch on a device with bright wallpaper. The very first frame should be dark; **no white flash**.
5. **Fresh install** — Uninstall app → fresh install → opens in System (default) without errors.
6. **Combined with locale** — Switch to Arabic + Dark → kill → relaunch → both Arabic and Dark persist correctly.
7. **No regression on the toggle UX** — Settings screen radio group still updates instantly when tapped (no lag from the new async write).
8. **Quality gates** — `flutter analyze`, `flutter test`, `cd functions && npm run lint` all green.

## Quality gates

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).

## Rollback considerations

- **Pure client-side** changes; no Firestore rules, no Cloud Functions, no `users/{uid}` schema impact.
- **Reverting the PR** removes persistence; behavior reverts to "always starts at System". `shared_preferences` becomes an unused dep (harmless). Any user with a `theme_mode` key in their device prefs is harmless — orphaned key, no data loss.
- **Backward-compatible**: existing users default to `system` until they next change theme.

## Definition of Done

- [ ] `pubspec.yaml` adds `shared_preferences: ^2.x.x` (no other dep changes).
- [ ] `ThemeCubit` accepts `prefs` + `initialMode` constructor params.
- [ ] All three setter methods write to `SharedPreferences` after `emit`, wrapped in try/catch + `FirebaseCrashlytics.recordError`.
- [ ] `main.dart` reads `SharedPreferences` after `Firebase.initializeApp()`, parses the stored theme (defaulting to `AppThemeMode.system` on missing/invalid), and passes the value to `ThemeCubit`.
- [ ] If `SharedPreferences.getInstance()` itself throws in `main()`, fall back to `AppThemeMode.system` and log via Crashlytics.
- [ ] No changes to `settings_screen.dart`, `app.dart`, or `theme_state.dart`.
- [ ] Quality gates green: `flutter analyze`, `flutter test`, `functions/` ESLint.
- [ ] All 7 manual smoke tests pass on at least one Android 13+ device and one iOS device.
- [ ] Workflow docs updated per "Workflow documentation" section below.
- [ ] PR opened to `dev` titled `fix(theme): persist theme preference across launches`.

## Workflow documentation (mandatory updates)

| File | What | Who |
|---|---|---|
| `docs/ai-workflow/CURRENT_TASK.md` | This spec → reset to "No active task" by implementing agent | Lead writes (this commit); agent resets |
| `docs/ai-workflow/BACKLOG.md` | Lead seeds new "v1.1 PR #3 — Theme persistence" entry "In progress" within the v1.1 subsection (move B4 out of the "upcoming entries" list); agent moves to Done on completion | Lead seeds; agent moves |
| `docs/ai-workflow/SESSION_LOG.md` | Lead adds planning entry now; implementing agent adds implementation entry on PR completion | Both |
| `docs/ai-workflow/DECISIONS_LOG.md` | New entry: "Theme persistence — local via shared_preferences, hydrate before runApp" recording the storage choice (no Firestore sync), the anti-flicker hydration strategy, and the best-effort write policy | Implementing agent |
| `docs/ai-workflow/PROJECT_CONTEXT.md` | §2 Tech Stack: add `shared_preferences` under "Mobile / Client" → Utilities row (or as its own row) | Implementing agent |
| `docs/ai-workflow/RULES.md` | No change |
| `docs/ai-workflow/NEXT_STEPS.md` | No change |
| `CHANGELOG.md` | Add `### Fixed` line under `## [Unreleased]`: "Theme preference (system / light / dark) now persists across app launches via `shared_preferences`. The persisted choice is hydrated before the first frame paints, so cold start does not flash the default theme." | Implementing agent |
| `docs/release-checklist.md` | No change |
| `docs/privacy-policy.md` | No change (no new personal data — theme is a device-local UI preference, not user data) |

## Out of scope

- Firestore sync for theme preference (`users/{uid}.themeMode`). Defer to a later version.
- Cubit-internal async hydration (would cause flicker on cold start — explicitly rejected).
- New theme modes beyond `system / light / dark`.
- Settings screen UI changes.
- Any change to `app.dart`, `theme_state.dart`, `app_theme.dart`, or the `MaterialApp.themeMode` mapping.
- Migrating prior `theme_mode` keys (none exist — no migration needed).
- Adding a `ThemeCubit` test (no existing tests; not required by spec; agent may add a small one if cheap, but not required).
- `pubspec.yaml` `name`, `version`, or `description` changes.

## Risks (all minor)

- **`shared_preferences` is a new dep** — Flutter team official, ^2.x is stable, low-risk. Same precedent as `package_info_plus` and `url_launcher` added in PR #14.
- **iOS pod install required** after dep add — agent runs `cd ios && pod install --repo-update`. Standard.
- **Cubit signature change** breaks any test of `ThemeCubit()`. Verified: no existing tests touch `ThemeCubit`. Safe.
- **`main()` cold-start cost** — adds one `await SharedPreferences.getInstance()`. Single-digit ms on modern hardware. Imperceptible.
- **Crashlytics flood risk** — if a user has a permanently-broken disk and every theme toggle records an error, Crashlytics could see noise. Acceptable: this is an edge case and Crashlytics dedupes by stack trace anyway.
