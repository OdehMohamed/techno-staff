import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:techno_staff/features/notifications/presentation/widgets/notifications_bell_button.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_state.dart';
import '../../../../features/tasks/presentation/cubit/tasks_cubit.dart';
import '../../../../features/tasks/presentation/cubit/tasks_state.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        context.read<NotificationsCubit>().listenToNotifications(user.id);
      }
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    await Future.wait([
      context.read<TasksCubit>().fetchTasksAssignedTo(user.id, silent: silent),
      context.read<DashboardCubit>().loadEmployeeStats(user.id, silent: silent),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('home'.tr()),
        actions: const [NotificationsBellButton()],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, dashboardState) {
                return BlocBuilder<TasksCubit, TasksState>(
                  builder: (context, tasksState) {
                    if (user != null &&
                        (tasksState.tasksAssignedToMeStatus == TasksStatus.initial ||
                            dashboardState.status == DashboardStatus.initial)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _loadData();
                      });
                    }

                    final isInitialLoad =
                        dashboardState.status == DashboardStatus.loading &&
                        dashboardState.stats.isEmpty &&
                        tasksState.tasksAssignedToMeStatus ==
                            TasksStatus.loading &&
                        tasksState.tasksAssignedToMe.isEmpty;

                    if (isInitialLoad) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final hasError =
                        dashboardState.status == DashboardStatus.error ||
                        tasksState.tasksAssignedToMeStatus == TasksStatus.error;

                    if (hasError) {
                      return RefreshIndicator(
                        onRefresh: () => _loadData(silent: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            EmptyStateWidget(
                              icon: Icons.error_outline,
                              titleKey: 'failed_to_load_dashboard',
                            ),
                          ],
                        ),
                      );
                    }

                    final stats = dashboardState.stats;
                    final tasks = tasksState.tasksAssignedToMe;

                    final totalTasks = stats['totalTasks'] ?? 0;
                    final completedTasks = stats['completedTasks'] ?? 0;
                    final inProgressTasks = stats['inProgressTasks'] ?? 0;
                    final pendingTasks = stats['pendingTasks'] ?? 0;
                    final completionRate = totalTasks == 0
                        ? 0
                        : ((completedTasks / totalTasks) * 100).round();

                    return RefreshIndicator(
                      onRefresh: () => _loadData(silent: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          SectionHeader(
                            title: 'employee_home'.tr(),
                            subtitle: user == null
                                ? null
                                : '${'welcome_back'.tr()}, ${user.name}',
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 700;

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _EmployeeStatCard(
                                        title: 'my_tasks'.tr(),
                                        value: totalTasks.toString(),
                                        icon: Icons.task_alt_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _EmployeeStatCard(
                                        title: 'completed'.tr(),
                                        value: completedTasks.toString(),
                                        icon: Icons.check_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _EmployeeStatCard(
                                        title: 'in_progress'.tr(),
                                        value: inProgressTasks.toString(),
                                        icon: Icons.pending_actions_outlined,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _EmployeeStatCard(
                                    title: 'my_tasks'.tr(),
                                    value: totalTasks.toString(),
                                    icon: Icons.task_alt_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _EmployeeStatCard(
                                    title: 'completed'.tr(),
                                    value: completedTasks.toString(),
                                    icon: Icons.check_circle_outline,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _EmployeeStatCard(
                                    title: 'in_progress'.tr(),
                                    value: inProgressTasks.toString(),
                                    icon: Icons.pending_actions_outlined,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSizes.xl),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'completion_rate'.tr()}: $completionRate%',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSizes.sm),
                                Text(
                                  '${'pending'.tr()}: $pendingTasks',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSizes.md),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 10,
                                    value: totalTasks == 0
                                        ? 0
                                        : completedTasks / totalTasks,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.xl),
                          SectionHeader(
                            title: 'my_tasks'.tr(),
                            subtitle: 'employee_tasks_subtitle'.tr(),
                          ),
                          if (tasks.isEmpty)
                            const EmptyStateWidget(
                              icon: Icons.task_alt_outlined,
                              titleKey: 'no_tasks_yet',
                            )
                          else
                            Column(
                              children: tasks.take(3).map((task) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSizes.md,
                                  ),
                                  child: AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task.title,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                              ),
                                            ),
                                            const SizedBox(width: AppSizes.sm),
                                            StatusBadge(status: task.status),
                                          ],
                                        ),
                                        const SizedBox(height: AppSizes.sm),
                                        Text(task.description),
                                        const SizedBox(height: AppSizes.md),
                                        PriorityBadge(priority: task.priority),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _EmployeeStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSizes.xs),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
