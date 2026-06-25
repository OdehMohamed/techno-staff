import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key});

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CustomersCubit>().loadCustomers();
  }

  String _accountStatusColor(String status) => status;

  Color _statusColor(String status) {
    switch (status) {
      case 'delinquent':
        return Colors.red;
      case 'at_risk':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('customers'.tr())),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, RouteNames.addCustomer);
          if (!context.mounted) return;
          if (result == true) context.read<CustomersCubit>().loadCustomers(silent: true);
        },
        icon: const Icon(Icons.person_add_outlined),
        label: Text('add_customer'.tr()),
      ),
      body: BlocBuilder<CustomersCubit, CustomersState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading && state.customers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == CollectionsStatus.error) {
            return RefreshIndicator(
              onRefresh: () => context.read<CustomersCubit>().loadCustomers(silent: true),
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

          if (state.customers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<CustomersCubit>().loadCustomers(silent: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyStateWidget(
                    icon: Icons.people_outline,
                    titleKey: 'no_customers_yet',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<CustomersCubit>().loadCustomers(silent: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.md).copyWith(bottom: 96),
              itemCount: state.customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (context, index) {
                final customer = state.customers[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(
                    context,
                    RouteNames.customerDetail,
                    arguments: customer,
                  ),
                  child: AppCard(
                    child: Row(
                      children: [
                      CircleAvatar(
                        child: Text(
                          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(customer.phone, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 2),
                            Text(
                              customer.assignedCollectorName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(_accountStatusColor(customer.accountStatus))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'account_status_${customer.accountStatus}'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(customer.accountStatus),
                          ),
                        ),
                      ),
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
}
