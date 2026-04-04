import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/routes/app_router.dart';
import '../core/routes/route_names.dart';
import '../core/theme/app_theme.dart';

class TechnoStaffApp extends StatelessWidget {
  const TechnoStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: RouteNames.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
