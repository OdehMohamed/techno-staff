import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import '../models/debt_model.dart';

class DebtsRepository {
  final FirebaseFirestore _firestore;

  DebtsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<DebtModel>> getByCustomer(String customerId) async {
    final snap = await _firestore
        .collection(FirebasePaths.debts)
        .where('customerId', isEqualTo: customerId)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs.map((d) => DebtModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<DebtModel>> getByCollector(String collectorId) async {
    final snap = await _firestore
        .collection(FirebasePaths.debts)
        .where('assignedCollectorId', isEqualTo: collectorId)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs.map((d) => DebtModel.fromMap(d.data(), d.id)).toList();
    // Collectors only see open debts, sorted by urgency then due date
    final open = list.where((d) => ['active', 'partial', 'overdue'].contains(d.status)).toList();
    const priority = {'overdue': 0, 'active': 1, 'partial': 2};
    open.sort((a, b) {
      final cmp = (priority[a.status] ?? 3).compareTo(priority[b.status] ?? 3);
      if (cmp != 0) return cmp;
      if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
      return 0;
    });
    return open;
  }

  Future<String> create(DebtModel debt) async {
    final ref = _firestore.collection(FirebasePaths.debts).doc();
    await ref.set(debt.toCreateMap());
    return ref.id;
  }

  Future<void> update(DebtModel debt) async {
    await _firestore
        .collection(FirebasePaths.debts)
        .doc(debt.id)
        .update(debt.toUpdateMap());
  }

  Future<void> updateStatus(
    String debtId,
    String status, {
    String? reason,
    int? settlementAmount,
    String? settlementNotes,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'cancelled') {
      data['isCancelled'] = true;
      data['cancelledAt'] = FieldValue.serverTimestamp();
      if (reason != null) data['cancellationReason'] = reason;
    }
    if (status == 'written_off' && reason != null) {
      data['writeOffReason'] = reason;
    }
    if (status == 'settled' && settlementAmount != null) {
      data['settlementAmount'] = settlementAmount;
      if (settlementNotes != null) data['settlementNotes'] = settlementNotes;
    }
    await _firestore.collection(FirebasePaths.debts).doc(debtId).update(data);
  }

  Future<void> markDisputed(
    String debtId, {
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    await _firestore.collection(FirebasePaths.debts).doc(debtId).update({
      'status': 'disputed',
      'dispute': {
        'reason': reason,
        'raisedBy': adminId,
        'raisedByName': adminName,
        'raisedAt': FieldValue.serverTimestamp(),
        'resolution': null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> writeOff(
    String debtId, {
    required String reason,
    required int remainingBalance,
    required String adminId,
    required String adminName,
  }) async {
    await _firestore.collection(FirebasePaths.debts).doc(debtId).update({
      'status': 'written_off',
      'remainingBalance': 0,
      'writeOff': {
        'amount': remainingBalance,
        'reason': reason,
        'authorizedBy': adminId,
        'authorizedByName': adminName,
        'at': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> settleForLess(
    String debtId, {
    required int settledAmount,
    required int originalBalance,
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    await _firestore.collection(FirebasePaths.debts).doc(debtId).update({
      'status': 'settled',
      'remainingBalance': 0,
      'settlementAmount': settledAmount,
      'settlementNotes': reason,
      'settlement': {
        'originalBalance': originalBalance,
        'settledAmount': settledAmount,
        'forgivenAmount': originalBalance - settledAmount,
        'reason': reason,
        'authorizedBy': adminId,
        'authorizedByName': adminName,
        'at': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
