import '../../../auth/domain/models/app_user.dart';

enum EmployeesStatus { initial, loading, loaded, error }

class EmployeesState {
  final EmployeesStatus status;
  final List<AppUser> employees;
  final String? errorMessage;
  final String? toggleError;

  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.employees = const [],
    this.errorMessage,
    this.toggleError,
  });

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<AppUser>? employees,
    String? errorMessage,
    String? toggleError,
    bool clearError = false,
    bool clearToggleError = false,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      toggleError:
          clearToggleError ? null : (toggleError ?? this.toggleError),
    );
  }
}
