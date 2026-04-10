import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/shared/widgets/app_pie_chart.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../presentation/cubit/reports_cubit.dart';
import '../../presentation/cubit/reports_state.dart';
import '../../../auth/domain/models/app_user.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  AppUser? _selectedEmployee;
  DateTime _selectedMonth = DateTime.now();
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsCubit>().loadEmployees();
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'select_month'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    decoration: InputDecoration(labelText: 'year'.tr()),
                    items: List.generate(5, (index) {
                      final year = now.year - 2 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: 12,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.2,
                        ),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final isSelected = month == selectedMonth;

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context, DateTime(selectedYear, month));
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.12)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            DateFormat.MMM(
                              context.locale.languageCode,
                            ).format(DateTime(2024, month)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedMonth = DateTime(result.year, result.month);
      });
    }
  }

  void _generateReport() {
    if (_selectedEmployee == null) return;

    context.read<ReportsCubit>().generateReport(
      employee: _selectedEmployee!,
      month: _selectedMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reports'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocListener<ReportsCubit, ReportsState>(
              listener: (context, state) {
                if (state.status == ReportsStatus.error &&
                    state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage!.tr())),
                  );
                }
              },
              child: BlocBuilder<ReportsCubit, ReportsState>(
                builder: (context, state) {
                  final completedTasks = state.tasks
                      .where((task) => task.status == 'completed')
                      .length;
                  final inProgressTasks = state.tasks
                      .where((task) => task.status == 'in_progress')
                      .length;
                  final pendingTasks = state.tasks
                      .where((task) => task.status == 'pending')
                      .length;
                  final completedOnTime = state.tasks.where((task) {
                    return task.status == 'completed' &&
                        task.completedAt != null &&
                        !task.completedAt!.isAfter(_endOfDay(task.dueDate));
                  }).length;

                  final completedLate = state.tasks.where((task) {
                    return task.status == 'completed' &&
                        task.completedAt != null &&
                        task.completedAt!.isAfter(_endOfDay(task.dueDate));
                  }).length;

                  final openOverdueTasks = state.tasks.where((task) {
                    return task.status != 'completed' &&
                        DateTime.now().isAfter(_endOfDay(task.dueDate));
                  }).length;
                  final totalTasks = state.tasks.length;
                  final completionRate = totalTasks == 0
                      ? 0
                      : ((completedTasks / totalTasks) * 100).round();

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'reports'.tr(),
                          subtitle: 'reports_subtitle'.tr(),
                        ),
                        AppCard(
                          child: Column(
                            children: [
                              DropdownButtonFormField<AppUser>(
                                initialValue: _selectedEmployee,
                                decoration: InputDecoration(
                                  labelText: 'select_employee'.tr(),
                                ),
                                items: state.employees
                                    .map(
                                      (employee) => DropdownMenuItem(
                                        value: employee,
                                        child: Text(employee.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedEmployee = value;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSizes.md),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${'selected_month'.tr()}: ${DateFormat('yyyy-MM').format(_selectedMonth)}',
                                ),
                                trailing: const Icon(Icons.calendar_month),
                                onTap: _pickMonth,
                              ),
                              const SizedBox(height: AppSizes.md),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      state.status == ReportsStatus.loading
                                      ? null
                                      : _generateReport,
                                  child: state.status == ReportsStatus.loading
                                      ? const CircularProgressIndicator()
                                      : Text('generate_report'.tr()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.xl),
                        if (state.selectedEmployee != null) ...[
                          SectionHeader(
                            title:
                                '${'employee_report'.tr()}: ${state.selectedEmployee!.name}',
                            subtitle:
                                '${'month'.tr()}: ${DateFormat('yyyy-MM').format(_selectedMonth)}',
                          ),
                          const SizedBox(height: AppSizes.md),

                          /// 🔥 PIE CHART
                          AppPieChart(
                            completed: completedTasks,
                            inProgress: inProgressTasks,
                            pending: pendingTasks,
                          ),
                          const SizedBox(height: AppSizes.sm),

                          /// 🔥 LEGEND
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _LegendItem(
                                color: Colors.green,
                                label: 'completed'.tr(),
                              ),
                              _LegendItem(
                                color: Colors.orange,
                                label: 'in_progress'.tr(),
                              ),
                              _LegendItem(
                                color: Colors.grey,
                                label: 'pending'.tr(),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSizes.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;
                              final isMedium = constraints.maxWidth >= 600;

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'total_tasks'.tr(),
                                        value: totalTasks.toString(),
                                        icon: Icons.task_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'completed'.tr(),
                                        value: completedTasks.toString(),
                                        icon: Icons.check_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'in_progress'.tr(),
                                        value: inProgressTasks.toString(),
                                        icon: Icons.pending_actions_outlined,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              if (isMedium) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'total_tasks'.tr(),
                                        value: totalTasks.toString(),
                                        icon: Icons.task_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'completed'.tr(),
                                        value: completedTasks.toString(),
                                        icon: Icons.check_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
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
                                  _ReportStatCard(
                                    title: 'total_tasks'.tr(),
                                    value: totalTasks.toString(),
                                    icon: Icons.task_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _ReportStatCard(
                                    title: 'completed'.tr(),
                                    value: completedTasks.toString(),
                                    icon: Icons.check_circle_outline,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _ReportStatCard(
                                    title: 'in_progress'.tr(),
                                    value: inProgressTasks.toString(),
                                    icon: Icons.pending_actions_outlined,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSizes.lg),
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
                                      child: _ReportStatCard(
                                        title: 'completed_on_time'.tr(),
                                        value: completedOnTime.toString(),
                                        icon: Icons.timer_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'completed_late'.tr(),
                                        value: completedLate.toString(),
                                        icon: Icons.event_busy_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'open_overdue'.tr(),
                                        value: openOverdueTasks.toString(),
                                        icon: Icons.warning_amber_outlined,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _ReportStatCard(
                                    title: 'completed_on_time'.tr(),
                                    value: completedOnTime.toString(),
                                    icon: Icons.timer_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _ReportStatCard(
                                    title: 'completed_late'.tr(),
                                    value: completedLate.toString(),
                                    icon: Icons.event_busy_outlined,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  _ReportStatCard(
                                    title: 'open_overdue'.tr(),
                                    value: openOverdueTasks.toString(),
                                    icon: Icons.warning_amber_outlined,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSizes.lg),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ElevatedButton.icon(
                              onPressed:
                                  state.status == ReportsStatus.exportingPdf
                                  ? null
                                  : () {
                                      context.read<ReportsCubit>().exportPdf();
                                    },
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: Text(
                                state.status == ReportsStatus.exportingPdf
                                    ? 'exporting_pdf'.tr()
                                    : 'export_pdf'.tr(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),

                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final callable = FirebaseFunctions.instance
                                    .httpsCallable('testTaskDeadlineReminders');

                                final result = await callable.call();

                                debugPrint(
                                  'REMINDER TEST RESULT: ${result.data}',
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Reminder sent: ${result.data}',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                debugPrint('REMINDER ERROR: $e');

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error sending reminder'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Test Reminder'),
                          ),
                          const SizedBox(height: AppSizes.xl),
                          SectionHeader(
                            title: 'tasks'.tr(),
                            subtitle: 'monthly_tasks_subtitle'.tr(),
                          ),
                          if (state.tasks.isEmpty)
                            const EmptyStateWidget(
                              icon: Icons.assignment_outlined,
                              titleKey: 'no_tasks_found_for_month',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.tasks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSizes.md),
                              itemBuilder: (context, index) {
                                final task = state.tasks[index];

                                return AppCard(
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
                                      Wrap(
                                        spacing: AppSizes.sm,
                                        runSpacing: AppSizes.sm,
                                        children: [
                                          PriorityBadge(
                                            priority: task.priority,
                                          ),
                                          _InfoChip(
                                            icon: Icons.calendar_today_outlined,
                                            label:
                                                '${'due_date'.tr()}: ${DateFormat('yyyy-MM-dd').format(task.dueDate)}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportStatCard({
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
