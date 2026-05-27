import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/attendance_model.dart';
import '../../data/models/work_schedule_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _attendanceRepository;
  final ScheduleRepository _scheduleRepository;
  StreamSubscription<AttendanceModel?>? _todaySubscription;
  String? _currentUserId;

  AttendanceCubit({
    required AttendanceRepository attendanceRepository,
    required ScheduleRepository scheduleRepository,
  }) : _attendanceRepository = attendanceRepository,
       _scheduleRepository = scheduleRepository,
       super(const AttendanceState());

  void startListeningToday(String userId) {
    _currentUserId = userId;
    emit(
      state.copyWith(
        todayStatus: AttendanceLoadStatus.loading,
        clearTodayError: true,
      ),
    );

    _todaySubscription?.cancel();
    _todaySubscription = _attendanceRepository
        .streamTodayRecord(userId)
        .listen(
          (record) {
            emit(
              state.copyWith(
                todayStatus: AttendanceLoadStatus.loaded,
                todayRecord: record,
                clearTodayError: true,
              ),
            );
          },
          onError: (error) {
            emit(
              state.copyWith(
                todayStatus: AttendanceLoadStatus.error,
                todayError: 'network_error',
              ),
            );
          },
        );
  }

  Future<void> loadHistory(String userId) async {
    emit(
      state.copyWith(
        historyStatus: AttendanceLoadStatus.loading,
        clearHistoryError: true,
      ),
    );

    try {
      final records = await _attendanceRepository.fetchHistory(userId);
      emit(
        state.copyWith(
          historyStatus: AttendanceLoadStatus.loaded,
          history: records,
          clearHistoryError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          historyStatus: AttendanceLoadStatus.error,
          historyError: 'network_error',
        ),
      );
    }
  }

  Future<void> checkIn() async {
    final userId = _currentUserId;
    emit(
      state.copyWith(
        actionStatus: AttendanceActionStatus.submitting,
        clearActionError: true,
      ),
    );

    try {
      await _attendanceRepository.checkIn();
      emit(
        state.copyWith(
          actionStatus: AttendanceActionStatus.success,
          clearActionError: true,
        ),
      );
      if (userId != null) {
        final record = await _attendanceRepository.fetchTodayRecord(userId);
        emit(state.copyWith(todayRecord: record));
      }
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: AttendanceActionStatus.error,
          actionError: _mapAttendanceError(error),
        ),
      );
    }
  }

  Future<void> checkOut() async {
    final userId = _currentUserId;
    emit(
      state.copyWith(
        actionStatus: AttendanceActionStatus.submitting,
        clearActionError: true,
      ),
    );

    try {
      await _attendanceRepository.checkOut();
      emit(
        state.copyWith(
          actionStatus: AttendanceActionStatus.success,
          clearActionError: true,
        ),
      );
      if (userId != null) {
        final record = await _attendanceRepository.fetchTodayRecord(userId);
        emit(state.copyWith(todayRecord: record));
      }
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: AttendanceActionStatus.error,
          actionError: _mapAttendanceError(error),
        ),
      );
    }
  }

  void clearActionFeedback() {
    emit(
      state.copyWith(
        actionStatus: AttendanceActionStatus.idle,
        clearActionError: true,
      ),
    );
  }

  Future<void> loadRoster(String date) async {
    emit(
      state.copyWith(
        rosterStatus: AttendanceLoadStatus.loading,
        selectedDate: date,
        clearRosterError: true,
      ),
    );
    try {
      final records = await _attendanceRepository.fetchRosterForDate(date);
      emit(
        state.copyWith(
          rosterStatus: AttendanceLoadStatus.loaded,
          roster: records,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          rosterStatus: AttendanceLoadStatus.error,
          rosterError: 'network_error',
        ),
      );
    }
  }

  Future<void> loadMonthlyAttendance(String userId, int year, int month) async {
    emit(
      state.copyWith(
        monthlyStatus: AttendanceLoadStatus.loading,
        clearMonthlyError: true,
      ),
    );
    try {
      final records = await _attendanceRepository.fetchMonthlyAttendance(
        userId,
        year,
        month,
      );
      emit(
        state.copyWith(
          monthlyStatus: AttendanceLoadStatus.loaded,
          monthlyRecords: records,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          monthlyStatus: AttendanceLoadStatus.error,
          monthlyError: 'network_error',
        ),
      );
    }
  }

  Future<void> adminCorrect({
    required String userId,
    required String date,
    required List<Map<String, dynamic>> sessions,
    String? notes,
  }) async {
    emit(
      state.copyWith(
        correctionStatus: AttendanceActionStatus.submitting,
        clearCorrectionError: true,
      ),
    );
    try {
      await _attendanceRepository.adminCorrect(
        userId: userId,
        date: date,
        sessions: sessions,
        notes: notes,
      );
      emit(state.copyWith(correctionStatus: AttendanceActionStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          correctionStatus: AttendanceActionStatus.error,
          correctionError: _mapAttendanceError(e),
        ),
      );
    }
  }

  void clearCorrectionFeedback() {
    emit(
      state.copyWith(
        correctionStatus: AttendanceActionStatus.idle,
        clearCorrectionError: true,
      ),
    );
  }

  Future<void> adminResetDay({
    required String userId,
    required String date,
    String? reason,
  }) async {
    emit(
      state.copyWith(
        resetStatus: AttendanceActionStatus.submitting,
        clearResetError: true,
      ),
    );
    try {
      await _attendanceRepository.adminResetDay(
        userId: userId,
        date: date,
        reason: reason,
      );
      emit(state.copyWith(resetStatus: AttendanceActionStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          resetStatus: AttendanceActionStatus.error,
          resetError: _mapAttendanceError(e),
        ),
      );
    }
  }

  void clearResetFeedback() {
    emit(
      state.copyWith(
        resetStatus: AttendanceActionStatus.idle,
        clearResetError: true,
      ),
    );
  }

  // ── Schedule methods ──────────────────────────────────────────────────────

  Future<void> loadMySchedule(String userId) async {
    emit(
      state.copyWith(
        scheduleStatus: AttendanceLoadStatus.loading,
        clearScheduleError: true,
      ),
    );
    try {
      final schedule = await _scheduleRepository.fetchSchedule(userId);
      emit(
        state.copyWith(
          scheduleStatus: AttendanceLoadStatus.loaded,
          mySchedule: schedule,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          scheduleStatus: AttendanceLoadStatus.error,
          scheduleError: 'network_error',
        ),
      );
    }
  }

  Future<void> loadEmployeeSchedule(String userId, String userName) async {
    emit(
      state.copyWith(
        editingScheduleStatus: AttendanceLoadStatus.loading,
        clearEditingSchedule: true,
      ),
    );
    try {
      final schedule = await _scheduleRepository.fetchSchedule(userId);
      emit(
        state.copyWith(
          editingScheduleStatus: AttendanceLoadStatus.loaded,
          editingSchedule:
              schedule ?? WorkScheduleModel.defaultFor(userId: userId, userName: userName),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          editingScheduleStatus: AttendanceLoadStatus.error,
        ),
      );
    }
  }

  Future<void> saveSchedule(
    WorkScheduleModel schedule, {
    required String updatedBy,
    required String updatedByName,
  }) async {
    emit(
      state.copyWith(
        scheduleSaveStatus: AttendanceActionStatus.submitting,
        clearScheduleSaveError: true,
      ),
    );
    try {
      await _scheduleRepository.saveSchedule(
        schedule,
        updatedBy: updatedBy,
        updatedByName: updatedByName,
      );
      emit(state.copyWith(scheduleSaveStatus: AttendanceActionStatus.success));
    } catch (_) {
      emit(
        state.copyWith(
          scheduleSaveStatus: AttendanceActionStatus.error,
          scheduleSaveError: 'network_error',
        ),
      );
    }
  }

  void clearScheduleSaveFeedback() {
    emit(
      state.copyWith(
        scheduleSaveStatus: AttendanceActionStatus.idle,
        clearScheduleSaveError: true,
      ),
    );
  }

  String _mapAttendanceError(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.code;
      final message = error.message?.toLowerCase() ?? '';
      final details = error.details?.toString().toLowerCase() ?? '';
      final combined = '$message $details';

      if (combined.contains('already-checked-in')) {
        return 'already_checked_in';
      }
      if (combined.contains('not-checked-in')) {
        return 'not_checked_in_yet';
      }
      if (code == 'unauthenticated') return 'not_authorized';
      if (code == 'permission-denied') return 'not_authorized';
      if (code == 'invalid-argument') return 'invalid_correction_data';
    }
    return 'network_error';
  }

  @override
  Future<void> close() {
    _todaySubscription?.cancel();
    return super.close();
  }
}
