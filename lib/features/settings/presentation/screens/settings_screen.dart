import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/theme/cubit/theme_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    final currentLanguageCode = locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text('language'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: RadioGroup<String>(
              groupValue: currentLanguageCode,
              onChanged: (value) async {
                if (value == null) return;

                if (value == 'en') {
                  await context.setLocale(const Locale('en'));
                } else if (value == 'ar') {
                  await context.setLocale(const Locale('ar'));
                }
              },
              child: Column(
                children: const [
                  RadioListTile<String>(value: 'en', title: Text('English')),
                  RadioListTile<String>(value: 'ar', title: Text('العربية')),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'appearance'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSizes.sm),
          BlocBuilder<ThemeCubit, AppThemeMode>(
            builder: (context, themeMode) {
              return Card(
                child: RadioGroup<AppThemeMode>(
                  groupValue: themeMode,
                  onChanged: (value) {
                    if (value == null) return;

                    switch (value) {
                      case AppThemeMode.system:
                        context.read<ThemeCubit>().setSystemTheme();
                        break;
                      case AppThemeMode.light:
                        context.read<ThemeCubit>().setLightTheme();
                        break;
                      case AppThemeMode.dark:
                        context.read<ThemeCubit>().setDarkTheme();
                        break;
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<AppThemeMode>(
                        value: AppThemeMode.system,
                        title: Text('system_default'.tr()),
                      ),
                      RadioListTile<AppThemeMode>(
                        value: AppThemeMode.light,
                        title: Text('light_mode'.tr()),
                      ),
                      RadioListTile<AppThemeMode>(
                        value: AppThemeMode.dark,
                        title: Text('dark_mode'.tr()),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
