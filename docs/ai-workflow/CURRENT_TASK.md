# Current Task

> Last updated: 2026-05-14

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Mandatory app-update system (v1.2 BACKLOG #9)**

Branch: `feat/mandatory-app-update` (created from `dev` post-v1.1.0, 2026-05-14).

On cold start, the app checks a minimum supported version stored in a Firestore `config/app_settings` doc. If the installed version is below the minimum, the user is shown a non-dismissible `UpdateRequiredScreen` with a direct link to the store. Any infrastructure failure (network down, doc missing, parse error) fails open — never blocks users for configuration reasons.

This is a **production safety valve**: once live, the minimum version can be bumped in the Firestore console at any time to force users off a bad build without a code push.

---

## Branch

`feat/mandatory-app-update` (created from `dev` 2026-05-14)

---

## Locked planning decisions

1. **No new packages** — `package_info_plus` and `url_launcher` are already in `pubspec.yaml`. `dart:io` `Platform` is stdlib.
2. **Version source** — Firestore `config/app_settings` doc. Fields: `minimumAndroidVersion`, `minimumIosVersion` (semver strings), `androidStoreUrl`, `iosStoreUrl` (strings). Store URLs in the doc so TestFlight links / Play Store listings can be updated without a binary push.
3. **Fail-open** — any error during the check (network unavailable, doc missing, field missing, parse failure, `url_launcher` failure) must never block the user. The version check gate is: `required: false` on any exception path.
4. **Check location** — `SplashScreen` before `checkAuthStatus()`, in the existing `addPostFrameCallback`. No new Cubit.
5. **No new Cubit** — `AppUpdateService` is a plain singleton with one async method. One-shot gate, not reactive UI state.
6. **`UpdateRequiredScreen`** — non-dismissible (`PopScope(canPop: false)`). No `AppBar` leading/back button. If `launchUrl` fails, the screen stays blocked and the user retries by tapping again. No bypass flow of any kind.
7. **Firestore rules** — new `match /config/{configId}` block: `allow read: if true; allow write: if isAdmin();`. Public read is intentional — no sensitive data, check must fire before auth.
8. **Semver comparison** — split on `.`, parse each segment with `int.tryParse ?? 0`, compare as `[major, minor, patch]` tuple. Equal version = not below = pass through.
9. **3 translation keys × 2 locales** → 245/245 parity.
10. **`config/app_settings` doc must be created manually** in the Firestore console before the feature gates anything. Until the doc exists, fail-open means no one is blocked. Documented in `docs/release-checklist.md`.
11. **Soft-update mode** (banner, not block) — explicitly out of scope.
12. **`firebase deploy --only firestore:rules`** required after merge.

---

## 1. Architecture (read this before any code)

### 1.1 The fail-open invariant

Every exception path in `AppUpdateService.checkUpdate()` must return `(required: false, storeUrl: null)`. This covers:

- `FirebaseFirestore` throws (network unavailable, permission error)
- Doc snapshot does not exist (`doc.exists == false`)
- Version field is null, empty, or malformed
- `int.tryParse` returns null on a non-numeric segment
- `Platform.isAndroid` / `Platform.isIOS` behavior in unexpected environments

**Do not** let any of these propagate to the caller as an exception. The `try-catch` in `checkUpdate()` is the sole safety net — wrap the entire method body.

### 1.2 The no-bypass invariant

`UpdateRequiredScreen` must never allow the user to continue using the app:

- `PopScope(canPop: false)` prevents Android back gesture.
- No `Navigator.pop`, `Navigator.pushReplacement`, or any other navigation away from this screen.
- If `launchUrl` returns `false` or throws, show no error dialog — the user simply taps again. The screen remains.
- No "skip" or "later" button. No timer that auto-dismisses. No tap-outside-to-dismiss.

### 1.3 The semver invariant

`"1.10.0" > "1.9.0"` is false under lexicographic string comparison. Always compare as integer tuples:

```dart
bool _isBelow(String installed, String minimum) {
  final i = _parse(installed);
  final m = _parse(minimum);
  for (int j = 0; j < 3; j++) {
    if (i[j] < m[j]) return true;
    if (i[j] > m[j]) return false;
  }
  return false; // equal = not below minimum
}

List<int> _parse(String version) {
  final parts = version.split('.');
  return List.generate(3, (i) => int.tryParse(parts.elementAtOrNull(i) ?? '') ?? 0);
}
```

---

## 2. `AppUpdateService`

**File:** `lib/core/services/app_update_service.dart` (new, ~55 lines)

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/firebase_paths.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  Future<({bool required, String? storeUrl})> checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final doc = await FirebaseFirestore.instance
          .collection(FirebasePaths.config)
          .doc(FirebasePaths.appSettings)
          .get();

      if (!doc.exists) return (required: false, storeUrl: null);

      final data = doc.data()!;
      final isAndroid = Platform.isAndroid;

      final minimumVersion = (isAndroid
              ? data['minimumAndroidVersion']
              : data['minimumIosVersion']) as String? ??
          '0.0.0';
      final storeUrl = (isAndroid
          ? data['androidStoreUrl']
          : data['iosStoreUrl']) as String?;

      final required = _isBelow(info.version, minimumVersion);
      return (required: required, storeUrl: required ? storeUrl : null);
    } catch (_) {
      return (required: false, storeUrl: null);
    }
  }

  bool _isBelow(String installed, String minimum) {
    final i = _parse(installed);
    final m = _parse(minimum);
    for (int j = 0; j < 3; j++) {
      if (i[j] < m[j]) return true;
      if (i[j] > m[j]) return false;
    }
    return false;
  }

  List<int> _parse(String version) {
    final parts = version.split('.');
    return List.generate(
      3,
      (i) => int.tryParse(parts.elementAtOrNull(i) ?? '') ?? 0,
    );
  }
}
```

Notes:
- `dart:io` `Platform` is safe on Android and iOS. The service is never called on web.
- `PackageInfo.fromPlatform()` returns `version` as the semver string (e.g. `"1.1.0"`), matching the Firestore field format.
- The Firestore read uses the default offline persistence cache. On first cold start with no network and no cached doc: `doc.exists == false` → fail-open.

---

## 3. Firestore `config/app_settings` document

**Collection:** `config`
**Document ID:** `app_settings`

Fields to create manually in the Firestore console before rollout:

| Field | Type | Example value | Notes |
|---|---|---|---|
| `minimumAndroidVersion` | string | `"1.1.0"` | Set to current shipped version initially so no one is blocked |
| `minimumIosVersion` | string | `"1.1.0"` | Same |
| `androidStoreUrl` | string | `"https://play.google.com/store/apps/details?id=<package_id>"` | Use `https://` form, not `market://` — universally compatible |
| `iosStoreUrl` | string | `"https://testflight.apple.com/join/<invite_code>"` | TestFlight invite link; update here when link changes |

