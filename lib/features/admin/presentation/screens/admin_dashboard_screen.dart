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
                final completedOnTime = state.stats['completedOnTime'] ?? 0;
                final completedLate = state.stats['completedLate'] ?? 0;
                final overdueOpenTasks = state.stats['overdueOpenTasks'] ?? 0;
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
                              ],
                            );
                          }

                          if (isMedium) {
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
                        title: 'delivery_performance'.tr(),
                        subtitle: 'delivery_performance_subtitle'.tr(),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'completed_on_time'.tr(),
                                    value: completedOnTime.toString(),
                                    icon: Icons.timer_outlined,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'completed_late'.tr(),
                                    value: completedLate.toString(),
                                    icon: Icons.event_busy_outlined,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: _DashboardStatCard(
                                    title: 'open_overdue'.tr(),
                                    value: overdueOpenTasks.toString(),
                                    icon: Icons.warning_amber_outlined,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _DashboardStatCard(
                                title: 'completed_on_time'.tr(),
                                value: completedOnTime.toString(),
                                icon: Icons.timer_outlined,
                              ),
                              const SizedBox(height: AppSizes.md),
                              _DashboardStatCard(
                                title: 'completed_late'.tr(),
                                value: completedLate.toString(),
                                icon: Icons.event_busy_outlined,
                              ),
                              const SizedBox(height: AppSizes.md),
                              _DashboardStatCard(
                                title: 'open_overdue'.tr(),
                                value: overdueOpenTasks.toString(),
                                icon: Icons.warning_amber_outlined,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.xl),

                      SectionHeader(
                        title: 'team_insights'.tr(),
                        subtitle: 'team_insights_subtitle'.tr(),
                      ),

                      const SizedBox(height: AppSizes.md),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _TeamInsightCard(
                                    title: 'top_performer'.tr(),
                                    name:
                                        (state.extraStats['topPerformer'] ??
                                                '-')
                                            .toString(),
                                    count:
                                        (state.extraStats['topCompleted'] ?? 0)
                                            as int,
                                    icon: Icons.emoji_events_outlined,
                                    countLabel: 'completed_tasks', // ✅
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: _TeamInsightCard(
                                    title: 'most_active'.tr(),
                                    name:
                                        (state.extraStats['mostActive'] ?? '-')
                                            .toString(),
                                    count:
                                        (state.extraStats['topActive'] ?? 0)
                                            as int,
                                    icon: Icons.local_fire_department_outlined,
                                    countLabel: 'active_tasks', // ✅
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _TeamInsightCard(
                                title: 'top_performer'.tr(),
                                name: (state.extraStats['topPerformer'] ?? '-')
                                    .toString(),
                                count:
                                    (state.extraStats['topCompleted'] ?? 0)
                                        as int,
                                icon: Icons.emoji_events_outlined,
                                countLabel: 'completed_tasks', // ✅
                              ),
                              const SizedBox(height: AppSizes.md),
                              _TeamInsightCard(
                                title: 'most_active'.tr(),
                                name: (state.extraStats['mostActive'] ?? '-')
                                    .toString(),
                                count:
                                    (state.extraStats['topActive'] ?? 0) as int,
                                icon: Icons.local_fire_department_outlined,
                                countLabel: 'active_tasks', // ✅
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.xl),

                      SectionHeader(
                        title: 'recent_activity'.tr(),
                        subtitle: 'recent_activity_subtitle'.tr(),
                      ),

                      const SizedBox(height: AppSizes.md),

                      if (state.activities.isEmpty)
                        const EmptyStateWidget(
                          icon: Icons.history,
                          titleKey: 'no_recent_activity',
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.activities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSizes.sm),
                          itemBuilder: (context, index) {
                            final activity = state.activities[index];

                            final action = activity['action'];
                            final name = activity['performedByName'] ?? '';
                            final task = activity['taskTitle'] ?? '';
                            final oldStatus =
                                activity['oldStatus'] ??
                                activity['previousStatus'] ??
                                '';
                            final newStatus = activity['newStatus'] ?? '';
                            final performedAt = activity['performedAt'];

                            DateTime? activityTime;
                            if (performedAt != null) {
                              activityTime = performedAt.toDate();
                            }

                            String text;

                            if (action == 'created') {
                              text = '$name ${'created_task'.tr()} "$task"';
                            } else if (action == 'status_changed') {
                              text =
                                  '$name ${'changed_status'.tr()} "$task" ${'to'.tr()} ${newStatus.toString().tr()}';
                            } else if (action == 'overdue_escalation') {
                              text =
                                  '${'overdue_task_escalation'.tr()} "$task"';
                            } else {
                              text = '$name $action "$task"';
                            }

                            return AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.history),
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          text,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge,
                                        ),
                                        if (activityTime != null) ...[
                                          const SizedBox(height: AppSizes.xs),
                                          Text(
                                            DateFormat(
                                              'yyyy-MM-dd • HH:mm',
                                            ).format(activityTime),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

class _TeamInsightCard extends StatelessWidget {
  final String title;
  final String name;
  final int count;
  final IconData icon;
  final String countLabel;

  const _TeamInsightCard({
    required this.title,
    required this.name,
    required this.count,
    required this.icon,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final isTopPerformer = icon == Icons.emoji_events_outlined;

    final accentColor = isTopPerformer
        ? Colors.amber.shade700
        : Colors.deepOrange.shade400;

    final avatarText = name.trim().isNotEmpty && name.trim() != '-'
        ? name.trim()[0].toUpperCase()
        : '?';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withValues(alpha: 0.14),
                child: Text(
                  avatarText,
                  style: textTheme.titleLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  '$count - ${countLabel.tr()}',
                  style: textTheme.titleSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
