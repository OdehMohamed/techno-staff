import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('dashboard'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('dashboard_title'.tr(), style: textTheme.headlineMedium),
            const SizedBox(height: AppSizes.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('overview'.tr(), style: textTheme.titleLarge),
                    const SizedBox(height: AppSizes.sm),
                    Text('starting_dashboard_message'.tr()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
