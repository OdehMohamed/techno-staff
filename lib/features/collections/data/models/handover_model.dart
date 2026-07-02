import 'package:cloud_firestore/cloud_firestore.dart';

class HandoverModel {
  final String id;
  final String collectorId;
  final String collectorName;

  // Financial (agorot)
  final int claimedAmount;
  final int? actualAmount;

  final List<String> paymentIds;

  // Lifecycle: pending_verification | verified | discrepancy
  final String status;
  final DateTime initiatedAt;

  // Verification (admin fills these)
  final DateTime? verifiedAt;
  final String? receivedBy;
  final String? receivedByName;

  // Discrepancy: positive = excess received; negative = shortage
  final int? discrepancyAmount;
  final String? discrepancyNotes;

  final String? notes;

  bool get isPending => status == 'pending_verification';
  bool get isVerified => status == 'verified';
  bool get hasDiscrepancy => status == 'discrepancy';

  const HandoverModel({
    required this.id,
    required this.collectorId,
    required this.collectorName,
    required this.claimedAmount,
    this.actualAmount,
    required this.paymentIds,
    this.status = 'pending_verification',
    required this.initiatedAt,
    this.verifiedAt,
    this.receivedBy,
    this.receivedByName,
    this.discrepancyAmount,
    this.discrepancyNotes,
    this.notes,
  });

  factory HandoverModel.fromMap(Map<String, dynamic> map, String id) {
    return HandoverModel(
      id: id,
      collectorId: map['collectorId'] as String? ?? '',
      collectorName: map['collectorName'] as String? ?? '',
      claimedAmount: (map['claimedAmount'] as num?)?.toInt() ?? 0,
      actualAmount: (map['actualAmount'] as num?)?.toInt(),
      paymentIds: (map['paymentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: map['status'] as String? ?? 'pending_verification',
      initiatedAt:
          (map['initiatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      receivedBy: map['receivedBy'] as String?,
      receivedByName: map['receivedByName'] as String?,
      discrepancyAmount: (map['discrepancyAmount'] as num?)?.toInt(),
      discrepancyNotes: map['discrepancyNotes'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'collectorId': collectorId,
      'collectorName': collectorName,
      'claimedAmount': claimedAmount,
      'paymentIds': paymentIds,
      'status': 'pending_verification',
      'initiatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toVerifyMap({
    required int actualAmount,
    required String receivedBy,
    required String receivedByName,
    String? discrepancyNotes,
    String? notes,
  }) {
    final hasDiscrepancyLocal = actualAmount != claimedAmount;
    return {
      'actualAmount': actualAmount,
      'status': hasDiscrepancyLocal ? 'discrepancy' : 'verified',
      'verifiedAt': FieldValue.serverTimestamp(),
      'receivedBy': receivedBy,
      'receivedByName': receivedByName,
      if (hasDiscrepancyLocal) 'discrepancyAmount': actualAmount - claimedAmount,
      if (hasDiscrepancyLocal && discrepancyNotes != null)
        'discrepancyNotes': discrepancyNotes,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  HandoverModel copyWith({
    String? id,
    String? collectorId,
    String? collectorName,
    int? claimedAmount,
    int? actualAmount,
    bool clearActualAmount = false,
    List<String>? paymentIds,
    String? status,
    DateTime? initiatedAt,
    DateTime? verifiedAt,
    bool clearVerifiedAt = false,
    String? receivedBy,
    bool clearReceivedBy = false,
    String? receivedByName,
    bool clearReceivedByName = false,
    int? discrepancyAmount,
    bool clearDiscrepancyAmount = false,
    String? discrepancyNotes,
    bool clearDiscrepancyNotes = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return HandoverModel(
      id: id ?? this.id,
      collectorId: collectorId ?? this.collectorId,
      collectorName: collectorName ?? this.collectorName,
      claimedAmount: claimedAmount ?? this.claimedAmount,
      actualAmount: clearActualAmount ? null : (actualAmount ?? this.actualAmount),
      paymentIds: paymentIds ?? this.paymentIds,
      status: status ?? this.status,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      verifiedAt: clearVerifiedAt ? null : (verifiedAt ?? this.verifiedAt),
      receivedBy: clearReceivedBy ? null : (receivedBy ?? this.receivedBy),
      receivedByName: clearReceivedByName ? null : (receivedByName ?? this.receivedByName),
      discrepancyAmount: clearDiscrepancyAmount ? null : (discrepancyAmount ?? this.discrepancyAmount),
      discrepancyNotes: clearDiscrepancyNotes ? null : (discrepancyNotes ?? this.discrepancyNotes),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}
