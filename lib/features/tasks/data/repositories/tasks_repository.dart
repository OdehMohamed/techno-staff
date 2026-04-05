import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import '../models/task_model.dart';

class TasksRepository {
  final FirebaseFirestore _firestore;

  TasksRepository(this._firestore);

  Future<void> createTask(TaskModel task) async {
    await _firestore.collection(FirebasePaths.tasks).add(task.toMap());
  }

  Future<List<TaskModel>> getTasksForUser(String userId) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedTo, isEqualTo: userId)
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
  }) async {
    await _firestore.collection(FirebasePaths.tasks).doc(taskId).update({
      FirebasePaths.status: status,
    });
  }
}
