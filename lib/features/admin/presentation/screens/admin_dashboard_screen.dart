import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_drawer.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('dashboard'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('admin_dashboard'.tr(), style: textTheme.headlineMedium),
                const SizedBox(height: AppSizes.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;

                    if (isWide) {
                      return Row(
                        children: const [
                          Expanded(child: _StatsCard(titleKey: 'total_tasks')),
                          SizedBox(width: AppSizes.md),
                          Expanded(
                            child: _StatsCard(titleKey: 'completed_tasks'),
                          ),
                          SizedBox(width: AppSizes.md),
                          Expanded(child: _StatsCard(titleKey: 'employees')),
                        ],
                      );
                    }

                    return const Column(
                      children: [
                        _StatsCard(titleKey: 'total_tasks'),
                        SizedBox(height: AppSizes.md),
                        _StatsCard(titleKey: 'completed_tasks'),
                        SizedBox(height: AppSizes.md),
                        _StatsCard(titleKey: 'employees'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String titleKey;

  const _StatsCard({required this.titleKey});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titleKey.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSizes.sm),
            Text('0', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
