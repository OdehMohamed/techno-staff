import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../cubit/task_details_cubit.dart';
import '../cubit/task_details_state.dart';
import '../../data/models/task_model.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskDetailsCubit>().loadTaskUserNames(
        assignedTo: widget.task.assignedTo,
        assignedBy: widget.task.assignedBy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final currentUser = context.read<AuthCubit>().state.user;
    final canEditTask =
        currentUser != null &&
        (currentUser.role == 'admin' || task.assignedBy == currentUser.id);
    return Scaffold(
      appBar: AppBar(
        title: Text('task_details'.tr()),

        actions: [
          if (canEditTask)
            IconButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  RouteNames.editTask,
                  arguments: task,
                );

                if (context.mounted && result == true) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
              builder: (context, state) {
                return SizedBox(
                  width: double.infinity,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          task.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSizes.lg),
                        Wrap(
                          spacing: AppSizes.sm,
                          runSpacing: AppSizes.sm,
                          children: [
                            StatusBadge(status: task.status),
                            PriorityBadge(priority: task.priority),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xl),
                        _DetailsRow(
                          label: 'assigned_to'.tr(),
                          value: state.assignedToName,
                        ),
                        const SizedBox(height: AppSizes.sm),
                        _DetailsRow(
                          label: 'assigned_by'.tr(),
                          value: state.assignedByName,
                        ),
                        const SizedBox(height: AppSizes.sm),
                        _DetailsRow(
                          label: 'due_date'.tr(),
                          value: DateFormat('yyyy-MM-dd').format(task.dueDate),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Text('$label:', style: Theme.of(context).textTheme.titleMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
