import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(subtitle!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
