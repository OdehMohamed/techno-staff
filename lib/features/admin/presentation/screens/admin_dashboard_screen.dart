import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_state.dart';
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
      context.read<DashboardCubit>().loadAdminStats();
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
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state.status == DashboardStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == DashboardStatus.error) {
                  return const EmptyStateWidget(
                    icon: Icons.error_outline,
                    titleKey: 'failed_to_load_dashboard',
                  );
                }

                final employeesCount = state.stats['employeesCount'] ?? 0;
                final totalTasks = state.stats['totalTasks'] ?? 0;
                final completedTasks = state.stats['completedTasks'] ?? 0;
                final overdueTasks = state.stats['overdueTasks'] ?? 0;
                final completionRate = totalTasks == 0
                    ? 0
                    : ((completedTasks / totalTasks) * 100).round();

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
                                    value: employeesCount.toString(),
                                    icon: Icons.group_outlined,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'total_tasks'.tr(),
                                    value: totalTasks.toString(),
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
                                        value: employeesCount.toString(),
                                        icon: Icons.group_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _DashboardStatCard(
                                        title: 'total_tasks'.tr(),
                                        value: totalTasks.toString(),
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
                                value: employeesCount.toString(),
                                icon: Icons.group_outlined,
                              ),
                              const SizedBox(height: AppSizes.md),
                              _DashboardStatCard(
                                title: 'total_tasks'.tr(),
                                value: totalTasks.toString(),
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
                        title: 'performance_overview'.tr(),
                        subtitle: 'performance_overview_subtitle'.tr(),
                      ),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'completion_rate'.tr()}: $completionRate%',
                              style: Theme.of(context).textTheme.titleLarge,
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
