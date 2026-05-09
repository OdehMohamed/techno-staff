import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/routes/route_names.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.name ?? '-'),
              accountEmail: Text(user?.email ?? '-'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            if (user?.role == 'admin')
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: Text('dashboard'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    RouteNames.adminDashboard,
                  );
                },
              ),
            if (user?.role == 'admin')
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text('employees'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, RouteNames.employees);
                },
              ),
            if (user?.role == 'employee')
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text('home'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    RouteNames.employeeHome,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.task_outlined),
              title: Text('tasks'.tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, RouteNames.tasks);
              },
            ),
            if (user?.role == 'admin')
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: Text('reports'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, RouteNames.reports);
                },
              ),
            if (user?.role == 'admin')
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text('recurring_tasks'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    RouteNames.recurringTasks,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text('settings'.tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, RouteNames.settings);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('logout'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthCubit>().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
