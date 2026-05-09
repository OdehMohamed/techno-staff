import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/task_model.dart';
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
      final tasks = await _tasksRepository.getTasksAssignedTo(userId);

      emit(
        state.copyWith(
          tasksAssignedToMeStatus: TasksStatus.loaded,
          tasksAssignedToMe: tasks,
          clearTasksAssignedToMeError: true,
        ),
      );
    } catch (_) {
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
      final tasks = await _tasksRepository.getTasksCreatedBy(userId);

      emit(
        state.copyWith(
          tasksCreatedByMeStatus: TasksStatus.loaded,
          tasksCreatedByMe: tasks,
          clearTasksCreatedByMeError: true,
        ),
      );
    } catch (_) {
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

  Future<void> deleteTask({
    required String taskId,
    required bool isAdmin,
    required String currentUserId,
  }) async {
    await _tasksRepository.deleteTask(taskId);

    if (isAdmin) {
      await fetchAllTasks();
      await fetchTasksAssignedTo(currentUserId);
    } else {
      await fetchTasksAssignedTo(currentUserId);
      await fetchTasksCreatedBy(currentUserId);
    }
  }

  Future<void> incrementTaskCounter({
    required String taskId,
    required bool isAdmin,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final updated = await _tasksRepository.incrementTaskCounter(
      taskId: taskId,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );

    if (updated == null) return;

    // Patch only the affected task in the three role-relevant lists. No
    // loading emit, no refetch — the transactional write is authoritative,
    // so the local state can be updated in place. This avoids the
    // full-screen spinner flash that a fetchAll/fetchAssigned/fetchCreated
    // chain would cause via TasksStatus.loading.
    emit(
      state.copyWith(
        tasks: _replaceTaskById(state.tasks, updated),
        tasksAssignedToMe: _replaceTaskById(state.tasksAssignedToMe, updated),
        tasksCreatedByMe: _replaceTaskById(state.tasksCreatedByMe, updated),
      ),
    );
  }

  List<TaskModel> _replaceTaskById(List<TaskModel> source, TaskModel updated) {
    return [
      for (final task in source)
        if (task.id == updated.id) updated else task,
    ];
  }
}
