import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';

/// Shared widget for selecting a due date with an optional specific time.
///
/// Renders a date tile (tap to open date picker) and, once a date is chosen,
/// a scrollable row of time chips: No time / 09:00 / 12:00 / 17:00 / 20:00 /
/// Custom (opens time picker). The "Custom" chip label becomes the picked time
/// once a non-preset time is active.
///
/// Calls [onChanged] with `(date, hasDueTime)` on every selection. When
/// [hasDueTime] is false the caller should apply [TaskModel.dueDateEndOfDay]
/// before persisting to Firestore — this widget returns the raw calendar date
/// from the picker in that case.
class DueDateTimePicker extends StatelessWidget {
  final DateTime? dueDate;
  final bool hasDueTime;
  final void Function(DateTime date, bool hasDueTime) onChanged;

  /// Earliest selectable date. Pass [DateTime.now()] to prevent past dates
  /// (add flow); omit / pass null to allow 1 year in the past (edit flow).
  final DateTime? firstDate;

  const DueDateTimePicker({
    super.key,
    required this.dueDate,
    required this.hasDueTime,
    required this.onChanged,
    this.firstDate,
  });

  static const _presets = [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ];

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _hmStr(int hour, int minute) =>
      '${_pad2(hour)}:${_pad2(minute)}';

  TimeOfDay? get _currentTime {
    if (!hasDueTime || dueDate == null) return null;
    return TimeOfDay(hour: dueDate!.hour, minute: dueDate!.minute);
  }

  bool _matchesPreset(TimeOfDay t) =>
      _presets.any((p) => p.hour == t.hour && p.minute == t.minute);

  Future<void> _tapDate(BuildContext context) async {
    final now = DateTime.now();
    final earliest = firstDate ?? DateTime(now.year - 1);
    final base = dueDate ?? now;
    final initial = base.isBefore(earliest) ? earliest : base;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !context.mounted) return;

    final t = _currentTime;
    if (hasDueTime && t != null) {
      onChanged(
        DateTime(picked.year, picked.month, picked.day, t.hour, t.minute),
        true,
      );
    } else {
      onChanged(picked, false);
    }
  }

  void _selectPreset(BuildContext context, TimeOfDay preset) {
    final base = dueDate ?? DateTime.now();
    onChanged(
      DateTime(base.year, base.month, base.day, preset.hour, preset.minute),
      true,
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _currentTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !context.mounted) return;
    final base = dueDate ?? DateTime.now();
    onChanged(
      DateTime(base.year, base.month, base.day, picked.hour, picked.minute),
      true,
    );
  }

  void _clearTime() {
    if (dueDate == null) return;
    onChanged(DateTime(dueDate!.year, dueDate!.month, dueDate!.day), false);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final t = _currentTime;
    final isCustom = t != null && !_matchesPreset(t);

    final String dateLabel;
    if (dueDate == null) {
      dateLabel = 'select_due_date'.tr();
    } else if (hasDueTime) {
      dateLabel =
          '${DateFormat.yMMMd(locale).format(dueDate!)}  •  ${_hmStr(dueDate!.hour, dueDate!.minute)}';
    } else {
      dateLabel = DateFormat.yMMMd(locale).format(dueDate!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text(dateLabel),
          onTap: () => _tapDate(context),
        ),
        if (dueDate != null) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'no_time'.tr(),
                  selected: !hasDueTime,
                  onTap: _clearTime,
                ),
                const SizedBox(width: AppSizes.xs),
                for (final preset in _presets) ...[
                  _Chip(
                    label: _hmStr(preset.hour, preset.minute),
                    selected: t != null &&
                        t.hour == preset.hour &&
                        t.minute == preset.minute,
                    onTap: () => _selectPreset(context, preset),
                  ),
                  const SizedBox(width: AppSizes.xs),
                ],
                _Chip(
                  label: isCustom
                      ? _hmStr(t.hour, t.minute)
                      : 'custom_time'.tr(),
                  selected: isCustom,
                  onTap: () => _pickCustom(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xs),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
