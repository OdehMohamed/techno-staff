import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techno_staff/core/routes/app_navigator.dart';
import 'package:techno_staff/core/routes/route_names.dart';
import 'package:techno_staff/core/services/notification_service.dart';
import 'package:techno_staff/features/attendance/data/repositories/attendance_repository.dart';
import 'package:techno_staff/features/attendance/data/repositories/schedule_repository.dart';
import 'package:techno_staff/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:techno_staff/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:techno_staff/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:techno_staff/features/notifications/data/repositories/notifications_repository.dart';
import 'package:techno_staff/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:techno_staff/features/reports/data/repositories/reports_repository.dart';
import 'package:techno_staff/features/reports/data/services/pdf_report_service.dart';
import 'package:techno_staff/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:techno_staff/features/chat/data/repositories/chat_repository.dart';
import 'package:techno_staff/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:techno_staff/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/task_logs_cubit.dart';
import 'app/app.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'core/theme/cubit/theme_state.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/user_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'firebase_options.dart';
import 'features/employees/data/repositories/employees_repository.dart';
import 'features/employees/presentation/cubit/employees_cubit.dart';
import 'features/tasks/data/repositories/task_attachments_repository.dart';
import 'features/tasks/data/repositories/tasks_repository.dart';
import 'features/tasks/data/repositories/templates_repository.dart';
import 'features/tasks/presentation/cubit/task_attachments_cubit.dart';
import 'features/tasks/presentation/cubit/tasks_cubit.dart';
import 'features/tasks/presentation/cubit/templates_cubit.dart';
import 'features/collections/data/repositories/customers_repository.dart';
import 'features/collections/data/repositories/debts_repository.dart';
import 'features/collections/data/repositories/payments_repository.dart';
import 'features/collections/data/repositories/handovers_repository.dart';
import 'features/collections/data/repositories/installments_repository.dart';
import 'features/collections/data/repositories/visits_repository.dart';
import 'features/collections/presentation/cubit/customers_cubit.dart';
import 'features/collections/presentation/cubit/debts_admin_cubit.dart';
import 'features/collections/presentation/cubit/collector_debts_cubit.dart';
import 'features/collections/presentation/cubit/payments_cubit.dart';
import 'features/collections/presentation/cubit/handover_cubit.dart';
import 'features/collections/presentation/cubit/installment_cubit.dart';
import 'features/collections/presentation/cubit/collections_dashboard_cubit.dart';
import 'features/collections/presentation/cubit/visit_cubit.dart';

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

  late final SharedPreferences prefs;
  AppThemeMode initialThemeMode = AppThemeMode.system;
  try {
    // Hydrate theme preference synchronously so the first frame paints correctly.
    prefs = await SharedPreferences.getInstance();
    final storedThemeName = prefs.getString('theme_mode');
    initialThemeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == storedThemeName,
      orElse: () => AppThemeMode.system,
    );
  } catch (e, stack) {
    await FirebaseCrashlytics.instance.recordError(e, stack);
    prefs = await SharedPreferences.getInstance();
  }

  // On iOS, let firebase_messaging present FCM banners natively in the
  // foreground. A Dart-side local notification cannot be used for this because
  // firebase_messaging's foreground presentation option is applied to every
  // notification it sees and silently suppresses our local one. Per-conversation
  // suppression is therefore handled natively in AppDelegate.willPresent, which
  // reads the active conversation id ConversationCubit writes to UserDefaults.
  if (Platform.isIOS) {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: false,
      sound: true,
    );
  }

  // Created before the FCM listeners so the onMessage handler can check
  // activeConversationId without going through BuildContext.
  final chatRepository = ChatRepository(FirebaseFirestore.instance);
  final conversationCubit = ConversationCubit(chatRepository: chatRepository);

  await NotificationService.initialize(
    onNotificationTap: (payload) {
      // Payload format: 'conv:<conversationId>' for chat, raw taskId for tasks.
      if (payload.startsWith('conv:')) {
        final conversationId = payload.substring(5);
        AppNavigator.navigatorKey.currentState?.pushNamed(
          RouteNames.conversation,
          arguments: conversationId,
        );
      } else {
        AppNavigator.navigatorKey.currentState?.pushNamed(
          RouteNames.taskDetails,
          arguments: payload,
        );
      }
    },
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // iOS: foreground display and per-conversation suppression are both handled
    // natively in AppDelegate.willPresent (firebase_messaging presents the banner
    // before Dart can intervene), so there is nothing to do here.
    if (Platform.isIOS) return;

    final conversationId = message.data['conversationId'];
    // Android: suppress when the user already has this conversation open.
    if (conversationId != null &&
        conversationCubit.activeConversationId == conversationId) {
      return;
    }
    NotificationService.showForegroundNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final conversationId = message.data['conversationId'];
    final taskId = message.data['taskId'];

    if (conversationId != null) {
      AppNavigator.navigatorKey.currentState?.pushNamed(
        RouteNames.conversation,
        arguments: conversationId,
      );
    } else if (taskId != null) {
      AppNavigator.navigatorKey.currentState?.pushNamed(
        RouteNames.taskDetails,
        arguments: taskId,
      );
    }
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    final conversationId = initialMessage.data['conversationId'];
    final taskId = initialMessage.data['taskId'];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conversationId != null) {
        AppNavigator.navigatorKey.currentState?.pushNamed(
          RouteNames.conversation,
          arguments: conversationId,
        );
      } else if (taskId != null) {
        AppNavigator.navigatorKey.currentState?.pushNamed(
          RouteNames.taskDetails,
          arguments: taskId,
        );
      }
    });
  }

  final authRepository = AuthRepository();
  final userRepository = UserRepository();
  final employeesRepository = EmployeesRepository();
  final tasksRepository = TasksRepository(FirebaseFirestore.instance);
  final templatesRepository = TemplatesRepository(FirebaseFirestore.instance);
  final dashboardRepository = DashboardRepository();
  final reportsRepository = ReportsRepository();
  final pdfReportService = PdfReportService();
  final attendanceRepository = AttendanceRepository();
  final scheduleRepository = ScheduleRepository();
  final taskAttachmentsRepository = TaskAttachmentsRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
  final customersRepository = CustomersRepository();
  final debtsRepository = DebtsRepository();
  final paymentsRepository = PaymentsRepository();
  final handoversRepository = HandoversRepository();
  final installmentsRepository = InstallmentsRepository();
  final visitsRepository = VisitsRepository();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                ThemeCubit(prefs: prefs, initialMode: initialThemeMode),
          ),
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
          BlocProvider(
            create: (_) => AttendanceCubit(
              attendanceRepository: attendanceRepository,
              scheduleRepository: scheduleRepository,
            ),
          ),
          BlocProvider(
            create: (_) =>
                TemplatesCubit(templatesRepository: templatesRepository),
          ),
          BlocProvider(
            create: (_) =>
                ChatListCubit(chatRepository: chatRepository),
          ),
          BlocProvider(
            create: (_) => TaskAttachmentsCubit(
              repository: taskAttachmentsRepository,
            ),
          ),
          // Pre-created instance — shared with the FCM onMessage suppression
          // logic above so no BuildContext is needed in the listener.
          BlocProvider.value(value: conversationCubit),
          BlocProvider(
            create: (_) => CustomersCubit(customersRepository: customersRepository),
          ),
          BlocProvider(
            create: (_) => DebtsAdminCubit(debtsRepository: debtsRepository),
          ),
          BlocProvider(
            create: (_) => CollectorDebtsCubit(debtsRepository: debtsRepository),
          ),
          BlocProvider(
            create: (_) => PaymentsCubit(paymentsRepository),
          ),
          BlocProvider(
            create: (_) => HandoverCubit(handoversRepository),
          ),
          BlocProvider(
            create: (_) => InstallmentCubit(installmentsRepository),
          ),
          BlocProvider(
            create: (_) => VisitCubit(visitsRepository),
          ),
          BlocProvider(
            create: (_) => CollectionsDashboardCubit(),
          ),
        ],
        child: const TechnoStaffApp(),
      ),
    ),
  );
}
