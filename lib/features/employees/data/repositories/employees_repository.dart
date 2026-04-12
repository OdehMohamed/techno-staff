import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import '../../../auth/domain/models/app_user.dart';

class EmployeesRepository {
  final FirebaseFirestore _firestore;

  EmployeesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<AppUser>> getEmployees() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.users)
        .orderBy(FirebasePaths.createdAt, descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addEmployee(AppUser user) async {
    await _firestore
        .collection(FirebasePaths.users)
        .doc(user.id)
        .set(user.toMap());
  }

  Future<void> updateEmployeeStatus({
    required String userId,
    required bool isActive,
  }) async {
    await _firestore.collection(FirebasePaths.users).doc(userId).update({
      'isActive': isActive,
    });
  }
}
