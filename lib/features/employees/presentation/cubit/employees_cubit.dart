import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/employees_repository.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final EmployeesRepository _employeesRepository;

  EmployeesCubit({required EmployeesRepository employeesRepository})
    : _employeesRepository = employeesRepository,
      super(const EmployeesState());

  Future<void> fetchEmployees({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: EmployeesStatus.loading, clearError: true));
    }

    try {
      final employees = await _employeesRepository.getEmployees();

      emit(
        state.copyWith(
          status: EmployeesStatus.loaded,
          employees: employees,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: EmployeesStatus.error,
          errorMessage: 'failed_to_load_employees',
        ),
      );
    }
  }

  Future<void> toggleEmployeeStatus({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _employeesRepository.updateEmployeeStatus(
        userId: userId,
        isActive: isActive,
      );
      await fetchEmployees();
    } catch (_) {
      emit(
        state.copyWith(toggleError: 'failed_to_update_employee_status'),
      );
    }
  }

  void clearToggleError() {
    emit(state.copyWith(clearToggleError: true));
  }
}
