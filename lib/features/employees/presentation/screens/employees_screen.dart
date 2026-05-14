import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../cubit/employees_cubit.dart';
import '../cubit/employees_state.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().fetchEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('employees'.tr())),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            RouteNames.addEmployee,
          );

          if (!context.mounted) return;

          if (result == true) {
            context.read<EmployeesCubit>().fetchEmployees();
          }
        },
        icon: const Icon(Icons.add),
        label: Text('add_employee'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                if (state.status == EmployeesStatus.loading &&
                    state.employees.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == EmployeesStatus.error) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<EmployeesCubit>().fetchEmployees(silent: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyStateWidget(
                          icon: Icons.error_outline,
                          titleKey: state.errorMessage ?? 'unknown_error',
                        ),
                      ],
                    ),
                  );
                }

                final currentUserId = context.read<AuthCubit>().state.user?.id;

                final visibleEmployees = state.employees
                    .where((employee) => employee.id != currentUserId)
                    .toList();

                if (visibleEmployees.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<EmployeesCubit>().fetchEmployees(silent: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        EmptyStateWidget(
                          icon: Icons.group_off_outlined,
                          titleKey: 'no_employees_found',
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'employees'.tr(),
                      subtitle: 'Manage employees and control account access'
                          .tr(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => context
                            .read<EmployeesCubit>()
                            .fetchEmployees(silent: true),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: visibleEmployees.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSizes.md),
                          itemBuilder: (context, index) {
                            final employee = visibleEmployees[index];

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: AppCard(
                                child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    child: Text(
                                      employee.name.isNotEmpty
                                          ? employee.name[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                employee.name,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                              ),
                                            ),
                                            StatusBadge(
                                              status: employee.isActive
                                                  ? 'active'
                                                  : 'inactive',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSizes.sm),
                                        Text(employee.email),
                                        const SizedBox(height: AppSizes.xs),
                                        Text(
                                          '${'role'.tr()}: ${employee.role.tr()}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Column(
                                    children: [
                                      Switch(
                                        value: employee.isActive,
                                        onChanged: (value) {
                                          context
                                              .read<EmployeesCubit>()
                                              .toggleEmployeeStatus(
                                                userId: employee.id,
                                                isActive: value,
                                              );
                                        },
                                      ),
                                      Text(
                                        employee.isActive
                                            ? 'active'.tr()
                                            : 'inactive'.tr(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
