import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/core/routes/app_navigator.dart';
import 'package:techno_staff/core/routes/route_names.dart';
import 'package:techno_staff/core/services/notification_service.dart';
import 'package:techno_staff/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:techno_staff/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:techno_staff/features/notifications/data/repositories/notifications_repository.dart';
import 'package:techno_staff/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:techno_staff/features/reports/data/repositories/reports_repository.dart';
import 'package:techno_staff/features/reports/data/services/pdf_report_service.dart';
import 'package:techno_staff/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/task_logs_cubit.dart';
import 'app/app.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/user_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'firebase_options.dart';
import 'features/employees/data/repositories/employees_repository.dart';
import 'features/employees/presentation/cubit/employees_cubit.dart';
import 'features/tasks/data/repositories/tasks_repository.dart';
import 'features/tasks/presentation/cubit/tasks_cubit.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.initialize(
    onNotificationTap: (payload) {
      AppNavigator.navigatorKey.currentState?.pushNamed(
        RouteNames.taskDetails,
        arguments: payload,
      );
    },
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.showForegroundNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final taskId = message.data['taskId'];

    if (taskId != null) {
      AppNavigator.navigatorKey.currentState?.pushNamed(
        RouteNames.taskDetails,
        arguments: taskId,
      );
    }
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    final taskId = initialMessage.data['taskId'];

    if (taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigator.navigatorKey.currentState?.pushNamed(
          RouteNames.taskDetails,
          arguments: taskId,
        );
      });
    }
  }

  final authRepository = AuthRepository();
  final userRepository = UserRepository();
  final employeesRepository = EmployeesRepository();
  final tasksRepository = TasksRepository(FirebaseFirestore.instance);
  final dashboardRepository = DashboardRepository();
  final reportsRepository = ReportsRepository();
  final pdfReportService = PdfReportService();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(
            create: (_) => AuthCubit(
              authRepository: authRepository,
              userRepository: userRepository,
            ),
          ),
          BlocProvider(
            create: (_) =>
                EmployeesCubit(employeesRepository: employeesRepository),
          ),
          BlocProvider(
            create: (_) => TasksCubit(tasksRepository: tasksRepository),
          ),
          BlocProvider(
            create: (_) => TaskDetailsCubit(tasksRepository: tasksRepository),
          ),
          BlocProvider(
            create: (_) =>
                DashboardCubit(dashboardRepository: dashboardRepository),
          ),
          BlocProvider(
            create: (_) => ReportsCubit(
              reportsRepository: reportsRepository,
              pdfReportService: pdfReportService,
            ),
          ),
          BlocProvider(
            create: (_) => TaskLogsCubit(tasksRepository: tasksRepository),
          ),
          BlocProvider(
            create: (_) => NotificationsCubit(NotificationsRepository()),
          ),
        ],
        child: const TechnoStaffApp(),
      ),
    ),
  );
}
