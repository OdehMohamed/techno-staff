# Current Task

> Last updated: 2026-05-01

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

No active task.

PR B (`chore/android-release-signing`) and PR A (`chore/app-icons`) are both complete. PR A is PR #19 to `dev`. PR B is ready for push + PR creation (commits pending).

> ⚠️ **Parallel work in flight**: PR A (`chore/app-icons`) is being implemented in parallel on a separate branch. They are independent — PR A touches `pubspec.yaml`, `assets/icon/app_icon.png`, and the generated icon files; PR B touches **only** `android/app/build.gradle.kts` and `docs/release-checklist.md`. Do **not** edit any file outside PR B's scope on this branch.

## Goal

Make Google Play uploads possible. Today `android/app/build.gradle.kts` signs release builds with debug keys (a leftover from the Flutter scaffolding TODO), which Play Console rejects on every track including internal/closed testing. This PR replaces the debug-key fallback with a release `signingConfig` driven by `android/key.properties` (gitignored), and updates `docs/release-checklist.md` with the exact `keytool` command + `key.properties` template the project owner runs once locally to generate the keystore.

## Branch

`chore/android-release-signing`, branched from `dev` post-v1.0.1. The branch exists locally and on `origin` once the planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-30 — 2026-05-01)

1. **Strict signing for release builds.** If `android/key.properties` is missing, `flutter build apk --release` / `flutter build appbundle --release` fails. No silent fallback to debug keys (that is precisely the bug we are fixing).
2. **Debug builds are unaffected.** `flutter run` and `flutter build apk --debug` still work without `key.properties` — debug builds use Android's auto-generated debug keystore as always.
3. **Keystore lives OUTSIDE the repo.** Default suggested location: `~/upload-keystore.jks`. `android/key.properties` references it by absolute path. Both `key.properties` and `*.jks` are already gitignored under `android/.gitignore` (verified).
4. **Documentation is part of this PR.** The `keytool` invocation, the `key.properties` template, and the operational reminder go into `docs/release-checklist.md` so the user can run them when they get to that step.
5. **No iOS signing changes.** iOS distribution signing is configured in Xcode UI (manual, separate from Gradle). Out of scope for this PR.

## Scope — file-by-file

### 1. `android/app/build.gradle.kts`

Apply three structural edits. Read the file first to preserve the existing `plugins`, `android.namespace`, `compileSdk`, `compileOptions`, `kotlinOptions`, `defaultConfig`, `dependencies`, and `flutter` blocks.

**Edit 1 — top of file (above `plugins` or just below it, Gradle Kotlin convention is below):**

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

**Edit 2 — inside the `android { }` block, before `buildTypes`:**

```kotlin
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
}
```

**Edit 3 — replace the existing `buildTypes.release` block:**

Currently:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Replace with:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

(Removes the TODO comment + switches the signing config reference. Nothing else inside `buildTypes` is added.)

**Do NOT** change: `namespace`, `applicationId`, `minSdk`, `targetSdk`, `compileSdk`, `ndkVersion`, `versionCode`, `versionName`, `compileOptions`, `kotlinOptions`, `dependencies`, `flutter { source = "../.." }`.

### 2. `docs/release-checklist.md`

Locate the existing item:

