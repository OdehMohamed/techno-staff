import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

class AttendanceStatusChip extends StatelessWidget {
  final String status;

  const AttendanceStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final label = switch (status) {
      'present' => 'attendance_status_present',
      'absent' => 'attendance_status_absent',
      'late' => 'attendance_status_late',
      'off_day' => 'attendance_status_off_day',
      'off_day_work' => 'attendance_status_off_day_work',
      'manual' => 'attendance_status_present',
      _ => 'attendance_status_present',
    };

    final bg = switch (status) {
      'absent' => cs.errorContainer,
      'late' => cs.tertiaryContainer,
      'off_day' => cs.surfaceContainerHighest,
      'off_day_work' => cs.secondaryContainer,
      _ => cs.primaryContainer,
    };

    final fg = switch (status) {
      'absent' => cs.onErrorContainer,
      'late' => cs.onTertiaryContainer,
      'off_day' => cs.onSurfaceVariant,
      'off_day_work' => cs.onSecondaryContainer,
      _ => cs.onPrimaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
