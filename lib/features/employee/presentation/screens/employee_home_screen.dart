import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:techno_staff/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:techno_staff/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:techno_staff/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:techno_staff/features/notifications/presentation/widgets/notifications_bell_button.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../../features/dashboard/presentation/cubit/dashboard_state.dart';
import '../../../../features/tasks/data/models/task_model.dart';
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
        context.read<ChatListCubit>().startListening(user.id);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        final att = context.read<AttendanceCubit>();
        if (att.state.todayStatus == AttendanceLoadStatus.initial) {
          att.startListeningToday(user.id);
        }
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

  // Overdue tasks float to top; within each group, nearest deadline first.
  List<TaskModel> _urgencySorted(List<TaskModel> tasks) {
    final now = DateTime.now();
    DateTime deadline(TaskModel t) => t.hasDueTime
        ? t.dueDate
        : DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day, 23, 59, 59);
    return [...tasks]
      ..sort((a, b) {
        final aOverdue = deadline(a).isBefore(now);
        final bOverdue = deadline(b).isBefore(now);
        if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
        return deadline(a).compareTo(deadline(b));
      });
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
                        (tasksState.tasksAssignedToMeStatus ==
                                TasksStatus.initial ||
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
                            const SizedBox(height: AppSizes.md),
                            const _TodayAttendanceCard(),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: AppSizes.sm),
                                  Text(
                                    '${'pending'.tr()}: $pendingTasks',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
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
                                children: _urgencySorted(tasks)
                                    .take(5)
                                    .map((task) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSizes.md,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          RouteNames.taskDetails,
                                          arguments: task,
                                        );
                                      },
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
                                                const SizedBox(
                                                  width: AppSizes.sm,
                                                ),
                                                StatusBadge(
                                                  status: task.status,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: AppSizes.sm),
                                            Text(
                                              task.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: AppSizes.md),
                                            Row(
                                              children: [
                                                PriorityBadge(
                                                  priority: task.priority,
                                                ),
                                                const Spacer(),
                                                _TaskDueLabel(task: task),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (tasks.length > 5)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      RouteNames.tasks,
                                    );
                                  },
                                  child: Text('all_tasks'.tr()),
                                ),
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

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        if (state.todayStatus == AttendanceLoadStatus.initial ||
            state.todayStatus == AttendanceLoadStatus.loading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.md),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Text(
                    'today_attendance'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final record = state.todayRecord;

        final Color iconColor;
        final IconData icon;
        if (record == null) {
          iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
          icon = Icons.schedule_outlined;
        } else if (record.hasOpenSession) {
          iconColor = Colors.green.shade600;
          icon = Icons.how_to_reg_outlined;
        } else {
          iconColor = Theme.of(context).colorScheme.primary;
          icon = Icons.check_circle_outline;
        }

        final String statusLabel;
        if (record == null) {
          statusLabel = 'not_checked_in_yet'.tr();
        } else if (record.hasOpenSession) {
          statusLabel = 'checked_in'.tr();
        } else {
          statusLabel = 'checked_out'.tr();
        }

        String? timeLabel;
        if (record != null && record.checkInAt != null) {
          final checkInStr = DateFormat.Hm().format(record.checkInAt!);
          if (record.hasOpenSession) {
            timeLabel = '${'check_in_time'.tr()}: $checkInStr';
          } else if (record.checkOutAt != null) {
            final checkOutStr = DateFormat.Hm().format(record.checkOutAt!);
            final dur = record.totalDurationMinutes;
            final durStr =
                dur >= 60 ? '${dur ~/ 60}h ${dur % 60}m' : '${dur}m';
            timeLabel = '$checkInStr → $checkOutStr · $durStr';
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(context, RouteNames.attendance),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'today_attendance'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (timeLabel != null) ...[
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            timeLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

class _TaskDueLabel extends StatelessWidget {
  final TaskModel task;

  const _TaskDueLabel({required this.task});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadline = task.hasDueTime
        ? task.dueDate
        : DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
            23,
            59,
            59,
          );
    final isOverdue = deadline.isBefore(now);
    final isDueToday = !isOverdue &&
        task.dueDate.year == now.year &&
        task.dueDate.month == now.month &&
        task.dueDate.day == now.day;

    final Color color;
    if (isOverdue) {
      color = Theme.of(context).colorScheme.error;
    } else if (isDueToday) {
      color = Colors.orange;
    } else {
      color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    final dateStr = DateFormat.yMMMd(
      context.locale.languageCode,
    ).format(task.dueDate);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOverdue || isDueToday)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              size: 14,
              color: color,
            ),
          ),
        Text(
          dateStr,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
