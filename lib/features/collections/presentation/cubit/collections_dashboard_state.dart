import '../../data/models/debt_model.dart';
import 'customers_state.dart';

class CollectorSummary {
  final String id;
  final String name;
  final int assignedDebtsCount;
  final int collectedMtdAgorot;
  final int cashOnHandAgorot;
  final int pendingHandoversCount;

  const CollectorSummary({
    required this.id,
    required this.name,
    required this.assignedDebtsCount,
    required this.collectedMtdAgorot,
    required this.cashOnHandAgorot,
    required this.pendingHandoversCount,
  });
}

class CollectionsDashboardState {
  final CollectionsStatus status;
  final String? error;

  // Portfolio totals
  final int totalOutstandingAgorot;
  final int collectedTodayAgorot;
  final int collectedThisWeekAgorot;
  final int collectedThisMonthAgorot;
  final int totalCashWithCollectorsAgorot;
  final int overdueDebtCount;
  final int overdueDebtTotalAgorot;

  // Aging breakdown: bucket → total remaining balance
  final Map<String, int> agingTotals;
  final Map<String, int> agingCounts;

  // Per-collector summary
  final List<CollectorSummary> collectorSummaries;

  // All active/overdue debts (for aging report)
  final List<DebtModel> allActiveDebts;

  const CollectionsDashboardState({
    this.status = CollectionsStatus.initial,
    this.error,
    this.totalOutstandingAgorot = 0,
    this.collectedTodayAgorot = 0,
    this.collectedThisWeekAgorot = 0,
    this.collectedThisMonthAgorot = 0,
    this.totalCashWithCollectorsAgorot = 0,
    this.overdueDebtCount = 0,
    this.overdueDebtTotalAgorot = 0,
    this.agingTotals = const {},
    this.agingCounts = const {},
    this.collectorSummaries = const [],
    this.allActiveDebts = const [],
  });

  CollectionsDashboardState copyWith({
    CollectionsStatus? status,
    String? error,
    bool clearError = false,
    int? totalOutstandingAgorot,
    int? collectedTodayAgorot,
    int? collectedThisWeekAgorot,
    int? collectedThisMonthAgorot,
    int? totalCashWithCollectorsAgorot,
    int? overdueDebtCount,
    int? overdueDebtTotalAgorot,
    Map<String, int>? agingTotals,
    Map<String, int>? agingCounts,
    List<CollectorSummary>? collectorSummaries,
    List<DebtModel>? allActiveDebts,
  }) {
    return CollectionsDashboardState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      totalOutstandingAgorot:
          totalOutstandingAgorot ?? this.totalOutstandingAgorot,
      collectedTodayAgorot: collectedTodayAgorot ?? this.collectedTodayAgorot,
      collectedThisWeekAgorot:
          collectedThisWeekAgorot ?? this.collectedThisWeekAgorot,
      collectedThisMonthAgorot:
          collectedThisMonthAgorot ?? this.collectedThisMonthAgorot,
      totalCashWithCollectorsAgorot:
          totalCashWithCollectorsAgorot ?? this.totalCashWithCollectorsAgorot,
      overdueDebtCount: overdueDebtCount ?? this.overdueDebtCount,
      overdueDebtTotalAgorot:
          overdueDebtTotalAgorot ?? this.overdueDebtTotalAgorot,
      agingTotals: agingTotals ?? this.agingTotals,
      agingCounts: agingCounts ?? this.agingCounts,
      collectorSummaries: collectorSummaries ?? this.collectorSummaries,
      allActiveDebts: allActiveDebts ?? this.allActiveDebts,
    );
  }
}
