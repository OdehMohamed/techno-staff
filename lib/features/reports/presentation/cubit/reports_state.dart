import '../../../auth/domain/models/app_user.dart';
import '../../../tasks/data/models/task_model.dart';

enum ReportsStatus {
  initial,
  loading,
  loaded,
  exportingPdf,
  pdfExported,
  error,
}

class ReportsState {
  final ReportsStatus status;
  final List<AppUser> employees;
  final List<TaskModel> tasks;
  final AppUser? selectedEmployee;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final String? errorMessage;

  const ReportsState({
    this.status = ReportsStatus.initial,
    this.employees = const [],
    this.tasks = const [],
    this.selectedEmployee,
    this.selectedStartDate,
    this.selectedEndDate,
    this.errorMessage,
  });

  ReportsState copyWith({
    ReportsStatus? status,
    List<AppUser>? employees,
    List<TaskModel>? tasks,
    AppUser? selectedEmployee,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      tasks: tasks ?? this.tasks,
      selectedEmployee: selectedEmployee ?? this.selectedEmployee,
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
