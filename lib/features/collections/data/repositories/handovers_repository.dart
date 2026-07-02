import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/handover_model.dart';
import '../../../../core/constants/firebase_paths.dart';

class HandoversRepository {
  final FirebaseFirestore _firestore;

  HandoversRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collector: load own handovers sorted by newest first.
  Future<List<HandoverModel>> getByCollector(String collectorId) async {
    final snap = await _firestore
        .collection(FirebasePaths.handovers)
        .where('collectorId', isEqualTo: collectorId)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .map((d) => HandoverModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
    return list;
  }

  // Admin: load all handovers. Pending first, then newest.
  Future<List<HandoverModel>> getAll() async {
    final snap = await _firestore
        .collection(FirebasePaths.handovers)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .map((d) => HandoverModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) {
      // pending_verification always first
      if (a.isPending && !b.isPending) return -1;
      if (!a.isPending && b.isPending) return 1;
      return b.initiatedAt.compareTo(a.initiatedAt);
    });
    return list;
  }

  // Collector creates a handover. CF (onHandoverCreated) notifies admins.
  Future<void> create(HandoverModel handover) async {
    await _firestore
        .collection(FirebasePaths.handovers)
        .add(handover.toCreateMap());
  }

  // Admin verifies or records discrepancy.
  // CF (onHandoverUpdated) updates included payments and collector cashOnHand.
  Future<void> verify({
    required String handoverId,
    required HandoverModel handover,
    required int actualAmount,
    required String receivedBy,
    required String receivedByName,
    String? discrepancyNotes,
    String? notes,
  }) async {
    await _firestore
        .collection(FirebasePaths.handovers)
        .doc(handoverId)
        .update(handover.toVerifyMap(
          actualAmount: actualAmount,
          receivedBy: receivedBy,
          receivedByName: receivedByName,
          discrepancyNotes: discrepancyNotes,
          notes: notes,
        ));
  }
}
