import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text('language'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: locale.languageCode,
                  title: const Text('English'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await context.setLocale(const Locale('en'));
                  },
                ),
                RadioListTile<String>(
                  value: 'ar',
                  groupValue: locale.languageCode,
                  title: const Text('العربية'),
                  onChanged: (value) async {
                    if (value == null) return;
                    await context.setLocale(const Locale('ar'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'appearance'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSizes.sm),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: Text('Theme switcher will be connected next.'),
            ),
          ),
        ],
      ),
    );
  }
}
