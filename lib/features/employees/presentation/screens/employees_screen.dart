import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_drawer.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            RouteNames.addEmployee,
          );

          if (result == true && mounted) {
            context.read<EmployeesCubit>().fetchEmployees();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                if (state.status == EmployeesStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == EmployeesStatus.error) {
                  return Center(
                    child: Text((state.errorMessage ?? 'unknown_error').tr()),
                  );
                }

                if (state.employees.isEmpty) {
                  return Center(child: Text('no_employees_found'.tr()));
                }

                return ListView.separated(
                  itemCount: state.employees.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.md),
                  itemBuilder: (context, index) {
                    final employee = state.employees[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: AppSizes.xs),
                                  Text(employee.email),
                                  const SizedBox(height: AppSizes.xs),
                                  Text('${'role'.tr()}: ${employee.role}'),
                                ],
                              ),
                            ),
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
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
