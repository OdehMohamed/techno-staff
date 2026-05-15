import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/attendance_model.dart';

class AttendanceRecordCard extends StatelessWidget {
  final AttendanceModel record;

  const AttendanceRecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final parsedDate = DateTime.tryParse(record.date);
    final dateLabel = parsedDate != null
        ? DateFormat.yMMMd(locale).format(parsedDate)
        : record.date;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusChip(status: record.status),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          _InfoRow(
            label: 'check_in_time'.tr(),
            value: _formatTime(record.checkInAt),
          ),
          const SizedBox(height: AppSizes.xs),
          _InfoRow(
            label: 'check_out_time'.tr(),
            value: _formatTime(record.checkOutAt),
          ),
          if (record.durationMinutes != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              'duration_minutes'.tr(
                namedArgs: {'minutes': '${record.durationMinutes}'},
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '-';
    }
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusKey = switch (status) {
      'present' => 'attendance_status_present',
      'absent' => 'attendance_status_absent',
      'manual' => 'attendance_status_manual',
      _ => 'attendance_status_present',
    };

    final colors = switch (status) {
      'absent' => (
          background: Theme.of(context).colorScheme.errorContainer,
          foreground: Theme.of(context).colorScheme.onErrorContainer,
        ),
      'manual' => (
          background: Theme.of(context).colorScheme.tertiaryContainer,
          foreground: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      _ => (
          background: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSizes.sm),
      ),
      child: Text(
        statusKey.tr(),
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.foreground),
      ),
    );
  }
}
