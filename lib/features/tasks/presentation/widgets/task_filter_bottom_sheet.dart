import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../features/auth/domain/models/app_user.dart';

enum TaskSortOption { newestFirst, dueDateSoonest, priorityHighestFirst }

class TaskFilters {
  final String searchQuery;
  final String statusFilter;
  final String priorityFilter;
  final TaskSortOption sortOption;
  final String? filterAssigneeId;
  final String? filterAssigneeName;

  const TaskFilters({
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.priorityFilter = 'all',
    this.sortOption = TaskSortOption.newestFirst,
    this.filterAssigneeId,
    this.filterAssigneeName,
  });

  TaskFilters copyWith({
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    TaskSortOption? sortOption,
    String? filterAssigneeId,
    String? filterAssigneeName,
    bool clearAssigneeFilter = false,
  }) {
    return TaskFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      sortOption: sortOption ?? this.sortOption,
      filterAssigneeId: clearAssigneeFilter ? null : (filterAssigneeId ?? this.filterAssigneeId),
      filterAssigneeName: clearAssigneeFilter ? null : (filterAssigneeName ?? this.filterAssigneeName),
    );
  }

  bool get hasActiveFilters {
    return searchQuery.trim().isNotEmpty ||
        statusFilter != 'all' ||
        priorityFilter != 'all' ||
        sortOption != TaskSortOption.newestFirst ||
        filterAssigneeId != null;
  }

  bool get hasActiveNonSearchFilters {
    return statusFilter != 'all' ||
        priorityFilter != 'all' ||
        sortOption != TaskSortOption.newestFirst ||
        filterAssigneeId != null;
  }
}

class TaskFilterBottomSheet extends StatefulWidget {
  final TaskFilters initialFilters;
  final List<AppUser> employees;
  final bool isAdmin;

  const TaskFilterBottomSheet({
    super.key,
    required this.initialFilters,
    this.employees = const [],
    this.isAdmin = false,
  });

  @override
  State<TaskFilterBottomSheet> createState() => _TaskFilterBottomSheetState();
}

class _TaskFilterBottomSheetState extends State<TaskFilterBottomSheet> {
  late String _statusFilter;
  late String _priorityFilter;
  late TaskSortOption _sortOption;
  String? _filterAssigneeId;
  String? _filterAssigneeName;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilters.statusFilter;
    _priorityFilter = widget.initialFilters.priorityFilter;
    _sortOption = widget.initialFilters.sortOption;
    _filterAssigneeId = widget.initialFilters.filterAssigneeId;
    _filterAssigneeName = widget.initialFilters.filterAssigneeName;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'filters'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.isAdmin && widget.employees.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'filter_by_assignee'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('all'.tr()),
                      selected: _filterAssigneeId == null,
                      onSelected: (_) => setState(() {
                        _filterAssigneeId = null;
                        _filterAssigneeName = null;
                      }),
                    ),
                    ...widget.employees.map((e) => ChoiceChip(
                          label: Text(e.name),
                          selected: _filterAssigneeId == e.id,
                          onSelected: (_) => setState(() {
                            _filterAssigneeId = e.id;
                            _filterAssigneeName = e.name;
                          }),
                        )),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'filter_by_status'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'all'.tr(),
                    value: 'all',
                    groupValue: _statusFilter,
                    onSelected: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: 'pending'.tr(),
                    value: 'pending',
                    groupValue: _statusFilter,
                    onSelected: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: 'in_progress'.tr(),
                    value: 'in_progress',
                    groupValue: _statusFilter,
                    onSelected: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'filter_by_priority'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'all'.tr(),
                    value: 'all',
                    groupValue: _priorityFilter,
                    onSelected: (value) {
                      setState(() {
                        _priorityFilter = value;
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: 'low'.tr(),
                    value: 'low',
                    groupValue: _priorityFilter,
                    onSelected: (value) {
                      setState(() {
                        _priorityFilter = value;
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: 'medium'.tr(),
                    value: 'medium',
                    groupValue: _priorityFilter,
                    onSelected: (value) {
                      setState(() {
                        _priorityFilter = value;
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: 'high'.tr(),
                    value: 'high',
                    groupValue: _priorityFilter,
                    onSelected: (value) {
                      setState(() {
                        _priorityFilter = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'sort_by'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSortChip(
                    label: 'sort_newest_first'.tr(),
                    value: TaskSortOption.newestFirst,
                  ),
                  _buildSortChip(
                    label: 'sort_due_date_soonest'.tr(),
                    value: TaskSortOption.dueDateSoonest,
                  ),
                  _buildSortChip(
                    label: 'sort_priority_highest_first'.tr(),
                    value: TaskSortOption.priorityHighestFirst,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          widget.initialFilters.copyWith(
                            statusFilter: _statusFilter,
                            priorityFilter: _priorityFilter,
                            sortOption: _sortOption,
                            filterAssigneeId: _filterAssigneeId,
                            filterAssigneeName: _filterAssigneeName,
                            clearAssigneeFilter: _filterAssigneeId == null,
                          ),
                        );
                      },
                      child: Text('apply'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<String> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: value == groupValue,
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _buildSortChip({
    required String label,
    required TaskSortOption value,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: _sortOption == value,
      onSelected: (_) {
        setState(() {
          _sortOption = value;
        });
      },
    );
  }
}