**To force a mandatory update:** bump `minimumAndroidVersion` or `minimumIosVersion` to the new required version. Takes effect on next app cold start — no binary push needed.

---

## 4. Splash screen changes

**File:** `lib/features/splash/presentation/screens/splash_screen.dart` (delta: ~15 lines)

Replace the single `checkAuthStatus` call with a `_checkVersionThenAuth()` helper:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _checkVersionThenAuth();
  });
}

Future<void> _checkVersionThenAuth() async {
  final result = await AppUpdateService.instance.checkUpdate();
  if (!mounted) return;
  if (result.required) {
    Navigator.pushReplacementNamed(
      context,
      RouteNames.updateRequired,
      arguments: result.storeUrl,
    );
    return;
  }
  context.read<AuthCubit>().checkAuthStatus(
    languageCode: context.locale.languageCode,
  );
}
```

**Read the actual splash screen before implementing** — match the exact existing method name and parameter for `checkAuthStatus`. The `BlocListener` in `build` and the rest of the splash UI are unchanged.

---

## 5. `UpdateRequiredScreen`

**File:** `lib/features/update/presentation/screens/update_required_screen.dart` (new, ~75 lines)

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_sizes.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String? storeUrl;
  const UpdateRequiredScreen({super.key, this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 80),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'update_required_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  'update_required_message'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: storeUrl == null ? null : () => _openStore(storeUrl!),
                    child: Text('update_now'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }
}
```

