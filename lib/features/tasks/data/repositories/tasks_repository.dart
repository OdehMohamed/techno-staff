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
