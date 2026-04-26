# Current Task

> Last updated: 2026-04-27

Only one task is active at a time. When this task is done, either replace the content with the next task or leave a short "No active task" note until one is picked.

---

## Active Task

**Add task search and filtering — backlog item "Add task search and filtering".**

## Goal

Improve task discoverability and organization. Users with many tasks across statuses should be able to find what they need fast — search by text, narrow by status / priority, and re-order by what matters now. All client-side; no Firestore queries change, no rules change.

## Branch

`feature/task-search-and-filtering`, branched from `dev` after PR #9 merged. The branch already exists locally and on `origin` once this planning commit is pushed — do **not** create a new branch.

## Product decisions (locked 2026-04-27)

1. **Search scope**: title + description + `assignedToName` + `assignedByName`. Live filter as the user types (no debounce — pure Dart on hundreds of items).
2. **Filter dimensions**: status (`pending` / `in_progress` / `completed` / `all`) + priority (`low` / `medium` / `high` / `all`). Assignee filter and date range are explicitly out of scope.
3. **Sort options** (3): newest first (`createdAt` desc, default), due date soonest (`dueDate` asc), priority highest first.
4. **Filter state**: GLOBAL across tabs — one filter set applies to whichever tab the user is viewing.
5. **State location**: local widget state on `_TasksScreenState` (`setState`) — not pushed into `TasksState`. Resets on screen leave; that is fine for a list view.
6. **UI placement**: search field + filter button visible above the `TabBar` (screen-level); per-tab the body shows result count + "Clear filters" + appropriate empty state.
7. **Bottom sheet for filters**: tapping the filter button opens a `showModalBottomSheet` with status, priority, and sort sections plus an "Apply" button. Filter button shows a badge dot when any non-default filter is active.
8. **Distinct empty state** when filters yield zero results: new `no_matching_tasks` key with a hint to clear filters.

## Scope — file-by-file

### 1. **NEW** — `lib/features/tasks/presentation/widgets/task_filter_bottom_sheet.dart`

A new feature-local widget folder; first widget in it.

- Stateless widget (uses internal `StatefulWidget` only if needed for the in-sheet selection). Receives the current filter values and an apply callback (or returns a result via `Navigator.pop<TaskFilterResult>`).
- Three sections (each with a localized header):
  - **Status** — segmented chips / `ChoiceChip` row: All, Pending, In progress, Completed.
  - **Priority** — segmented chips / `ChoiceChip` row: All, Low, Medium, High.
  - **Sort by** — radio list (or `RadioListTile`) with the three options from product decision #3.
- "Apply" button at the bottom that pops the sheet with the selected values.
- "Cancel" / dismiss via tapping outside or the system back gesture (no commit).
- Reuses existing `cancel`, `pending`, `in_progress`, `completed`, `low`, `medium`, `high`, `apply` translation keys (some new — see §4).

Define a small public value class in this file:

```dart
enum TaskSortOption { newestFirst, dueDateSoonest, priorityHighestFirst }

class TaskFilters {
  final String searchQuery;
  final String statusFilter;   // 'all' | 'pending' | 'in_progress' | 'completed'
  final String priorityFilter; // 'all' | 'low' | 'medium' | 'high'
  final TaskSortOption sortOption;
  const TaskFilters({...defaults...});
  TaskFilters copyWith({...});
  bool get hasActiveFilters; // true iff any non-default OR searchQuery non-empty
  bool get hasActiveNonSearchFilters; // for the badge — excludes search, sort default counts as inactive
}
```

`TaskFilters` lives in this file (it is a pure value object, used by the sheet and by the screen). It does **not** belong in `TasksState` — local screen state only.

### 2. `lib/features/tasks/presentation/screens/tasks_screen.dart`

- Add a private `TaskFilters _filters = const TaskFilters();` to `_TasksScreenState`. Default: empty search, status='all', priority='all', sort=newestFirst.
- Add a `final TextEditingController _searchController = TextEditingController();` disposed in `dispose()`.
- Build a row above the `TabBar` (and above the existing `SectionHeader`) containing:
  - A `TextField` for search bound to `_searchController` with placeholder `'search_tasks'.tr()`, a leading `Icons.search`, and a trailing `Icons.close` clear button visible when the field is non-empty. Updating it calls `setState` to update `_filters.searchQuery`.
  - An `IconButton` with `Icons.tune` (or `Icons.filter_list`) wrapped in `Badge(isLabelVisible: _filters.hasActiveNonSearchFilters)` for the dot indicator. `onPressed` opens the bottom sheet via `showModalBottomSheet<TaskFilters>(...)`. The returned filters (if any) are merged into `_filters` via `setState`.
