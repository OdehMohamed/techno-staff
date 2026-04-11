import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_paths.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore;

  DashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

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

    final completedOnTime = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data['status'] != 'completed' ||
          data['completedAt'] == null ||
          data['dueDate'] == null) {
        return false;
      }

      final completedAt = (data['completedAt'] as Timestamp).toDate();
      final dueDate = (data['dueDate'] as Timestamp).toDate();

      return !completedAt.isAfter(_endOfDay(dueDate));
    }).length;

    final completedLate = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data['status'] != 'completed' ||
          data['completedAt'] == null ||
          data['dueDate'] == null) {
        return false;
      }

      final completedAt = (data['completedAt'] as Timestamp).toDate();
      final dueDate = (data['dueDate'] as Timestamp).toDate();

      return completedAt.isAfter(_endOfDay(dueDate));
    }).length;

    final overdueOpenTasks = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data['status'] == 'completed' || data['dueDate'] == null) {
        return false;
      }

      final dueDate = (data['dueDate'] as Timestamp).toDate();
      return DateTime.now().isAfter(_endOfDay(dueDate));
    }).length;

    return {
      'employeesCount': employeesCount,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completedOnTime': completedOnTime,
      'completedLate': completedLate,
      'overdueOpenTasks': overdueOpenTasks,
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

  Future<Map<String, dynamic>> getTopPerformer() async {
    final tasksSnapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .get();

    final Map<String, int> completedCount = {};
    final Map<String, int> activeCount = {};

    for (final doc in tasksSnapshot.docs) {
      final data = doc.data();

      final userId = data['assignedTo'];
      final userName = data['assignedToName'];

      if (userId == null || userName == null) continue;

      // Completed tasks
      if (data['status'] == 'completed') {
        completedCount[userName] = (completedCount[userName] ?? 0) + 1;
      }

      // Active tasks
      if (data['status'] == 'pending' || data['status'] == 'in_progress') {
        activeCount[userName] = (activeCount[userName] ?? 0) + 1;
      }
    }

    String? topPerformer;
    int topCompleted = 0;

    completedCount.forEach((name, count) {
      if (count > topCompleted) {
        topCompleted = count;
        topPerformer = name;
      }
    });

    String? mostActive;
    int topActive = 0;

    activeCount.forEach((name, count) {
      if (count > topActive) {
        topActive = count;
        mostActive = name;
      }
    });

    return {
      'topPerformer': topPerformer ?? '-',
      'topCompleted': topCompleted,
      'mostActive': mostActive ?? '-',
      'topActive': topActive,
    };
  }
}
