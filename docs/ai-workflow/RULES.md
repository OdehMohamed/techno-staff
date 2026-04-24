# Rules

> Last updated: 2026-04-24
> This file is the authoritative source of project rules. When any other doc (including `CLAUDE.md` or in-code comments) conflicts with this file, this file wins until explicitly amended.

Originally migrated from the ratified constitution v1.0.0 (2026-04-17) and extended with git, commit, and AI-agent conventions.

---

## 1. Workflow for every task

Before starting **any** task — feature, fix, refactor, doc, or spike — every agent (human or AI) MUST:

1. Read [PROJECT_CONTEXT.md](./PROJECT_CONTEXT.md) for the current state of the system.
2. Read [CURRENT_TASK.md](./CURRENT_TASK.md) to see if a task is already in flight.
3. Skim [BACKLOG.md](./BACKLOG.md) to see if the intended work is already queued.
4. Read [DECISIONS_LOG.md](./DECISIONS_LOG.md) to avoid re-opening settled decisions.
5. Read this file (`RULES.md`) in full the first time you work on the repo and whenever an agent prompts you to.
6. Scan [NEXT_STEPS.md](./NEXT_STEPS.md) for relevant forward-looking notes.

After finishing **any** task:

1. Update [CURRENT_TASK.md](./CURRENT_TASK.md) (mark the task done or replace it with the next one).
2. Move any completed items in [BACKLOG.md](./BACKLOG.md) into the `Done` section.
3. If a non-trivial decision was made, append an entry to [DECISIONS_LOG.md](./DECISIONS_LOG.md).
4. Add an entry to [SESSION_LOG.md](./SESSION_LOG.md).
5. If `PROJECT_CONTEXT.md` facts changed (new module, new dep, etc.), update it.

Do not rely only on chat memory. If chat contradicts a markdown file, the markdown file wins.

## 2. Core architectural principles (from the constitution)

### Principle I — Feature-First Clean Architecture

Every user-facing capability MUST live under `lib/features/<feature>/` with the three-way split:

- `data/` — Firestore / Functions DTOs and repositories.
- `domain/models/` — plain domain types (only where a feature genuinely needs them).
- `presentation/` — `cubit/` and `screens/`.

Cross-feature code MUST live under `lib/core/` (routing, theme, constants, services) or `lib/shared/widgets/` (reusable UI). It MUST NOT be co-located inside a feature folder.

**Rationale**: `lib/app/app.dart` wires every repository and Cubit into a single top-level `MultiBlocProvider`. That only works if features stay self-contained and never reach into each other's `data/` or `presentation/` layers.

### Principle II — Cubit State Management Discipline

State management MUST use `flutter_bloc` `Cubit`. `Bloc` event classes are disallowed.

- State classes MUST be immutable.
- Each state class MUST expose a `copyWith` plus explicit `clear*` flags for nullable fields (see `AuthState` in [lib/features/auth/presentation/cubit/auth_cubit.dart](../../lib/features/auth/presentation/cubit/auth_cubit.dart) as the reference pattern).
- Features MUST consume cubits via `context.read<XCubit>()` from the app-level provider.
- Local `BlocProvider` instantiation inside a screen is forbidden unless the cubit's lifetime is strictly scoped to that screen, and the exception is documented in the PR description.

**Rationale**: Uniform state shape makes Cubits composable with the FCM deep-link flow that navigates via `AppNavigator.navigatorKey` without a `BuildContext`.

### Principle III — Firestore Rules & Server-Authoritative Writes (NON-NEGOTIABLE)

`firestore.rules` is the authoritative access matrix.

- Any change to a Firestore collection's shape or access pattern MUST be accompanied by the matching rules update in the same PR.
- Firestore field and collection names MUST come from `lib/core/constants/firebase_paths.dart`. String literals for Firestore paths are prohibited in feature code.
- The client MUST NOT write to `task_logs/` — it is server-only (`allow write: if false`).
- The client MUST NOT duplicate FCM / notification writes that Cloud Functions already produce (`sendTaskAssignedNotification`, `sendTaskStatusNotification`, the deadline/overdue crons, `createInAppNotification`).
- New task-lifecycle events MUST be added in `functions/index.js` first, then consumed by the client.

**Rationale**: Two write paths for the same event desynchronize quickly and can mask security-rule regressions. Centralizing audit-style writes server-side is how the role model stays enforceable.

### Principle IV — Shared Design System & Localization

- All user-visible text MUST be a translation key resolved via `easy_localization` (`.tr()`).
- New keys MUST be added to both `assets/translations/en.json` and `assets/translations/ar.json`.
- Hard-coded English strings in widgets are prohibited.
- UI MUST prefer the shared widgets in `lib/shared/widgets/` (`AppCard`, `AppDrawer`, `AppPieChart`, `ChartLegend`, `EmptyStateWidget`, `PriorityBadge`, `SectionHeader`, `StatusBadge`) and theme values from `lib/core/theme/` + `lib/core/constants/` over rolling bespoke equivalents.
- New reusable components MUST land in `lib/shared/widgets/` before a second feature consumes them.

**Rationale**: Arabic is a first-class locale, not an afterthought — a missing translation key ships a broken screen. The shared widget set is the only way status/priority rendering stays consistent between the admin and employee shells.

### Principle V — Quality Gates Before Merge (NON-NEGOTIABLE)

Every PR MUST pass, locally or in CI, before review approval:

