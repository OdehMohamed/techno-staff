import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'countdown_clock_provider.dart';

/// Pill chip that shows time-to-deadline (end-of-day of dueDate). Rebuilds
/// on every tick of the enclosing CountdownClockProvider, but the rebuild is
/// scoped to this widget only — parent AppCard/InkWell stay stable.
///
/// Hidden when isCompleted == true.
class CountdownChip extends StatelessWidget {
  final DateTime dueDate;
  final bool isCompleted;

  const CountdownChip({
    super.key,
    required this.dueDate,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) return const SizedBox.shrink();

    final clock = CountdownClockProvider.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: clock,
      builder: (context, now, _) {
        final endOfDay = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          23,
          59,
          59,
        );
        final remaining = endOfDay.difference(now);
        final visual = _resolveVisual(context, remaining);
        return _ChipBody(
          icon: visual.icon,
          label: _formatLabel(context, remaining, dueDate, now),
          background: visual.background,
          foreground: visual.foreground,
        );
      },
    );
  }

  String _formatLabel(
    BuildContext context,
    Duration remaining,
    DateTime dueDate,
    DateTime now,
  ) {
    if (remaining <= Duration.zero && _isSameCalendarDay(dueDate, now)) {
      return 'due_today'.tr();
    }

    if (remaining >= const Duration(days: 1)) {
      final days = remaining.inDays;
      return 'due_in_days'.plural(days);
    }

    if (remaining > const Duration(hours: 1) ||
        remaining == const Duration(hours: 1)) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      return 'due_in_hours_minutes'.tr(
        namedArgs: {'hours': hours.toString(), 'minutes': minutes.toString()},
      );
    }

    if (remaining > Duration.zero) {
      final minutes = remaining.inMinutes <= 0 ? 1 : remaining.inMinutes;
      return 'due_in_minutes'.tr(namedArgs: {'minutes': minutes.toString()});
    }

    final overdue = remaining.abs();
    if (overdue >= const Duration(days: 1)) {
      final days = overdue.inDays <= 0 ? 1 : overdue.inDays;
      return 'overdue_by_days'.plural(days);
    }

    final hours = overdue.inHours <= 0 ? 1 : overdue.inHours;
    return 'overdue_by_hours'.tr(namedArgs: {'count': hours.toString()});
  }

  _CountdownVisual _resolveVisual(BuildContext context, Duration remaining) {
    if (remaining <= Duration.zero) {
      return _CountdownVisual(
        icon: Icons.warning_amber_rounded,
        background: Colors.red.withValues(alpha: 0.12),
        foreground: Colors.red.shade700,
      );
    }

    if (remaining <= const Duration(hours: 24)) {
      return _CountdownVisual(
        icon: Icons.schedule,
        background: Colors.orange.withValues(alpha: 0.12),
        foreground: Colors.orange.shade700,
      );
    }

    return _CountdownVisual(
      icon: Icons.schedule,
      background: Theme.of(context).colorScheme.surfaceContainerHighest,
      foreground: Theme.of(context).colorScheme.onSurface,
    );
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ChipBody extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _ChipBody({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownVisual {
  final IconData icon;
  final Color background;
  final Color foreground;

  const _CountdownVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });
}
