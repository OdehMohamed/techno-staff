import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../data/models/task_template_model.dart';
import '../cubit/templates_cubit.dart';
import '../cubit/templates_state.dart';

class AddTemplateScreen extends StatefulWidget {
  const AddTemplateScreen({super.key});

  @override
  State<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends State<AddTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetCountController = TextEditingController();
  final _dayOfMonthController = TextEditingController();

  final Set<String> _selectedEmployeeIds = {};
  final Map<String, String> _employeeIdToName = {};
  String _selectedPriority = 'medium';
  String _selectedTaskType = 'standard';
  String _selectedRecurrenceType = 'daily';
  final Set<int> _selectedDaysOfWeek = {};
  bool _isActive = true;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('employee_required'.tr())),
      );
      return;
    }
    if (_selectedRecurrenceType == 'weekly' && _selectedDaysOfWeek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('days_of_week_required'.tr())),
      );
      return;
    }

    final currentUser = context.read<AuthCubit>().state.user;
    if (currentUser == null) return;

    final int? targetCount = _selectedTaskType == 'counter'
        ? int.tryParse(_targetCountController.text.trim())
        : null;

    List<int>? daysOfWeek;
    int? dayOfMonth;
    if (_selectedRecurrenceType == 'weekly') {
      daysOfWeek = _selectedDaysOfWeek.toList()..sort();
    }
    if (_selectedRecurrenceType == 'monthly') {
      dayOfMonth = int.tryParse(_dayOfMonthController.text.trim()) ?? 1;
    }

    final recurrence = RecurrenceRule(
      type: _selectedRecurrenceType,
      daysOfWeek: daysOfWeek,
      dayOfMonth: dayOfMonth,
    );

    final now = DateTime.now();
    final template = TaskTemplateModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assignedToIds: _selectedEmployeeIds.toList(),
      assignedToNames:
          _selectedEmployeeIds.map((id) => _employeeIdToName[id] ?? '').toList(),
      assignedBy: currentUser.id,
      assignedByName: currentUser.name,
      priority: _selectedPriority,
      taskType: _selectedTaskType,
      targetCount: targetCount,
      recurrence: recurrence,
      isActive: _isActive,
      createdAt: now,
      updatedAt: now,
    );

    await context.read<TemplatesCubit>().createTemplate(template);

    if (!mounted) return;
    final state = context.read<TemplatesCubit>().state;
    if (state.status == TemplatesStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? 'error'.tr())),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('add_template'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: BlocBuilder<EmployeesCubit, EmployeesState>(
          builder: (context, empState) {
            final employees = empState.employees;
            final isLoading =
                empState.status == EmployeesStatus.loading && employees.isEmpty;

            // Keep name map current so _save() can resolve assignedToNames.
            for (final e in employees) {
              _employeeIdToName[e.id] = e.name;
            }

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: 'task_title'.tr()),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'task_title_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'description'.tr()),
                    maxLines: 3,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'description_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'assign_to'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (isLoading) const LinearProgressIndicator(),
                  _EmployeeMultiPicker(
                    employeeNames: {for (final e in employees) e.id: e.name},
                    selectedIds: _selectedEmployeeIds,
                    onChanged: (ids) => setState(() {
                      _selectedEmployeeIds
                        ..clear()
                        ..addAll(ids);
                    }),
                  ),
                  const SizedBox(height: AppSizes.md),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPriority,
                    decoration: InputDecoration(labelText: 'priority'.tr()),
                    items: [
                      DropdownMenuItem(value: 'low', child: Text('low'.tr())),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('medium'.tr()),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('high'.tr())),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedPriority = v ?? 'medium'),
                  ),
                  const SizedBox(height: AppSizes.md),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTaskType,
                    decoration: InputDecoration(labelText: 'task_type'.tr()),
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
                    onChanged: (v) => setState(() {
                      _selectedTaskType = v ?? 'standard';
                      if (_selectedTaskType != 'counter') {
                        _targetCountController.clear();
                      }
                    }),
                  ),
                  if (_selectedTaskType == 'counter') ...[
                    const SizedBox(height: AppSizes.md),
                    TextFormField(
                      controller: _targetCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'target_count'.tr(),
                      ),
                      validator: (v) {
                        if (_selectedTaskType != 'counter') return null;
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return 'target_count_required'.tr();
                        final parsed = int.tryParse(raw);
                        if (parsed == null || parsed < 1 || parsed > 999) {
                          return 'target_count_invalid_range'.tr();
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSizes.md),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRecurrenceType,
                    decoration: InputDecoration(labelText: 'recurrence'.tr()),
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
                    const SizedBox(height: AppSizes.md),
                    Text('days_of_week'.tr()),
                    const SizedBox(height: 8),
                    _WeekdayPicker(
                      selected: _selectedDaysOfWeek,
                      onChanged: (days) => setState(() {
                        _selectedDaysOfWeek
                          ..clear()
                          ..addAll(days);
                      }),
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
                        if (_selectedRecurrenceType != 'monthly') {
                          return null;
                        }
                        final parsed = int.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 1 || parsed > 31) {
                          return 'day_of_month_invalid'.tr();
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSizes.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('template_active'.tr()),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  BlocBuilder<TemplatesCubit, TemplatesState>(
                    builder: (context, state) {
                      final saving = state.status == TemplatesStatus.loading;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving ? null : _save,
                          child: saving
                              ? const CircularProgressIndicator()
                              : Text('save'.tr()),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmployeeMultiPicker extends StatelessWidget {
  final Map<String, String> employeeNames; // id → display name
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const _EmployeeMultiPicker({
    required this.employeeNames,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (employeeNames.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: employeeNames.entries.map((entry) {
        final isSelected = selectedIds.contains(entry.key);
        return FilterChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (val) {
            final updated = Set<String>.from(selectedIds);
            if (val) {
              updated.add(entry.key);
            } else {
              updated.remove(entry.key);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const days = [
      (1, 'weekday_mon'),
      (2, 'weekday_tue'),
      (3, 'weekday_wed'),
      (4, 'weekday_thu'),
      (5, 'weekday_fri'),
      (6, 'weekday_sat'),
      (7, 'weekday_sun'),
    ];
    return Wrap(
      spacing: 8,
      children: days.map((entry) {
        final dayNum = entry.$1;
        final key = entry.$2;
        final isSelected = selected.contains(dayNum);
        return FilterChip(
          label: Text(key.tr()),
          selected: isSelected,
          onSelected: (val) {
            final updated = Set<int>.from(selected);
            if (val) {
              updated.add(dayNum);
            } else {
              updated.remove(dayNum);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
