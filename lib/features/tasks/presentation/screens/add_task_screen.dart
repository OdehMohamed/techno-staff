import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_template_model.dart';
import '../../data/repositories/tasks_repository.dart';
import '../cubit/templates_cubit.dart';
import '../cubit/templates_state.dart';
import '../widgets/due_date_time_picker.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetCountController = TextEditingController();
  final _dayOfMonthController = TextEditingController();

  String? _selectedEmployeeId;
  String _selectedPriority = 'medium';
  String _selectedTaskType = 'standard';
  DateTime? _selectedDueDate;
  bool _hasDueTime = false;
  bool _isSaving = false;

  // Recurring task options
  bool _isRecurring = false;
  bool _createFirstInstance = false;
  String _selectedRecurrenceType = 'daily';
  final Set<int> _selectedDaysOfWeek = {};

  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().fetchEmployees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetCountController.dispose();
    _dayOfMonthController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) return;
    final needsDueDate = !_isRecurring || _createFirstInstance;
    if (needsDueDate && _selectedDueDate == null) return;

    if (_isRecurring &&
        _selectedRecurrenceType == 'weekly' &&
        _selectedDaysOfWeek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('days_of_week_required'.tr())),
      );
      return;
    }

    final taskType = _selectedTaskType;
    final int? targetCount = taskType == 'counter'
        ? int.tryParse(_targetCountController.text.trim())
        : null;
    if (taskType == 'counter' &&
        (targetCount == null || targetCount < 1 || targetCount > 999)) {
      return;
    }

    final currentUser = context.read<AuthCubit>().state.user;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      final employees = context.read<EmployeesCubit>().state.employees;
      final selectedEmployee =
          employees.firstWhere((u) => u.id == _selectedEmployeeId);

      if (_isRecurring) {
        List<int>? daysOfWeek;
        int? dayOfMonth;
        if (_selectedRecurrenceType == 'weekly') {
          daysOfWeek = _selectedDaysOfWeek.toList()..sort();
        }
        if (_selectedRecurrenceType == 'monthly') {
          dayOfMonth =
              int.tryParse(_dayOfMonthController.text.trim()) ?? 1;
        }

        final now = DateTime.now();
        final template = TaskTemplateModel(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          assignedToIds: [_selectedEmployeeId!],
          assignedToNames: [selectedEmployee.name],
          assignedBy: currentUser.id,
          assignedByName: currentUser.name,
          priority: _selectedPriority,
          taskType: taskType,
          targetCount: targetCount,
          recurrence: RecurrenceRule(
            type: _selectedRecurrenceType,
            daysOfWeek: daysOfWeek,
            dayOfMonth: dayOfMonth,
          ),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await context.read<TemplatesCubit>().createTemplate(template);

        if (!mounted) return;
        final templateState = context.read<TemplatesCubit>().state;
        if (templateState.status == TemplatesStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('failed_to_add_task'.tr())),
          );
          return;
        }

        if (_createFirstInstance && _selectedDueDate != null) {
          final dueDate = _hasDueTime
              ? _selectedDueDate!
              : TaskModel.dueDateEndOfDay(_selectedDueDate!);
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
            dueDate: dueDate,
            hasDueTime: _hasDueTime,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            completedAt: null,
            taskType: taskType,
            targetCount: targetCount,
            currentCount: 0,
          );
          final repository = TasksRepository(FirebaseFirestore.instance);
          await repository.createTask(task);
        }
      } else {
        final dueDate = _hasDueTime
            ? _selectedDueDate!
            : TaskModel.dueDateEndOfDay(_selectedDueDate!);
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
          dueDate: dueDate,
          hasDueTime: _hasDueTime,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          completedAt: null,
          taskType: taskType,
          targetCount: targetCount,
          currentCount: 0,
        );
        final repository = TasksRepository(FirebaseFirestore.instance);
        await repository.createTask(task);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed_to_add_task'.tr())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 700 ? 550.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: Text('add_task'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                final assignableUsers = state.employees.toList();
                final selectedAssignableUserId =
                    assignableUsers.any(
                      (user) => user.id == _selectedEmployeeId,
                    )
                    ? _selectedEmployeeId
                    : null;
                final isEmployeesLoading =
                    state.status == EmployeesStatus.loading &&
                    state.employees.isEmpty;
                final hasEmployeesError = state.status == EmployeesStatus.error;

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
                      if (isEmployeesLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.md),
                          child: LinearProgressIndicator(),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAssignableUserId,
                        decoration: InputDecoration(
                          labelText: 'assign_to'.tr(),
                          helperText: hasEmployeesError
                              ? 'failed_to_load_employees'.tr()
                              : (assignableUsers.isEmpty
                                    ? 'no_employees_found'.tr()
                                    : null),
                          enabled: assignableUsers.isNotEmpty,
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: assignableUsers
                            .map(
                              (assignee) => DropdownMenuItem(
                                value: assignee.id,
                                child: Text(
                                  assignee.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: assignableUsers.isEmpty
                            ? null
                            : (value) {
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
                      if (hasEmployeesError)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              context.read<EmployeesCubit>().fetchEmployees();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text('failed_to_load_employees'.tr()),
                          ),
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
                        initialValue: _selectedTaskType,
                        decoration: InputDecoration(
                          labelText: 'task_type'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'standard',
                            child: Text('task_type_standard'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'counter',
                            child: Text('task_type_counter'.tr()),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTaskType = value ?? 'standard';
                            if (_selectedTaskType != 'counter') {
                              _targetCountController.clear();
                            }
                          });
                        },
                      ),
                      if (_selectedTaskType == 'counter') ...[
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _targetCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'target_count'.tr(),
                          ),
                          validator: (value) {
                            if (_selectedTaskType != 'counter') return null;
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
                      ],
                      const SizedBox(height: AppSizes.md),
                      // ── Repeat toggle ────────────────────────────────
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('repeat_task'.tr()),
                        value: _isRecurring,
                        onChanged: (v) => setState(() {
                          _isRecurring = v;
                          if (!v) {
                            _createFirstInstance = false;
                            _selectedDaysOfWeek.clear();
                            _dayOfMonthController.clear();
                          }
                        }),
                      ),
                      if (_isRecurring) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRecurrenceType,
                          decoration: InputDecoration(
                            labelText: 'recurrence'.tr(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('recurrence_daily'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('recurrence_weekly'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('recurrence_monthly'.tr()),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedRecurrenceType = v ?? 'daily';
                            _selectedDaysOfWeek.clear();
                            _dayOfMonthController.clear();
                          }),
                        ),
                        if (_selectedRecurrenceType == 'weekly') ...[
                          const SizedBox(height: AppSizes.sm),
                          Text('days_of_week'.tr()),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final entry in {
                                1: 'weekday_mon',
                                2: 'weekday_tue',
                                3: 'weekday_wed',
                                4: 'weekday_thu',
                                5: 'weekday_fri',
                                6: 'weekday_sat',
                                7: 'weekday_sun',
                              }.entries)
                                FilterChip(
                                  label: Text(entry.value.tr()),
                                  selected:
                                      _selectedDaysOfWeek.contains(entry.key),
                                  onSelected: (on) => setState(() {
                                    if (on) {
                                      _selectedDaysOfWeek.add(entry.key);
                                    } else {
                                      _selectedDaysOfWeek.remove(entry.key);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ],
                        if (_selectedRecurrenceType == 'monthly') ...[
                          const SizedBox(height: AppSizes.md),
                          TextFormField(
                            controller: _dayOfMonthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'day_of_month'.tr(),
                              helperText: 'day_of_month_clamp_hint'.tr(),
                            ),
                            validator: (v) {
                              if (!_isRecurring ||
                                  _selectedRecurrenceType != 'monthly') {
                                return null;
                              }
                              final parsed = int.tryParse(v?.trim() ?? '');
                              if (parsed == null ||
                                  parsed < 1 ||
                                  parsed > 31) {
                                return 'day_of_month_invalid'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: AppSizes.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('create_first_instance'.tr()),
                          subtitle:
                              Text('create_first_instance_hint'.tr()),
                          value: _createFirstInstance,
                          onChanged: (v) => setState(() {
                            _createFirstInstance = v;
                            if (!v) {
                              _selectedDueDate = null;
                              _hasDueTime = false;
                            }
                          }),
                        ),
                      ],
                      if (!_isRecurring || _createFirstInstance) ...[
                        const SizedBox(height: AppSizes.md),
                        DueDateTimePicker(
                          dueDate: _selectedDueDate,
                          hasDueTime: _hasDueTime,
                          firstDate: DateTime.now(),
                          onChanged: (date, hasTime) {
                            setState(() {
                              _selectedDueDate = date;
                              _hasDueTime = hasTime;
                            });
                          },
                        ),
                      ],
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