- A small helper `List<TaskModel> _applyFilters(List<TaskModel> source)`:
  1. Apply search (case-insensitive `contains` against title, description, assignedToName, assignedByName).
  2. Apply status filter (skip if `'all'`).
  3. Apply priority filter (skip if `'all'`).
  4. Sort using `TaskSortOption` (priority sort uses an internal `{high:3, medium:2, low:1}` rank).
  5. Return the new list (do not mutate the source).
- Pass the filtered list into the existing `_buildTasksList(...)`.
- Inside `_buildTasksTabContent` (or a new sibling helper), when the loaded list is non-empty, wrap the result with a small header row showing:
  - Result count: `'tasks_count_short'.tr(args: ['<filtered>', '<original>'])` rendered like `"5 of 23 tasks"` — only when `_filters.hasActiveFilters`.
  - "Clear filters" `TextButton` with `Icons.close` — only when `_filters.hasActiveFilters`. On tap: `setState(() { _filters = const TaskFilters(); _searchController.clear(); })`.
- For the empty state inside `_buildTasksList`, branch on the source list length:
  - source is empty AND `!_filters.hasActiveFilters` → existing `EmptyStateWidget(titleKey: 'no_tasks_found', icon: Icons.task_alt_outlined)`.
  - filtered is empty BUT source is not empty (i.e. filters cut everything) → `EmptyStateWidget(titleKey: 'no_matching_tasks', icon: Icons.search_off)`.
  - The list goes through filters at the screen level; pass both the original count and a `bool hasFilters` (or the `TaskFilters`) into `_buildTasksList` so it can pick the right empty state.

### 3. `lib/features/tasks/presentation/cubit/tasks_cubit.dart` and `tasks_state.dart`

**No changes.** Filter state lives in the screen.

### 4. Translations

Add **12 new keys** in both `assets/translations/en.json` and `assets/translations/ar.json`. Verify each does not already exist before adding (grep first).

| Key | EN | AR |
|---|---|---|
| `search_tasks` | "Search tasks" | "ابحث في المهام" |
| `filters` | "Filters" | "تصفية" |
| `sort_by` | "Sort by" | "ترتيب حسب" |
| `filter_by_status` | "Status" | "الحالة" |
| `filter_by_priority` | "Priority" | "الأولوية" |
| `all` | "All" | "الكل" |
| `sort_newest_first` | "Newest first" | "الأحدث أولاً" |
| `sort_due_date_soonest` | "Due soonest" | "الموعد الأقرب أولاً" |
| `sort_priority_highest_first` | "Priority (high → low)" | "الأولوية (الأعلى أولاً)" |
| `clear_filters` | "Clear filters" | "مسح التصفية" |
| `no_matching_tasks` | "No tasks match your search or filters" | "لا توجد مهام مطابقة لبحثك أو تصفيتك" |
| `apply` | "Apply" | "تطبيق" |
| `tasks_count_short` | "{} of {} tasks" | "{} من {} مهمة" |

Use `easy_localization` positional `{}` args for `tasks_count_short` (called as `'tasks_count_short'.tr(args: [filtered.toString(), original.toString()])`).

The existing keys are reused: `pending`, `in_progress`, `completed`, `low`, `medium`, `high`, `cancel`.

### 5. Tests

Optional. If a unit test for `_applyFilters` is straightforward to write (extract the helper as a top-level pure function in the screen file or in `task_filter_bottom_sheet.dart`), add one covering search + status + priority + each sort option. Skip if it would require extensive mocking. Do **not** add a brittle widget test for the bottom sheet just to tick a box.

### 6. Workflow docs (after implementation, before opening PR)

