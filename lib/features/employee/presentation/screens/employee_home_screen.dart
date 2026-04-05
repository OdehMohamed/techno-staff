import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
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
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        context.read<TasksCubit>().fetchTasksForUser(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(title: Text('home'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<TasksCubit, TasksState>(
              builder: (context, state) {
                if (state.status == TasksStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == TasksStatus.error) {
                  return const EmptyStateWidget(
                    icon: Icons.error_outline,
                    titleKey: 'failed_to_load_tasks',
                  );
                }

                final tasks = state.tasks;
                final completedTasks = tasks
                    .where((task) => task.status == 'completed')
                    .length;
                final pendingTasks = tasks
                    .where((task) => task.status == 'pending')
                    .length;
                final inProgressTasks = tasks
                    .where((task) => task.status == 'in_progress')
                    .length;

                return SingleChildScrollView(
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
                                    value: tasks.length.toString(),
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
                                value: tasks.length.toString(),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Wrap(
                                      spacing: AppSizes.sm,
                                      runSpacing: AppSizes.sm,
                                      children: [
                                        PriorityBadge(priority: task.priority),
                                        _EmployeeInfoChip(
                                          icon: Icons.circle,
                                          label: pendingTasks.toString(),
                                          useSmallIcon: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
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

class _EmployeeInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool useSmallIcon;

  const _EmployeeInfoChip({
    required this.icon,
    required this.label,
    this.useSmallIcon = false,
  });

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
        children: [
          Icon(icon, size: useSmallIcon ? 10 : 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
