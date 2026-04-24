import 'package:flutter_test/flutter_test.dart';
import 'package:techno_staff/features/tasks/data/models/task_model.dart';
import 'package:techno_staff/features/tasks/presentation/cubit/tasks_state.dart';

void main() {
  group('TasksState', () {
    test('copyWith updates assigned and created lists independently', () {
      final assignedTask = TaskModel(
        id: 'a1',
        title: 'Assigned task',
        description: 'desc',
        assignedTo: 'u1',
        assignedToName: 'User 1',
        assignedBy: 'u2',
        assignedByName: 'User 2',
        priority: 'medium',
        status: 'pending',
        dueDate: DateTime(2026, 4, 30),
        createdAt: DateTime(2026, 4, 24),
        updatedAt: DateTime(2026, 4, 24),
      );

      final createdTask = TaskModel(
        id: 'c1',
        title: 'Created task',
        description: 'desc',
        assignedTo: 'u3',
        assignedToName: 'User 3',
        assignedBy: 'u1',
        assignedByName: 'User 1',
        priority: 'high',
        status: 'in_progress',
        dueDate: DateTime(2026, 5, 1),
        createdAt: DateTime(2026, 4, 24),
        updatedAt: DateTime(2026, 4, 24),
      );

      final state = const TasksState().copyWith(
        tasksAssignedToMeStatus: TasksStatus.loaded,
        tasksAssignedToMe: [assignedTask],
        tasksCreatedByMeStatus: TasksStatus.loaded,
        tasksCreatedByMe: [createdTask],
      );

      expect(state.tasksAssignedToMeStatus, TasksStatus.loaded);
      expect(state.tasksCreatedByMeStatus, TasksStatus.loaded);
      expect(state.tasksAssignedToMe.single.id, 'a1');
      expect(state.tasksCreatedByMe.single.id, 'c1');
    });

    test('clear flags clear tab-specific errors', () {
      final state = const TasksState().copyWith(
        tasksAssignedToMeErrorMessage: 'assigned_error',
        tasksCreatedByMeErrorMessage: 'created_error',
      );

      final clearedAssigned = state.copyWith(clearTasksAssignedToMeError: true);
      final clearedCreated = state.copyWith(clearTasksCreatedByMeError: true);

      expect(clearedAssigned.tasksAssignedToMeErrorMessage, isNull);
      expect(clearedAssigned.tasksCreatedByMeErrorMessage, 'created_error');
      expect(clearedCreated.tasksCreatedByMeErrorMessage, isNull);
      expect(clearedCreated.tasksAssignedToMeErrorMessage, 'assigned_error');
    });
  });
}
