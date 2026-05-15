import '../../data/models/attendance_model.dart';

enum AttendanceLoadStatus { initial, loading, loaded, error }

enum AttendanceActionStatus { idle, submitting, success, error }

class AttendanceState {
  final AttendanceLoadStatus todayStatus;
  final AttendanceLoadStatus historyStatus;
  final AttendanceLoadStatus rosterStatus;
  final AttendanceActionStatus actionStatus;
  final AttendanceActionStatus correctionStatus;
  final AttendanceModel? todayRecord;
  final List<AttendanceModel> history;
  final List<AttendanceModel> roster;
  final String? todayError;
  final String? historyError;
  final String? actionError;
  final String? rosterError;
  final String? correctionError;
  final String? selectedDate;

  const AttendanceState({
    this.todayStatus = AttendanceLoadStatus.initial,
    this.historyStatus = AttendanceLoadStatus.initial,
    this.rosterStatus = AttendanceLoadStatus.initial,
    this.actionStatus = AttendanceActionStatus.idle,
    this.correctionStatus = AttendanceActionStatus.idle,
    this.todayRecord,
    this.history = const [],
    this.roster = const [],
    this.todayError,
    this.historyError,
    this.actionError,
    this.rosterError,
    this.correctionError,
    this.selectedDate,
  });

  AttendanceState copyWith({
    AttendanceLoadStatus? todayStatus,
    AttendanceLoadStatus? historyStatus,
    AttendanceLoadStatus? rosterStatus,
    AttendanceActionStatus? actionStatus,
    AttendanceActionStatus? correctionStatus,
    AttendanceModel? todayRecord,
    List<AttendanceModel>? history,
    List<AttendanceModel>? roster,
    String? todayError,
    String? historyError,
    String? actionError,
    String? rosterError,
    String? correctionError,
    String? selectedDate,
    bool clearTodayError = false,
    bool clearHistoryError = false,
    bool clearActionError = false,
    bool clearTodayRecord = false,
    bool clearRosterError = false,
    bool clearCorrectionError = false,
  }) {
    return AttendanceState(
      todayStatus: todayStatus ?? this.todayStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      rosterStatus: rosterStatus ?? this.rosterStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      correctionStatus: correctionStatus ?? this.correctionStatus,
      todayRecord: clearTodayRecord ? null : (todayRecord ?? this.todayRecord),
      history: history ?? this.history,
      roster: roster ?? this.roster,
      todayError: clearTodayError ? null : (todayError ?? this.todayError),
      historyError: clearHistoryError
          ? null
          : (historyError ?? this.historyError),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      rosterError: clearRosterError ? null : (rosterError ?? this.rosterError),
      correctionError: clearCorrectionError
          ? null
          : (correctionError ?? this.correctionError),
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}
