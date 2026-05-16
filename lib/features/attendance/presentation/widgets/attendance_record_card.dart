import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/attendance_session.dart';

class AttendanceRecordCard extends StatefulWidget {
  final AttendanceModel record;

  const AttendanceRecordCard({super.key, required this.record});

  @override
  State<AttendanceRecordCard> createState() => _AttendanceRecordCardState();
}

class _AttendanceRecordCardState extends State<AttendanceRecordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final locale = context.locale.languageCode;
    final parsedDate = DateTime.tryParse(record.date);
    final dateLabel =
        parsedDate != null ? DateFormat.yMMMd(locale).format(parsedDate) : record.date;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSizes.sm),
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
                    if (record.isCorrected) ...[
                      const SizedBox(width: AppSizes.xs),
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                    if (record.notes?.isNotEmpty == true) ...[
                      const SizedBox(width: AppSizes.xs),
                      Icon(
                        Icons.note_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                    const SizedBox(width: AppSizes.xs),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${_formatTime(record.checkInAt)} → ${_formatTime(record.checkOutAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(record.totalDurationMinutes),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (record.sessions.length > 1) ...[
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        '· ${'sessions_count'.tr(namedArgs: {'count': '${record.sessions.length}'})}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? _DetailSection(record: record)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

class _DetailSection extends StatelessWidget {
  final AttendanceModel record;

  const _DetailSection({required this.record});

  @override
  Widget build(BuildContext context) {
    final dimStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSizes.md),
        ...List.generate(record.sessions.length, (i) {
          return _SessionDetailRow(
            index: i + 1,
            session: record.sessions[i],
          );
        }),
        if (record.notes?.isNotEmpty == true) ...[
          const SizedBox(height: AppSizes.xs),
          Text('notes'.tr(), style: dimStyle),
          const SizedBox(height: 2),
          Text(record.notes!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (record.isCorrected) ...[
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'corrected_by'.tr(namedArgs: {
                  'name': record.correctedByName?.isNotEmpty == true
                      ? record.correctedByName!
                      : 'admin'.tr(),
                }),
                style: dimStyle,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SessionDetailRow extends StatelessWidget {
  final int index;
  final AttendanceSession session;

  const _SessionDetailRow({required this.index, required this.session});

  @override
  Widget build(BuildContext context) {
    final checkIn = DateFormat('HH:mm').format(session.checkInAt.toLocal());
    final checkOut = session.checkOutAt != null
        ? DateFormat('HH:mm').format(session.checkOutAt!.toLocal())
        : '--:--';
    final duration = session.durationMinutes != null
        ? _formatDuration(session.durationMinutes!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Row(
        children: [
          Text(
            'session_number'.tr(namedArgs: {'n': '$index'}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: AppSizes.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$checkIn → $checkOut',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (duration.isNotEmpty) ...[
            const Spacer(),
            Text(
              duration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
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
      'manual' => 'attendance_status_present',
      _ => 'attendance_status_present',
    };

    final colors = switch (status) {
      'absent' => (
          background: Theme.of(context).colorScheme.errorContainer,
          foreground: Theme.of(context).colorScheme.onErrorContainer,
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
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: colors.foreground),
      ),
    );
  }
}

String _formatDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

