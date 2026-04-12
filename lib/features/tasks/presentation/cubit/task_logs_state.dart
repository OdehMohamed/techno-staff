import '../../data/models/task_log_model.dart';

enum TaskLogsStatus { initial, loading, loaded, error }

class TaskLogsState {
  final TaskLogsStatus status;
  final List<TaskLogModel> logs;
  final String? errorMessage;

  const TaskLogsState({
    this.status = TaskLogsStatus.initial,
    this.logs = const [],
    this.errorMessage,
  });

  TaskLogsState copyWith({
    TaskLogsStatus? status,
    List<TaskLogModel>? logs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskLogsState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
