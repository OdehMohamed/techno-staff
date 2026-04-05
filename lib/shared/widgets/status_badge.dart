import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _backgroundColor(BuildContext context) {
    switch (status) {
      case 'completed':
      case 'active':
        return Colors.green.withValues(alpha: 0.12);
      case 'in_progress':
        return Colors.orange.withValues(alpha: 0.12);
      case 'inactive':
        return Colors.red.withValues(alpha: 0.12);
      case 'pending':
      default:
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    }
  }

  Color _textColor(BuildContext context) {
    switch (status) {
      case 'completed':
      case 'active':
        return Colors.green.shade700;
      case 'in_progress':
        return Colors.orange.shade700;
      case 'inactive':
        return Colors.red.shade700;
      case 'pending':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _textColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
