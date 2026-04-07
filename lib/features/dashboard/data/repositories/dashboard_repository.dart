import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_paths.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore;

  DashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, int>> getAdminStats() async {
    final usersSnapshot = await _firestore
        .collection(FirebasePaths.users)
        .get();

    final tasksSnapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .get();

    final employeesCount = usersSnapshot.docs
        .where((doc) => doc.data()['role'] == 'employee')
        .length;

    final totalTasks = tasksSnapshot.docs.length;

    final completedTasks = tasksSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    final overdueTasks = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      final status = data['status'];
      final dueDate = data['dueDate'];

      if (status == 'completed' || dueDate == null) return false;

      final due = (dueDate as Timestamp).toDate();
      return due.isBefore(DateTime.now());
    }).length;

    return {
      'employeesCount': employeesCount,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
    };
  }

  Future<Map<String, int>> getEmployeeStats(String userId) async {
    final tasksSnapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedTo, isEqualTo: userId)
        .get();

    final totalTasks = tasksSnapshot.docs.length;

    final completedTasks = tasksSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    final inProgressTasks = tasksSnapshot.docs
        .where((doc) => doc.data()['status'] == 'in_progress')
        .length;

    final pendingTasks = tasksSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'inProgressTasks': inProgressTasks,
      'pendingTasks': pendingTasks,
    };
  }
}
