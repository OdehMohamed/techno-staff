# Changelog

All notable changes to Techno Staff are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Edit Profile screen (Settings → Account → Edit Profile) — users can update their display name (2–50 chars). Save button disabled until value is valid and changed from current.
- Change Password screen (Settings → Account → Change Password) — reauthenticates with current password before updating; minimum 8 chars; confirm-field cross-validation.

### Fixed

- Auth lifecycle now clears FCM token state on sign-out and successful account deletion, and delete-account now reliably transitions to login by emitting unauthenticated state instead of relying on passive listener behavior.
- FCM push notifications now respect the recipient's chosen language (English / Arabic). In-app notifications were already localized; this fix covers the system-tray push payload.
- Theme preference (system / light / dark) now persists across app launches via `shared_preferences`. The persisted choice is hydrated before the first frame paints, so cold start does not flash the default theme.

## [1.0.1] - 2026-04-30

### Fixed

- Privacy policy URL inside the About screen no longer returns 404 (switched to `.md` path).
- Final support email applied in `privacy-policy.md`.
- CHANGELOG date placeholder corrected.

## [1.0.0] - 2026-04-30

### Added

- Employee task creation with any-to-any assignment (PR #6).
- Admin task tabs: "Assigned to me" and "All tasks" (PR #8).
- Task delete UI for admins and creators (PR #9).
- Task search and filtering with global filter state and bottom-sheet UX (PR #10).
- Account deletion via Cloud Function callable and Settings account section (PR #14).
- Privacy policy at `docs/privacy-policy.md` and Settings About screen (PR #14).
- Android 13+ POST_NOTIFICATIONS manifest permission (PR #13).
- Firebase Crashlytics global error reporting and per-user identification (PR #5).

### Changed

- Bilingual app surface using `easy_localization` (en, ar) with RTL support.
- Tasks screen supports global search, filter, and sort across role-specific tabs (PR #10).
- App display name standardized to "Techno Staff" across Android and iOS (PR #12).
- Bumped Firebase Flutter packages: cloud_firestore 6.3, cloud_functions 6.2, firebase_auth 6.4, firebase_core 4.7, firebase_messaging 16.2 (PR #5).

### Fixed

- English chart legend rendering: rename `in_pending_tasks` to `pending_tasks` (PR #12).

### Security

- Removed all `debugPrint` calls from `lib/`, eliminating release-log leakage of FCM tokens, user IDs, and task metadata (PR #11).
- Tightened Firestore rules to require `assignedBy` immutability on task updates (PR #6).

[Unreleased]: https://github.com/OdehMohamed/techno-staff/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/OdehMohamed/techno-staff/releases/tag/v1.0.0
