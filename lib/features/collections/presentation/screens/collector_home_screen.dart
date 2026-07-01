import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/debt_model.dart';
import '../cubit/collector_debts_cubit.dart';
import '../cubit/customers_state.dart';
import '../cubit/debts_state.dart';
import '../cubit/payments_cubit.dart';
import '../cubit/payments_state.dart';
import '../widgets/debt_status_badge.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthCubit>().state.user?.id;
    if (userId != null) {
      context.read<CollectorDebtsCubit>().loadCollectorDebts(userId);
      context.read<PaymentsCubit>().loadCollectorPendingPayments(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_debts'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Discrepancy balance warning — shown when collector owes money from
          // a past handover where the admin received less than claimed.
          BlocBuilder<PaymentsCubit, PaymentsState>(
            builder: (context, payState) {
              if (payState.discrepancyBalance <= 0) return const SizedBox.shrink();
              final scheme = Theme.of(context).colorScheme;
              return Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: scheme.onErrorContainer, size: 20),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'discrepancy_balance_label'.tr()}: ${DebtModel.formatAmountIls(payState.discrepancyBalance)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: scheme.onErrorContainer),
                            ),
                            Text(
                              'discrepancy_balance_info'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Cash on hand banner
          BlocBuilder<PaymentsCubit, PaymentsState>(
            builder: (context, payState) {
              if (payState.cashOnHand <= 0 && payState.maxCashOnHand == null) {
                return const SizedBox.shrink();
              }
              final scheme = Theme.of(context).colorScheme;
              final atLimit = payState.isAtCashLimit;
              final approaching = payState.isApproachingCashLimit;
              final bannerColor = atLimit
                  ? scheme.errorContainer
                  : approaching
                      ? Colors.orange.shade100
                      : scheme.primaryContainer;
              final onBannerColor = atLimit
                  ? scheme.onErrorContainer
                  : approaching
                      ? Colors.orange.shade900
                      : scheme.onPrimaryContainer;
              final barColor = atLimit
                  ? scheme.error
                  : approaching
                      ? Colors.orange
                      : scheme.primary;
              return Material(
                color: bannerColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: onBannerColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'cash_on_hand'.tr()}: ${DebtModel.formatAmountIls(payState.cashOnHand)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: onBannerColor),
                                ),
                                if (payState.maxCashOnHand != null)
                                  Text(
                                    atLimit
                                        ? 'max_cash_reached_error'.tr()
                                        : approaching
                                            ? 'max_cash_approaching_warning'.tr()
                                            : '${'max_cash_on_hand_limit'.tr()}: ${DebtModel.formatAmountIls(payState.maxCashOnHand!)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: onBannerColor),
                                  ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: onBannerColor.withValues(alpha: 0.15),
                              foregroundColor: onBannerColor,
                            ),
                            onPressed: () {
                              final paymentsCubit =
                                  context.read<PaymentsCubit>();
                              final userId =
                                  context.read<AuthCubit>().state.user?.id;
                              Navigator.pushNamed(
                                context,
                                RouteNames.handoverInit,
                              ).then((_) {
                                if (userId != null) {
                                  paymentsCubit
                                      .loadCollectorPendingPayments(userId);
                                }
                              });
                            },
                            child: Text('hand_over_cash'.tr()),
                          ),
                        ],
                      ),
                      if (payState.maxCashOnHand != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: payState.cashLimitFraction,
                            minHeight: 6,
                            backgroundColor:
                                onBannerColor.withValues(alpha: 0.2),
                            valueColor:
                                AlwaysStoppedAnimation(barColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: BlocBuilder<CollectorDebtsCubit, DebtsState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == CollectionsStatus.error) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    icon: Icons.error_outline,
                    titleKey: state.error ?? 'unknown_error',
                  ),
                ],
              ),
            );
          }

          if (state.debts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyStateWidget(
                    icon: Icons.account_balance_wallet_outlined,
                    titleKey: 'no_debts_assigned',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: state.debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (context, index) {
                final debt = state.debts[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(
                    context,
                    RouteNames.debtDetail,
                    arguments: debt,
                  ),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt.customerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DebtModel.formatAmountIls(debt.remainingBalance),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (debt.dueDate != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${'due_date'.tr()}: ${_formatDate(debt.dueDate!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        DebtStatusBadge(status: debt.status),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final userId = context.read<AuthCubit>().state.user?.id;
    if (userId != null) {
      await Future.wait([
        context.read<CollectorDebtsCubit>().loadCollectorDebts(userId),
        context.read<PaymentsCubit>().loadCollectorPendingPayments(userId),
      ]);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
