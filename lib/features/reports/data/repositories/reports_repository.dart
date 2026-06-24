import 'package:cloud_firestore/cloud_firestore.dart';
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
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<TaskModel>> getTasksForEmployee({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.tasks)
        .where(FirebasePaths.assignedTo, isEqualTo: employeeId)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('dueDate', isLessThan: Timestamp.fromDate(endDate))
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
