import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/features/dashboard/presentation/cubit/dashboard_state.dart';
import '../../../../core/constants/firebase_paths.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore;

  DashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  Future<Map<String, int>> getAdminStats({
    required DashboardFilter filter,
  }) async {
    DateTime now = DateTime.now();

    DateTime start;

    switch (filter) {
      case DashboardFilter.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DashboardFilter.week:
        start = now.subtract(const Duration(days: 7));
        break;
      case DashboardFilter.month:
        start = DateTime(now.year, now.month, 1);
        break;
    }
    final usersSnapshot = await _firestore
        .collection(FirebasePaths.users)
        .get();

    final tasksSnapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(
          FirebasePaths.createdAt,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .get();

    final employeesCount = usersSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.role] == 'employee')
        .length;

    final totalTasks = tasksSnapshot.docs.length;

    final completedTasks = tasksSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.status] == 'completed')
        .length;

    final inProgressTasks = tasksSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.status] == 'in_progress')
        .length;

    final pendingTasks = tasksSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.status] == 'pending')
        .length;

    final completedOnTime = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data[FirebasePaths.status] != 'completed' ||
          data['completedAt'] == null ||
          data[FirebasePaths.dueDate] == null) {
        return false;
      }

      final completedAt = (data['completedAt'] as Timestamp).toDate();
      final dueDate = (data[FirebasePaths.dueDate] as Timestamp).toDate();

      return !completedAt.isAfter(_endOfDay(dueDate));
    }).length;

    final completedLate = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data[FirebasePaths.status] != 'completed' ||
          data['completedAt'] == null ||
          data[FirebasePaths.dueDate] == null) {
        return false;
      }

      final completedAt = (data['completedAt'] as Timestamp).toDate();
      final dueDate = (data[FirebasePaths.dueDate] as Timestamp).toDate();

      return completedAt.isAfter(_endOfDay(dueDate));
    }).length;

    final overdueOpenTasks = tasksSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data[FirebasePaths.status] == 'completed' ||
          data[FirebasePaths.dueDate] == null) {
        return false;
      }

      final dueDate = (data[FirebasePaths.dueDate] as Timestamp).toDate();
      return DateTime.now().isAfter(_endOfDay(dueDate));
    }).length;

    return {
      'employeesCount': employeesCount,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'inProgressTasks': inProgressTasks,
      'pendingTasks': pendingTasks,
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
        .where((doc) => doc.data()[FirebasePaths.status] == 'completed')
        .length;

    final inProgressTasks = tasksSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.status] == 'in_progress')
        .length;

    final pendingTasks = tasksSnapshot.docs
        .where((doc) => doc.data()[FirebasePaths.status] == 'pending')
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

      final userName = data['assignedToName'];

      if (userName == null || userName.toString().trim().isEmpty) {
        continue;
      }

      if (data[FirebasePaths.status] == 'completed') {
        completedCount[userName] = (completedCount[userName] ?? 0) + 1;
      }

      if (data[FirebasePaths.status] == 'pending' ||
          data[FirebasePaths.status] == 'in_progress') {
        activeCount[userName] = (activeCount[userName] ?? 0) + 1;
      }
    }

    String topPerformer = '-';
    int topCompleted = 0;

    completedCount.forEach((name, count) {
      if (count > topCompleted) {
        topCompleted = count;
        topPerformer = name;
      }
    });

    String mostActive = '-';
    int topActive = 0;

    activeCount.forEach((name, count) {
      if (count > topActive) {
        topActive = count;
        mostActive = name;
      }
    });

    return {
      'topPerformer': topPerformer,
      'topCompleted': topCompleted,
      'mostActive': mostActive,
      'topActive': topActive,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentActivities() async {
    final snapshot = await _firestore
        .collection('task_logs')
        .orderBy('performedAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'action': data['action'] ?? '',
        'taskTitle': data['taskTitle'] ?? '',
        'performedByName': data['performedByName'] ?? '',
        'performedAt': data['performedAt'],
        'previousStatus': data['previousStatus'],
        'newStatus': data['newStatus'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTasksTrend() async {
    final snapshot = await _firestore.collection(FirebasePaths.tasks).get();

    final Map<String, int> createdPerDay = {};
    final Map<String, int> completedPerDay = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Created
      if (data[FirebasePaths.createdAt] != null) {
        final createdDate = (data[FirebasePaths.createdAt] as Timestamp)
            .toDate();

        final key =
            "${createdDate.year}-${createdDate.month}-${createdDate.day}";

        createdPerDay[key] = (createdPerDay[key] ?? 0) + 1;
      }

      // Completed
      if (data['completedAt'] != null) {
        final completedDate = (data['completedAt'] as Timestamp).toDate();

        final key =
            "${completedDate.year}-${completedDate.month}-${completedDate.day}";

        completedPerDay[key] = (completedPerDay[key] ?? 0) + 1;
      }
    }

    final List<Map<String, dynamic>> result = [];

    final allKeys = {...createdPerDay.keys, ...completedPerDay.keys}.toList()
      ..sort();

    for (final key in allKeys) {
      result.add({
        'date': key,
        'created': createdPerDay[key] ?? 0,
        'completed': completedPerDay[key] ?? 0,
      });
    }

    return result;
  }
}
