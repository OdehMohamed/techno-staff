import 'package:flutter/material.dart';
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
      case RouteNames.updateRequired:
        return MaterialPageRoute(
          builder: (_) => UpdateRequiredScreen(
            storeUrl: settings.arguments as String?,
          ),
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
