# Current Task

> Last updated: 2026-04-24

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Organize the shared AI / developer workflow under `/docs/ai-workflow/`.**

## Goal

Establish a single, markdown-based source of truth that any AI agent (Claude, Cursor, Copilot, ChatGPT, Gemini, etc.) or human developer can read before starting a task, so work stays consistent and nothing gets lost between sessions or between assistants.

## Scope

- Create `/docs/ai-workflow/` with 7 files: `PROJECT_CONTEXT.md`, `CURRENT_TASK.md`, `BACKLOG.md`, `DECISIONS_LOG.md`, `RULES.md`, `NEXT_STEPS.md`, `SESSION_LOG.md`.
- Migrate the ratified Spec Kit constitution (`.specify/memory/constitution.md`) into `RULES.md` and extend it with git/commit conventions and agent rules.
- Remove the unused Spec Kit artifacts (`specs/`, `.specify/`, and the `speckit-*` skills in `.claude/skills/`).
- Add a short pointer from `CLAUDE.md` to `/docs/ai-workflow/`.

## Out of Scope (for this task)

- Identifying bugs or opening issues.
- Adding features.
- Populating `BACKLOG.md` with real items — we are intentionally starting with an empty, well-structured backlog.
- Running any kind of audit.

## Steps

1. ✅ Review current repo state and decide on structure.
2. ✅ Create branch `chore/ai-workflow-docs`.
3. ⏳ Create `/docs/ai-workflow/` with all 7 files.
4. ⏳ Migrate constitution content into `RULES.md`.
5. ⏳ Add pointer to `/docs/ai-workflow/` from `CLAUDE.md`.
6. ⏳ Delete `specs/`, `.specify/`, and `speckit-*` skills under `.claude/skills/`.
7. ⏳ Commit on `chore/ai-workflow-docs`.

## Files Likely Affected

- `docs/ai-workflow/*.md` — new.
- `CLAUDE.md` — small addition pointing to the workflow folder.
- `specs/` — deleted.
- `.specify/` — deleted.
- `.claude/skills/speckit-*` — deleted.

## Definition of Done

- [ ] All 7 markdown files exist under `/docs/ai-workflow/` and render correctly.
- [ ] Constitution principles are preserved inside `RULES.md` (no content loss).
- [ ] `specs/`, `.specify/`, and all `speckit-*` skills are gone.
- [ ] `CLAUDE.md` references `/docs/ai-workflow/` as the starting point.
- [ ] Changes are committed on `chore/ai-workflow-docs` with a conventional-style message.
- [ ] `SESSION_LOG.md` has an entry for this session.
