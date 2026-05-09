import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/features/tasks/data/models/task_model.dart';

void main() {
  group('TaskModel.deriveCounterStatus', () {
    test('returns pending when current is zero', () {
      expect(TaskModel.deriveCounterStatus(0, 5), 'pending');
    });

    test('returns in_progress when current is between zero and target', () {
      expect(TaskModel.deriveCounterStatus(3, 5), 'in_progress');
    });

    test('returns completed when current reaches target', () {
      expect(TaskModel.deriveCounterStatus(5, 5), 'completed');
    });
  });

  test('fromMap defaults to standard task when counter fields are absent', () {
    final now = Timestamp.now();
    final task = TaskModel.fromMap('task-1', {
      'title': 'Title',
      'description': 'Description',
      'assignedTo': 'u1',
      'assignedToName': 'User 1',
      'assignedBy': 'u2',
      'assignedByName': 'User 2',
      'priority': 'medium',
      'status': 'pending',
      'dueDate': now,
      'createdAt': now,
    });

    expect(task.taskType, 'standard');
    expect(task.isCounter, isFalse);
    expect(task.targetCount, isNull);
    expect(task.currentCount, 0);
  });
}
