enum TaskDetailsStatus { initial, loading, loaded, error }

class TaskDetailsState {
  final TaskDetailsStatus status;
  final String assignedToName;
  final String assignedByName;
  final String? errorMessage;

  const TaskDetailsState({
    this.status = TaskDetailsStatus.initial,
    this.assignedToName = '-',
    this.assignedByName = '-',
    this.errorMessage,
  });

  TaskDetailsState copyWith({
    TaskDetailsStatus? status,
    String? assignedToName,
    String? assignedByName,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskDetailsState(
      status: status ?? this.status,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedByName: assignedByName ?? this.assignedByName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
