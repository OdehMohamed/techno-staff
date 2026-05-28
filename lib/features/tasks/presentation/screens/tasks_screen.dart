import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/task_model.dart';
import '../cubit/tasks_cubit.dart';
import '../cubit/tasks_state.dart';
import '../widgets/countdown_chip.dart';
import '../widgets/countdown_clock_provider.dart';
import '../widgets/task_filter_bottom_sheet.dart';

enum _QuickFilter { overdue, dueSoon, highPriority }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  TaskFilters _filters = const TaskFilters();
  Set<_QuickFilter> _quickFilters = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
      if (context.read<AuthCubit>().state.user?.role == 'admin') {
        context.read<EmployeesCubit>().fetchEmployees(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool silent = false}) async {
    final authState = context.read<AuthCubit>().state;
    final user = authState.user;

    if (user == null) return;

    if (user.role == 'admin') {
      await Future.wait([
        context.read<TasksCubit>().fetchAllTasks(silent: silent),
        context.read<TasksCubit>().fetchTasksAssignedTo(
          user.id,
          silent: silent,
        ),
      ]);
    } else {
      await Future.wait([
        context.read<TasksCubit>().fetchTasksAssignedTo(
          user.id,
          silent: silent,
        ),
        context.read<TasksCubit>().fetchTasksCreatedBy(user.id, silent: silent),
      ]);
    }
  }

  Future<void> _loadCompletedTasks({bool silent = false}) async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    await context.read<TasksCubit>().fetchCompletedTasks(
      userId: user.id,
      isAdmin: user.role == 'admin',
      silent: silent,
    );
  }

  Future<void> _openFilterBottomSheet() async {
    final isAdmin =
        context.read<AuthCubit>().state.user?.role == 'admin';
    final employees = isAdmin
        ? context.read<EmployeesCubit>().state.employees
        : <AppUser>[];
    final selectedFilters = await showModalBottomSheet<TaskFilters>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return TaskFilterBottomSheet(
          initialFilters: _filters,
          employees: employees,
          isAdmin: isAdmin,
        );
      },
    );

    if (!context.mounted) return;
    if (selectedFilters == null) return;

    setState(() {
      _filters = selectedFilters;
    });
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  List<TaskModel> _applyFilters(List<TaskModel> source) {
    final query = _filters.searchQuery.trim().toLowerCase();
    final highPriorityOnly = _quickFilters.contains(_QuickFilter.highPriority);

    final filtered = source.where((task) {
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          task.assignedToName.toLowerCase().contains(query) ||
          task.assignedByName.toLowerCase().contains(query);

      final matchesStatus =
          _filters.statusFilter == 'all' ||
          task.status == _filters.statusFilter;

      final matchesPriority =
          _filters.priorityFilter == 'all' ||
          task.priority == _filters.priorityFilter;

      final matchesQuickPriority =
          !highPriorityOnly || task.priority == 'high';

      final matchesAssignee =
          _filters.filterAssigneeId == null ||
          task.assignedTo == _filters.filterAssigneeId;

      return matchesSearch && matchesStatus && matchesPriority &&
          matchesQuickPriority && matchesAssignee;
    }).toList();

    switch (_filters.sortOption) {
      case TaskSortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortOption.dueDateSoonest:
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSortOption.priorityHighestFirst:
        filtered.sort((a, b) {
          final cmp =
              _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return filtered;
  }

  /// Like [_applyFilters] but for completed tasks: skips the status filter
  /// (irrelevant — everything is completed) and keeps [completedAt] DESC
  /// ordering for the default sort instead of re-sorting by [createdAt].
  List<TaskModel> _applyCompletedFilters(List<TaskModel> source) {
    final query = _filters.searchQuery.trim().toLowerCase();
    final highPriorityOnly = _quickFilters.contains(_QuickFilter.highPriority);

    final filtered = source.where((task) {
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          task.assignedToName.toLowerCase().contains(query) ||
          task.assignedByName.toLowerCase().contains(query);

      final matchesPriority =
          _filters.priorityFilter == 'all' ||
          task.priority == _filters.priorityFilter;

      final matchesQuickPriority =
          !highPriorityOnly || task.priority == 'high';

      final matchesAssignee =
          _filters.filterAssigneeId == null ||
          task.assignedTo == _filters.filterAssigneeId;

      return matchesSearch && matchesPriority && matchesQuickPriority &&
          matchesAssignee;
    }).toList();

    switch (_filters.sortOption) {
      case TaskSortOption.newestFirst:
        // Preserve completedAt DESC ordering that came from Firestore.
        break;
      case TaskSortOption.dueDateSoonest:
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSortOption.priorityHighestFirst:
        filtered.sort((a, b) {
          final cmp =
              _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
          if (cmp != 0) return cmp;
          final aAt = a.completedAt;
          final bAt = b.completedAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
        break;
    }

    return filtered;
  }

  List<DateTime> _collectVisibleDueDates(TasksState state, bool isAdmin) {
    final lists = <List<TaskModel>>[
      state.tasks,
      state.tasksAssignedToMe,
      state.tasksCreatedByMe,
    ];
    return [
      for (final list in lists)
        for (final task in list)
          if (task.status != 'completed') task.dueDate,
    ];
  }

  /// Effective deadline for urgency comparisons. Date-only tasks use local
  /// 23:59:59 of the due calendar day so they move to "Overdue" only after the
  /// day ends, regardless of what time the date picker stored in dueDate.
  DateTime _effectiveDeadline(TaskModel t) {
    if (t.hasDueTime) return t.dueDate;
    return DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day, 23, 59, 59);
  }

  Widget _buildSearchAndFiltersBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _filters = _filters.copyWith(searchQuery: value);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'search_tasks'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filters = _filters.copyWith(searchQuery: '');
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Badge(
              isLabelVisible: _filters.hasActiveNonSearchFilters,
              child: IconButton(
                tooltip: 'filters'.tr(),
                onPressed: _openFilterBottomSheet,
                icon: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        _buildQuickFiltersRow(),
      ],
    );
  }

  Widget _buildQuickFiltersRow() {
    final cs = Theme.of(context).colorScheme;
    final hasAnyActive =
        _quickFilters.isNotEmpty || _filters.hasActiveNonSearchFilters;

    void toggle(_QuickFilter f) {
      setState(() {
        final next = Set<_QuickFilter>.from(_quickFilters);
        if (next.contains(f)) {
          next.remove(f);
        } else {
          next.add(f);
        }
        _quickFilters = next;
      });
    }

    bool has(_QuickFilter f) => _quickFilters.contains(f);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            avatar: has(_QuickFilter.overdue)
                ? null
                : Icon(Icons.warning_amber_rounded,
                    size: 16, color: cs.error),
            label: Text('urgency_overdue'.tr()),
            selected: has(_QuickFilter.overdue),
            selectedColor: cs.errorContainer,
            checkmarkColor: cs.onErrorContainer,
            labelStyle: has(_QuickFilter.overdue)
                ? TextStyle(color: cs.onErrorContainer)
                : null,
            onSelected: (_) => toggle(_QuickFilter.overdue),
          ),
          const SizedBox(width: AppSizes.xs),
          FilterChip(
            avatar: has(_QuickFilter.dueSoon)
                ? null
                : const Icon(Icons.schedule, size: 16),
            label: Text('due_soon'.tr()),
            selected: has(_QuickFilter.dueSoon),
            onSelected: (_) => toggle(_QuickFilter.dueSoon),
          ),
          const SizedBox(width: AppSizes.xs),
          FilterChip(
            avatar: has(_QuickFilter.highPriority)
                ? null
                : const Icon(Icons.keyboard_double_arrow_up, size: 16),
            label: Text('high'.tr()),
            selected: has(_QuickFilter.highPriority),
            onSelected: (_) => toggle(_QuickFilter.highPriority),
          ),
          if (hasAnyActive) ...[
            const SizedBox(width: AppSizes.xs),
            ActionChip(
              avatar: const Icon(Icons.close, size: 16),
              label: Text('clear_filters'.tr()),
              onPressed: _clearAllFilters,
            ),
          ],
        ],
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _filters = const TaskFilters();
      _quickFilters = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text('tasks'.tr())),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, RouteNames.addTask);

          if (result == true && mounted) {
            _loadTasks();
          }
        },
        icon: const Icon(Icons.add),
        label: Text('add_task'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocBuilder<TasksCubit, TasksState>(
              builder: (context, state) {
                if (user != null) {
                  final shouldLoadAdmin =
                      isAdmin &&
                      state.status == TasksStatus.initial &&
                      state.tasksAssignedToMeStatus == TasksStatus.initial;
                  final shouldLoadEmployee =
                      !isAdmin &&
                      state.tasksAssignedToMeStatus == TasksStatus.initial &&
                      state.tasksCreatedByMeStatus == TasksStatus.initial;

                  if (shouldLoadAdmin || shouldLoadEmployee) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _loadTasks();
                    });
                  }
                }

                final visibleDueDates = _collectVisibleDueDates(state, isAdmin);

                if (isAdmin) {
                  return CountdownClockProvider(
                    dueDates: visibleDueDates,
                    child: _buildAdminTabs(state, user),
                  );
                }

                return CountdownClockProvider(
                  dueDates: visibleDueDates,
                  child: _buildEmployeeTabs(state, user),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTabs(TasksState state, AppUser? user) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFiltersBar(),
          const SizedBox(height: AppSizes.md),
          SectionHeader(title: 'tasks'.tr(), subtitle: 'tasks_overview'.tr()),
          TabBar(
            tabs: [
              Tab(text: 'assigned_to_me'.tr()),
              Tab(text: 'all_tasks'.tr()),
              Tab(text: 'completed'.tr()),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Expanded(
            child: TabBarView(
              children: [
                _buildTasksTabContent(
                  status: state.tasksAssignedToMeStatus,
                  errorKey: state.tasksAssignedToMeErrorMessage,
                  tasks: state.tasksAssignedToMe,
                  currentUser: user,
                  isAdmin: true,
                ),
                _buildTasksTabContent(
                  status: state.status,
                  errorKey: state.errorMessage,
                  tasks: state.tasks,
                  currentUser: user,
                  isAdmin: true,
                ),
                _buildCompletedTabContent(
                  state: state,
                  currentUser: user,
                  isAdmin: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTabs(TasksState state, AppUser? user) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFiltersBar(),
          const SizedBox(height: AppSizes.md),
          SectionHeader(
            title: 'tasks'.tr(),
            subtitle: 'Track and update your assigned tasks'.tr(),
          ),
          TabBar(
            tabs: [
              Tab(text: 'assigned_to_me'.tr()),
              Tab(text: 'created_by_me'.tr()),
              Tab(text: 'completed'.tr()),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Expanded(
            child: TabBarView(
              children: [
                _buildTasksTabContent(
                  status: state.tasksAssignedToMeStatus,
                  errorKey: state.tasksAssignedToMeErrorMessage,
                  tasks: state.tasksAssignedToMe,
                  currentUser: user,
                  isAdmin: false,
                ),
                _buildTasksTabContent(
                  status: state.tasksCreatedByMeStatus,
                  errorKey: state.tasksCreatedByMeErrorMessage,
                  tasks: state.tasksCreatedByMe,
                  currentUser: user,
                  isAdmin: false,
                ),
                _buildCompletedTabContent(
                  state: state,
                  currentUser: user,
                  isAdmin: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTabContent({
    required TasksStatus status,
    required String? errorKey,
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadTasks(silent: true),
      child: _buildTasksTabBody(
        status: status,
        errorKey: errorKey,
        tasks: tasks,
        currentUser: currentUser,
        isAdmin: isAdmin,
      ),
    );
  }

  Widget _buildTasksTabBody({
    required TasksStatus status,
    required String? errorKey,
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    if (status == TasksStatus.loading && tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (status == TasksStatus.error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateWidget(
            icon: Icons.error_outline,
            titleKey: errorKey ?? 'unknown_error',
          ),
        ],
      );
    }

    final filteredTasks = _applyFilters(tasks);

    if (filteredTasks.isEmpty) {
      if (tasks.isNotEmpty && _filters.hasActiveFilters) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyStateWidget(
              icon: Icons.search_off,
              titleKey: 'no_matching_tasks',
            ),
          ],
        );
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyStateWidget(
            icon: Icons.task_alt_outlined,
            titleKey: 'no_tasks_found',
          ),
        ],
      );
    }

    final hasAnyActive = _filters.hasActiveFilters || _quickFilters.isNotEmpty;

    return Column(
      children: [
        if (hasAnyActive)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'tasks_count_short'.tr(
                      args: [
                        filteredTasks.length.toString(),
                        tasks.length.toString(),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.close),
                  label: Text('clear_filters'.tr()),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildTasksList(
            tasks: filteredTasks,
            currentUser: currentUser,
            isAdmin: isAdmin,
          ),
        ),
      ],
    );
  }

  Widget _buildTasksList({
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    final now = DateTime.now();
    final endOfTomorrow = DateTime(now.year, now.month, now.day + 2);
    final endOfWeek = DateTime(now.year, now.month, now.day + 8);

    final showOverdue = _quickFilters.contains(_QuickFilter.overdue);
    final showDueSoon = _quickFilters.contains(_QuickFilter.dueSoon);
    final hasUrgencyFilter = showOverdue || showDueSoon;

    bool groupVisible(String key) {
      if (!hasUrgencyFilter) return true;
      if (key == 'urgency_overdue') return showOverdue;
      if (key == 'urgency_today_tomorrow') return showDueSoon;
      return false; // This Week and Later are collapsed when urgency filter active
    }

    final groups = [
      ('urgency_overdue', tasks.where((t) => _effectiveDeadline(t).isBefore(now)).toList()),
      (
        'urgency_today_tomorrow',
        tasks
            .where(
              (t) =>
                  !_effectiveDeadline(t).isBefore(now) &&
                  _effectiveDeadline(t).isBefore(endOfTomorrow),
            )
            .toList(),
      ),
      (
        'urgency_this_week',
        tasks
            .where(
              (t) =>
                  !_effectiveDeadline(t).isBefore(endOfTomorrow) &&
                  _effectiveDeadline(t).isBefore(endOfWeek),
            )
            .toList(),
      ),
      ('urgency_later', tasks.where((t) => !_effectiveDeadline(t).isBefore(endOfWeek)).toList()),
    ].where((g) => g.$2.isNotEmpty && groupVisible(g.$1)).toList();

    final children = <Widget>[];
    for (final (key, groupTasks) in groups) {
      children.add(_UrgencyGroupHeader(
        label: key.tr(),
        isOverdue: key == 'urgency_overdue',
      ));
      for (final task in groupTasks) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: AppSizes.sm),
          child: _buildTaskCard(
            task: task,
            currentUser: currentUser,
            isAdmin: isAdmin,
          ),
        ));
      }
      children.add(const SizedBox(height: AppSizes.sm));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  Widget _buildTaskCard({
    required TaskModel task,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            RouteNames.taskDetails,
            arguments: task,
          );

          if (result == true && mounted) {
            _loadTasks();
            final cubit = context.read<TasksCubit>();
            if (cubit.state.completedTasksStatus != TasksStatus.initial) {
              _loadCompletedTasks(silent: true);
            }
          }
        },
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isAdmin && task.assignedTo != currentUser?.id) ...[
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedToName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSizes.md),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  PriorityBadge(priority: task.priority),
                  if (task.isCounter) const _CounterTypeBadge(),
                  CountdownChip(
                    dueDate: task.dueDate,
                    hasDueTime: task.hasDueTime,
                    isCompleted: task.status == 'completed',
                  ),
                ],
              ),
              if (currentUser != null &&
                  task.assignedTo == currentUser.id &&
                  task.status != 'completed') ...[
                const SizedBox(height: AppSizes.lg),
                if (task.isCounter)
                  _CounterProgressRow(
                    task: task,
                    onIncrement:
                        task.currentCount >= (task.targetCount ?? 0)
                        ? null
                        : () {
                            context.read<TasksCubit>().incrementTaskCounter(
                              taskId: task.id,
                              isAdmin: isAdmin,
                              currentUserId: currentUser.id,
                              currentUserName: currentUser.name,
                            );
                          },
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: task.status,
                    decoration: InputDecoration(
                      labelText: 'update_status'.tr(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('pending'.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('in_progress'.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('completed'.tr()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      context.read<TasksCubit>().updateTaskStatus(
                        taskId: task.id,
                        status: value,
                        isAdmin: isAdmin,
                        currentUserId: currentUser.id,
                        currentUserName: currentUser.name,
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Completed tab ────────────────────────────────────────────────────────

  Widget _buildCompletedTabContent({
    required TasksState state,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadCompletedTasks(silent: true),
      child: _buildCompletedTabBody(
        status: state.completedTasksStatus,
        errorKey: state.completedTasksErrorMessage,
        tasks: state.completedTasks,
        currentUser: currentUser,
        isAdmin: isAdmin,
      ),
    );
  }

  Widget _buildCompletedTabBody({
    required TasksStatus status,
    required String? errorKey,
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    if (status == TasksStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadCompletedTasks();
      });
    }

    if (status == TasksStatus.loading && tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (status == TasksStatus.error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateWidget(
            icon: Icons.error_outline,
            titleKey: errorKey ?? 'unknown_error',
          ),
        ],
      );
    }

    final filtered = _applyCompletedFilters(tasks);
    final hasAnyActive = _filters.hasActiveFilters || _quickFilters.isNotEmpty;

    if (filtered.isEmpty) {
      if (tasks.isNotEmpty && hasAnyActive) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyStateWidget(
              icon: Icons.search_off,
              titleKey: 'no_matching_tasks',
            ),
          ],
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyStateWidget(
            icon: Icons.task_alt,
            titleKey: 'no_tasks_found',
          ),
        ],
      );
    }

    return Column(
      children: [
        if (hasAnyActive)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'tasks_count_short'.tr(
                      args: [
                        filtered.length.toString(),
                        tasks.length.toString(),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.close),
                  label: Text('clear_filters'.tr()),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildCompletedTasksList(
            tasks: filtered,
            currentUser: currentUser,
            isAdmin: isAdmin,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTasksList({
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    final now = DateTime.now();
    final weekAgo = DateTime(now.year, now.month, now.day - 6);
    final monthStart = DateTime(now.year, now.month, 1);

    final thisWeek = <TaskModel>[];
    final thisMonth = <TaskModel>[];
    final older = <TaskModel>[];

    for (final task in tasks) {
      final at = task.completedAt;
      if (at == null) {
        older.add(task);
      } else if (!at.isBefore(weekAgo)) {
        thisWeek.add(task);
      } else if (!at.isBefore(monthStart)) {
        thisMonth.add(task);
      } else {
        older.add(task);
      }
    }

    final groups = [
      ('completed_this_week', thisWeek),
      ('completed_this_month', thisMonth),
      ('completed_older', older),
    ].where((g) => g.$2.isNotEmpty).toList();

    final children = <Widget>[];
    for (final (key, groupTasks) in groups) {
      children.add(_UrgencyGroupHeader(label: key.tr()));
      for (final task in groupTasks) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: AppSizes.sm),
          child: _buildTaskCard(
            task: task,
            currentUser: currentUser,
            isAdmin: isAdmin,
          ),
        ));
      }
      children.add(const SizedBox(height: AppSizes.sm));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _UrgencyGroupHeader extends StatelessWidget {
  final String label;
  final bool isOverdue;

  const _UrgencyGroupHeader({required this.label, this.isOverdue = false});

  @override
  Widget build(BuildContext context) {
    final color = isOverdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm, bottom: AppSizes.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    );
  }
}

class _CounterTypeBadge extends StatelessWidget {
  const _CounterTypeBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.numbers, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'task_type_counter'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterProgressRow extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onIncrement;

  const _CounterProgressRow({required this.task, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    final target = task.targetCount ?? 0;
    final current = task.currentCount.clamp(0, target);
    final ratio = target == 0 ? 0.0 : current / target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${'progress'.tr()}: $current / $target',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: onIncrement,
              tooltip: 'increment'.tr(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio, minHeight: 8),
        ),
      ],
    );
  }
}
