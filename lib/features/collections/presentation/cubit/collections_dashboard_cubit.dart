import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/debt_model.dart';
import 'collections_dashboard_state.dart';
import 'customers_state.dart';

class CollectionsDashboardCubit extends Cubit<CollectionsDashboardState> {
  final FirebaseFirestore _firestore;

  CollectionsDashboardCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const CollectionsDashboardState());

  Future<void> load() async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearError: true,
      allActiveDebts: [],
    ));

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart =
          todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // 1. Active debts (for outstanding + aging)
      final debtSnap = await _firestore
          .collection('debts')
          .where('status', whereIn: ['active', 'partial', 'overdue'])
          .get(const GetOptions(source: Source.server));

      final debts = debtSnap.docs
          .map((d) => DebtModel.fromMap(d.data(), d.id))
          .toList();

      int totalOutstanding = 0;
      int overdueCount = 0;
      int overdueTotal = 0;
      final agingTotals = <String, int>{};
      final agingCounts = <String, int>{};

      for (final d in debts) {
        totalOutstanding += d.remainingBalance;
        if (d.status == 'overdue') {
          overdueCount++;
          overdueTotal += d.remainingBalance;
        }
        agingTotals[d.agingBucket] =
            (agingTotals[d.agingBucket] ?? 0) + d.remainingBalance;
        agingCounts[d.agingBucket] =
            (agingCounts[d.agingBucket] ?? 0) + 1;
      }

      // 2. Payments — three date-range queries run in parallel
      final futures = await Future.wait([
        _firestore
            .collection('payments')
            .where('collectedAt',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(todayStart))
            .where('isCancelled', isEqualTo: false)
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('payments')
            .where('collectedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('isCancelled', isEqualTo: false)
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('payments')
            .where('collectedAt',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(monthStart))
            .where('isCancelled', isEqualTo: false)
            .get(const GetOptions(source: Source.server)),
        // 3. Collectors (for cash on hand + per-collector summary)
        _firestore
            .collection('users')
            .where('role', isEqualTo: 'collector')
            .where('isActive', isEqualTo: true)
            .get(const GetOptions(source: Source.server)),
      ]);

      final todaySnap = futures[0];
      final weekSnap = futures[1];
      final monthSnap = futures[2];
      final collectorsSnap = futures[3];

      int collectedToday = 0;
      for (final d in todaySnap.docs) {
        collectedToday += ((d.data()['amount'] as num?)?.toInt() ?? 0);
      }

      int collectedWeek = 0;
      for (final d in weekSnap.docs) {
        collectedWeek += ((d.data()['amount'] as num?)?.toInt() ?? 0);
      }

      // Build month-level per-collector map at the same time
      final collectorMtd = <String, int>{}; // collectorId → agorot
      int collectedMonth = 0;
      for (final d in monthSnap.docs) {
        final data = d.data();
        final amt = (data['amount'] as num?)?.toInt() ?? 0;
        collectedMonth += amt;
        final cid = data['collectorId'] as String? ?? '';
        if (cid.isNotEmpty) {
          collectorMtd[cid] = (collectorMtd[cid] ?? 0) + amt;
        }
      }

      // 4. Per-collector summary
      int totalCash = 0;
      final summaries = <CollectorSummary>[];

      for (final doc in collectorsSnap.docs) {
        final data = doc.data();
        final cashOnHand = (data['cashOnHand'] as num?)?.toInt() ?? 0;
        totalCash += cashOnHand;

        final assignedCount = debts
            .where((d) => d.assignedCollectorId == doc.id)
            .length;

        summaries.add(CollectorSummary(
          id: doc.id,
          name: data['name'] as String? ?? '',
          assignedDebtsCount: assignedCount,
          collectedMtdAgorot: collectorMtd[doc.id] ?? 0,
          cashOnHandAgorot: cashOnHand,
          pendingHandoversCount: 0, // omitted to avoid extra queries
        ));
      }

      summaries.sort(
          (a, b) => b.collectedMtdAgorot.compareTo(a.collectedMtdAgorot));

      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        totalOutstandingAgorot: totalOutstanding,
        collectedTodayAgorot: collectedToday,
        collectedThisWeekAgorot: collectedWeek,
        collectedThisMonthAgorot: collectedMonth,
        totalCashWithCollectorsAgorot: totalCash,
        overdueDebtCount: overdueCount,
        overdueDebtTotalAgorot: overdueTotal,
        agingTotals: agingTotals,
        agingCounts: agingCounts,
        collectorSummaries: summaries,
        allActiveDebts: debts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_dashboard',
        allActiveDebts: [],
      ));
    }
  }
}