> Configure Android signed release keystore — generate a keystore with `keytool`, place it at `android/app/upload-keystore.jks` (gitignored), create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword` (gitignored), and reference it from `android/app/build.gradle.kts` `signingConfigs.release`.

Replace it with the explicit, copy-pasteable version below. The previous wording was a hint; this version is operational truth:

````
- [ ] **Configure Android signed release keystore (one-time per project owner)** —
  Required before any `flutter build appbundle --release` or upload to Play
  Console. Skip this if the keystore is already generated and `android/key.properties`
  is in place.

  1. Generate the upload keystore (run from anywhere — store it OUTSIDE the repo):

     ```
     keytool -genkey -v \
       -keystore ~/upload-keystore.jks \
       -keyalg RSA -keysize 2048 -validity 10000 \
       -alias upload
     ```

     `keytool` will prompt for: a store password, a key password, and a Distinguished
     Name (CN, OU, O, L, ST, C). Use any values; record the passwords in a password
     manager — losing them is unrecoverable.

  2. Create `android/key.properties` (gitignored — never commit):

     ```
     storePassword=<store-password-from-step-1>
     keyPassword=<key-password-from-step-1>
     keyAlias=upload
     storeFile=/Users/<your-username>/upload-keystore.jks
     ```

     `storeFile` must be an **absolute path** to the .jks from step 1.

  3. Verify by building a release App Bundle:

     ```
     flutter build appbundle --release
     ```

     Should complete successfully and produce a signed `.aab` at
     `build/app/outputs/bundle/release/app-release.aab`.

     If you get `keystore was tampered with, or password was incorrect` →
     password mismatch, re-check `key.properties`.
     If you get `Keystore file '/...jks' not found` → wrong path in
     `storeFile`.
````

**Do NOT** modify any other section of the checklist.

### 3. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append "Android release signing — strict, key.properties-driven" recording: no fallback to debug for release builds; keystore lives outside the repo; iOS signing remains a manual Xcode UI step out of scope.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — no changes expected.
- **`docs/ai-workflow/BACKLOG.md`** — add a "Pre-build polish (v1.0.1 stores)" subsection (under `Done` if PR A has already merged when this PR opens, otherwise under `Should-fix` `In progress`). Add this PR's entry there. If the subsection already exists from PR A's merge, add this entry alongside.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — reset to "No active task" with a note about whether PR A is still in flight.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes; run anyway).
- **`flutter build apk --debug`** must still succeed without `key.properties` (regression check that debug builds are unaffected).

## Manual smoke tests

These are critical and must run on the implementing agent's local machine.

1. **Without `key.properties` present**:
   - `flutter build apk --debug` succeeds.
   - `flutter run` (debug) launches the app fine.
   - `flutter build apk --release` **fails with a clear error** about missing keystore (acceptable failure — that is the new strict behavior). The exact error wording is up to Gradle/Flutter; what matters is that it does NOT silently sign with debug keys.

2. **With `key.properties` present** (the agent generates a throwaway keystore for testing — does NOT commit it; deletes it after):
   - Generate test keystore using the keytool command from `docs/release-checklist.md`.
   - Create `android/key.properties` with valid values pointing at the test keystore.
   - `flutter build appbundle --release` succeeds. Output is a signed `.aab`.
   - `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab` reports the signing certificate (it is the test keystore, not the Android default debug certificate).
   - **Delete the test keystore and `key.properties` before commit. Verify with `git status` that they are not staged.**

3. **No regression on iOS**: `flutter build ios --release --no-codesign` still succeeds. (No-codesign because iOS distribution signing is set up later in Xcode and is out of scope.)

4. **Workflow file diff is clean**: the only changed files are `android/app/build.gradle.kts`, `docs/release-checklist.md`, and the workflow docs in §3. `git diff` shows no `key.properties`, no `*.jks`, no other unrelated changes.

## Definition of Done

- [ ] `android/app/build.gradle.kts` reads `key.properties` and configures a `release` `signingConfig` driven by it; `buildTypes.release.signingConfig` references the new release config; the `// TODO:` comment is removed.
- [ ] `docs/release-checklist.md` "Configure Android signed release keystore" item replaced with the explicit `keytool` + `key.properties` instructions.
- [ ] `flutter analyze`, `flutter test`, `functions/` ESLint all green.
- [ ] `flutter build apk --debug` succeeds without `key.properties`.
- [ ] `flutter build appbundle --release` succeeds when `key.properties` is present (verified once with a throwaway keystore that is then removed).
- [ ] `flutter build apk --release` fails clearly when `key.properties` is missing (no silent debug-key fallback).
- [ ] `git status` shows no committed `key.properties` and no committed `*.jks`.
- [ ] `DECISIONS_LOG.md`, `BACKLOG.md`, `SESSION_LOG.md` updated.
- [ ] `CURRENT_TASK.md` reset to "No active task" with note about PR A status.
- [ ] PR opened against `dev` titled `chore(android): configure release signing via key.properties`.

## Out of scope

- No iOS signing changes (Xcode UI, manual). Captured separately in `docs/release-checklist.md`.
- No `applicationId` / `PRODUCT_BUNDLE_IDENTIFIER` change — confirmed final at `com.mohamedodeh.technostaff`.
- No `version`, `pubspec.yaml`, `lib/`, `functions/`, or `firestore.rules` changes.
- No CI/CD integration, no fastlane, no Firebase App Distribution.
- No edits on this branch to files belonging to PR A (`pubspec.yaml`, `assets/icon/app_icon.png`, generated icon files). PR A handles those independently in parallel.
- No changes to `compileSdk`, `minSdk`, `targetSdk`, `ndkVersion`, or `compileOptions`.

## Risks

- **The strict-failure approach changes behavior** for any developer who runs `flutter build apk --release` locally without setting up `key.properties`. Today they get a debug-signed APK silently; after this PR they get a build error. This is intentional — the silent debug signing is precisely what was leaking to Play uploads. Documented in DoD smoke test 1.
- **Keystore loss is unrecoverable.** If the project owner loses the keystore + passwords, they cannot upload further versions of the same app to Play (the upload key is tied to the listing). Google's Play App Signing Key Reset is a manual support process. Mitigation: the `keytool` step in the checklist explicitly tells the user to record the passwords in a password manager.
- **`flutter build apk` vs `flutter build appbundle`** — Play Console accepts AAB only (since Aug 2021 for new apps). The smoke test uses `appbundle` to match the actual upload artifact. APKs are still useful for sideloading.
