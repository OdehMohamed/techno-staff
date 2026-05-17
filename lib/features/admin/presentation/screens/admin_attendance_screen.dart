import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/attendance_status_chip.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/presentation/cubit/attendance_cubit.dart';
import '../../../attendance/presentation/cubit/attendance_state.dart';

String _formatDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _fmtTime(DateTime? dt) {
  if (dt == null) return '--:--';
  return DateFormat('HH:mm').format(dt.toLocal());
}

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
    return Scaffold(
      appBar: AppBar(title: Text('attendance_management'.tr())),
      drawer: const AppDrawer(),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          if (state.correctionStatus == AttendanceActionStatus.success) {
            context.read<AttendanceCubit>().clearCorrectionFeedback();
            Navigator.of(context).pop();
            context.read<AttendanceCubit>().loadRoster(_selectedDate);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('attendance_corrected'.tr())),
            );
          } else if (state.correctionStatus == AttendanceActionStatus.error &&
              state.correctionError != null) {
            context.read<AttendanceCubit>().clearCorrectionFeedback();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.correctionError!.tr())),
            );
          }
        },
        builder: (context, state) {
          final locale = context.locale.languageCode;
          final parsedDate = DateTime.tryParse(_selectedDate);
          final dateLabel = parsedDate != null
              ? DateFormat.yMMMd(locale).format(parsedDate)
              : _selectedDate;

          return Padding(
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
                Expanded(child: _buildRosterContent(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRosterContent(BuildContext context, AttendanceState state) {
    if (state.rosterStatus == AttendanceLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.rosterStatus == AttendanceLoadStatus.error) {
      return Center(
        child: Text((state.rosterError ?? 'network_error').tr()),
      );
    }

    if (state.roster.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.people_outline,
        titleKey: 'no_attendance_records_yet',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<AttendanceCubit>().loadRoster(_selectedDate),
      child: ListView.separated(
        itemCount: state.roster.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (context, index) {
          final record = state.roster[index];
          return _RosterRow(
            record: record,
            onCorrect: () => _openCorrectionSheet(record),
          );
        },
      ),
    );
  }
}

// ─── Roster row (expandable) ─────────────────────────────────────────────────

class _RosterRow extends StatefulWidget {
  final AttendanceModel record;
  final VoidCallback onCorrect;

  const _RosterRow({required this.record, required this.onCorrect});

  @override
  State<_RosterRow> createState() => _RosterRowState();
}

class _RosterRowState extends State<_RosterRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSizes.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.userName.isNotEmpty
                            ? record.userName
                            : record.userId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    AttendanceStatusChip(status: record.status),
                    if (record.isCorrected) ...[
                      const SizedBox(width: AppSizes.xs),
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                    if (record.notes?.isNotEmpty == true) ...[
                      const SizedBox(width: AppSizes.xs),
                      Icon(
                        Icons.note_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                    const SizedBox(width: AppSizes.xs),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${_fmtTime(record.checkInAt)} → ${_fmtTime(record.checkOutAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(record.totalDurationMinutes),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (record.sessions.length > 1) ...[
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        '· ${'sessions_count'.tr(namedArgs: {'count': '${record.sessions.length}'})}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? _RosterExpandedSection(
                    record: record,
                    onCorrect: widget.onCorrect,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RosterExpandedSection extends StatelessWidget {
  final AttendanceModel record;
  final VoidCallback onCorrect;

  const _RosterExpandedSection({
    required this.record,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final dimStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSizes.md),
        if (record.sessions.isEmpty)
          Text('no_attendance_records'.tr(), style: dimStyle)
        else
          ...List.generate(record.sessions.length, (i) {
            final s = record.sessions[i];
            final checkIn = DateFormat('HH:mm').format(s.checkInAt.toLocal());
            final checkOut = s.checkOutAt != null
                ? DateFormat('HH:mm').format(s.checkOutAt!.toLocal())
                : '--:--';
            final duration =
                s.durationMinutes != null ? _formatDuration(s.durationMinutes!) : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.xs),
              child: Row(
                children: [
                  Text(
                    'session_number'.tr(namedArgs: {'n': '${i + 1}'}),
                    style: dimStyle,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '$checkIn → $checkOut',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (duration.isNotEmpty) ...[
                    const Spacer(),
                    Text(duration, style: dimStyle),
                  ],
                ],
              ),
            );
          }),
        if (record.notes?.isNotEmpty == true) ...[
          const SizedBox(height: AppSizes.xs),
          Text('notes'.tr(), style: dimStyle),
          const SizedBox(height: 2),
          Text(record.notes!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (record.isCorrected) ...[
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'corrected_by'.tr(namedArgs: {
                  'name': record.correctedByName?.isNotEmpty == true
                      ? record.correctedByName!
                      : 'admin'.tr(),
                }),
                style: dimStyle,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSizes.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: onCorrect,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text('correct_attendance'.tr()),
          ),
        ),
      ],
    );
  }
}

// ─── Correction sheet (session-level editing) ────────────────────────────────

class _SessionDraft {
  TimeOfDay? checkInTime;
  TimeOfDay? checkOutTime;

  _SessionDraft({this.checkInTime, this.checkOutTime});
}

class _CorrectionSheet extends StatefulWidget {
  final AttendanceModel record;

  const _CorrectionSheet({required this.record});

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  final List<_SessionDraft> _sessions = [];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sorted = [...widget.record.sessions]
      ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));

    for (final s in sorted) {
      final local = s.checkInAt.toLocal();
      final localOut = s.checkOutAt?.toLocal();
      _sessions.add(
        _SessionDraft(
          checkInTime: TimeOfDay(hour: local.hour, minute: local.minute),
          checkOutTime: localOut != null
              ? TimeOfDay(hour: localOut.hour, minute: localOut.minute)
              : null,
        ),
      );
    }

    if (_sessions.isEmpty) {
      _sessions.add(_SessionDraft());
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

  Future<void> _pickCheckIn(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sessions[index].checkInTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _sessions[index].checkInTime = picked);
  }

  Future<void> _pickCheckOut(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sessions[index].checkOutTime ??
          _sessions[index].checkInTime ??
          TimeOfDay.now(),
    );
    if (picked != null) setState(() => _sessions[index].checkOutTime = picked);
  }

  String _timeToIso(TimeOfDay time, String dateYmd) {
    final parts = dateYmd.split('-');
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      time.hour,
      time.minute,
    );
    return dt.toUtc().toIso8601String();
  }

  void _save() {
    final drafts = [..._sessions]..sort((a, b) {
        final aMin =
            (a.checkInTime?.hour ?? 0) * 60 + (a.checkInTime?.minute ?? 0);
        final bMin =
            (b.checkInTime?.hour ?? 0) * 60 + (b.checkInTime?.minute ?? 0);
        return aMin.compareTo(bMin);
      });

    final sessions = drafts
        .where((d) => d.checkInTime != null)
        .map<Map<String, dynamic>>((d) => {
              'checkInAt': _timeToIso(d.checkInTime!, widget.record.date),
              if (d.checkOutTime != null)
                'checkOutAt': _timeToIso(d.checkOutTime!, widget.record.date),
            })
        .toList();

    if (sessions.isEmpty) return;

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    context.read<AttendanceCubit>().adminCorrect(
      userId: widget.record.userId,
      date: widget.record.date,
      sessions: sessions,
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
              const SizedBox(height: 2),
              Text(
                widget.record.userName.isNotEmpty
                    ? widget.record.userName
                    : widget.record.userId,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppSizes.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...List.generate(_sessions.length, (i) {
                        final draft = _sessions[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.xs),
                          child: Row(
                            children: [
                              Text(
                                'session_number'
                                    .tr(namedArgs: {'n': '${i + 1}'}),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(width: AppSizes.xs),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.sm,
                                          vertical: AppSizes.xs,
                                        ),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () => _pickCheckIn(i),
                                      child: Text(
                                        draft.checkInTime?.format(context) ??
                                            '--:--',
                                      ),
                                    ),
                                    const Text('→'),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.sm,
                                          vertical: AppSizes.xs,
                                        ),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: draft.checkInTime != null
                                          ? () => _pickCheckOut(i)
                                          : null,
                                      child: Text(
                                        draft.checkOutTime?.format(context) ??
                                            '--:--',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (_sessions.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _sessions.removeAt(i)),
                                ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _sessions.add(_SessionDraft())),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('add_session'.tr()),
                      ),
                      const Divider(),
                      TextFormField(
                        controller: _notesController,
                        decoration:
                            InputDecoration(labelText: 'notes'.tr()),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
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
