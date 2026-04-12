import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/tasks_repository.dart';
import 'task_logs_state.dart';

class TaskLogsCubit extends Cubit<TaskLogsState> {
  final TasksRepository _tasksRepository;

  TaskLogsCubit({required TasksRepository tasksRepository})
    : _tasksRepository = tasksRepository,
      super(const TaskLogsState());

  Future<void> fetchTaskLogs(String taskId) async {
    emit(state.copyWith(status: TaskLogsStatus.loading, clearError: true));

    try {
      final logs = await _tasksRepository.getTaskLogs(taskId);

      emit(
        state.copyWith(
          status: TaskLogsStatus.loaded,
          logs: logs,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TaskLogsStatus.error,
          errorMessage: 'failed_to_load_task_logs',
        ),
      );
    }
  }
}
