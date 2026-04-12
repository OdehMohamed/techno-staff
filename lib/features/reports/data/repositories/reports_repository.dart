import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../tasks/data/models/task_model.dart';

class ReportsRepository {
  final FirebaseFirestore _firestore;

  ReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<AppUser>> getEmployees() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.users)
        .where('role', isEqualTo: 'employee')
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<TaskModel>> getTasksForEmployeeByMonth({
    required String employeeId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    debugPrint('REPORT EMPLOYEE ID: $employeeId');
    debugPrint('REPORT START: $start');
    debugPrint('REPORT END: $end');

    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedTo, isEqualTo: employeeId)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();

    debugPrint('REPORT TASKS COUNT: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dueDate = data['dueDate'];
      debugPrint('TASK DOC ID: ${doc.id}');
      debugPrint('TASK ASSIGNED TO: ${data['assignedTo']}');
      debugPrint('TASK DUE DATE: $dueDate');
    }

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
