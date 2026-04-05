import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String? subtitleKey;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.titleKey,
    this.subtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              titleKey.tr(),
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitleKey != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                subtitleKey!.tr(),
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
