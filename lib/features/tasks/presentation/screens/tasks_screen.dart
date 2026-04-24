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

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
    });
  }

  void _loadTasks() {
    final authState = context.read<AuthCubit>().state;
    final user = authState.user;

    if (user == null) return;

    if (user.role == 'admin') {
      context.read<TasksCubit>().fetchAllTasks();
    } else {
      context.read<TasksCubit>().fetchTasksAssignedTo(user.id);
      context.read<TasksCubit>().fetchTasksCreatedBy(user.id);
    }
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
          final result = await Navigator.pushNamed(
            context,
            RouteNames.addTask,
          );

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
                      isAdmin && state.status == TasksStatus.initial;
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

                if (isAdmin) {
                  return _buildAdminTasks(state, user);
                }

                return _buildEmployeeTabs(state, user);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTasks(TasksState state, AppUser? user) {
    if (state.status == TasksStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == TasksStatus.error) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        titleKey: state.errorMessage ?? 'unknown_error',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'tasks'.tr(),
          subtitle: 'Manage and monitor all assigned tasks'.tr(),
        ),
        Expanded(
          child: _buildTasksList(
            tasks: state.tasks,
            currentUser: user,
            isAdmin: true,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeTabs(TasksState state, AppUser? user) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

    return _buildTasksList(
      tasks: tasks,
      currentUser: currentUser,
      isAdmin: isAdmin,
    );
  }

  Widget _buildTasksList({
    required List<TaskModel> tasks,
    required AppUser? currentUser,
    required bool isAdmin,
  }) {
    if (tasks.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.task_alt_outlined,
        titleKey: 'no_tasks_found',
      );
    }

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
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label:
                            '${'due_date'.tr()}: ${DateFormat('yyyy-MM-dd').format(task.dueDate)}',
                      ),
                    ],
                  ),
                  if (currentUser != null && task.assignedTo == currentUser.id) ...[
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}
