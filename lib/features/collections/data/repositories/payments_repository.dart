import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../../../../core/constants/firebase_paths.dart';

class PaymentsRepository {
  final FirebaseFirestore _firestore;

  PaymentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Real-time stream of payments for a specific debt.
  // Automatically pushes updates (e.g. CF writing receiptNumber) without a manual reload.
  // Collectors must pass their own uid — Firestore rules require collectorId constraint.
  Stream<List<PaymentModel>> streamByDebt(
    String debtId, {
    String? forCollectorId,
  }) {
    var query = _firestore
        .collection(FirebasePaths.payments)
        .where('debtId', isEqualTo: debtId);
    if (forCollectorId != null) {
      query = query.where('collectorId', isEqualTo: forCollectorId);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PaymentModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
      return list;
    });
  }

  // Load collector's pending_handover payments (for cash on hand + handover init).
  // Uses composite index: collectorId + status.
  Future<List<PaymentModel>> getCollectorPending(String collectorId) async {
    final snap = await _firestore
        .collection(FirebasePaths.payments)
        .where('collectorId', isEqualTo: collectorId)
        .where('status', isEqualTo: 'pending_handover')
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .map((d) => PaymentModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    return list;
  }

  // Create a payment using a client-generated ID for offline idempotency.
  // CF (onPaymentCreated) fills receiptNumber and updates debt/collector balances.
  Future<void> create(PaymentModel payment) async {
    final docId = _firestore.collection(FirebasePaths.payments).doc().id;
    await _firestore
        .collection(FirebasePaths.payments)
        .doc(docId)
        .set(payment.toCreateMap());
  }

  // Fetch a single payment by document ID (used by PaymentDetailLoaderScreen).
  Future<PaymentModel?> getById(String paymentId) async {
    final snap = await _firestore
        .collection(FirebasePaths.payments)
        .doc(paymentId)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;
    return PaymentModel.fromMap(snap.data()!, snap.id);
  }

  // Fetch payments by a list of IDs (used for handover reconciliation PDF).
  // Firestore has no "get by ids" query; uses parallel document reads.
  Future<List<PaymentModel>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snapshots = await Future.wait(
      ids.map((id) => _firestore
          .collection(FirebasePaths.payments)
          .doc(id)
          .get(const GetOptions(source: Source.server))),
    );
    return snapshots
        .where((s) => s.exists)
        .map((s) => PaymentModel.fromMap(s.data()!, s.id))
        .toList();
  }

  // Admin cancels a payment. CF (onPaymentCancelled) reverses debt balances.
  // Blocked by CF if the payment is part of a verified handover.
  Future<void> cancel({
    required String paymentId,
    required String reason,
    required String cancelledBy,
  }) async {
    await _firestore.collection(FirebasePaths.payments).doc(paymentId).update({
      'isCancelled': true,
      'cancellationReason': reason,
      'cancelledBy': cancelledBy,
      'cancelledAt': FieldValue.serverTimestamp(),
      'status': 'cancelled',
    });
  }
}
