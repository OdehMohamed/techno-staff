import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/debt_model.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key});

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<CustomersCubit>().loadCustomers();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<CustomersCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _matches(customer) {
    if (_searchQuery.isEmpty) return true;
    return customer.name.toLowerCase().contains(_searchQuery) ||
        customer.phone.contains(_searchQuery) ||
        (customer.address ?? '').toLowerCase().contains(_searchQuery) ||
        customer.assignedCollectorName.toLowerCase().contains(_searchQuery);
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.sm, AppSizes.md, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<CustomersCubit, CustomersState>(
              builder: (context, state) {
                if (state.status == CollectionsStatus.loading &&
                    state.customers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == CollectionsStatus.error) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<CustomersCubit>().loadCustomers(silent: true),
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

                final customers =
                    state.customers.where(_matches).toList();

                if (customers.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<CustomersCubit>().loadCustomers(silent: true),
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
                  onRefresh: () =>
                      context.read<CustomersCubit>().loadCustomers(silent: true),
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSizes.md).copyWith(bottom: 96),
                    itemCount: customers.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, index) {
                      if (index == customers.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                          child: Center(
                            child: Text('loading_more'.tr(),
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        );
                      }
                      final customer = customers[index];
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
                                  customer.name.isNotEmpty
                                      ? customer.name[0].toUpperCase()
                                      : '?',
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
                                    Text(customer.phone,
                                        style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 2),
                                    Text(
                                      customer.assignedCollectorName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                    if (customer.totalOutstandingBalance > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        DebtModel.formatAmountIls(
                                            customer.totalOutstandingBalance),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                          _accountStatusColor(customer.accountStatus))
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
          ),
        ],
      ),
    );
  }
}
