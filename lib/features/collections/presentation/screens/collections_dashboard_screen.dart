import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/debt_model.dart';
import '../cubit/collections_dashboard_cubit.dart';
import '../cubit/collections_dashboard_state.dart';
import '../cubit/customers_state.dart';

class CollectionsDashboardScreen extends StatefulWidget {
  const CollectionsDashboardScreen({super.key});

  @override
  State<CollectionsDashboardScreen> createState() =>
      _CollectionsDashboardScreenState();
}

class _CollectionsDashboardScreenState
    extends State<CollectionsDashboardScreen> {
  static const _bucketOrder = ['90+', '61-90', '31-60', '1-30', 'current'];

  @override
  void initState() {
    super.initState();
    context.read<CollectionsDashboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('collections_dashboard'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CollectionsDashboardCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<CollectionsDashboardCubit, CollectionsDashboardState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading ||
              state.status == CollectionsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CollectionsStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error?.tr() ?? 'error'.tr()),
                  const SizedBox(height: AppSizes.md),
                  FilledButton(
                    onPressed: () =>
                        context.read<CollectionsDashboardCubit>().load(),
                    child: Text('retry'.tr()),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                context.read<CollectionsDashboardCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                // Portfolio totals
                _SectionHeader('collections_overview'.tr()),
                const SizedBox(height: AppSizes.sm),
                _StatGrid([
                  _StatItem(
                    label: 'total_outstanding'.tr(),
                    value: DebtModel.formatAmountIls(
                        state.totalOutstandingAgorot),
                    color: Theme.of(context).colorScheme.error,
                  ),
                  _StatItem(
                    label: 'cash_with_collectors'.tr(),
                    value: DebtModel.formatAmountIls(
                        state.totalCashWithCollectorsAgorot),
                    color: Colors.orange,
                  ),
                  _StatItem(
                    label: 'collected_today'.tr(),
                    value: DebtModel.formatAmountIls(
                        state.collectedTodayAgorot),
                    color: Colors.teal,
                  ),
                  _StatItem(
                    label: 'collected_this_week'.tr(),
                    value: DebtModel.formatAmountIls(
                        state.collectedThisWeekAgorot),
                    color: Colors.teal,
                  ),
                  _StatItem(
                    label: 'collected_this_month'.tr(),
                    value: DebtModel.formatAmountIls(
                        state.collectedThisMonthAgorot),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _StatItem(
                    label: 'overdue_debts'.tr(),
                    value:
                        '${state.overdueDebtCount}  (${DebtModel.formatAmountIls(state.overdueDebtTotalAgorot)})',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ]),
                const SizedBox(height: AppSizes.lg),

                // Aging breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader('aging_breakdown'.tr()),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.agingReport),
                      child: Text('aging_report'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                AppCard(
                  child: Column(
                    children: [
                      for (final bucket in _bucketOrder)
                        if ((state.agingCounts[bucket] ?? 0) > 0)
                          _AgingRow(
                            bucket: bucket,
                            count: state.agingCounts[bucket] ?? 0,
                            total: state.agingTotals[bucket] ?? 0,
                            grandTotal: state.totalOutstandingAgorot,
                          ),
                      if (state.agingTotals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          child: Text(
                            'no_overdue_debts'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),

                // Per-collector summary
                _SectionHeader('collector_summary'.tr()),
                const SizedBox(height: AppSizes.sm),
                if (state.collectorSummaries.isEmpty)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      child: Text(
                        'no_collectors'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  AppCard(
                    child: Column(
                      children: [
                        _CollectorTableHeader(),
                        const Divider(height: 1),
                        for (final s in state.collectorSummaries) ...[
                          _CollectorRow(summary: s),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSizes.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.sm,
        crossAxisSpacing: AppSizes.sm,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return AppCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgingRow extends StatelessWidget {
  final String bucket;
  final int count;
  final int total;
  final int grandTotal;

  const _AgingRow({
    required this.bucket,
    required this.count,
    required this.total,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    final pct =
        grandTotal > 0 ? (total / grandTotal).clamp(0.0, 1.0) : 0.0;
    final color = _bucketColor(bucket, context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSizes.sm, horizontal: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$bucket ($count)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                DebtModel.formatAmountIls(total),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor:
                  color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _bucketColor(String bucket, BuildContext context) {
    switch (bucket) {
      case 'current':
        return Colors.teal;
      case '1-30':
        return Colors.amber;
      case '31-60':
        return Colors.orange;
      case '61-90':
        return Colors.deepOrange;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }
}

class _CollectorTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('collector_role'.tr(), style: style)),
          Expanded(
              flex: 2,
              child: Text('assigned_debts'.tr(),
                  style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('collected_this_month'.tr(),
                  style: style, textAlign: TextAlign.right)),
          Expanded(
              flex: 3,
              child: Text('cash_with_collectors'.tr(),
                  style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _CollectorRow extends StatelessWidget {
  final CollectorSummary summary;
  const _CollectorRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(summary.name,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${summary.assignedDebtsCount}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              DebtModel.formatAmountIls(summary.collectedMtdAgorot),
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              DebtModel.formatAmountIls(summary.cashOnHandAgorot),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: summary.cashOnHandAgorot > 0
                        ? Colors.orange
                        : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
