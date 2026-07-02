import 'package:flutter/material.dart';
import 'package:techno_staff/app/collector_app.dart';
import 'package:techno_staff/features/collections/data/models/customer_model.dart';
import 'package:techno_staff/features/collections/data/models/debt_model.dart';
import 'package:techno_staff/features/collections/presentation/screens/admin_customer_detail_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/admin_customer_form_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/admin_customer_list_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/admin_debt_form_screen.dart';
import 'package:techno_staff/features/collections/data/models/handover_model.dart';
import 'package:techno_staff/features/collections/data/models/installment_plan_model.dart';
import 'package:techno_staff/features/collections/data/models/payment_model.dart';
import 'package:techno_staff/features/collections/presentation/screens/aging_report_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/collections_dashboard_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/collections_settings_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/installment_plan_detail_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/installment_plan_form_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/log_visit_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/debt_detail_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/handover_init_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/handover_list_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/handover_verification_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/payment_detail_loader_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/debt_detail_loader_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/payment_detail_screen.dart';
import 'package:techno_staff/features/collections/presentation/screens/record_payment_screen.dart';
import 'package:techno_staff/features/admin/presentation/screens/admin_attendance_screen.dart';
import 'package:techno_staff/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:techno_staff/features/chat/presentation/screens/conversation_screen.dart';
import 'package:techno_staff/features/chat/presentation/screens/group_settings_screen.dart';
import 'package:techno_staff/features/chat/presentation/screens/new_group_screen.dart';
import 'package:techno_staff/features/attendance/presentation/screens/employee_monthly_attendance_screen.dart';
import 'package:techno_staff/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:techno_staff/features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:techno_staff/features/reports/presentation/screens/reports_screen.dart';
import 'package:techno_staff/features/tasks/presentation/screens/task_details_loader_screen.dart';
import '../../features/employees/presentation/screens/add_employee_screen.dart';
import '../../features/employees/presentation/screens/employees_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/employee/presentation/screens/employee_home_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/tasks/presentation/screens/add_task_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/tasks/data/models/task_model.dart';
import '../../features/tasks/data/models/task_template_model.dart';
import '../../features/tasks/presentation/screens/edit_task_screen.dart';
import '../../features/tasks/presentation/screens/task_details_screen.dart';
import '../../features/tasks/presentation/screens/recurring_tasks_screen.dart';
import '../../features/tasks/presentation/screens/add_template_screen.dart';
import '../../features/tasks/presentation/screens/edit_template_screen.dart';
import '../../features/update/presentation/screens/update_required_screen.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case RouteNames.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case RouteNames.adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
          settings: settings,
        );

      case RouteNames.employeeHome:
        return MaterialPageRoute(
          builder: (_) => const EmployeeHomeScreen(),
          settings: settings,
        );

      case RouteNames.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      case RouteNames.employees:
        return MaterialPageRoute(
          builder: (_) => const EmployeesScreen(),
          settings: settings,
        );

      case RouteNames.addEmployee:
        return MaterialPageRoute(
          builder: (_) => const AddEmployeeScreen(),
          settings: settings,
        );

      case RouteNames.tasks:
        return MaterialPageRoute(
          builder: (_) => const TasksScreen(),
          settings: settings,
        );

      case RouteNames.addTask:
        return MaterialPageRoute(
          builder: (_) => const AddTaskScreen(),
          settings: settings,
        );

      case RouteNames.taskDetails:
        final argument = settings.arguments;

        if (argument is String) {
          return MaterialPageRoute(
            builder: (_) => TaskDetailsLoaderScreen(taskId: argument),
            settings: settings,
          );
        }

        if (argument is TaskModel) {
          return MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(task: argument),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Invalid task details argument')),
          ),
          settings: settings,
        );

      case RouteNames.editTask:
        final task = settings.arguments as TaskModel;
        return MaterialPageRoute(
          builder: (_) => EditTaskScreen(task: task),
          settings: settings,
        );
      case RouteNames.reports:
        return MaterialPageRoute(
          builder: (_) => const ReportsScreen(),
          settings: settings,
        );
      case RouteNames.notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          settings: settings,
        );
      case RouteNames.about:
        return MaterialPageRoute(
          builder: (_) => const AboutScreen(),
          settings: settings,
        );
      case RouteNames.editProfile:
        return MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
          settings: settings,
        );
      case RouteNames.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
          settings: settings,
        );
      case RouteNames.recurringTasks:
        return MaterialPageRoute(
          builder: (_) => const RecurringTasksScreen(),
          settings: settings,
        );
      case RouteNames.addTemplate:
        return MaterialPageRoute(
          builder: (_) => const AddTemplateScreen(),
          settings: settings,
        );
      case RouteNames.editTemplate:
        final template = settings.arguments as TaskTemplateModel;
        return MaterialPageRoute(
          builder: (_) => EditTemplateScreen(template: template),
          settings: settings,
        );
      case RouteNames.attendance:
        return MaterialPageRoute(
          builder: (_) => const AttendanceScreen(),
          settings: settings,
        );
      case RouteNames.employeeMonthlyAttendance:
        return MaterialPageRoute(
          builder: (_) => const EmployeeMonthlyAttendanceScreen(),
          settings: settings,
        );
      case RouteNames.adminAttendance:
        return MaterialPageRoute(
          builder: (_) => const AdminAttendanceScreen(),
          settings: settings,
        );
      case RouteNames.updateRequired:
        return MaterialPageRoute(
          builder: (_) =>
              UpdateRequiredScreen(storeUrl: settings.arguments as String?),
          settings: settings,
        );

      case RouteNames.chatList:
        return MaterialPageRoute(
          builder: (_) => const ChatListScreen(),
          settings: settings,
        );

      case RouteNames.conversation:
        final arg = settings.arguments;
        final conversationId = arg is String ? arg : '';
        return MaterialPageRoute(
          builder: (_) => ConversationScreen(conversationId: conversationId),
          settings: settings,
        );

      case RouteNames.newGroup:
        return MaterialPageRoute(
          builder: (_) => const NewGroupScreen(),
          settings: settings,
        );

      case RouteNames.groupSettings:
        return MaterialPageRoute(
          builder: (_) => const GroupSettingsScreen(),
          settings: settings,
        );

      // Collections subsystem (v2.0.0)
      case RouteNames.collectorHome:
        return MaterialPageRoute(
          builder: (_) => const CollectorApp(),
          settings: settings,
        );

      case RouteNames.customerList:
        return MaterialPageRoute(
          builder: (_) => const AdminCustomerListScreen(),
          settings: settings,
        );

      case RouteNames.addCustomer:
        return MaterialPageRoute(
          builder: (_) => const AdminCustomerFormScreen(),
          settings: settings,
        );

      case RouteNames.editCustomer:
        return MaterialPageRoute(
          builder: (_) => AdminCustomerFormScreen(
            customer: settings.arguments as CustomerModel,
          ),
          settings: settings,
        );

      case RouteNames.customerDetail:
        return MaterialPageRoute(
          builder: (_) => AdminCustomerDetailScreen(
            customer: settings.arguments as CustomerModel,
          ),
          settings: settings,
        );

      case RouteNames.addDebt:
        final addArgs = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AdminDebtFormScreen(
            customer: addArgs['customer'] as CustomerModel,
          ),
          settings: settings,
        );

      case RouteNames.editDebt:
        final editArgs = settings.arguments as Map<String, dynamic>;
        final editDebt = editArgs['debt'] as DebtModel;
        final minimalCustomer = CustomerModel(
          id: editDebt.customerId,
          name: editDebt.customerName,
          phone: '',
          assignedCollectorId: editDebt.assignedCollectorId,
          assignedCollectorName: editDebt.assignedCollectorName,
          accountStatus: 'good_standing',
          createdBy: '',
          createdByName: '',
          createdAt: editDebt.createdAt,
          isActive: true,
        );
        return MaterialPageRoute(
          builder: (_) => AdminDebtFormScreen(
            customer: minimalCustomer,
            debt: editDebt,
          ),
          settings: settings,
        );

      case RouteNames.debtDetail:
        return MaterialPageRoute(
          builder: (_) => DebtDetailScreen(
            debt: settings.arguments as DebtModel,
          ),
          settings: settings,
        );

      case RouteNames.recordPayment:
        return MaterialPageRoute(
          builder: (_) => RecordPaymentScreen(
            debt: settings.arguments as DebtModel,
          ),
          settings: settings,
        );

      case RouteNames.paymentDetail:
        return MaterialPageRoute(
          builder: (_) => PaymentDetailScreen(
            payment: settings.arguments as PaymentModel,
          ),
          settings: settings,
        );

      case RouteNames.paymentDetailLoader:
        return MaterialPageRoute(
          builder: (_) => PaymentDetailLoaderScreen(
            paymentId: settings.arguments as String,
          ),
          settings: settings,
        );

      case RouteNames.debtDetailLoader:
        return MaterialPageRoute(
          builder: (_) => DebtDetailLoaderScreen(
            debtId: settings.arguments as String,
          ),
          settings: settings,
        );

      case RouteNames.handoverList:
        return MaterialPageRoute(
          builder: (_) => const HandoverListScreen(),
          settings: settings,
        );

      case RouteNames.handoverInit:
        return MaterialPageRoute(
          builder: (_) => const HandoverInitScreen(),
          settings: settings,
        );

      case RouteNames.handoverVerification:
        return MaterialPageRoute(
          builder: (_) => HandoverVerificationScreen(
            handover: settings.arguments as HandoverModel,
          ),
          settings: settings,
        );

      case RouteNames.installmentPlanDetail:
        return MaterialPageRoute(
          builder: (_) => InstallmentPlanDetailScreen(
            plan: settings.arguments as InstallmentPlanModel,
          ),
          settings: settings,
        );

      case RouteNames.createInstallmentPlan:
        return MaterialPageRoute(
          builder: (_) => InstallmentPlanFormScreen(
            debt: settings.arguments as DebtModel,
          ),
          settings: settings,
        );

      case RouteNames.logVisit:
        return MaterialPageRoute(
          builder: (_) => LogVisitScreen(
            debt: settings.arguments as DebtModel,
          ),
          settings: settings,
        );

      case RouteNames.collectionsSettings:
        return MaterialPageRoute(
          builder: (_) => const CollectionsSettingsScreen(),
          settings: settings,
        );

      case RouteNames.collectionsDashboard:
        return MaterialPageRoute(
          builder: (_) => const CollectionsDashboardScreen(),
          settings: settings,
        );

      case RouteNames.agingReport:
        return MaterialPageRoute(
          builder: (_) => const AgingReportScreen(),
          settings: settings,
        );


      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('No route found'))),
        );
    }
  }
}
