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

  late String _selectedPriority;
  late String _selectedStatus;
  String? _selectedEmployeeId;
  DateTime? _selectedDueDate;
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
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
      final updatedTask = TaskModel(
        id: widget.task.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _selectedEmployeeId!,
        assignedToName: selectedEmployee.name,
        assignedBy: widget.task.assignedBy,
        assignedByName: widget.task.assignedByName,
        priority: _selectedPriority,
        status: _selectedStatus,
        dueDate: _selectedDueDate!,
        createdAt: widget.task.createdAt,
        updatedAt: DateTime.now(),
        updatedBy: currentUser.id,
        updatedByName: currentUser.name,
        completedAt: _selectedStatus == 'completed'
            ? (widget.task.completedAt ?? DateTime.now())
            : null,
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
                final employees = state.employees
                    .where((user) => user.role == 'employee')
                    .toList();

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
                        initialValue: _selectedEmployeeId,
                        decoration: InputDecoration(
                          labelText: 'assign_to'.tr(),
                        ),
                        items: employees
                            .map(
                              (employee) => DropdownMenuItem(
                                value: employee.id,
                                child: Text(employee.name),
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
                        decoration: InputDecoration(labelText: 'priority'.tr()),
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
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(labelText: 'status'.tr()),
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _selectedDueDate == null
                              ? 'select_due_date'.tr()
                              : '${'due_date'.tr()}: ${DateFormat('yyyy-MM-dd').format(_selectedDueDate!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDueDate,
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
