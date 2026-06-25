import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String id;
  final String customerId;
  final String customerName;
  // All monetary values are in agorot (integer). 1 ILS = 100 agorot.
  final int originalAmount;
  final int paidAmount;       // CF-maintained after payments
  final int remainingBalance; // CF-maintained after payments
  final String status; // active | partial | settled | overdue | written_off | disputed | cancelled
  final String assignedCollectorId;
  final String assignedCollectorName;
  final DateTime? dueDate;
  final String? description;
  final String? notes;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? writeOffReason;
  final int? settlementAmount; // agorot
  final String? settlementNotes;

  const DebtModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.originalAmount,
    this.paidAmount = 0,
    required this.remainingBalance,
    this.status = 'active',
    required this.assignedCollectorId,
    required this.assignedCollectorName,
    this.dueDate,
    this.description,
    this.notes,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancellationReason,
    this.writeOffReason,
    this.settlementAmount,
    this.settlementNotes,
  });

  static String formatAmountIls(int agorot) {
    final ils = agorot / 100;
    return '₪${ils.toStringAsFixed(2)}';
  }

  static int parseAmountIls(String text) {
    final sanitized = text.replaceAll(',', '').trim();
    final value = double.tryParse(sanitized) ?? 0.0;
    return (value * 100).round();
  }

  factory DebtModel.fromMap(Map<String, dynamic> map, String id) {
    return DebtModel(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      originalAmount: (map['originalAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toInt() ?? 0,
      remainingBalance: (map['remainingBalance'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'active',
      assignedCollectorId: map['assignedCollectorId'] as String? ?? '',
      assignedCollectorName: map['assignedCollectorName'] as String? ?? '',
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCancelled: map['isCancelled'] as bool? ?? false,
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: map['cancellationReason'] as String?,
      writeOffReason: map['writeOffReason'] as String?,
      settlementAmount: (map['settlementAmount'] as num?)?.toInt(),
      settlementNotes: map['settlementNotes'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'originalAmount': originalAmount,
      'paidAmount': 0,
      'remainingBalance': originalAmount,
      'status': 'active',
      'assignedCollectorId': assignedCollectorId,
      'assignedCollectorName': assignedCollectorName,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      if (description != null && description!.isNotEmpty) 'description': description,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'isCancelled': false,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'assignedCollectorId': assignedCollectorId,
      'assignedCollectorName': assignedCollectorName,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'description': (description?.isNotEmpty == true) ? description : null,
      'notes': (notes?.isNotEmpty == true) ? notes : null,
    };
  }

  DebtModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    int? originalAmount,
    int? paidAmount,
    int? remainingBalance,
    String? status,
    String? assignedCollectorId,
    String? assignedCollectorName,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? description,
    String? notes,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? writeOffReason,
    int? settlementAmount,
    String? settlementNotes,
  }) {
    return DebtModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      originalAmount: originalAmount ?? this.originalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      assignedCollectorId: assignedCollectorId ?? this.assignedCollectorId,
      assignedCollectorName: assignedCollectorName ?? this.assignedCollectorName,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      description: description ?? this.description,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      writeOffReason: writeOffReason ?? this.writeOffReason,
      settlementAmount: settlementAmount ?? this.settlementAmount,
      settlementNotes: settlementNotes ?? this.settlementNotes,
    );
  }
}
