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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_debts'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<CollectorDebtsCubit, DebtsState>(
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
    );
  }

  Future<void> _refresh() async {
    final userId = context.read<AuthCubit>().state.user?.id;
    if (userId != null) {
      await context.read<CollectorDebtsCubit>().loadCollectorDebts(userId);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
