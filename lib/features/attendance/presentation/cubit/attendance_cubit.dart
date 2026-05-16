import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _attendanceRepository;
  StreamSubscription<AttendanceModel?>? _todaySubscription;

  AttendanceCubit({required AttendanceRepository attendanceRepository})
    : _attendanceRepository = attendanceRepository,
      super(const AttendanceState());

  void startListeningToday(String userId) {
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
    } catch (_) {
      emit(
        state.copyWith(
          correctionStatus: AttendanceActionStatus.error,
          correctionError: 'network_error',
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
      if (code == 'unauthenticated') {
        return 'not_authorized';
      }
    }
    return 'network_error';
  }

  @override
  Future<void> close() {
    _todaySubscription?.cancel();
    return super.close();
  }
}
