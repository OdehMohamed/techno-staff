import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../cubit/tasks_cubit.dart';
import '../cubit/tasks_state.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
    });
  }

  void _loadTasks() {
    final authState = context.read<AuthCubit>().state;
    final user = authState.user;

    if (user == null) return;
    debugPrint('TASKS SCREEN USER ID: ${user.id}');
    debugPrint('TASKS SCREEN USER ROLE: ${user.role}');
    debugPrint('TASKS SCREEN USER EMAIL: ${user.email}');
    if (user.role == 'admin') {
      context.read<TasksCubit>().fetchAllTasks();
    } else {
      context.read<TasksCubit>().fetchTasksForUser(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text('tasks'.tr())),
      drawer: const AppDrawer(),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  RouteNames.addTask,
                );

                if (result == true && mounted) {
                  _loadTasks();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: BlocBuilder<TasksCubit, TasksState>(
              builder: (context, state) {
                if (state.status == TasksStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == TasksStatus.error) {
                  return Center(
                    child: Text((state.errorMessage ?? 'unknown_error').tr()),
                  );
                }

                if (state.tasks.isEmpty) {
                  return Center(child: Text('no_tasks_found'.tr()));
                }

                return ListView.separated(
                  itemCount: state.tasks.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.md),
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(task.description),
                            const SizedBox(height: AppSizes.sm),
                            Text('${'priority'.tr()}: ${task.priority}'),
                            const SizedBox(height: AppSizes.xs),
                            Text('${'status'.tr()}: ${task.status}'),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              '${'due_date'.tr()}: '
                              '${DateFormat('yyyy-MM-dd').format(task.dueDate)}',
                            ),
                            const SizedBox(height: AppSizes.md),
                            if (!isAdmin)
                              DropdownButtonFormField<String>(
                                initialValue: task.status,
                                decoration: InputDecoration(
                                  labelText: 'update_status'.tr(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('pending'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('in_progress'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('completed'.tr()),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null || user == null) return;

                                  context.read<TasksCubit>().updateTaskStatus(
                                    taskId: task.id,
                                    status: value,
                                    isAdmin: false,
                                    currentUserId: user.id,
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
