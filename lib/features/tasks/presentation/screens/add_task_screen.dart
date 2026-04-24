import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedEmployeeId;
  String _selectedPriority = 'medium';
  DateTime? _selectedDueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().fetchEmployees();
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
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null || _selectedDueDate == null) return;

    final currentUser = context.read<AuthCubit>().state.user;
    if (currentUser == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = TasksRepository(FirebaseFirestore.instance);
      final employees = context.read<EmployeesCubit>().state.employees;
      final selectedEmployee = employees.firstWhere(
        (user) => user.id == _selectedEmployeeId,
      );
      final task = TaskModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _selectedEmployeeId!,
        assignedToName: selectedEmployee.name,
        assignedBy: currentUser.id,
        assignedByName: currentUser.name,
        priority: _selectedPriority,
        status: 'pending',
        dueDate: _selectedDueDate!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
      );
      debugPrint('CREATING TASK FOR EMPLOYEE ID: $_selectedEmployeeId');
      debugPrint('ASSIGNED BY USER ID: ${currentUser.id}');
      debugPrint('TASK TITLE: ${_titleController.text.trim()}');
      await repository.createTask(task);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed_to_add_task'.tr())));
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

    return Scaffold(
      appBar: AppBar(title: Text('add_task'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                final assignableUsers = state.employees
                    .where((user) => user.id != currentUser?.id)
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
                        items: assignableUsers
                            .map(
                              (assignee) => DropdownMenuItem(
                                value: assignee.id,
                                child: Text(assignee.name),
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
                          onPressed: _isSaving ? null : _saveTask,
                          child: _isSaving
                              ? const CircularProgressIndicator()
                              : Text('save'.tr()),
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
