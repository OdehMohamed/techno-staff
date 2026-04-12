import '../../../auth/domain/models/app_user.dart';

enum EmployeesStatus { initial, loading, loaded, error }

class EmployeesState {
  final EmployeesStatus status;
  final List<AppUser> employees;
  final String? errorMessage;

  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.employees = const [],
    this.errorMessage,
  });

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<AppUser>? employees,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
