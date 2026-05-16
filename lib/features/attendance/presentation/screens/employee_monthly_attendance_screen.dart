import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';
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
      context.read<AttendanceCubit>().loadMonthlyAttendance(
        user.id,
        _year,
        _month,
      );
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
                      .where((r) => r.status == 'present')
                      .length;
                  final daysAbsent = state.monthlyRecords
                      .where((r) => r.status == 'absent')
                      .length;
                  final corrections = state.monthlyRecords
                      .where((r) => r.isCorrected)
                      .length;
                  final totalMinutes = state.monthlyRecords.fold<int>(
                    0,
                    (sum, r) => sum + r.totalDurationMinutes,
                  );
                  final totalHoursLabel = _hoursLabel(totalMinutes);

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
                            daysAbsent: daysAbsent,
                            totalHoursWorked: totalHoursLabel,
                            corrections: corrections,
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

class _MonthlySummaryCard extends StatelessWidget {
  final int daysPresent;
  final int daysAbsent;
  final String totalHoursWorked;
  final int corrections;

  const _MonthlySummaryCard({
    required this.daysPresent,
    required this.daysAbsent,
    required this.totalHoursWorked,
    required this.corrections,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        children: [
          _SummaryChip(
            label: 'days_present'.tr(),
            value: daysPresent.toString(),
          ),
          _SummaryChip(label: 'days_absent'.tr(), value: daysAbsent.toString()),
          _SummaryChip(
            label: 'total_hours_worked'.tr(),
            value: totalHoursWorked,
          ),
          _SummaryChip(
            label: 'corrections'.tr(),
            value: corrections.toString(),
          ),
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
