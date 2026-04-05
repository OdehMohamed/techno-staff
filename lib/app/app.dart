import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/constants/app_strings.dart';
import '../core/routes/app_navigator.dart';
import '../core/routes/app_router.dart';
import '../core/routes/route_names.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/cubit/theme_cubit.dart';
import '../core/theme/cubit/theme_state.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/cubit/auth_state.dart';

class TechnoStaffApp extends StatelessWidget {
  const TechnoStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            RouteNames.login,
            (route) => false,
          );
        }
      },
      child: BlocBuilder<ThemeCubit, AppThemeMode>(
        builder: (context, themeModeState) {
          ThemeMode themeMode;

          switch (themeModeState) {
            case AppThemeMode.light:
              themeMode = ThemeMode.light;
              break;
            case AppThemeMode.dark:
              themeMode = ThemeMode.dark;
              break;
            case AppThemeMode.system:
              themeMode = ThemeMode.system;
              break;
          }

          return MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            initialRoute: RouteNames.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: [
              ...context.localizationDelegates,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
