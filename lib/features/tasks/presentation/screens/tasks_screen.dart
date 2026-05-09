import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
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

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  TaskFilters _filters = const TaskFilters();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTasks() {
    final authState = context.read<AuthCubit>().state;
    final user = authState.user;

    if (user == null) return;

    if (user.role == 'admin') {
      context.read<TasksCubit>().fetchAllTasks();
      context.read<TasksCubit>().fetchTasksAssignedTo(user.id);
    } else {
      context.read<TasksCubit>().fetchTasksAssignedTo(user.id);
      context.read<TasksCubit>().fetchTasksCreatedBy(user.id);
    }
  }

  Future<void> _openFilterBottomSheet() async {
    final selectedFilters = await showModalBottomSheet<TaskFilters>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return TaskFilterBottomSheet(initialFilters: _filters);
      },
    );

    if (!context.mounted) return;
    if (selectedFilters == null) return;

    setState(() {
      _filters = selectedFilters;
    });
  }

  List<TaskModel> _applyFilters(List<TaskModel> source) {
    final query = _filters.searchQuery.trim().toLowerCase();

    final filtered = source.where((task) {
      final title = task.title.toLowerCase();
      final description = task.description.toLowerCase();
      final assignedToName = task.assignedToName.toLowerCase();
      final assignedByName = task.assignedByName.toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          title.contains(query) ||
          description.contains(query) ||
          assignedToName.contains(query) ||
          assignedByName.contains(query);

      final matchesStatus =
          _filters.statusFilter == 'all' ||
          task.status == _filters.statusFilter;

      final matchesPriority =
          _filters.priorityFilter == 'all' ||
          task.priority == _filters.priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    int priorityRank(String priority) {
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

    switch (_filters.sortOption) {
      case TaskSortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortOption.dueDateSoonest:
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSortOption.priorityHighestFirst:
        filtered.sort((a, b) {
          final rankComparison = priorityRank(
            b.priority,
          ).compareTo(priorityRank(a.priority));
          if (rankComparison != 0) {
            return rankComparison;
          }
          return b.createdAt.compareTo(a.createdAt);
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

  Widget _buildSearchAndFiltersBar() {
    return Row(
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
    );
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
      length: 2,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTabs(TasksState state, AppUser? user) {
    return DefaultTabController(
      length: 2,
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
    if (status == TasksStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == TasksStatus.error) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        titleKey: errorKey ?? 'unknown_error',
      );
    }

    final filteredTasks = _applyFilters(tasks);

    if (filteredTasks.isEmpty) {
      if (tasks.isNotEmpty && _filters.hasActiveFilters) {
        return const EmptyStateWidget(
          icon: Icons.search_off,
          titleKey: 'no_matching_tasks',
        );
      }

      return const EmptyStateWidget(
        icon: Icons.task_alt_outlined,
        titleKey: 'no_tasks_found',
      );
    }

    return Column(
      children: [
        if (_filters.hasActiveFilters)
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
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _filters = const TaskFilters();
                    });
                  },
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
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
      itemBuilder: (context, index) {
        final task = tasks[index];

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
                  Text(task.description),
                  const SizedBox(height: AppSizes.md),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      PriorityBadge(priority: task.priority),
                      CountdownChip(
                        dueDate: task.dueDate,
                        isCompleted: task.status == 'completed',
                      ),
                    ],
                  ),
                  if (currentUser != null &&
                      task.assignedTo == currentUser.id) ...[
                    const SizedBox(height: AppSizes.lg),
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
                        if (value == null) {
                          return;
                        }

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
      },
    );
  }
}
