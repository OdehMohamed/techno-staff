<!--
SYNC IMPACT REPORT
Version change: (uninitialized template) → 1.0.0
Rationale: Initial ratification — first concrete constitution replacing placeholder template;
MAJOR bump is the canonical initial version per semantic versioning policy.

Modified principles: N/A (new document)
Added sections:
  - Core Principles (5): Feature-First Clean Architecture; Cubit State Management Discipline;
    Firestore Rules & Server-Authoritative Writes; Shared Design System & Localization;
    Quality Gates Before Merge
  - Additional Constraints & Platform Standards
  - Development Workflow & Review Process
  - Governance
Removed sections: all placeholder tokens

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — Constitution Check section references this file;
       no rewording needed (gate text is generic). Reviewed.
  - ✅ .specify/templates/spec-template.md — no constitution-specific mandatory sections to
       add/remove. Reviewed.
  - ✅ .specify/templates/tasks-template.md — task categorization (Setup, Foundational,
       per-story, Polish) already aligns with the principles. Reviewed.
  - ⚠ README.md — still the default Flutter starter readme; does not yet link to this
       constitution. Non-blocking follow-up.

Deferred items / TODOs: none.
-->

# Techno Staff Constitution

## Core Principles

### I. Feature-First Clean Architecture

Every user-facing capability MUST live under `lib/features/<feature>/` with the three-way
split `data/` (Firestore/Functions DTOs + repositories), `domain/models/` (plain domain
types, only where a feature genuinely needs them), and `presentation/` (`cubit/` + `screens/`).
Cross-feature code MUST go under `lib/core/` (routing, theme, constants, services) or
`lib/shared/widgets/` (reusable UI); it MUST NOT be co-located inside a feature folder.

**Rationale**: The split enforced by `lib/app/app.dart` wiring every repository and Cubit
into a single top-level `MultiBlocProvider` only works if features stay self-contained and
never reach into each other's `data/` or `presentation/` layers. Drift breaks the DI graph
and makes role-based navigation impossible to reason about.

### II. Cubit State Management Discipline

State management MUST use `flutter_bloc` `Cubit`. `Bloc` event classes are disallowed.
State classes MUST be immutable and expose a `copyWith` plus explicit `clear*` flags for
nullable fields (see `AuthState` in `lib/features/auth/presentation/cubit/auth_cubit.dart`
as the reference pattern). Features MUST consume cubits via `context.read<XCubit>()` from
the app-level provider; local `BlocProvider` instantiation inside a screen is forbidden
unless the cubit's lifetime is strictly scoped to that screen and the exception is
documented in the PR.

**Rationale**: Uniform state shape makes Cubits composable with the notification/FCM deep-link
flow that navigates via `AppNavigator.navigatorKey` without a `BuildContext`. Deviations
break this flow and produce stale-state bugs that are expensive to trace.

### III. Firestore Rules & Server-Authoritative Writes (NON-NEGOTIABLE)

`firestore.rules` is the authoritative access matrix. Any change to a Firestore collection's
shape or access pattern MUST be accompanied by the matching rules update in the same PR.
Field names MUST come from `lib/core/constants/firebase_paths.dart`; string literals for
Firestore field or collection names are prohibited in feature code. The client MUST NOT
write to `task_logs/` (server-only) and MUST NOT duplicate FCM/notification writes that
Cloud Functions already produce (`sendTaskAssignedNotification`,
`sendTaskStatusNotification`, deadline/overdue crons, `createInAppNotification`). New
task-lifecycle events MUST be added in `functions/index.js` first.

**Rationale**: Two write paths for the same event desynchronize quickly and, worse, can
mask security-rule regressions. Centralizing audit-style writes server-side is how the
role model (admin vs. employee) stays enforceable.

### IV. Shared Design System & Localization

All user-visible text MUST be a translation key resolved via `easy_localization` (`.tr()`),
with entries added to both `assets/translations/en.json` and `assets/translations/ar.json`.
Hard-coded English strings in widgets are prohibited. UI MUST prefer the shared widgets in
`lib/shared/widgets/` (`AppCard`, `AppDrawer`, `AppPieChart`, `ChartLegend`,
`EmptyStateWidget`, `PriorityBadge`, `SectionHeader`, `StatusBadge`) and theme values from
`lib/core/theme/` + `lib/core/constants/` over rolling bespoke equivalents. New reusable
components MUST land in `lib/shared/widgets/` before a second feature consumes them.

**Rationale**: Arabic is a first-class locale, not an afterthought; missing a translation
key ships a broken screen. The shared widget set is also the only way status/priority
rendering stays consistent between admin and employee shells.

