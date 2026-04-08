import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/reports_repository.dart';
import 'reports_state.dart';
import '../../../auth/domain/models/app_user.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _reportsRepository;

  ReportsCubit({required ReportsRepository reportsRepository})
    : _reportsRepository = reportsRepository,
      super(const ReportsState());

  Future<void> loadEmployees() async {
    emit(state.copyWith(status: ReportsStatus.loading, clearError: true));

    try {
      final employees = await _reportsRepository.getEmployees();

      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          employees: employees,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_load_reports',
        ),
      );
    }
  }

  Future<void> generateReport({
    required AppUser employee,
    required DateTime month,
  }) async {
    emit(
      state.copyWith(
        status: ReportsStatus.loading,
        selectedEmployee: employee,
        selectedMonth: month,
        clearError: true,
      ),
    );

    try {
      debugPrint('GENERATE REPORT FOR: ${employee.id}');
      debugPrint('GENERATE REPORT MONTH: $month');
      final tasks = await _reportsRepository.getTasksForEmployeeByMonth(
        employeeId: employee.id,
        month: month,
      );

      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          tasks: tasks,
          selectedEmployee: employee,
          selectedMonth: month,
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('REPORT ERROR: $e');
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_load_reports',
        ),
      );
    }
  }
}
