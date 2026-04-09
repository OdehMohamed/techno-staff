import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/core/services/notification_service.dart';
import 'package:techno_staff/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:techno_staff/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:techno_staff/features/reports/data/repositories/reports_repository.dart';
import 'package:techno_staff/features/reports/data/services/pdf_report_service.dart';
import 'package:techno_staff/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/task_details_cubit.dart';
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔵 Background Message: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.showForegroundNotification(message);
  });
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
        ],
        child: const TechnoStaffApp(),
      ),
    ),
  );
}