Notes:
- `PopScope(canPop: false)` is the Flutter 3.12+ API. If the project's Flutter SDK is older, use `WillPopScope(onWillPop: () async => false, ...)` instead. Check `pubspec.yaml` `environment.sdk` before choosing.
- Button `onPressed: null` when `storeUrl` is null — disabled, but user is still fully blocked. No bypass.
- `_openStore` catches all errors silently. Screen stays. User retries by tapping.

---

## 6. Routing

**`lib/core/routes/route_names.dart`** — add:

```dart
static const String updateRequired = '/update-required';
```

**`lib/core/routes/app_router.dart`** — add case before `default:`:

```dart
case RouteNames.updateRequired:
  return MaterialPageRoute(
    builder: (_) => UpdateRequiredScreen(
      storeUrl: settings.arguments as String?,
    ),
    settings: settings,
  );
```

Import: `import '../../features/update/presentation/screens/update_required_screen.dart';`

---

## 7. Firestore rules delta

Add inside `match /databases/{database}/documents { ... }`, after the `task_templates` block:

```
match /config/{configId} {
  allow read: if true;
  allow write: if isAdmin();
}
```

`allow read: if true` is intentional — no sensitive data, must be readable before auth.

---

## 8. `FirebasePaths` constants

**`lib/core/constants/firebase_paths.dart`** — add:

```dart
static const String config = 'config';
static const String appSettings = 'app_settings';
```

---

## 9. Translations

Add 3 keys × 2 locales. Current parity: 242/242. Target: 245/245.

**`assets/translations/en.json`** — append:

```json
"update_required_title": "Update Required",
"update_required_message": "A new version of the app is required to continue. Please update and reopen.",
"update_now": "Update Now"
```

**`assets/translations/ar.json`** — append:

```json
"update_required_title": "تحديث مطلوب",
"update_required_message": "إصدار جديد من التطبيق مطلوب للمتابعة. يرجى التحديث وإعادة الفتح.",
"update_now": "تحديث الآن"
```

Verify:
```bash
python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"
```
Expected: `245 245 []`

---

## 10. Affected files

| File | Change | Type |
|---|---|---|
| `lib/core/services/app_update_service.dart` | New singleton | New, ~55 lines |
| `lib/core/constants/firebase_paths.dart` | +2 constants | +2 lines |
| `lib/features/splash/presentation/screens/splash_screen.dart` | `_checkVersionThenAuth` helper | ~15 line delta |
| `lib/features/update/presentation/screens/update_required_screen.dart` | New screen | New, ~75 lines |
| `lib/core/routes/route_names.dart` | +1 constant | +1 line |
| `lib/core/routes/app_router.dart` | +1 case + import | +6 line delta |
| `firestore.rules` | `config/` block | +4 line delta |
| `assets/translations/en.json` | +3 keys | +3 lines |
| `assets/translations/ar.json` | +3 keys | +3 lines |
| `docs/release-checklist.md` | `config/app_settings` creation + `firebase deploy` steps | +8 lines |

**Zero changes to:** `pubspec.yaml`, `main.dart`, `app.dart`, Cloud Functions, any existing cubit, any task/auth/notification screen, `AppDrawer`.

---

## 11. Quality gates

```bash
flutter analyze          # zero warnings
flutter test             # all existing tests green (no new unit tests — Platform.isAndroid
                         # throws in test context; cover via smoke tests instead)
cd functions && npm run lint  # clean (no CF changes, confirming no regression)
python3 -c "import json; e=json.load(open('assets/translations/en.json')); a=json.load(open('assets/translations/ar.json')); print(len(e), len(a), [k for k in e if k not in a])"
# Expected: 245 245 []
```

---

