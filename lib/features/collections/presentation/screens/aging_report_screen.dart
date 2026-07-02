import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/debt_model.dart';
import '../../data/services/collections_report_service.dart';
import '../cubit/collections_dashboard_cubit.dart';
import '../cubit/collections_dashboard_state.dart';
import '../cubit/customers_state.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> {
  static const _bucketOrder = ['90+', '61-90', '31-60', '1-30', 'current'];
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<CollectionsDashboardCubit>().state;
    if (st.status == CollectionsStatus.initial) {
      context.read<CollectionsDashboardCubit>().load();
    }
  }

  Future<void> _exportPdf(List<DebtModel> debts) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final locale = context.locale.languageCode;
      final file = await generateAgingReportPdf(debts: debts, locale: locale);
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'aging_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_generate_pdf'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionsDashboardCubit, CollectionsDashboardState>(
      builder: (context, state) {
        final debts = state.allActiveDebts;

        return Scaffold(
          appBar: AppBar(
            title: Text('aging_report'.tr()),
            actions: [
              if (debts.isNotEmpty)
                _exportingPdf
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'aging_report'.tr(),
                        onPressed: () => _exportPdf(debts),
                      ),
            ],
          ),
          body: state.status == CollectionsStatus.loading ||
                  state.status == CollectionsStatus.initial
              ? const Center(child: CircularProgressIndicator())
              : state.status == CollectionsStatus.error
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error?.tr() ?? 'error'.tr()),
                          const SizedBox(height: AppSizes.md),
                          FilledButton(
                            onPressed: () => context
                                .read<CollectionsDashboardCubit>()
                                .load(),
                            child: Text('retry'.tr()),
                          ),
                        ],
                      ),
                    )
                  : debts.isEmpty
                      ? Center(child: Text('no_overdue_debts'.tr()))
                      : ListView(
                          padding: const EdgeInsets.all(AppSizes.md),
                          children: [
                            for (final bucket in _bucketOrder) ...[
                              _BucketSection(
                                bucket: bucket,
                                debts: debts
                                    .where((d) => d.agingBucket == bucket)
                                    .toList()
                                  ..sort((a, b) => b.remainingBalance
                                      .compareTo(a.remainingBalance)),
                              ),
                            ],
                          ],
                        ),
        );
      },
    );
  }
}

class _BucketSection extends StatelessWidget {
  final String bucket;
  final List<DebtModel> debts;

  const _BucketSection({required this.bucket, required this.debts});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const SizedBox.shrink();

    final total = debts.fold<int>(0, (s, d) => s + d.remainingBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              bottom: AppSizes.xs, top: AppSizes.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bucket,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${debts.length}  ·  ${DebtModel.formatAmountIls(total)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (int i = 0; i < debts.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _DebtRow(debt: debts[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  final DebtModel debt;
  const _DebtRow({required this.debt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.customerName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (debt.description?.isNotEmpty == true)
                  Text(
                    debt.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            DebtModel.formatAmountIls(debt.remainingBalance),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
