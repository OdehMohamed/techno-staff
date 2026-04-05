import '../../data/models/task_model.dart';

enum TasksStatus { initial, loading, loaded, error }

class TasksState {
  final TasksStatus status;
  final List<TaskModel> tasks;
  final String? errorMessage;

  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  TasksState copyWith({
    TasksStatus? status,
    List<TaskModel>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
