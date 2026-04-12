import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/tasks_repository.dart';
import 'task_details_state.dart';

class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  final TasksRepository _tasksRepository;

  TaskDetailsCubit({required TasksRepository tasksRepository})
    : _tasksRepository = tasksRepository,
      super(const TaskDetailsState());

  Future<void> loadTaskUserNames({
    required String assignedTo,
    required String assignedBy,
  }) async {
    emit(state.copyWith(status: TaskDetailsStatus.loading, clearError: true));

    try {
      final result = await _tasksRepository.getTaskUserNames(
        assignedTo: assignedTo,
        assignedBy: assignedBy,
      );

      emit(
        state.copyWith(
          status: TaskDetailsStatus.loaded,
          assignedToName: result['assignedToName'] ?? '-',
          assignedByName: result['assignedByName'] ?? '-',
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TaskDetailsStatus.error,
          errorMessage: 'failed_to_load_task_details',
        ),
      );
    }
  }
}
