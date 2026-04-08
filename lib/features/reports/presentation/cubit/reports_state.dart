import '../../../auth/domain/models/app_user.dart';
import '../../../tasks/data/models/task_model.dart';

enum ReportsStatus { initial, loading, loaded, error }

class ReportsState {
  final ReportsStatus status;
  final List<AppUser> employees;
  final List<TaskModel> tasks;
  final AppUser? selectedEmployee;
  final DateTime? selectedMonth;
  final String? errorMessage;

  const ReportsState({
    this.status = ReportsStatus.initial,
    this.employees = const [],
    this.tasks = const [],
    this.selectedEmployee,
    this.selectedMonth,
    this.errorMessage,
  });

  ReportsState copyWith({
    ReportsStatus? status,
    List<AppUser>? employees,
    List<TaskModel>? tasks,
    AppUser? selectedEmployee,
    DateTime? selectedMonth,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      tasks: tasks ?? this.tasks,
      selectedEmployee: selectedEmployee ?? this.selectedEmployee,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
