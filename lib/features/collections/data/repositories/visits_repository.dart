import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../models/visit_model.dart';

class VisitsRepository {
  final FirebaseFirestore _firestore;

  VisitsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> create(VisitModel visit) async {
    await _firestore
        .collection(FirebasePaths.visits)
        .add(visit.toCreateMap());
  }

  // forCollectorId must be provided for collector queries (Firestore rule requires
  // collectorId == uid on collection queries; admin can omit it).
  Future<List<VisitModel>> getByDebt(
    String debtId, {
    String? forCollectorId,
  }) async {
    var query = _firestore
        .collection(FirebasePaths.visits)
        .where('debtId', isEqualTo: debtId);
    if (forCollectorId != null) {
      query = query.where('collectorId', isEqualTo: forCollectorId);
    }
    final snap = await query.get(const GetOptions(source: Source.server));
    final list =
        snap.docs.map((d) => VisitModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return list;
  }

  Future<List<VisitModel>> getByCustomer(String customerId) async {
    final snap = await _firestore
        .collection(FirebasePaths.visits)
        .where('customerId', isEqualTo: customerId)
        .get(const GetOptions(source: Source.server));
    final list =
        snap.docs.map((d) => VisitModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return list;
  }
}
