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
  final String? disputeReason;
  final int? settlementAmount; // agorot — what was collected
  final int? forgivenAmount;  // agorot — original remaining minus settled
  final String? settlementNotes;
  // Installment plan (CF-maintained after plan creation)
  final bool hasInstallmentPlan;
  final String? installmentPlanId;
  final DateTime? nextInstallmentDueDate;
  // Aging (CF-maintained daily by updateDebtAgingBuckets cron)
  final int daysPastDue;
  final String agingBucket; // 'current' | '1-30' | '31-60' | '61-90' | '90+'
  final DateTime? lastOverdueEscalationAt;
  final DateTime? settledAt;
  final bool hasPendingSettlementRequest;
  final int? pendingSettlementAmount;
  final String? pendingSettlementReason;
  final String? pendingSettlementRequestedByName;
  final DateTime? pendingSettlementRequestedAt;

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
    this.disputeReason,
    this.settlementAmount,
    this.forgivenAmount,
    this.settlementNotes,
    this.hasInstallmentPlan = false,
    this.installmentPlanId,
    this.nextInstallmentDueDate,
    this.daysPastDue = 0,
    this.agingBucket = 'current',
    this.lastOverdueEscalationAt,
    this.settledAt,
    this.hasPendingSettlementRequest = false,
    this.pendingSettlementAmount,
    this.pendingSettlementReason,
    this.pendingSettlementRequestedByName,
    this.pendingSettlementRequestedAt,
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
      writeOffReason: (map['writeOffReason'] as String?) ??
          ((map['writeOff'] is Map)
              ? (map['writeOff'] as Map)['reason'] as String?
              : null),
      disputeReason: (map['dispute'] is Map)
          ? (map['dispute'] as Map)['reason'] as String?
          : null,
      settlementAmount: (map['settlementAmount'] as num?)?.toInt(),
      forgivenAmount: (map['settlement'] is Map)
          ? ((map['settlement'] as Map)['forgivenAmount'] as num?)?.toInt()
          : null,
      settlementNotes: map['settlementNotes'] as String?,
      hasInstallmentPlan: map['hasInstallmentPlan'] as bool? ?? false,
      installmentPlanId: map['installmentPlanId'] as String?,
      nextInstallmentDueDate: (map['nextInstallmentDueDate'] as Timestamp?)?.toDate(),
      daysPastDue: (map['daysPastDue'] as num?)?.toInt() ?? 0,
      agingBucket: map['agingBucket'] as String? ?? 'current',
      lastOverdueEscalationAt:
          (map['lastOverdueEscalationAt'] as Timestamp?)?.toDate(),
      settledAt: (map['settledAt'] as Timestamp?)?.toDate(),
      hasPendingSettlementRequest:
          map['hasPendingSettlementRequest'] as bool? ?? false,
      pendingSettlementAmount: (map['settlementRequest'] is Map)
          ? ((map['settlementRequest'] as Map)['requestedAmount'] as num?)
              ?.toInt()
          : null,
      pendingSettlementReason: (map['settlementRequest'] is Map)
          ? (map['settlementRequest'] as Map)['reason'] as String?
          : null,
      pendingSettlementRequestedByName: (map['settlementRequest'] is Map)
          ? (map['settlementRequest'] as Map)['requestedByName'] as String?
          : null,
      pendingSettlementRequestedAt: (map['settlementRequest'] is Map)
          ? ((map['settlementRequest'] as Map)['requestedAt'] as Timestamp?)
              ?.toDate()
          : null,
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
    String? disputeReason,
    int? settlementAmount,
    int? forgivenAmount,
    String? settlementNotes,
    bool? hasInstallmentPlan,
    String? installmentPlanId,
    bool clearInstallmentPlanId = false,
    DateTime? nextInstallmentDueDate,
    int? daysPastDue,
    String? agingBucket,
    DateTime? lastOverdueEscalationAt,
    DateTime? settledAt,
    bool? hasPendingSettlementRequest,
    int? pendingSettlementAmount,
    String? pendingSettlementReason,
    String? pendingSettlementRequestedByName,
    DateTime? pendingSettlementRequestedAt,
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
      disputeReason: disputeReason ?? this.disputeReason,
      settlementAmount: settlementAmount ?? this.settlementAmount,
      forgivenAmount: forgivenAmount ?? this.forgivenAmount,
      settlementNotes: settlementNotes ?? this.settlementNotes,
      hasInstallmentPlan: hasInstallmentPlan ?? this.hasInstallmentPlan,
      installmentPlanId: clearInstallmentPlanId ? null : (installmentPlanId ?? this.installmentPlanId),
      nextInstallmentDueDate: nextInstallmentDueDate ?? this.nextInstallmentDueDate,
      daysPastDue: daysPastDue ?? this.daysPastDue,
      agingBucket: agingBucket ?? this.agingBucket,
      lastOverdueEscalationAt: lastOverdueEscalationAt ?? this.lastOverdueEscalationAt,
      settledAt: settledAt ?? this.settledAt,
      hasPendingSettlementRequest:
          hasPendingSettlementRequest ?? this.hasPendingSettlementRequest,
      pendingSettlementAmount: pendingSettlementAmount ?? this.pendingSettlementAmount,
      pendingSettlementReason: pendingSettlementReason ?? this.pendingSettlementReason,
      pendingSettlementRequestedByName:
          pendingSettlementRequestedByName ?? this.pendingSettlementRequestedByName,
      pendingSettlementRequestedAt:
          pendingSettlementRequestedAt ?? this.pendingSettlementRequestedAt,
    );
  }
}
