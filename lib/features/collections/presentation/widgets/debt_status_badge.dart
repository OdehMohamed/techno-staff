import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DebtStatusBadge extends StatelessWidget {
  final String status;

  const DebtStatusBadge({super.key, required this.status});

  Color _backgroundColor() {
    switch (status) {
      case 'overdue':
        return Colors.red.withValues(alpha: 0.12);
      case 'active':
        return Colors.green.withValues(alpha: 0.12);
      case 'partial':
        return Colors.orange.withValues(alpha: 0.12);
      case 'settled':
        return Colors.teal.withValues(alpha: 0.12);
      case 'disputed':
        return Colors.amber.withValues(alpha: 0.12);
      case 'written_off':
      case 'cancelled':
      default:
        return Colors.grey.withValues(alpha: 0.12);
    }
  }

  Color _textColor() {
    switch (status) {
      case 'overdue':
        return Colors.red.shade700;
      case 'active':
        return Colors.green.shade700;
      case 'partial':
        return Colors.orange.shade700;
      case 'settled':
        return Colors.teal.shade700;
      case 'disputed':
        return Colors.amber.shade800;
      case 'written_off':
      case 'cancelled':
      default:
        return Colors.grey.shade700;
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
        'debt_status_$status'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _textColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
