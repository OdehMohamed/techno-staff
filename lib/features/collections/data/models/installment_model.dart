import 'package:cloud_firestore/cloud_firestore.dart';

class InstallmentModel {
  final String id; // zero-padded installment number: '001', '002', …
  final int number; // 1-indexed
  final DateTime dueDate;
  final int expectedAmount; // agorot
  final int paidAmount; // agorot; CF-maintained
  final String status; // 'pending' | 'partial' | 'paid' | 'overdue'
  final List<String> paymentIds;
  final DateTime? paidAt;

  const InstallmentModel({
    required this.id,
    required this.number,
    required this.dueDate,
    required this.expectedAmount,
    this.paidAmount = 0,
    this.status = 'pending',
    this.paymentIds = const [],
    this.paidAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPartial => status == 'partial';
  bool get isOverdue => status == 'overdue';
  bool get isPending => status == 'pending';

  factory InstallmentModel.fromMap(Map<String, dynamic> map, String id) {
    return InstallmentModel(
      id: id,
      number: (map['number'] as num?)?.toInt() ?? 0,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expectedAmount: (map['expectedAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'pending',
      paymentIds: (map['paymentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
    );
  }
}