## 12. Smoke tests

| # | Environment | Test |
|---|---|---|
| 1 | real device | Installed `1.1.0`, doc minimum `1.1.0` → normal launch, no block |
| 2 | real device | Installed `1.1.0`, minimum bumped to `1.2.0` → cold start shows `UpdateRequiredScreen` |
| 3 | real device | Tap "Update Now" → correct store opens (Play Store on Android, TestFlight on iOS) |
| 4 | real device | Android back gesture on `UpdateRequiredScreen` → screen stays, no exit |
| 5 | real device | Arabic locale → `UpdateRequiredScreen` in Arabic, RTL correct |
| 6 | emulator | Airplane mode, doc not cached → fail-open, normal splash |
| 7 | emulator | `config/app_settings` doc does not exist → fail-open, normal splash |
| 8 | emulator | `storeUrl` field absent, update required → `UpdateRequiredScreen` shows, button disabled |
| 9 | emulator | Minimum `"1.10.0"`, installed `"1.9.0"` → blocked (tuple comparison, not string) |
| 10 | emulator | Minimum `"1.1.0"`, installed `"1.1.0"` → pass through (equal = not below) |
| 11 | Firestore console | Admin bumps minimum → next cold start affected users are blocked |

---

## 13. Definition of Done

- [ ] `AppUpdateService` at `lib/core/services/app_update_service.dart`; entire body in try-catch; all exception paths return `(required: false, storeUrl: null)`.
- [ ] `FirebasePaths.config` and `FirebasePaths.appSettings` added.
- [ ] `SplashScreen._checkVersionThenAuth()` fires before `checkAuthStatus()`; `BlocListener` and splash UI unchanged.
- [ ] `UpdateRequiredScreen`: `PopScope(canPop: false)` present; button disabled when `storeUrl` null; `_openStore` catches all errors silently; no navigation out.
- [ ] `RouteNames.updateRequired` and `AppRouter` case registered.
- [ ] Firestore rules `config/` block added.
- [ ] Translation parity `245 245 []`.
- [ ] `docs/release-checklist.md` updated with `config/app_settings` creation step and `firebase deploy --only firestore:rules` step.
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] No changes outside files listed in §10.
- [ ] Workflow docs updated (SESSION_LOG, BACKLOG #9 Done, CURRENT_TASK reset).
- [ ] PR title: `feat(app): add mandatory app-update gate with Firestore version config`.

---

## 14. Risks

- **`Platform.isAndroid` in unit tests** — throws `UnsupportedError` in test context. Do not write unit tests that exercise the platform branch. Cover with smoke tests #1–#3.
- **`config/app_settings` doc absent on first deploy** — fail-open is correct; feature is inert until the admin creates the doc. Release checklist update is the mitigation.
- **Firestore offline cache staleness** — if a user has a cached doc from when the minimum was lower, they pass through until next online cold start. Accepted limitation; the gate fires correctly once online.
- **`market://` scheme on Android** — use `https://play.google.com/store/...` form in `androidStoreUrl`, not `market://`. The `https://` form works universally; `market://` fails if Play Store is not the default handler.
- **`PopScope` Flutter version** — `PopScope` requires Flutter 3.12+. Check `environment.sdk` in `pubspec.yaml`. If older, use `WillPopScope(onWillPop: () async => false, ...)`.

---

## 15. Out of scope

- Soft-update mode (banner, dismissible)
- Admin UI for version management (Firestore console is sufficient)
- Web platform support (`dart:io` `Platform` not available on web)
- Mid-session update checks (cold-start gate only)
- Shorebird patch vs store-build semantics (BACKLOG #10 audit)

---

## 16. Workflow doc updates required on completion

| File | Change |
|---|---|
| `CURRENT_TASK.md` | Reset to "No active task" |
| `BACKLOG.md` | Mark item #9 Done with completion date and quality gate results |
| `SESSION_LOG.md` | Append implementation entry at top |
| `docs/release-checklist.md` | Add `config/app_settings` creation step + `firebase deploy --only firestore:rules` |
