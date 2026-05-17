import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/due_date_time_picker.dart';

class EditTaskScreen extends StatefulWidget {
  final TaskModel task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetCountController;
  late final TextEditingController _currentCountController;

  late String _selectedPriority;
  late String _selectedStatus;
  String? _selectedEmployeeId;
  DateTime? _selectedDueDate;
  bool _hasDueTime = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().fetchEmployees();

    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _selectedPriority = widget.task.priority;
    _selectedStatus = widget.task.status;
    _selectedEmployeeId = widget.task.assignedTo;
    _selectedDueDate = widget.task.dueDate;
    _hasDueTime = widget.task.hasDueTime;
    _targetCountController = TextEditingController(
      text: (widget.task.targetCount ?? 1).toString(),
    );
    _currentCountController = TextEditingController(
      text: widget.task.currentCount.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetCountController.dispose();
    _currentCountController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null || _selectedDueDate == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = TasksRepository(FirebaseFirestore.instance);
      final employees = context.read<EmployeesCubit>().state.employees;
      final selectedEmployee = employees.firstWhere(
        (user) => user.id == _selectedEmployeeId,
      );
      final currentUser = context.read<AuthCubit>().state.user;
      if (currentUser == null) return;

      String resolvedStatus;
      DateTime? resolvedCompletedAt;
      int? resolvedTargetCount;
      int resolvedCurrentCount;

      if (widget.task.isCounter) {
        final newTarget = int.parse(_targetCountController.text.trim());
        final currentInput = int.parse(_currentCountController.text.trim());
        final newCurrent = currentInput.clamp(0, newTarget);
        resolvedTargetCount = newTarget;
        resolvedCurrentCount = newCurrent;
        resolvedStatus = TaskModel.deriveCounterStatus(newCurrent, newTarget);
        resolvedCompletedAt = resolvedStatus == 'completed'
            ? (widget.task.completedAt ?? DateTime.now())
            : null;
      } else {
        resolvedStatus = _selectedStatus;
        resolvedCompletedAt = _selectedStatus == 'completed'
            ? (widget.task.completedAt ?? DateTime.now())
            : null;
        resolvedTargetCount = null;
        resolvedCurrentCount = 0;
      }

      final dueDate = _hasDueTime
          ? _selectedDueDate!
          : TaskModel.dueDateEndOfDay(_selectedDueDate!);

      final updatedTask = TaskModel(
        id: widget.task.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _selectedEmployeeId!,
        assignedToName: selectedEmployee.name,
        assignedBy: widget.task.assignedBy,
        assignedByName: widget.task.assignedByName,
        priority: _selectedPriority,
        status: resolvedStatus,
        dueDate: dueDate,
        hasDueTime: _hasDueTime,
        createdAt: widget.task.createdAt,
        updatedAt: DateTime.now(),
        updatedBy: currentUser.id,
        updatedByName: currentUser.name,
        completedAt: resolvedCompletedAt,
        taskType: widget.task.taskType,
        targetCount: widget.task.isCounter ? resolvedTargetCount : null,
        currentCount: widget.task.isCounter ? resolvedCurrentCount : 0,
      );

      await repository.updateTask(updatedTask);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed_to_update_task'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 700 ? 550.0 : double.infinity;
    final currentUser = context.read<AuthCubit>().state.user;
    final canEditTask =
        currentUser != null &&
        (currentUser.role == 'admin' ||
            widget.task.assignedBy == currentUser.id);
    if (!canEditTask) {
      return Scaffold(
        appBar: AppBar(title: Text('edit_task'.tr())),
        body: const Center(
          child: Text('You are not allowed to edit this task'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('edit_task'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                final employees = state.employees.toList();
                final selectedEmployeeIdValid =
                    employees.any((user) => user.id == _selectedEmployeeId)
                    ? _selectedEmployeeId
                    : null;

                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'task_title'.tr(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'task_title_required'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'description'.tr(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'description_required'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployeeIdValid,
                        decoration: InputDecoration(
                          labelText: 'assign_to'.tr(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: employees
                            .map(
                              (employee) => DropdownMenuItem(
                                value: employee.id,
                                child: Text(
                                  employee.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEmployeeId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'employee_required'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPriority,
                        decoration: InputDecoration(
                          labelText: 'priority'.tr(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('low'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('medium'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('high'.tr()),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPriority = value ?? 'medium';
                          });
                        },
                      ),
                      if (widget.task.isCounter) ...[
                        const SizedBox(height: AppSizes.md),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${'task_type'.tr()}: ${'task_type_counter'.tr()}',
                          ),
                        ),
                        TextFormField(
                          controller: _targetCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'target_count'.tr(),
                          ),
                          validator: (value) {
                            final raw = value?.trim() ?? '';
                            if (raw.isEmpty) {
                              return 'target_count_required'.tr();
                            }
                            final parsed = int.tryParse(raw);
                            if (parsed == null || parsed < 1 || parsed > 999) {
                              return 'target_count_invalid_range'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _currentCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'current_count'.tr(),
                          ),
                          validator: (value) {
                            final raw = value?.trim() ?? '';
                            final target = int.tryParse(
                              _targetCountController.text.trim(),
                            );
                            final current = int.tryParse(raw);
                            if (target == null || target < 1 || target > 999) {
                              return 'target_count_invalid_range'.tr();
                            }
                            if (current == null ||
                                current < 0 ||
                                current > target) {
                              return 'current_count_invalid_range'.tr();
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: AppSizes.md),
                      if (!widget.task.isCounter) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'status'.tr(),
                            isDense: true,
                          ),
                          isExpanded: true,
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
                            setState(() {
                              _selectedStatus = value ?? 'pending';
                            });
                          },
                        ),
                        const SizedBox(height: AppSizes.md),
                      ],
                      DueDateTimePicker(
                        dueDate: _selectedDueDate,
                        hasDueTime: _hasDueTime,
                        onChanged: (date, hasTime) {
                          setState(() {
                            _selectedDueDate = date;
                            _hasDueTime = hasTime;
                          });
                        },
                      ),
                      const SizedBox(height: AppSizes.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          child: _isSaving
                              ? const CircularProgressIndicator()
                              : Text('save_changes'.tr()),
                        ),
                      ),
                    ],
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
