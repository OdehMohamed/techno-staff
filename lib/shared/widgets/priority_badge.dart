import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  Color _backgroundColor() {
    switch (priority) {
      case 'high':
        return Colors.red.withValues(alpha: 0.12);
      case 'medium':
        return Colors.orange.withValues(alpha: 0.12);
      case 'low':
      default:
        return Colors.blue.withValues(alpha: 0.12);
    }
  }

  Color _textColor() {
    switch (priority) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
      default:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _textColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
