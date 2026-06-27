import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String debtId;
  final String customerId;
  final String customerName;
  final String? installmentPlanId;

  // Who physically collected vs. who tapped "save"
  final String collectorId;
  final String collectorName;
  final String recordedById;
  final String recordedByName;

  // Financial (agorot)
  final int amount;
  final String paymentMethod; // cash | check | bank_transfer
  final String? checkNumber;
  final String? bankReference;

  // Timestamps
  final DateTime collectedAt;
  final DateTime createdAt;

  // Receipt number — '' while CF is pending
  final String receiptNumber;

  // Lifecycle: pending_handover | handed_over | verified | cancelled | invalid
  final String status;
  final String? handoverId;

  final String? notes;

  // Cancellation (never deleted, only cancelled)
  final bool isCancelled;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  // Correction chain
  final bool isCorrection;
  final String? originalPaymentId;

  bool get isReceiptPending => receiptNumber.isEmpty;
  bool get isVerified => status == 'verified';
  bool get isCancelable => !isCancelled && status != 'verified' && status != 'invalid';

  const PaymentModel({
    required this.id,
    required this.debtId,
    required this.customerId,
    required this.customerName,
    this.installmentPlanId,
    required this.collectorId,
    required this.collectorName,
    required this.recordedById,
    required this.recordedByName,
    required this.amount,
    required this.paymentMethod,
    this.checkNumber,
    this.bankReference,
    required this.collectedAt,
    required this.createdAt,
    this.receiptNumber = '',
    this.status = 'pending_handover',
    this.handoverId,
    this.notes,
    this.isCancelled = false,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.isCorrection = false,
    this.originalPaymentId,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      debtId: map['debtId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      installmentPlanId: map['installmentPlanId'] as String?,
      collectorId: map['collectorId'] as String? ?? '',
      collectorName: map['collectorName'] as String? ?? '',
      recordedById: map['recordedById'] as String? ?? '',
      recordedByName: map['recordedByName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      checkNumber: map['checkNumber'] as String?,
      bankReference: map['bankReference'] as String?,
      collectedAt: (map['collectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receiptNumber: map['receiptNumber'] as String? ?? '',
      status: map['status'] as String? ?? 'pending_handover',
      handoverId: map['handoverId'] as String?,
      notes: map['notes'] as String?,
      isCancelled: map['isCancelled'] as bool? ?? false,
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      isCorrection: map['isCorrection'] as bool? ?? false,
      originalPaymentId: map['originalPaymentId'] as String?,
    );
  }

  // Client creates payment; CF fills receiptNumber, updates balances.
  Map<String, dynamic> toCreateMap() {
    return {
      'debtId': debtId,
      'customerId': customerId,
      'customerName': customerName,
      if (installmentPlanId != null) 'installmentPlanId': installmentPlanId,
      'collectorId': collectorId,
      'collectorName': collectorName,
      'recordedById': recordedById,
      'recordedByName': recordedByName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (checkNumber != null && checkNumber!.isNotEmpty) 'checkNumber': checkNumber,
      if (bankReference != null && bankReference!.isNotEmpty) 'bankReference': bankReference,
      'collectedAt': Timestamp.fromDate(collectedAt),
      'createdAt': FieldValue.serverTimestamp(),
      'receiptNumber': '',
      'status': 'pending_handover',
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'isCancelled': false,
      'isCorrection': false,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? debtId,
    String? customerId,
    String? customerName,
    String? installmentPlanId,
    bool clearInstallmentPlanId = false,
    String? collectorId,
    String? collectorName,
    String? recordedById,
    String? recordedByName,
    int? amount,
    String? paymentMethod,
    String? checkNumber,
    bool clearCheckNumber = false,
    String? bankReference,
    bool clearBankReference = false,
    DateTime? collectedAt,
    DateTime? createdAt,
    String? receiptNumber,
    String? status,
    String? handoverId,
    bool clearHandoverId = false,
    String? notes,
    bool clearNotes = false,
    bool? isCancelled,
    String? cancellationReason,
    bool clearCancellationReason = false,
    String? cancelledBy,
    bool clearCancelledBy = false,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
    bool? isCorrection,
    String? originalPaymentId,
    bool clearOriginalPaymentId = false,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      installmentPlanId: clearInstallmentPlanId ? null : (installmentPlanId ?? this.installmentPlanId),
      collectorId: collectorId ?? this.collectorId,
      collectorName: collectorName ?? this.collectorName,
      recordedById: recordedById ?? this.recordedById,
      recordedByName: recordedByName ?? this.recordedByName,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      checkNumber: clearCheckNumber ? null : (checkNumber ?? this.checkNumber),
      bankReference: clearBankReference ? null : (bankReference ?? this.bankReference),
      collectedAt: collectedAt ?? this.collectedAt,
      createdAt: createdAt ?? this.createdAt,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      status: status ?? this.status,
      handoverId: clearHandoverId ? null : (handoverId ?? this.handoverId),
      notes: clearNotes ? null : (notes ?? this.notes),
      isCancelled: isCancelled ?? this.isCancelled,
      cancellationReason: clearCancellationReason ? null : (cancellationReason ?? this.cancellationReason),
      cancelledBy: clearCancelledBy ? null : (cancelledBy ?? this.cancelledBy),
      cancelledAt: clearCancelledAt ? null : (cancelledAt ?? this.cancelledAt),
      isCorrection: isCorrection ?? this.isCorrection,
      originalPaymentId: clearOriginalPaymentId ? null : (originalPaymentId ?? this.originalPaymentId),
    );
  }
}
