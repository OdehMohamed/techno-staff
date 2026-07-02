import 'package:cloud_firestore/cloud_firestore.dart';

class InstallmentPlanModel {
  final String id;
  final String debtId;
  final String customerId;
  final int totalInstallments;
  final int installmentAmount; // agorot; last installment may differ to absorb rounding
  final String frequency; // 'weekly' | 'biweekly' | 'monthly'
  final DateTime startDate;
  final String createdBy;
  final DateTime createdAt;

  const InstallmentPlanModel({
    required this.id,
    required this.debtId,
    required this.customerId,
    required this.totalInstallments,
    required this.installmentAmount,
    required this.frequency,
    required this.startDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory InstallmentPlanModel.fromMap(Map<String, dynamic> map, String id) {
    return InstallmentPlanModel(
      id: id,
      debtId: map['debtId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 0,
      installmentAmount: (map['installmentAmount'] as num?)?.toInt() ?? 0,
      frequency: map['frequency'] as String? ?? 'monthly',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'debtId': debtId,
      'customerId': customerId,
      'totalInstallments': totalInstallments,
      'installmentAmount': installmentAmount,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
