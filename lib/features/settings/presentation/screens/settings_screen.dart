import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/theme/cubit/theme_state.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  bool _isSigningOutOtherDevices = false;

  Future<void> _handleSignOutOtherDevices() async {
    final cubit = context.read<AuthCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sign_out_other_devices'.tr()),
        content: Text('sign_out_other_devices_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => _isSigningOutOtherDevices = true);

    try {
      await cubit.signOutOtherDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sign_out_other_devices_success'.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sign_out_other_devices_failed'.tr())),
      );
    } finally {
      if (mounted) setState(() => _isSigningOutOtherDevices = false);
    }
  }

  Future<void> _persistLanguageCode(String languageCode) async {
    final currentUser = context.read<AuthCubit>().state.user;

    if (currentUser == null) return;

    final resolvedLanguageCode = languageCode == 'ar' ? 'ar' : 'en';

    try {
      await FirebaseFirestore.instance
          .collection(FirebasePaths.users)
          .doc(currentUser.id)
          .update({FirebasePaths.languageCode: resolvedLanguageCode});
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final cubit = context.read<AuthCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_account_confirm_title'.tr()),
        content: Text('delete_account_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('delete_account'.tr()),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (!context.mounted) return;
    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await cubit.deleteAccount();
      if (!mounted) return;
      if (!context.mounted) return;
      if (_isDeleting) {
        setState(() => _isDeleting = false);
      }
    } catch (_) {
      if (!mounted) return;
      if (!context.mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed_to_delete_account'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    final currentLanguageCode = locale.languageCode;

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.unauthenticated,
      listener: (context, state) {
        if (_isDeleting) {
          setState(() => _isDeleting = false);
        }

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.login, (_) => false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('settings'.tr())),
        body: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Text(
              'language'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSizes.sm),
            Card(
              child: RadioGroup<String>(
                groupValue: currentLanguageCode,
                onChanged: (value) async {
                  if (value == null) return;

                  if (value == 'en') {
                    await context.setLocale(const Locale('en'));
                    if (!context.mounted) return;
                    await _persistLanguageCode('en');
                    if (!context.mounted) return;
                  } else if (value == 'ar') {
                    await context.setLocale(const Locale('ar'));
                    if (!context.mounted) return;
                    await _persistLanguageCode('ar');
                    if (!context.mounted) return;
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
            const SizedBox(height: AppSizes.lg),
            Text('account'.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSizes.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('about'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(RouteNames.about),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('edit_profile'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(RouteNames.editProfile),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text('change_password'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RouteNames.changePassword),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.devices_outlined),
                    title: Text('sign_out_other_devices'.tr()),
                    trailing: _isSigningOutOtherDevices
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    enabled: !_isSigningOutOtherDevices,
                    onTap: _isSigningOutOtherDevices
                        ? null
                        : _handleSignOutOtherDevices,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'delete_account'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    trailing: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    enabled: !_isDeleting,
                    onTap: _isDeleting ? null : _handleDeleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
