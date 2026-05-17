import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../models/work_schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore;

  ScheduleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<WorkScheduleModel?> fetchSchedule(String userId) async {
    final doc = await _firestore
        .collection(FirebasePaths.schedules)
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) return null;
    return WorkScheduleModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<WorkScheduleModel>> fetchAllSchedules() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.schedules)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => WorkScheduleModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> saveSchedule(
    WorkScheduleModel schedule, {
    required String updatedBy,
    required String updatedByName,
  }) async {
    await _firestore
        .collection(FirebasePaths.schedules)
        .doc(schedule.userId)
        .set(schedule.toMap(updatedBy: updatedBy, updatedByName: updatedByName));
  }
}
