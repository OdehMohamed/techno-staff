# Techno Staff

Techno Staff is a bilingual (English/Arabic) staff and task-management app for the Techno team. It supports role-based workflows for admins and employees, backed by Firebase Auth, Firestore, Cloud Functions, and FCM-driven notifications.

## Tech stack

- Flutter (Dart SDK ^3.9.2) for Android, iOS, and Web
- flutter_bloc (Cubit pattern)
- easy_localization (en, ar)
- Firebase (Auth, Firestore, Cloud Functions, FCM)
- flutter_lints + ESLint (Google) for Cloud Functions

## Getting started

```bash
flutter pub get
flutter run
```

For Cloud Functions:

```bash
cd functions
npm install
npm run lint
```

## Project documentation

- CLAUDE.md: operational guide for AI and human contributors.
- docs/ai-workflow/: shared workflow docs (project context, current task, backlog, decisions, rules, session log).

## Firebase project

techno-staff (see .firebaserc and lib/firebase_options.dart).
