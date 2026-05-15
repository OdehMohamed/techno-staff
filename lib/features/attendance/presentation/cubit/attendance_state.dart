import '../../data/models/attendance_model.dart';

enum AttendanceLoadStatus { initial, loading, loaded, error }

enum AttendanceActionStatus { idle, submitting, success, error }

class AttendanceState {
  final AttendanceLoadStatus todayStatus;
  final AttendanceLoadStatus historyStatus;
  final AttendanceActionStatus actionStatus;
  final AttendanceModel? todayRecord;
  final List<AttendanceModel> history;
  final String? todayError;
  final String? historyError;
  final String? actionError;

  const AttendanceState({
    this.todayStatus = AttendanceLoadStatus.initial,
    this.historyStatus = AttendanceLoadStatus.initial,
    this.actionStatus = AttendanceActionStatus.idle,
    this.todayRecord,
    this.history = const [],
    this.todayError,
    this.historyError,
    this.actionError,
  });

  AttendanceState copyWith({
    AttendanceLoadStatus? todayStatus,
    AttendanceLoadStatus? historyStatus,
    AttendanceActionStatus? actionStatus,
    AttendanceModel? todayRecord,
    List<AttendanceModel>? history,
    String? todayError,
    String? historyError,
    String? actionError,
    bool clearTodayError = false,
    bool clearHistoryError = false,
    bool clearActionError = false,
    bool clearTodayRecord = false,
  }) {
    return AttendanceState(
      todayStatus: todayStatus ?? this.todayStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      todayRecord: clearTodayRecord ? null : (todayRecord ?? this.todayRecord),
      history: history ?? this.history,
      todayError: clearTodayError ? null : (todayError ?? this.todayError),
      historyError: clearHistoryError
          ? null
          : (historyError ?? this.historyError),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}
