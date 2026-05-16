import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/attendance_model.dart';

class AttendanceCheckButton extends StatelessWidget {
  final AttendanceModel? todayRecord;
  final bool isOnline;
  final bool isSubmitting;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;

  const AttendanceCheckButton({
    super.key,
    required this.todayRecord,
    required this.isOnline,
    required this.isSubmitting,
    this.onCheckIn,
    this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    final hasOpenSession = todayRecord?.hasOpenSession ?? false;
    final canCheckIn = todayRecord == null || !hasOpenSession;
    final canCheckOut = hasOpenSession;

    String actionKey = 'check_in';
    IconData icon = Icons.login;
    VoidCallback? onPressed = canCheckIn ? onCheckIn : null;

    if (canCheckOut) {
      actionKey = 'check_out';
      icon = Icons.logout;
      onPressed = onCheckOut;
    }

    if (!isOnline) {
      onPressed = null;
    }

    final subtitleKey = !isOnline
        ? 'no_internet_for_attendance'
        : hasOpenSession
        ? 'checked_in'
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: (isSubmitting || onPressed == null) ? null : onPressed,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(actionKey.tr()),
          ),
          if (subtitleKey != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              subtitleKey.tr(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
