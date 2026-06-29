import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/handover_model.dart';
import '../../data/models/payment_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/handover_cubit.dart';
import '../cubit/handover_state.dart';
import '../cubit/payments_cubit.dart';
import '../cubit/payments_state.dart';

class HandoverInitScreen extends StatefulWidget {
  const HandoverInitScreen({super.key});

  @override
  State<HandoverInitScreen> createState() => _HandoverInitScreenState();
}

class _HandoverInitScreenState extends State<HandoverInitScreen> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthCubit>().state.user?.id;
    if (userId != null) {
      context.read<PaymentsCubit>().loadCollectorPendingPayments(userId);
    }
  }

  void _toggleAll(List<PaymentModel> payments) {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
        _selectAll = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(payments.map((p) => p.id));
        _selectAll = true;
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _initiate(List<PaymentModel> payments) async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_at_least_one_payment'.tr())),
      );
      return;
    }
    final user = context.read<AuthCubit>().state.user!;
    final selected = payments.where((p) => _selectedIds.contains(p.id)).toList();
    final claimed = selected.fold<int>(0, (s, p) => s + p.amount);

    final handover = HandoverModel(
      id: '',
      collectorId: user.id,
      collectorName: user.name,
      claimedAmount: claimed,
      paymentIds: selected.map((p) => p.id).toList(),
      initiatedAt: DateTime.now(),
    );

    context.read<HandoverCubit>().initiateHandover(handover);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('initiate_handover'.tr())),
      body: BlocConsumer<HandoverCubit, HandoverState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == CollectionsStatus.loaded) {
            context.read<HandoverCubit>().clearFormStatus();
            // Reload pending payments so cashOnHand updates
            final userId = context.read<AuthCubit>().state.user?.id;
            if (userId != null) {
              context
                  .read<PaymentsCubit>()
                  .loadCollectorPendingPayments(userId);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('handover_initiated'.tr())),
            );
            Navigator.pop(context, true);
          }
          if (state.formStatus == CollectionsStatus.error &&
              state.formError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.formError!.tr())),
            );
            context.read<HandoverCubit>().clearFormStatus();
          }
        },
        builder: (context, handoverState) {
          final isSubmitting =
              handoverState.formStatus == CollectionsStatus.loading;
          return BlocBuilder<PaymentsCubit, PaymentsState>(
            builder: (context, payState) {
              if (payState.status == CollectionsStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final payments = payState.payments;

              if (payments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Text(
                      'no_pending_payments'.tr(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final selectedPayments =
                  payments.where((p) => _selectedIds.contains(p.id)).toList();
              final totalSelected =
                  selectedPayments.fold<int>(0, (s, p) => s + p.amount);

              return Column(
                children: [
                  // Summary bar
                  Material(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'handover_claimed_amount'.tr()}: ${DebtModel.formatAmountIls(totalSelected)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_selectedIds.length} / ${payments.length} ${'payments'.tr().toLowerCase()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _toggleAll(payments),
                            child: Text(
                              _selectAll
                                  ? 'deselect_all'.tr()
                                  : 'select_all'.tr(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Payment list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: payments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, index) {
                        final p = payments[index];
                        final isSelected = _selectedIds.contains(p.id);
                        return Card(
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggle(p.id),
                            title: Text(
                              DebtModel.formatAmountIls(p.amount),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${p.customerName}  ·  ${DateFormat('dd/MM/yyyy').format(p.collectedAt)}  ·  ${'payment_method_${p.paymentMethod}'.tr()}',
                            ),
                            secondary: p.isReceiptPending
                                ? Tooltip(
                                    message: 'receipt_pending'.tr(),
                                    child: const Icon(
                                        Icons.hourglass_empty_outlined,
                                        size: 18),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  // Submit button
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _selectedIds.isEmpty
                              ? 'initiate_handover'.tr()
                              : '${'initiate_handover'.tr()} (${DebtModel.formatAmountIls(totalSelected)})',
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () => _initiate(payments),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
