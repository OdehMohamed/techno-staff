import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../../../../core/constants/firebase_paths.dart';

class PaymentsRepository {
  final FirebaseFirestore _firestore;

  PaymentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Load all payments for a specific debt (admin + collector viewing debt detail).
  // No orderBy to avoid missing index. Sorted client-side by collectedAt desc.
  Future<List<PaymentModel>> getByDebt(String debtId) async {
    final snap = await _firestore
        .collection(FirebasePaths.payments)
        .where('debtId', isEqualTo: debtId)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .map((d) => PaymentModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    return list;
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
