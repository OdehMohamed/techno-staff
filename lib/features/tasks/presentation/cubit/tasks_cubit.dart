import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/tasks_repository.dart';
import 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  final TasksRepository _tasksRepository;

  TasksCubit({required TasksRepository tasksRepository})
    : _tasksRepository = tasksRepository,
      super(const TasksState());

  Future<void> fetchTasksForUser(String userId) async {
    emit(state.copyWith(status: TasksStatus.loading, clearError: true));

    try {
      debugPrint('FETCHING TASKS FOR USER ID: $userId');

      final tasks = await _tasksRepository.getTasksForUser(userId);

      debugPrint('TASKS COUNT FOR USER: ${tasks.length}');

      emit(
        state.copyWith(
          status: TasksStatus.loaded,
          tasks: tasks,
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('FETCH TASKS ERROR: $e');
      emit(
        state.copyWith(
          status: TasksStatus.error,
          errorMessage: 'failed_to_load_tasks',
        ),
      );
    }
  }

  Future<void> fetchAllTasks() async {
    emit(state.copyWith(status: TasksStatus.loading, clearError: true));

    try {
      final tasks = await _tasksRepository.getAllTasks();

      emit(
        state.copyWith(
          status: TasksStatus.loaded,
          tasks: tasks,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TasksStatus.error,
          errorMessage: 'failed_to_load_tasks',
        ),
      );
    }
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    required bool isAdmin,
    required String currentUserId,
  }) async {
    await _tasksRepository.updateTaskStatus(taskId: taskId, status: status);

    if (isAdmin) {
      await fetchAllTasks();
    } else {
      await fetchTasksForUser(currentUserId);
    }
  }
}
