import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/tasks_repository.dart';
import 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  final TasksRepository _tasksRepository;

  TasksCubit({required TasksRepository tasksRepository})
    : _tasksRepository = tasksRepository,
      super(const TasksState());

  Future<void> fetchTasksAssignedTo(String userId) async {
    emit(
      state.copyWith(
        tasksAssignedToMeStatus: TasksStatus.loading,
        clearTasksAssignedToMeError: true,
      ),
    );

    try {
      debugPrint('FETCHING TASKS ASSIGNED TO USER ID: $userId');

      final tasks = await _tasksRepository.getTasksAssignedTo(userId);

      debugPrint('TASKS COUNT ASSIGNED TO USER: ${tasks.length}');

      emit(
        state.copyWith(
          tasksAssignedToMeStatus: TasksStatus.loaded,
          tasksAssignedToMe: tasks,
          clearTasksAssignedToMeError: true,
        ),
      );
    } catch (e) {
      debugPrint('FETCH ASSIGNED TASKS ERROR: $e');
      emit(
        state.copyWith(
          tasksAssignedToMeStatus: TasksStatus.error,
          tasksAssignedToMeErrorMessage: 'failed_to_load_tasks',
        ),
      );
    }
  }

  Future<void> fetchTasksCreatedBy(String userId) async {
    emit(
      state.copyWith(
        tasksCreatedByMeStatus: TasksStatus.loading,
        clearTasksCreatedByMeError: true,
      ),
    );

    try {
      debugPrint('FETCHING TASKS CREATED BY USER ID: $userId');

      final tasks = await _tasksRepository.getTasksCreatedBy(userId);

      debugPrint('TASKS COUNT CREATED BY USER: ${tasks.length}');

      emit(
        state.copyWith(
          tasksCreatedByMeStatus: TasksStatus.loaded,
          tasksCreatedByMe: tasks,
          clearTasksCreatedByMeError: true,
        ),
      );
    } catch (e) {
      debugPrint('FETCH CREATED TASKS ERROR: $e');
      emit(
        state.copyWith(
          tasksCreatedByMeStatus: TasksStatus.error,
          tasksCreatedByMeErrorMessage: 'failed_to_load_tasks',
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
    required String currentUserName,
  }) async {
    await _tasksRepository.updateTaskStatus(
      taskId: taskId,
      status: status,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );

    if (isAdmin) {
      await fetchAllTasks();
      await fetchTasksAssignedTo(currentUserId);
    } else {
      await fetchTasksAssignedTo(currentUserId);
      await fetchTasksCreatedBy(currentUserId);
    }
  }
}
