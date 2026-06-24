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
import '../../../attendance/presentation/widgets/attendance_record_card.dart';
import '../../presentation/cubit/reports_cubit.dart';
import '../../presentation/cubit/reports_state.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../attendance/data/models/work_schedule_model.dart';
import '../../../attendance/presentation/cubit/attendance_cubit.dart';
import '../../../attendance/presentation/cubit/attendance_state.dart';

int _countWorkingDaysInRange(
  WorkScheduleModel schedule,
  DateTime start,
  DateTime end,
) {
  var count = 0;
  var current = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(rangeEnd)) {
    final daySchedule = schedule.days[current.weekday.toString()];
    if (daySchedule?.isWorkingDay ?? true) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}

bool _recordInRange(String recordDate, DateTime start, DateTime end) {
  // record.date is 'YYYY-MM-DD' — ISO dates sort correctly via compareTo
  final startStr = DateFormat('yyyy-MM-dd').format(start);
  final endStr = DateFormat('yyyy-MM-dd').format(end);
  return recordDate.compareTo(startStr) >= 0 && recordDate.compareTo(endStr) <= 0;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  AppUser? _selectedEmployee;
  DateTimeRange? _selectedRange;

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsCubit>().loadEmployees();
    });
  }

  Future<void> _pickDateRange() async {
    final today = DateTime.now();
    final lastDate = DateTime(today.year, today.month, today.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      initialDateRange: _selectedRange != null &&
              !_selectedRange!.end.isAfter(lastDate)
          ? _selectedRange
          : null,
      helpText: 'select_date_range'.tr(),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  void _generateReport() {
    if (_selectedEmployee == null || _selectedRange == null) return;

    context.read<ReportsCubit>().generateReport(
      employee: _selectedEmployee!,
      startDate: _selectedRange!.start,
      endDate: _selectedRange!.end,
    );
  }

  String _hoursLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
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

                if (state.status == ReportsStatus.loaded &&
                    state.selectedEmployee != null &&
                    state.selectedStartDate != null) {
                  context.read<AttendanceCubit>().loadMonthlyAttendance(
                    state.selectedEmployee!.id,
                    state.selectedStartDate!.year,
                    state.selectedStartDate!.month,
                  );
                  context.read<AttendanceCubit>().loadEmployeeSchedule(
                    state.selectedEmployee!.id,
                    state.selectedEmployee!.name,
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
                                  _selectedRange == null
                                      ? 'tap_to_select_range'.tr()
                                      : '${DateFormat.yMMMd(context.locale.languageCode).format(_selectedRange!.start)} – ${DateFormat.yMMMd(context.locale.languageCode).format(_selectedRange!.end)}',
                                ),
                                subtitle: Text('selected_period'.tr()),
                                trailing: const Icon(Icons.date_range),
                                onTap: _pickDateRange,
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
                            subtitle: state.selectedStartDate != null && state.selectedEndDate != null
                                ? '${DateFormat.yMMMd(context.locale.languageCode).format(state.selectedStartDate!)} – ${DateFormat.yMMMd(context.locale.languageCode).format(state.selectedEndDate!)}'
                                : '',
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
                              final isWide = constraints.maxWidth >= 500;

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
                              final isWide = constraints.maxWidth >= 500;

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
                                      final attState = context
                                          .read<AttendanceCubit>()
                                          .state;
                                      final records = state.selectedStartDate != null &&
                                              state.selectedEndDate != null
                                          ? attState.monthlyRecords
                                              .where((r) => _recordInRange(
                                                    r.date,
                                                    state.selectedStartDate!,
                                                    state.selectedEndDate!,
                                                  ))
                                              .toList()
                                          : attState.monthlyRecords;
                                      context.read<ReportsCubit>().exportPdf(
                                        monthlyRecords: records,
                                        schedule: attState.editingSchedule,
                                        locale:
                                            context.locale.languageCode,
                                      );
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
                                                '${'due_date'.tr()}: ${DateFormat.yMMMd(context.locale.languageCode).format(task.dueDate)}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: AppSizes.xl),
                          SectionHeader(
                            title: 'monthly_attendance'.tr(),
                            subtitle: state.selectedStartDate != null
                                ? DateFormat.yMMMM(
                                    context.locale.languageCode,
                                  ).format(state.selectedStartDate!)
                                : '',
                          ),
                          BlocBuilder<AttendanceCubit, AttendanceState>(
                            builder: (context, attendanceState) {
                              if (attendanceState.monthlyStatus ==
                                  AttendanceLoadStatus.loading) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(AppSizes.md),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (attendanceState.monthlyStatus ==
                                  AttendanceLoadStatus.error) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSizes.sm,
                                  ),
                                  child: Text(
                                    (attendanceState.monthlyError ??
                                            'network_error')
                                        .tr(),
                                  ),
                                );
                              }

                              // Filter attendance records to the selected date range.
                              final filteredRecords = state.selectedStartDate != null &&
                                      state.selectedEndDate != null
                                  ? attendanceState.monthlyRecords
                                      .where((r) => _recordInRange(
                                            r.date,
                                            state.selectedStartDate!,
                                            state.selectedEndDate!,
                                          ))
                                      .toList()
                                  : attendanceState.monthlyRecords;

                              if (filteredRecords.isEmpty) {
                                return const EmptyStateWidget(
                                  icon: Icons.calendar_month_outlined,
                                  titleKey: 'no_attendance_records',
                                );
                              }

                              final daysPresent = filteredRecords
                                  .where((r) =>
                                      r.status == 'present' ||
                                      r.status == 'manual')
                                  .length;
                              final daysLate = filteredRecords
                                  .where((r) => r.status == 'late')
                                  .length;
                              final daysAbsent = filteredRecords
                                  .where((r) => r.status == 'absent')
                                  .length;
                              final daysOff = filteredRecords
                                  .where((r) => r.status == 'off_day')
                                  .length;
                              final daysOffWork = filteredRecords
                                  .where((r) => r.status == 'off_day_work')
                                  .length;
                              final corrections = filteredRecords
                                  .where((r) => r.isCorrected)
                                  .length;
                              final totalMinutes = filteredRecords.fold<int>(
                                0,
                                (sum, r) => sum + r.totalDurationMinutes,
                              );

                              final daysWorked =
                                  daysPresent + daysLate + daysOffWork;
                              final schedule = attendanceState.editingSchedule;
                              double? attendanceRate;
                              if (schedule != null &&
                                  state.selectedStartDate != null &&
                                  state.selectedEndDate != null) {
                                final workingDays = _countWorkingDaysInRange(
                                  schedule,
                                  state.selectedStartDate!,
                                  state.selectedEndDate!,
                                );
                                if (workingDays > 0) {
                                  attendanceRate =
                                      (daysWorked / workingDays * 100)
                                          .clamp(0.0, 100.0);
                                }
                              }

                              return Column(
                                children: [
                                  _MonthlyAttendanceSummaryCard(
                                    daysPresent: daysPresent,
                                    daysLate: daysLate,
                                    daysAbsent: daysAbsent,
                                    daysOff: daysOff,
                                    daysOffWork: daysOffWork,
                                    totalHoursWorked: _hoursLabel(totalMinutes),
                                    corrections: corrections,
                                    attendanceRate: attendanceRate,
                                  ),
                                  const SizedBox(height: AppSizes.md),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRecords.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSizes.sm),
                                    itemBuilder: (context, index) {
                                      return AttendanceRecordCard(
                                        record: filteredRecords[index],
                                      );
                                    },
                                  ),
                                ],
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

class _MonthlyAttendanceSummaryCard extends StatelessWidget {
  final int daysPresent;
  final int daysLate;
  final int daysAbsent;
  final int daysOff;
  final int daysOffWork;
  final String totalHoursWorked;
  final int corrections;
  final double? attendanceRate;

  const _MonthlyAttendanceSummaryCard({
    required this.daysPresent,
    required this.daysLate,
    required this.daysAbsent,
    required this.daysOff,
    required this.daysOffWork,
    required this.totalHoursWorked,
    required this.corrections,
    required this.attendanceRate,
  });

  Color _rateColor(ColorScheme cs, double rate) {
    if (rate >= 80) return cs.primary;
    if (rate >= 60) return cs.tertiary;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attendanceRate != null) ...[
            Row(
              children: [
                Text(
                  'attendance_rate'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${attendanceRate!.round()}%',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _rateColor(cs, attendanceRate!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: attendanceRate! / 100,
                color: _rateColor(cs, attendanceRate!),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const Divider(height: AppSizes.lg),
          ],
          Text(
            'worked'.tr(),
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSizes.xs),
          Wrap(
            spacing: AppSizes.xs,
            runSpacing: AppSizes.xs,
            children: [
              _SummaryChip(
                label: 'days_present'.tr(),
                value: daysPresent.toString(),
              ),
              if (daysLate > 0)
                _SummaryChip(
                  label: 'days_late'.tr(),
                  value: daysLate.toString(),
                ),
              if (daysOffWork > 0)
                _SummaryChip(
                  label: 'days_off_work'.tr(),
                  value: daysOffWork.toString(),
                ),
              _SummaryChip(
                label: 'total_hours_worked'.tr(),
                value: totalHoursWorked,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'not_worked'.tr(),
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSizes.xs),
          Wrap(
            spacing: AppSizes.xs,
            runSpacing: AppSizes.xs,
            children: [
              _SummaryChip(
                label: 'days_absent'.tr(),
                value: daysAbsent.toString(),
              ),
              if (daysOff > 0)
                _SummaryChip(
                  label: 'days_off'.tr(),
                  value: daysOff.toString(),
                ),
            ],
          ),
          if (corrections > 0) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSizes.xs),
                Text(
                  '$corrections ${'corrections'.tr()}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