### V. Quality Gates Before Merge (NON-NEGOTIABLE)

Every PR MUST pass, locally or in CI, before review approval:

- `flutter analyze` — zero warnings (the `flutter_lints` rule set is authoritative)
- `flutter test` — all existing tests green; new behavior SHOULD land with at least one
  widget or unit test when the change is non-trivial
- `npm run lint` in `functions/` — mandatory whenever `functions/` is touched (also runs
  as Firebase `predeploy`)

Breakage of any gate blocks merge. Gates MUST NOT be bypassed with `--no-verify`,
`// ignore:` comments, or lint suppressions without a reviewer-approved justification
captured in the PR description.

**Rationale**: The project has no separate QA environment; the gates above are the only
automated signal that a change is safe to deploy to the single `techno-staff` Firebase
project.

## Additional Constraints & Platform Standards

- **Platform**: Flutter (Dart SDK `^3.9.2`) targeting Android, iOS, and Web. Firebase
  project id is `techno-staff` (see `.firebaserc`, `lib/firebase_options.dart`).
- **Backend runtime**: Firebase Cloud Functions, Node 22, single-file (`functions/index.js`).
  Adding a second file is allowed only once the single file exceeds coherent responsibility
  boundaries; the split MUST be documented in the PR.
- **Routing**: All navigation MUST go through `AppRouter.onGenerateRoute` with route names
  from `lib/core/routes/route_names.dart`. Deep-linking from FCM payloads MUST use
  `AppNavigator.navigatorKey` and route to `RouteNames.taskDetails` with a string `taskId`;
  `TaskDetailsLoaderScreen` is the required entry point when only an id (not a full
  `TaskModel`) is available.
- **Roles**: The two-role model (`admin`, `employee`) is fixed. Adding a third role
  requires a constitution amendment because it affects Firestore rules, the `admin` and
  `employee` shells, and the employee-creation Cloud Function (`createEmployeeUser`).
- **Secrets & config**: `lib/firebase_options.dart` is generated output; do not hand-edit.
  Service-account keys, `.env` files, and any credential material MUST stay out of the
  repository.

## Development Workflow & Review Process

- **Branching**: Feature work branches from `dev` using the speckit git-feature flow.
  PRs target `dev`; `main` is fast-forwarded from `dev` only at release points.
- **Spec-driven changes**: Non-trivial features SHOULD go through `/speckit-specify`,
  `/speckit-plan`, `/speckit-tasks` before implementation. The `Constitution Check` gate
  in `plan-template.md` MUST be evaluated against the principles above before Phase 0
  research and re-evaluated after Phase 1 design.
- **Review**: At least one reviewer approval is required. Reviewers MUST verify: no
  string-literal Firestore paths (Principle III), no duplicated notification writes
  (Principle III), no hard-coded user-facing strings (Principle IV), and that the quality
  gates ran (Principle V).
- **Commits**: Conventional-style subject prefixes are preferred (`feat:`, `fix:`,
  `core:`, `docs:`) to match the existing history. Co-author trailers from AI assistants
  are allowed.

## Governance

This constitution supersedes ad-hoc conventions. When a principle here conflicts with an
older doc, CLAUDE.md note, or in-repo comment, this file wins until amended.

**Amendment procedure**: Amendments land via PR that (a) edits this file, (b) updates the
Sync Impact Report comment at the top, (c) bumps the version per the policy below, and
(d) updates any dependent templates (`plan-template.md`, `spec-template.md`,
`tasks-template.md`) in the same PR. Amendments adding or removing a NON-NEGOTIABLE
principle require explicit maintainer approval in the PR description.

**Versioning policy**: Semantic versioning applied to governance, not code.

- **MAJOR**: Backward-incompatible change — principle removed or redefined, role model
  changed, or a NON-NEGOTIABLE added/removed.
- **MINOR**: New principle or materially expanded section.
- **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements.

**Compliance review**: Reviewers enforce this constitution on every PR. A periodic sweep
(at minimum once per release cut to `main`) SHOULD confirm that `firestore.rules`,
`functions/index.js`, and the shared widget set still match Principles III and IV.
Drift found during the sweep MUST be fixed or tracked as a follow-up issue before the
release is tagged.

**Runtime guidance**: `CLAUDE.md` at the repo root is the operational guide for AI and
human contributors. It MUST stay consistent with this constitution; when the two
disagree, amend whichever is wrong in the same PR.

**Version**: 1.0.0 | **Ratified**: 2026-04-17 | **Last Amended**: 2026-04-17
