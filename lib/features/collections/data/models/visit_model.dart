import 'package:cloud_firestore/cloud_firestore.dart';

class PtpData {
  final int amount; // agorot
  final DateTime promisedDate;
  final String status; // 'pending' | 'kept' | 'broken'

  const PtpData({
    required this.amount,
    required this.promisedDate,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';
  bool get isKept => status == 'kept';
  bool get isBroken => status == 'broken';

  factory PtpData.fromMap(Map<String, dynamic> map) {
    return PtpData(
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      promisedDate:
          (map['promisedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'promisedDate': Timestamp.fromDate(promisedDate),
      'status': status,
    };
  }
}

class VisitModel {
  final String id;
  final String customerId;
  final String customerName;
  final String? debtId;
  final String collectorId;
  final String collectorName;
  final DateTime visitedAt;
  final DateTime createdAt;
  final String contactType; // 'in_person' | 'phone'
  final String outcome;
  final String? paymentId;
  final PtpData? promiseToPay;
  final String? notes;

  const VisitModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.debtId,
    required this.collectorId,
    required this.collectorName,
    required this.visitedAt,
    required this.createdAt,
    required this.contactType,
    required this.outcome,
    this.paymentId,
    this.promiseToPay,
    this.notes,
  });

  bool get hasPtp => promiseToPay != null;

  factory VisitModel.fromMap(Map<String, dynamic> map, String id) {
    final ptpMap = map['promiseToPay'] as Map<String, dynamic>?;
    return VisitModel(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      debtId: map['debtId'] as String?,
      collectorId: map['collectorId'] as String? ?? '',
      collectorName: map['collectorName'] as String? ?? '',
      visitedAt:
          (map['visitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contactType: map['contactType'] as String? ?? 'in_person',
      outcome: map['outcome'] as String? ?? '',
      paymentId: map['paymentId'] as String?,
      promiseToPay: ptpMap != null ? PtpData.fromMap(ptpMap) : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      if (debtId != null) 'debtId': debtId,
      'collectorId': collectorId,
      'collectorName': collectorName,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'createdAt': FieldValue.serverTimestamp(),
      'contactType': contactType,
      'outcome': outcome,
      if (paymentId != null) 'paymentId': paymentId,
      if (promiseToPay != null) 'promiseToPay': promiseToPay!.toMap(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