- **`docs/ai-workflow/DECISIONS_LOG.md`** — append "Task search and filtering — global state, client-side, bottom sheet UX" with: filter state is global across tabs, all filtering/sorting is client-side, search covers title + description + assigned-to/by names, sheet uses showModalBottomSheet with apply pattern.
- **`docs/ai-workflow/PROJECT_CONTEXT.md`** — small note under §4 Modules `tasks` row: mention search + filter + sort capability.
- **`docs/ai-workflow/BACKLOG.md`** — move the item "Add task search and filtering" out of `Should-fix` into `Done` with completion date.
- **`docs/ai-workflow/SESSION_LOG.md`** — add an entry for the implementation session.
- **`docs/ai-workflow/CURRENT_TASK.md`** — check every DoD item, then replace with a "No active task" placeholder.

## Quality gates (all must be green before PR)

- `flutter analyze` — zero warnings.
- `flutter test` — all green.
- `cd functions && npm run lint` — green (no functions changes expected; run anyway).

## Manual smoke tests

1. Search by title — typing "rep" finds tasks whose title contains "rep" (case-insensitive).
2. Search by description — typing finds tasks whose description matches.
3. Search by `assignedToName` (admin view) — typing a teammate's name finds tasks assigned to them.
4. Search by `assignedByName` — typing finds tasks created by that person.
5. Filter by status → "Pending" → only pending tasks shown.
6. Filter by priority → "High" → only high priority shown.
7. Combine search + status + priority → strictly intersected.
8. Sort by due date — list is ascending by `dueDate`.
9. Sort by priority — high tasks first, then medium, then low.
10. Filter button shows a badge dot when status, priority, or sort is non-default; the dot disappears when defaults are restored.
11. Result count "X of Y tasks" appears only when filters are active and reflects the visible count.
12. "Clear filters" resets everything (search, status, priority, sort) and the badge disappears.
13. Empty state when filters yield zero results uses `no_matching_tasks` (different copy from `no_tasks_found`).
14. Switch tabs while filtered — same filter applies on the new tab (global state).
15. Localization — toggle to Arabic; placeholder, sheet labels, sort labels, and empty state copy all show Arabic strings; RTL layout reads correctly.
16. No regressions: FAB still creates tasks, status dropdown still updates, tap-to-details still navigates, delete UI still works, admin tabs and employee tabs still function.

## Definition of Done

- [ ] `task_filter_bottom_sheet.dart` exists under `lib/features/tasks/presentation/widgets/` with `TaskFilters`, `TaskSortOption`, and the bottom-sheet widget.
- [ ] `tasks_screen.dart` holds the search controller and `_filters` in local state, and renders search field + filter button above `TabBar`.
- [ ] `_applyFilters` correctly handles search, status, priority, and the three sort options.
- [ ] Result count and "Clear filters" appear only when filters are active.
- [ ] Empty state distinguishes "no tasks at all" vs "no matches".
- [ ] Filter button badge reflects active non-search, non-default filters.
- [ ] All 13 translation keys added in both `en.json` and `ar.json` (no duplicates).
- [ ] `flutter analyze` clean, `flutter test` green, `functions/` ESLint green.
- [ ] All manual smoke tests pass.
- [ ] `DECISIONS_LOG.md` has an entry.
- [ ] `PROJECT_CONTEXT.md` `tasks` row updated.
- [ ] `BACKLOG.md` item moved to `Done`.
- [ ] `SESSION_LOG.md` entry added.
- [ ] `CURRENT_TASK.md` reset to "No active task".
- [ ] PR opened against `dev` titled `feat(tasks): add task search and filtering`.

## Out of scope

- No `firestore.rules` changes.
- No `functions/index.js` changes.
- No new repository or cubit methods. No `TasksState` shape changes.
- No assignee filter, no date-range filter, no multi-select filters.
- No server-side search (no Algolia, no Firestore composite indexes).
- No pagination / infinite scroll.
- No saved filters / "my views".
- No filtering on the dashboard or other screens.
- No new dependencies. No new top-level folders. No refactors outside the files listed above.

## Risks

- `tasks_screen.dart` is already 346 lines; the extraction of the bottom sheet is mandatory to keep this from ballooning.
- Filter state resets on screen leave (intentional). If the user navigates away to task details and back, filters reset. This is an accepted UX trade-off; flag for the user only if they hit it during smoke testing.
- For task volumes >5,000 the client-side approach would need revisiting. Current expected volumes are well within tolerances.
