import '../../data/models/task_model.dart';

enum TasksStatus { initial, loading, loaded, error }

class TasksState {
  final TasksStatus status;
  final List<TaskModel> tasks;
  final String? errorMessage;
  final TasksStatus tasksAssignedToMeStatus;
  final List<TaskModel> tasksAssignedToMe;
  final String? tasksAssignedToMeErrorMessage;
  final TasksStatus tasksCreatedByMeStatus;
  final List<TaskModel> tasksCreatedByMe;
  final String? tasksCreatedByMeErrorMessage;

  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.errorMessage,
    this.tasksAssignedToMeStatus = TasksStatus.initial,
    this.tasksAssignedToMe = const [],
    this.tasksAssignedToMeErrorMessage,
    this.tasksCreatedByMeStatus = TasksStatus.initial,
    this.tasksCreatedByMe = const [],
    this.tasksCreatedByMeErrorMessage,
  });

  TasksState copyWith({
    TasksStatus? status,
    List<TaskModel>? tasks,
    String? errorMessage,
    TasksStatus? tasksAssignedToMeStatus,
    List<TaskModel>? tasksAssignedToMe,
    String? tasksAssignedToMeErrorMessage,
    TasksStatus? tasksCreatedByMeStatus,
    List<TaskModel>? tasksCreatedByMe,
    String? tasksCreatedByMeErrorMessage,
    bool clearError = false,
    bool clearTasksAssignedToMeError = false,
    bool clearTasksCreatedByMeError = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tasksAssignedToMeStatus:
          tasksAssignedToMeStatus ?? this.tasksAssignedToMeStatus,
      tasksAssignedToMe: tasksAssignedToMe ?? this.tasksAssignedToMe,
      tasksAssignedToMeErrorMessage: clearTasksAssignedToMeError
          ? null
          : (tasksAssignedToMeErrorMessage ?? this.tasksAssignedToMeErrorMessage),
      tasksCreatedByMeStatus:
          tasksCreatedByMeStatus ?? this.tasksCreatedByMeStatus,
      tasksCreatedByMe: tasksCreatedByMe ?? this.tasksCreatedByMe,
      tasksCreatedByMeErrorMessage: clearTasksCreatedByMeError
          ? null
          : (tasksCreatedByMeErrorMessage ?? this.tasksCreatedByMeErrorMessage),
    );
  }
}
