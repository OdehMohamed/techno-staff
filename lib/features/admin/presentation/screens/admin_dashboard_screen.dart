import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../../../features/tasks/presentation/cubit/tasks_cubit.dart';
import '../../../../features/tasks/presentation/cubit/tasks_state.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeesCubit>().fetchEmployees();
      context.read<TasksCubit>().fetchAllTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('dashboard'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, employeesState) {
                return BlocBuilder<TasksCubit, TasksState>(
                  builder: (context, tasksState) {
                    final employees = employeesState.employees
                        .where((user) => user.role == 'employee')
                        .toList();

                    final tasks = tasksState.tasks;

                    final completedTasks = tasks
                        .where((task) => task.status == 'completed')
                        .length;

                    final pendingTasks = tasks
                        .where((task) => task.status == 'pending')
                        .length;

                    final inProgressTasks = tasks
                        .where((task) => task.status == 'in_progress')
                        .length;

                    final overdueTasks = tasks
                        .where(
                          (task) =>
                              task.status != 'completed' &&
                              task.dueDate.isBefore(DateTime.now()),
                        )
                        .length;

                    if (employeesState.status == EmployeesStatus.loading ||
                        tasksState.status == TasksStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (employeesState.status == EmployeesStatus.error ||
                        tasksState.status == TasksStatus.error) {
                      return const EmptyStateWidget(
                        icon: Icons.error_outline,
                        titleKey: 'failed_to_load_dashboard',
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'admin_dashboard'.tr(),
                            subtitle: 'dashboard_admin_subtitle'.tr(),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;
                              final isMedium = constraints.maxWidth >= 600;

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardStatCard(
                                        title: 'employees'.tr(),
                                        value: employees.length.toString(),
                                        icon: Icons.group_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _DashboardStatCard(
                                        title: 'total_tasks'.tr(),
                                        value: tasks.length.toString(),
                                        icon: Icons.task_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _DashboardStatCard(
                                        title: 'completed_tasks'.tr(),
                                        value: completedTasks.toString(),
                                        icon: Icons.check_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _DashboardStatCard(
                                        title: 'overdue_tasks'.tr(),
                                        value: overdueTasks.toString(),
                                        icon: Icons.warning_amber_rounded,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              if (isMedium) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _DashboardStatCard(
                                            title: 'employees'.tr(),
                                            value: employees.length.toString(),
                                            icon: Icons.group_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: AppSizes.md),
                                        Expanded(
                                          child: _DashboardStatCard(
                                            title: 'total_tasks'.tr(),
                                            value: tasks.length.toString(),
                                            icon: Icons.task_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _DashboardStatCard(
                                            title: 'completed_tasks'.tr(),
                                            value: completedTasks.toString(),
                                            icon: Icons.check_circle_outline,
                                          ),
                                        ),
                                        const SizedBox(width: AppSizes.md),
                                        Expanded(
                                          child: _DashboardStatCard(
                                            title: 'overdue_tasks'.tr(),
                                            value: overdueTasks.toString(),
                                            icon: Icons.warning_amber_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _DashboardStatCard(
                                    title: 'employees'.tr(),
                                    value: employees.length.toString(),
                                    icon: Icons.group_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _DashboardStatCard(
                                    title: 'total_tasks'.tr(),
                                    value: tasks.length.toString(),
                                    icon: Icons.task_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _DashboardStatCard(
                                    title: 'completed_tasks'.tr(),
                                    value: completedTasks.toString(),
                                    icon: Icons.check_circle_outline,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _DashboardStatCard(
                                    title: 'overdue_tasks'.tr(),
                                    value: overdueTasks.toString(),
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSizes.xl),
                          SectionHeader(
                            title: 'tasks_overview'.tr(),
                            subtitle: 'tasks_overview_subtitle'.tr(),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 700;

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _MiniOverviewCard(
                                        title: 'pending'.tr(),
                                        value: pendingTasks.toString(),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _MiniOverviewCard(
                                        title: 'in_progress'.tr(),
                                        value: inProgressTasks.toString(),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _MiniOverviewCard(
                                        title: 'completed'.tr(),
                                        value: completedTasks.toString(),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _MiniOverviewCard(
                                    title: 'pending'.tr(),
                                    value: pendingTasks.toString(),
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _MiniOverviewCard(
                                    title: 'in_progress'.tr(),
                                    value: inProgressTasks.toString(),
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _MiniOverviewCard(
                                    title: 'completed'.tr(),
                                    value: completedTasks.toString(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
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

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardStatCard({
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

class _MiniOverviewCard extends StatelessWidget {
  final String title;
  final String value;

  const _MiniOverviewCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSizes.sm),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}
