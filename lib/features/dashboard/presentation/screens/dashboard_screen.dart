import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Techno Staff Dashboard', style: textTheme.headlineMedium),
            const SizedBox(height: AppSizes.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: textTheme.titleLarge),
                    const SizedBox(height: AppSizes.sm),
                    const Text('This is the starting dashboard screen.'),
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
