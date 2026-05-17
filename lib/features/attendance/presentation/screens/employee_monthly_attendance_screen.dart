import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../data/models/work_schedule_model.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_record_card.dart';

class EmployeeMonthlyAttendanceScreen extends StatefulWidget {
  const EmployeeMonthlyAttendanceScreen({super.key});

  @override
  State<EmployeeMonthlyAttendanceScreen> createState() =>
      _EmployeeMonthlyAttendanceScreenState();
}

class _EmployeeMonthlyAttendanceScreenState
    extends State<EmployeeMonthlyAttendanceScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.user;
      if (user == null) {
        return;
      }
      final cubit = context.read<AttendanceCubit>();
      cubit.loadMonthlyAttendance(user.id, _year, _month);
      if (cubit.state.mySchedule == null) {
        cubit.loadMySchedule(user.id);
      }
    });
  }

  void _changeMonth(int delta) {
    final candidate = DateTime(_year, _month + delta);
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);

    if (candidate.isAfter(currentMonthStart)) {
      return;
    }

    setState(() {
      _year = candidate.year;
      _month = candidate.month;
    });

    final user = context.read<AuthCubit>().state.user;
    if (user == null) {
      return;
    }

    context.read<AttendanceCubit>().loadMonthlyAttendance(
      user.id,
      _year,
      _month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final selectedMonth = DateTime(_year, _month);
    final now = DateTime.now();
    final canGoNext = selectedMonth.isBefore(DateTime(now.year, now.month));

    return Scaffold(
      appBar: AppBar(title: Text('monthly_attendance'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'monthly_attendance'.tr(),
              subtitle: DateFormat.yMMMM(
                context.locale.languageCode,
              ).format(selectedMonth),
            ),
            AppCard(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM(
                        context.locale.languageCode,
                      ).format(selectedMonth),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: canGoNext ? () => _changeMonth(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(
              child: BlocBuilder<AttendanceCubit, AttendanceState>(
                builder: (context, state) {
                  if (state.monthlyStatus == AttendanceLoadStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.monthlyStatus == AttendanceLoadStatus.error) {
                    return Center(
                      child: Text((state.monthlyError ?? 'network_error').tr()),
                    );
                  }

                  if (state.monthlyRecords.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.calendar_month_outlined,
                      titleKey: 'no_attendance_records',
                    );
                  }

                  final daysPresent = state.monthlyRecords
                      .where((r) => r.status == 'present' || r.status == 'manual')
                      .length;
                  final daysLate = state.monthlyRecords
                      .where((r) => r.status == 'late')
                      .length;
                  final daysAbsent = state.monthlyRecords
                      .where((r) => r.status == 'absent')
                      .length;
                  final daysOff = state.monthlyRecords
                      .where((r) => r.status == 'off_day')
                      .length;
                  final daysOffWork = state.monthlyRecords
                      .where((r) => r.status == 'off_day_work')
                      .length;
                  final corrections = state.monthlyRecords
                      .where((r) => r.isCorrected)
                      .length;
                  final totalMinutes = state.monthlyRecords.fold<int>(
                    0,
                    (sum, r) => sum + r.totalDurationMinutes,
                  );
                  final totalHoursLabel = _hoursLabel(totalMinutes);

                  final daysWorked = daysPresent + daysLate + daysOffWork;
                  double? attendanceRate;
                  final schedule = state.mySchedule;
                  if (schedule != null) {
                    final workingDays =
                        _countWorkingDays(schedule, _year, _month);
                    if (workingDays > 0) {
                      attendanceRate =
                          (daysWorked / workingDays * 100).clamp(0.0, 100.0);
                    }
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      if (user == null) return;
                      await context
                          .read<AttendanceCubit>()
                          .loadMonthlyAttendance(user.id, _year, _month);
                    },
                    child: ListView.separated(
                      itemCount: state.monthlyRecords.length + 1,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _MonthlySummaryCard(
                            daysPresent: daysPresent,
                            daysLate: daysLate,
                            daysAbsent: daysAbsent,
                            daysOff: daysOff,
                            daysOffWork: daysOffWork,
                            totalHoursWorked: totalHoursLabel,
                            corrections: corrections,
                            attendanceRate: attendanceRate,
                          );
                        }

                        final record = state.monthlyRecords[index - 1];
                        return AttendanceRecordCard(record: record);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hoursLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

int _countWorkingDays(WorkScheduleModel schedule, int year, int month) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  var count = 0;
  for (var day = 1; day <= daysInMonth; day++) {
    final weekday = DateTime(year, month, day).weekday;
    final daySchedule = schedule.days[weekday.toString()];
    if (daySchedule?.isWorkingDay ?? true) count++;
  }
  return count;
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _MonthlySummaryCard extends StatelessWidget {
  final int daysPresent;
  final int daysLate;
  final int daysAbsent;
  final int daysOff;
  final int daysOffWork;
  final String totalHoursWorked;
  final int corrections;
  final double? attendanceRate;

  const _MonthlySummaryCard({
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
          // Attendance rate (only when schedule data is available)
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

          // Worked group
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

          // Not-worked group
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

          // Corrections (shown only when > 0)
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
