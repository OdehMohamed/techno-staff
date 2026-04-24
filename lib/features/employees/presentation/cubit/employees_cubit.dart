import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/employees_repository.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final EmployeesRepository _employeesRepository;

  EmployeesCubit({required EmployeesRepository employeesRepository})
    : _employeesRepository = employeesRepository,
      super(const EmployeesState());

  Future<void> fetchEmployees() async {
    debugPrint('EmployeesCubit: fetching employees...');
    emit(state.copyWith(status: EmployeesStatus.loading, clearError: true));

    try {
      final employees = await _employeesRepository.getEmployees();
      debugPrint('EmployeesCubit: fetched ${employees.length} employees');

      emit(
        state.copyWith(
          status: EmployeesStatus.loaded,
          employees: employees,
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('EmployeesCubit: error fetching employees: $e');
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
    await _employeesRepository.updateEmployeeStatus(
      userId: userId,
      isActive: isActive,
    );

    await fetchEmployees();
  }
}
