import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/attendance/data/models/schedule_day.dart';
import 'package:techno_staff/features/attendance/data/models/work_schedule_model.dart';
import 'package:techno_staff/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:techno_staff/features/attendance/presentation/cubit/attendance_state.dart';
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

  void _openScheduleSheet(
    BuildContext context,
    String userId,
    String userName,
  ) {
    context.read<AttendanceCubit>().loadEmployeeSchedule(userId, userName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<AttendanceCubit>(),
        child: _ScheduleEditSheet(userId: userId, userName: userName),
      ),
    );
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
                    onRefresh: () => context
                        .read<EmployeesCubit>()
                        .fetchEmployees(silent: true),
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
                    onRefresh: () => context
                        .read<EmployeesCubit>()
                        .fetchEmployees(silent: true),
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
                                        const SizedBox(height: AppSizes.xs),
                                        IconButton(
                                          icon: const Icon(Icons.schedule),
                                          tooltip: 'schedule'.tr(),
                                          onPressed: () => _openScheduleSheet(
                                            context,
                                            employee.id,
                                            employee.name,
                                          ),
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

// ── Schedule edit sheet ───────────────────────────────────────────────────────

class _ScheduleEditSheet extends StatefulWidget {
  final String userId;
  final String userName;

  const _ScheduleEditSheet({required this.userId, required this.userName});

  @override
  State<_ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<_ScheduleEditSheet> {
  WorkScheduleModel? _draft;
  bool _initialized = false;

  // Mon=1 … Sun=7 (matches Dart DateTime.weekday + existing Cloud Function)
  static const _dayKeys = [1, 2, 3, 4, 5, 6, 7];
  static const _dayNameKeys = {
    1: 'monday',
    2: 'tuesday',
    3: 'wednesday',
    4: 'thursday',
    5: 'friday',
    6: 'saturday',
    7: 'sunday',
  };

  static const _graceOptions = [5, 10, 15, 20, 30];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String? hhmm) {
    if (hhmm == null) return const TimeOfDay(hour: 8, minute: 0);
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  void _initDraft(WorkScheduleModel schedule) {
    if (!_initialized) {
      _draft = schedule;
      _initialized = true;
    }
  }

  void _toggleDay(int dayKey, bool isWorking) {
    if (_draft == null) return;
    final days = Map<String, ScheduleDay>.from(
      _draft!.days.map((k, v) => MapEntry(k, v)),
    );
    final current = days[dayKey.toString()] ?? const ScheduleDay(isWorkingDay: false);
    days[dayKey.toString()] = current.copyWith(isWorkingDay: isWorking);
    setState(() => _draft = _draft!.copyWith(days: days));
  }

  Future<void> _pickTime(int dayKey, bool isStart) async {
    if (_draft == null) return;
    final current = _draft!.days[dayKey.toString()];
    final initial = isStart
        ? _parseTime(current?.expectedStartTime)
        : _parseTime(current?.expectedEndTime ?? '17:00');

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    final days = Map<String, ScheduleDay>.from(
      _draft!.days.map((k, v) => MapEntry(k, v)),
    );
    final day = days[dayKey.toString()] ?? const ScheduleDay(isWorkingDay: true);
    days[dayKey.toString()] = isStart
        ? day.copyWith(expectedStartTime: _formatTime(picked))
        : day.copyWith(expectedEndTime: _formatTime(picked));
    setState(() => _draft = _draft!.copyWith(days: days));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceCubit, AttendanceState>(
      listenWhen: (prev, curr) =>
          prev.editingScheduleStatus != curr.editingScheduleStatus ||
          prev.scheduleSaveStatus != curr.scheduleSaveStatus,
      listener: (context, state) {
        if (state.editingScheduleStatus == AttendanceLoadStatus.loaded &&
            state.editingSchedule != null) {
          _initDraft(state.editingSchedule!);
        }
        if (state.scheduleSaveStatus == AttendanceActionStatus.success) {
          context.read<AttendanceCubit>().clearScheduleSaveFeedback();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('schedule_saved'.tr())),
          );
        }
        if (state.scheduleSaveStatus == AttendanceActionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.scheduleSaveError?.tr() ?? 'network_error'.tr()),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.editingScheduleStatus == AttendanceLoadStatus.loading) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.editingScheduleStatus == AttendanceLoadStatus.error) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('network_error'.tr())),
          );
        }

        if (state.editingSchedule != null && !_initialized) {
          _initDraft(state.editingSchedule!);
        }

        final draft = _draft;
        if (draft == null) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final isSaving =
            state.scheduleSaveStatus == AttendanceActionStatus.submitting;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.md,
                    AppSizes.md,
                    AppSizes.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${'schedule'.tr()} — ${widget.userName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    children: [
                      // Grace period selector
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'default_grace_minutes'.tr(),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            DropdownButton<int>(
                              value: _graceOptions.contains(draft.defaultGraceMinutes)
                                  ? draft.defaultGraceMinutes
                                  : 15,
                              items: _graceOptions
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text('$g min'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _draft = draft.copyWith(
                                    defaultGraceMinutes: v,
                                  ));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Per-day rows
                      ..._dayKeys.map((dayKey) {
                        final daySchedule = draft.days[dayKey.toString()] ??
                            const ScheduleDay(isWorkingDay: true);
                        return _DayRow(
                          dayNameKey: _dayNameKeys[dayKey]!,
                          daySchedule: daySchedule,
                          onToggle: (v) => _toggleDay(dayKey, v),
                          onPickStart: () => _pickTime(dayKey, true),
                          onPickEnd: () => _pickTime(dayKey, false),
                        );
                      }),
                      const SizedBox(height: AppSizes.md),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving
                            ? null
                            : () {
                                final auth = context.read<AuthCubit>().state;
                                context.read<AttendanceCubit>().saveSchedule(
                                  draft,
                                  updatedBy: auth.user?.id ?? '',
                                  updatedByName: auth.user?.name ?? '',
                                );
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('save'.tr()),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final String dayNameKey;
  final ScheduleDay daySchedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DayRow({
    required this.dayNameKey,
    required this.daySchedule,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dayNameKey.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Switch(
              value: daySchedule.isWorkingDay,
              onChanged: onToggle,
            ),
          ],
        ),
        if (daySchedule.isWorkingDay) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(daySchedule.expectedStartTime ?? '--:--'),
                  onPressed: onPickStart,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_filled, size: 16),
                  label: Text(daySchedule.expectedEndTime ?? '--:--'),
                  onPressed: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
        ],
        const Divider(),
      ],
    );
  }
}
