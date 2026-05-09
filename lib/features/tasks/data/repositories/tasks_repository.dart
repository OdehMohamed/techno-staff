import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import 'package:techno_staff/features/tasks/data/models/task_log_model.dart';
import '../models/task_model.dart';

class TasksRepository {
  final FirebaseFirestore _firestore;

  TasksRepository(this._firestore);

  Future<void> createTask(TaskModel task) async {
    await _firestore.collection(FirebasePaths.tasks).add(task.toMap());
  }

  Future<List<TaskModel>> getTasksAssignedTo(String userId) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedTo, isEqualTo: userId)
        .orderBy(FirebasePaths.createdAt, descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<TaskModel>> getTasksCreatedBy(String userId) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedBy, isEqualTo: userId)
        .orderBy(FirebasePaths.createdAt, descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<TaskModel>> getAllTasks() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .orderBy(FirebasePaths.createdAt, descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final now = Timestamp.now();

    final updateData = <String, dynamic>{
      FirebasePaths.status: status,
      'updatedAt': now,
      'updatedBy': currentUserId,
      'updatedByName': currentUserName,
    };

    if (status == 'completed') {
      updateData['completedAt'] = now;
    } else {
      updateData['completedAt'] = null;
    }

    await _firestore
        .collection(FirebasePaths.tasks)
        .doc(taskId)
        .update(updateData);
  }

  Future<void> deleteTask(String taskId) async {
    await _firestore.collection(FirebasePaths.tasks).doc(taskId).delete();
  }

  Future<TaskModel?> getTaskById(String taskId) async {
    final doc = await _firestore
        .collection(FirebasePaths.tasks)
        .doc(taskId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return TaskModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateTask(TaskModel task) async {
    await _firestore
        .collection(FirebasePaths.tasks)
        .doc(task.id)
        .update(task.toMap());
  }

  Future<TaskModel?> incrementTaskCounter({
    required String taskId,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final ref = _firestore.collection(FirebasePaths.tasks).doc(taskId);
    TaskModel? updated;
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final taskType = (data['taskType'] as String?) ?? 'standard';
      if (taskType != 'counter') return;

      final target = (data['targetCount'] as int?) ?? 0;
      final current = (data['currentCount'] as int?) ?? 0;
      if (current >= target) return;

      final next = current + 1;
      final newStatus = TaskModel.deriveCounterStatus(next, target);
      final completedAt = newStatus == 'completed' ? Timestamp.now() : null;
      final updatedAt = Timestamp.now();

      final updateFields = <String, dynamic>{
        'currentCount': next,
        FirebasePaths.status: newStatus,
        'completedAt': completedAt,
        'updatedAt': updatedAt,
        'updatedBy': currentUserId,
        'updatedByName': currentUserName,
      };

      txn.update(ref, updateFields);

      // Build the post-transaction TaskModel from the snap data merged with
      // the locked update fields. Returning it lets the cubit patch local
      // state directly without a follow-up read or a list refetch.
      updated = TaskModel.fromMap(snap.id, {...data, ...updateFields});
    });
    return updated;
  }

  Future<String> getUserNameById(String userId) async {
    final doc = await _firestore
        .collection(FirebasePaths.users)
        .doc(userId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return '-';
    }

    return doc.data()!['name'] as String? ?? '-';
  }

  Future<Map<String, String>> getTaskUserNames({
    required String assignedTo,
    required String assignedBy,
  }) async {
    final assignedToName = await getUserNameById(assignedTo);
    final assignedByName = await getUserNameById(assignedBy);

    return {'assignedToName': assignedToName, 'assignedByName': assignedByName};
  }

  Future<List<TaskLogModel>> getTaskLogs(String taskId) async {
    final snapshot = await _firestore
        .collection('task_logs')
        .where('taskId', isEqualTo: taskId)
        .orderBy('performedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TaskLogModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