- `flutter analyze` — zero warnings (the `flutter_lints` rule set is authoritative).
- `flutter test` — all existing tests green; new behavior SHOULD land with at least one widget or unit test when the change is non-trivial.
- `npm run lint` in `functions/` — mandatory whenever `functions/` is touched (it also runs as Firebase `predeploy`).

Breakage of any gate blocks merge. Gates MUST NOT be bypassed with `--no-verify`, `// ignore:` comments, or lint suppressions without a reviewer-approved justification captured in the PR description.

**Rationale**: There is no separate QA environment — these gates are the only automated signal that a change is safe to deploy to the single `techno-staff` Firebase project.

## 3. Platform standards

- **Platform targets**: Flutter (Dart `^3.9.2`) targeting Android, iOS, and Web.
- **Firebase project**: `techno-staff` (see `.firebaserc`, `lib/firebase_options.dart`).
- **Backend runtime**: Firebase Cloud Functions, Node 22, single file at `functions/index.js`. Splitting into multiple files is allowed only once the single file exceeds coherent responsibility boundaries; the split MUST be documented in the PR.
- **Routing**: All navigation MUST go through `AppRouter.onGenerateRoute` with route names from `lib/core/routes/route_names.dart`. FCM deep-linking MUST use `AppNavigator.navigatorKey` and route to `RouteNames.taskDetails` with a string `taskId`. `TaskDetailsLoaderScreen` is the required entry point when only an id (not a full `TaskModel`) is available.
- **Roles**: The two-role model (`admin`, `employee`) is fixed. Adding a third role requires a documented decision in `DECISIONS_LOG.md` because it affects Firestore rules, both role shells, and the `createEmployeeUser` function.
- **Secrets & config**: `lib/firebase_options.dart` is generated output — do not hand-edit. Service-account keys, `.env` files, and any credential material MUST stay out of the repository.

## 4. Git & commit conventions

### Branches

- `main` — production. Only fast-forwarded from `dev` at release points.
- `dev` — integration branch. All feature/fix/chore work merges here first.
- `feature/<short-name>` — new feature work.
- `fix/<short-name>` — bug fixes.
- `chore/<short-name>` — tooling, docs, non-functional work.
- `refactor/<short-name>` — internal refactors with no behavior change.

### Commit messages

Conventional-style subject prefixes, matching the existing history:

- `feat(<scope>): …` — new capability for a user.
- `fix(<scope>): …` — bug fix.
- `refactor(<scope>): …` — internal change without behavior change.
- `docs(<scope>): …` — docs only.
- `core(<scope>): …` — cross-cutting / infrastructure.
- `chore(<scope>): …` — tooling.

Keep the subject ≤ 72 chars. Use the body only when the "why" is non-obvious.

AI co-author trailers are allowed. Do not use `--no-verify` unless the user explicitly asks for it.

### PRs

- Target `dev` unless explicitly releasing to `main`.
- PR description MUST include: short summary, what changed, and how it was tested.
- At least one reviewer approval is required.
- Reviewers MUST verify: no string-literal Firestore paths, no duplicated notification writes, no hard-coded user-facing strings, and that the quality gates (Principle V) ran.

## 5. What agents MUST NOT do without asking

AI agents must ask for explicit user confirmation before taking any of the following actions:

- **Changing architecture** — touching the feature split, the top-level Cubit wiring, the routing model, or the role model.
- **Changing `firestore.rules`** — the security surface is not a casual edit. Always explain the risk and the fix first.
- **Touching Cloud Functions** — adding a new trigger, changing an existing one, or altering cron schedules.
- **Adding or upgrading dependencies** — both Flutter (`pubspec.yaml`) and Functions (`functions/package.json`).
- **Destructive git operations** — `push --force`, `reset --hard`, branch deletion, `git clean -f`, history rewrites.
- **Pushing to `main`** — ever.
- **Amending a pushed commit** — always prefer new commits.
- **Bypassing quality gates** — `--no-verify`, `// ignore:`, disabling lints.
- **Adding a new role** — see Platform Standards.
- **Changing the localization strategy** or removing a locale.
- **Creating new top-level directories** outside the existing `lib/`, `functions/`, `docs/`, and platform folders.
- **Editing `lib/firebase_options.dart`** — it is generated output.
- **Committing secrets** — service-account keys, `.env`, API keys, or any credential material.

If a task seems to require one of the above, stop and ask first. Explain the risk, propose the smallest safe step, and wait for approval.

## 6. Security-sensitive changes

For any change touching authentication, Firestore rules, Cloud Functions, or the role model, the agent MUST:

1. Explain the risk in plain terms before making the change.
2. Describe the smallest safe fix.
3. Wait for explicit approval before editing.
4. After the change, update `DECISIONS_LOG.md` if the decision is non-trivial.

## 7. Testing expectations

- `flutter test` MUST remain green on every PR.
- New non-trivial behavior SHOULD land with at least one widget or unit test.
- Critical flows (auth, task lifecycle, notifications) SHOULD gain regression tests over time. Track specific coverage goals in `NEXT_STEPS.md`.

## 8. Governance of this file

- Any material change to `RULES.md` MUST be accompanied by an entry in `DECISIONS_LOG.md`.
- Small clarifications (wording, typos) can be made in place.
- Adding or removing a NON-NEGOTIABLE rule requires an explicit user decision logged in `DECISIONS_LOG.md`.
