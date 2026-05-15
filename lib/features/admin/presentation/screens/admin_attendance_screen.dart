import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/presentation/cubit/attendance_cubit.dart';
import '../../../attendance/presentation/cubit/attendance_state.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayJerusalemYmd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceCubit>().loadRoster(_selectedDate);
    });
  }

  String _todayJerusalemYmd() {
    final nowJerusalem = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateFormat('yyyy-MM-dd').format(nowJerusalem);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final firstDate = today.subtract(const Duration(days: 90));
    final parsed = DateTime.tryParse(_selectedDate) ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: firstDate,
      lastDate: today,
    );

    if (picked != null && mounted) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() => _selectedDate = formatted);
      context.read<AttendanceCubit>().loadRoster(formatted);
    }
  }

  void _openCorrectionSheet(AttendanceModel record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<AttendanceCubit>(),
        child: _CorrectionSheet(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final parsedDate = DateTime.tryParse(_selectedDate);
    final dateLabel = parsedDate != null
        ? DateFormat.yMMMd(locale).format(parsedDate)
        : _selectedDate;

    return Scaffold(
      appBar: AppBar(title: Text('attendance_management'.tr())),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'attendance_management'.tr()),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dateLabel),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(
              child: BlocBuilder<AttendanceCubit, AttendanceState>(
                builder: (context, state) {
                  if (state.rosterStatus == AttendanceLoadStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.rosterStatus == AttendanceLoadStatus.error) {
                    return Center(
                      child: Text(
                        (state.rosterError ?? 'network_error').tr(),
                      ),
                    );
                  }

                  if (state.roster.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.people_outline,
                      titleKey: 'no_attendance_records',
                    );
                  }

                  return ListView.separated(
                    itemCount: state.roster.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, index) {
                      final record = state.roster[index];
                      return _RosterRow(
                        record: record,
                        onTap: () => _openCorrectionSheet(record),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  final AttendanceModel record;
  final VoidCallback onTap;

  const _RosterRow({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          record.userName.isNotEmpty ? record.userName : record.userId,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Row(
          children: [
            Text(_formatTime(record.checkInAt)),
            const Text(' → '),
            Text(_formatTime(record.checkOutAt)),
          ],
        ),
        trailing: _AttendanceStatusChip(status: record.status),
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  final String status;

  const _AttendanceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusKey = switch (status) {
      'present' => 'attendance_status_present',
      'absent' => 'attendance_status_absent',
      'manual' => 'attendance_status_manual',
      _ => 'attendance_status_present',
    };

    final colors = switch (status) {
      'absent' => (
          background: Theme.of(context).colorScheme.errorContainer,
          foreground: Theme.of(context).colorScheme.onErrorContainer,
        ),
      'manual' => (
          background: Theme.of(context).colorScheme.tertiaryContainer,
          foreground: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      _ => (
          background: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusKey.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.foreground,
        ),
      ),
    );
  }
}

class _CorrectionSheet extends StatefulWidget {
  final AttendanceModel record;

  const _CorrectionSheet({required this.record});

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late String _selectedStatus;
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  final _notesController = TextEditingController();
  bool _listenerRegistered = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.record.status;
    if (widget.record.checkInAt != null) {
      final local = widget.record.checkInAt!.toLocal();
      _checkInTime = TimeOfDay(hour: local.hour, minute: local.minute);
    }
    if (widget.record.checkOutAt != null) {
      final local = widget.record.checkOutAt!.toLocal();
      _checkOutTime = TimeOfDay(hour: local.hour, minute: local.minute);
    }
    if (widget.record.notes != null) {
      _notesController.text = widget.record.notes!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerRegistered) {
      _listenerRegistered = true;
      context.read<AttendanceCubit>().stream.listen((state) {
        if (!mounted) return;
        if (state.correctionStatus == AttendanceActionStatus.success) {
          context.read<AttendanceCubit>().clearCorrectionFeedback();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('attendance_corrected'.tr())),
          );
        } else if (state.correctionStatus == AttendanceActionStatus.error &&
            state.correctionError != null) {
          context.read<AttendanceCubit>().clearCorrectionFeedback();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text((state.correctionError!).tr())),
          );
        }
      });
    }
  }

  Future<void> _pickCheckIn() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _checkInTime = picked);
  }

  Future<void> _pickCheckOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _checkOutTime = picked);
  }

  String _timeToIso(TimeOfDay time, String dateYmd) {
    final parts = dateYmd.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final dt = DateTime(year, month, day, time.hour, time.minute);
    return dt.toUtc().toIso8601String();
  }

  void _save() {
    final fields = <String, dynamic>{};
    final original = widget.record;

    if (_selectedStatus != original.status) {
      fields['status'] = _selectedStatus;
    }

    if (_checkInTime != null) {
      final iso = _timeToIso(_checkInTime!, original.date);
      final originalIso = original.checkInAt?.toUtc().toIso8601String();
      if (iso != originalIso) fields['checkInAt'] = iso;
    }

    if (_checkOutTime != null) {
      final iso = _timeToIso(_checkOutTime!, original.date);
      final originalIso = original.checkOutAt?.toUtc().toIso8601String();
      if (iso != originalIso) fields['checkOutAt'] = iso;
    }

    final notes =
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    context.read<AttendanceCubit>().adminCorrect(
      userId: original.userId,
      date: original.date,
      fields: fields,
      notes: notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        final isSubmitting =
            state.correctionStatus == AttendanceActionStatus.submitting;

        return Padding(
          padding: EdgeInsets.only(
            left: AppSizes.md,
            right: AppSizes.md,
            top: AppSizes.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'correct_attendance'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSizes.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('check_in_time'.tr()),
                trailing: Text(
                  _checkInTime != null
                      ? _checkInTime!.format(context)
                      : '-',
                ),
                onTap: _pickCheckIn,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('check_out_time'.tr()),
                trailing: Text(
                  _checkOutTime != null
                      ? _checkOutTime!.format(context)
                      : '-',
                ),
                onTap: _pickCheckOut,
              ),
              const SizedBox(height: AppSizes.sm),
              InputDecorator(
                decoration: InputDecoration(labelText: 'status'.tr()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'present', child: Text('present')),
                      DropdownMenuItem(value: 'absent', child: Text('absent')),
                      DropdownMenuItem(value: 'manual', child: Text('manual')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedStatus = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'notes'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: AppSizes.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _save,
                  child: isSubmitting
                      ? const CircularProgressIndicator()
                      : Text('save'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
