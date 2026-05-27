import '../../data/models/attendance_model.dart';
import '../../data/models/work_schedule_model.dart';

enum AttendanceLoadStatus { initial, loading, loaded, error }

enum AttendanceActionStatus { idle, submitting, success, error }

class AttendanceState {
  final AttendanceLoadStatus todayStatus;
  final AttendanceLoadStatus historyStatus;
  final AttendanceLoadStatus rosterStatus;
  final AttendanceLoadStatus monthlyStatus;
  final AttendanceLoadStatus scheduleStatus;
  final AttendanceLoadStatus editingScheduleStatus;
  final AttendanceActionStatus actionStatus;
  final AttendanceActionStatus correctionStatus;
  final AttendanceActionStatus resetStatus;
  final AttendanceActionStatus scheduleSaveStatus;
  final AttendanceModel? todayRecord;
  final List<AttendanceModel> history;
  final List<AttendanceModel> roster;
  final List<AttendanceModel> monthlyRecords;
  final WorkScheduleModel? mySchedule;
  final WorkScheduleModel? editingSchedule;
  final String? todayError;
  final String? historyError;
  final String? actionError;
  final String? rosterError;
  final String? monthlyError;
  final String? correctionError;
  final String? resetError;
  final String? scheduleError;
  final String? scheduleSaveError;
  final String? selectedDate;

  const AttendanceState({
    this.todayStatus = AttendanceLoadStatus.initial,
    this.historyStatus = AttendanceLoadStatus.initial,
    this.rosterStatus = AttendanceLoadStatus.initial,
    this.monthlyStatus = AttendanceLoadStatus.initial,
    this.scheduleStatus = AttendanceLoadStatus.initial,
    this.editingScheduleStatus = AttendanceLoadStatus.initial,
    this.actionStatus = AttendanceActionStatus.idle,
    this.correctionStatus = AttendanceActionStatus.idle,
    this.resetStatus = AttendanceActionStatus.idle,
    this.scheduleSaveStatus = AttendanceActionStatus.idle,
    this.todayRecord,
    this.history = const [],
    this.roster = const [],
    this.monthlyRecords = const [],
    this.mySchedule,
    this.editingSchedule,
    this.todayError,
    this.historyError,
    this.actionError,
    this.rosterError,
    this.monthlyError,
    this.correctionError,
    this.resetError,
    this.scheduleError,
    this.scheduleSaveError,
    this.selectedDate,
  });

  AttendanceState copyWith({
    AttendanceLoadStatus? todayStatus,
    AttendanceLoadStatus? historyStatus,
    AttendanceLoadStatus? rosterStatus,
    AttendanceLoadStatus? monthlyStatus,
    AttendanceLoadStatus? scheduleStatus,
    AttendanceLoadStatus? editingScheduleStatus,
    AttendanceActionStatus? actionStatus,
    AttendanceActionStatus? correctionStatus,
    AttendanceActionStatus? resetStatus,
    AttendanceActionStatus? scheduleSaveStatus,
    AttendanceModel? todayRecord,
    List<AttendanceModel>? history,
    List<AttendanceModel>? roster,
    List<AttendanceModel>? monthlyRecords,
    WorkScheduleModel? mySchedule,
    WorkScheduleModel? editingSchedule,
    String? todayError,
    String? historyError,
    String? actionError,
    String? rosterError,
    String? monthlyError,
    String? correctionError,
    String? resetError,
    String? scheduleError,
    String? scheduleSaveError,
    String? selectedDate,
    bool clearTodayError = false,
    bool clearHistoryError = false,
    bool clearActionError = false,
    bool clearTodayRecord = false,
    bool clearRosterError = false,
    bool clearMonthlyError = false,
    bool clearCorrectionError = false,
    bool clearResetError = false,
    bool clearScheduleError = false,
    bool clearScheduleSaveError = false,
    bool clearMySchedule = false,
    bool clearEditingSchedule = false,
  }) {
    return AttendanceState(
      todayStatus: todayStatus ?? this.todayStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      rosterStatus: rosterStatus ?? this.rosterStatus,
      monthlyStatus: monthlyStatus ?? this.monthlyStatus,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
      editingScheduleStatus: editingScheduleStatus ?? this.editingScheduleStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      correctionStatus: correctionStatus ?? this.correctionStatus,
      resetStatus: resetStatus ?? this.resetStatus,
      scheduleSaveStatus: scheduleSaveStatus ?? this.scheduleSaveStatus,
      todayRecord: clearTodayRecord ? null : (todayRecord ?? this.todayRecord),
      history: history ?? this.history,
      roster: roster ?? this.roster,
      monthlyRecords: monthlyRecords ?? this.monthlyRecords,
      mySchedule: clearMySchedule ? null : (mySchedule ?? this.mySchedule),
      editingSchedule: clearEditingSchedule ? null : (editingSchedule ?? this.editingSchedule),
      todayError: clearTodayError ? null : (todayError ?? this.todayError),
      historyError: clearHistoryError ? null : (historyError ?? this.historyError),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      rosterError: clearRosterError ? null : (rosterError ?? this.rosterError),
      monthlyError: clearMonthlyError ? null : (monthlyError ?? this.monthlyError),
      correctionError: clearCorrectionError ? null : (correctionError ?? this.correctionError),
      resetError: clearResetError ? null : (resetError ?? this.resetError),
      scheduleError: clearScheduleError ? null : (scheduleError ?? this.scheduleError),
      scheduleSaveError: clearScheduleSaveError ? null : (scheduleSaveError ?? this.scheduleSaveError),
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}
