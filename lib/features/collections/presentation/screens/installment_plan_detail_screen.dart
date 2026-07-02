import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/installment_model.dart';
import '../../data/models/installment_plan_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/installment_cubit.dart';
import '../cubit/installment_state.dart';

class InstallmentPlanDetailScreen extends StatefulWidget {
  final InstallmentPlanModel plan;

  const InstallmentPlanDetailScreen({super.key, required this.plan});

  @override
  State<InstallmentPlanDetailScreen> createState() =>
      _InstallmentPlanDetailScreenState();
}

class _InstallmentPlanDetailScreenState
    extends State<InstallmentPlanDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load installments if cubit doesn't have them for this plan yet.
    final cubitPlan = context.read<InstallmentCubit>().state.plan;
    if (cubitPlan?.id != widget.plan.id) {
      context.read<InstallmentCubit>().loadPlanForDebt(widget.plan.debtId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('installment_schedule'.tr())),
      body: BlocBuilder<InstallmentCubit, InstallmentState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CollectionsStatus.error) {
            return EmptyStateWidget(
              icon: Icons.error_outline,
              titleKey: state.error ?? 'unknown_error',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row('total_installments'.tr(),
                          '${widget.plan.totalInstallments}'),
                      _Row(
                        'installment_amount'.tr(),
                        DebtModel.formatAmountIls(
                            widget.plan.installmentAmount),
                      ),
                      _Row(
                        'frequency'.tr(),
                        'frequency_${widget.plan.frequency}'.tr(),
                      ),
                      _Row(
                        'start_date'.tr(),
                        DateFormat('dd/MM/yyyy').format(widget.plan.startDate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  'installments'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSizes.sm),
                if (state.installments.isEmpty &&
                    state.status == CollectionsStatus.loaded)
                  const EmptyStateWidget(
                    icon: Icons.playlist_add_outlined,
                    titleKey: 'no_installment_plan',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.installments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, i) {
                      return AppCard(
                        child: _InstallmentRow(
                            installment: state.installments[i]),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final InstallmentModel installment;

  const _InstallmentRow({required this.installment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = installment.isPaid
        ? Colors.green
        : installment.isOverdue
            ? scheme.error
            : installment.isPartial
                ? Colors.orange
                : scheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${installment.number}  ·  ${DateFormat('dd/MM/yyyy').format(installment.dueDate)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                DebtModel.formatAmountIls(installment.expectedAmount),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (installment.isPartial) ...[
                const SizedBox(height: 2),
                Text(
                  '${'paid_amount'.tr()}: ${DebtModel.formatAmountIls(installment.paidAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'installment_status_${installment.status}'.tr(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: statusColor),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
