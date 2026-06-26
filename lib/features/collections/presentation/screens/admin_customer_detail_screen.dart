import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/debt_model.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';
import '../cubit/debts_admin_cubit.dart';
import '../cubit/debts_state.dart';
import '../widgets/debt_status_badge.dart';

class AdminCustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const AdminCustomerDetailScreen({super.key, required this.customer});

  @override
  State<AdminCustomerDetailScreen> createState() => _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  late CustomerModel _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    context.read<DebtsAdminCubit>().loadCustomerDebts(_customer.id);
  }

  Future<void> _openEdit() async {
    await Navigator.pushNamed(
      context,
      RouteNames.editCustomer,
      arguments: _customer,
    );
    // The form triggers CustomersCubit.loadCustomers(silent:true).
    // _syncFromCubit() fires via BlocListener when that reload completes.
  }

  void _syncFromCubit(CustomersState state) {
    final updated = state.customers
        .where((c) => c.id == _customer.id)
        .firstOrNull;
    if (updated != null && updated != _customer) {
      setState(() => _customer = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'edit_customer'.tr(),
            onPressed: _openEdit,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            RouteNames.addDebt,
            arguments: {'customer': _customer},
          );
          if (!context.mounted) return;
          if (result == true) {
            context.read<DebtsAdminCubit>().loadCustomerDebts(_customer.id);
          }
        },
        icon: const Icon(Icons.add),
        label: Text('add_debt'.tr()),
      ),
      body: BlocListener<CustomersCubit, CustomersState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status && curr.status == CollectionsStatus.loaded,
        listener: (_, state) => _syncFromCubit(state),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md).copyWith(bottom: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow('phone'.tr(), _customer.phone),
                  if (_customer.phone2 != null)
                    _InfoRow('phone2'.tr(), _customer.phone2!),
                  if (_customer.address != null)
                    _InfoRow('address'.tr(), _customer.address!),
                  _InfoRow('collector_role'.tr(), _customer.assignedCollectorName),
                  _InfoRow(
                    'account_status_good_standing'.tr().split(' ').first,
                    'account_status_${_customer.accountStatus}'.tr(),
                  ),
                  if (_customer.guarantor != null)
                    _InfoRow('guarantor'.tr(), _customer.guarantor!),
                  if (_customer.guarantorPhone != null)
                    _InfoRow('guarantor_phone'.tr(), _customer.guarantorPhone!),
                  if (_customer.externalReference != null)
                    _InfoRow('external_reference'.tr(), _customer.externalReference!),
                  if (_customer.notes != null)
                    _InfoRow('notes'.tr(), _customer.notes!),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text('debts'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.sm),
            BlocBuilder<DebtsAdminCubit, DebtsState>(
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
                if (state.debts.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    titleKey: 'no_debts_found',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                                    DebtModel.formatAmountIls(debt.originalAmount),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${'remaining_balance'.tr()}: ${DebtModel.formatAmountIls(debt.remainingBalance)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (debt.dueDate != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${'due_date'.tr()}: ${DateFormat.yMd().format(debt.dueDate!)}',
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
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
