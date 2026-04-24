# Decisions Log

> Append-only log of non-trivial technical or product decisions. Newest at the top.

Decisions capture "why we did it" so that a future reader (human or AI) can tell whether a constraint is still load-bearing or safe to revisit.

---

## Template

```
### YYYY-MM-DD — <Short decision title>

- **Decision**: What did we decide?
- **Reason**: Why? What alternatives did we consider?
- **Impact**: What changes because of this decision? Who / what is affected?
- **Owner**: Who made the call?
- **Related**: Links to PRs, commits, backlog items, or other decisions.
```

---

## 2026-04-24 — Adopt `/docs/ai-workflow/` as the single shared source of truth

- **Decision**: All cross-session project context, rules, decisions, backlog, and forward-looking ideas live under `/docs/ai-workflow/` as plain markdown. Every AI agent and human developer reads these files before starting a task and updates them after finishing.
- **Reason**: We work with multiple AI agents that do not share memory across sessions. A file-based source of truth prevents drift, reduces hallucinations, and survives changes to the specific models or tools we use.
- **Impact**: New mandatory workflow — see `RULES.md` for the "Workflow for every task" section. `CLAUDE.md` now points here as the entry point.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md`, `PROJECT_CONTEXT.md`.

## 2026-04-24 — Remove Spec Kit; migrate the constitution into `RULES.md`

- **Decision**: Delete `specs/`, `.specify/`, and the `speckit-*` skills under `.claude/skills/`. The ratified constitution v1.0.0 (previously in `.specify/memory/constitution.md`) moves into `/docs/ai-workflow/RULES.md`. Spec Kit slash commands are no longer the workflow.
- **Reason**: The team prefers one lightweight markdown-based workflow over two overlapping systems. Spec Kit introduced `/specs/` folders, templates, and slash commands that duplicated what `/docs/ai-workflow/` will cover. Keeping both would split context across two systems and increase the chance of stale docs.
- **Impact**: Fewer concepts to keep in sync. All project rules live in one file. No more `/speckit.*` commands; new features are documented via `CURRENT_TASK.md` + `BACKLOG.md` + (optionally) a short design note inside the PR description.
- **Owner**: Mohamed Odeh.
- **Related**: `RULES.md` (contains the migrated constitution content).
