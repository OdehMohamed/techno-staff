import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/payment_model.dart';
import '../cubit/collector_debts_cubit.dart';
import '../cubit/customers_state.dart';
import '../cubit/debts_admin_cubit.dart';
import '../cubit/debts_state.dart';
import '../cubit/payments_cubit.dart';
import '../cubit/payments_state.dart';
import '../widgets/debt_status_badge.dart';

class DebtDetailScreen extends StatefulWidget {
  final DebtModel debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  late DebtModel _debt;
  // Captured in initState; passed to loadDebtPayments so the Firestore rule's
  // collectorId constraint is satisfied for non-admin collection queries.
  String? _forCollectorId;

  @override
  void initState() {
    super.initState();
    _debt = widget.debt;
    final user = context.read<AuthCubit>().state.user!;
    _forCollectorId = user.role == 'collector' ? user.id : null;
    context
        .read<PaymentsCubit>()
        .loadDebtPayments(_debt.id, forCollectorId: _forCollectorId);
  }

  Future<void> _openPaymentDetail(PaymentModel p) async {
    final cubit = context.read<PaymentsCubit>();
    final v = await Navigator.pushNamed(
      context,
      RouteNames.paymentDetail,
      arguments: p,
    );
    if (!mounted) return;
    if (v == true) cubit.loadDebtPayments(_debt.id, forCollectorId: _forCollectorId);
  }

  Future<void> _openRecordPayment() async {
    final cubit = context.read<PaymentsCubit>();
    final v = await Navigator.pushNamed(
      context,
      RouteNames.recordPayment,
      arguments: _debt,
    );
    if (!mounted) return;
    if (v == true) cubit.loadDebtPayments(_debt.id, forCollectorId: _forCollectorId);
  }

  void _syncFromDebts(List<DebtModel> debts) {
    final updated = debts.where((d) => d.id == _debt.id).firstOrNull;
    if (updated != null && updated != _debt) {
      setState(() => _debt = updated);
    }
  }

  bool get _isTerminal =>
      _debt.isCancelled ||
      _debt.status == 'settled' ||
      _debt.status == 'written_off';

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthCubit>().state.user?.role == 'admin';

    return BlocListener<DebtsAdminCubit, DebtsState>(
      listenWhen: (prev, curr) =>
          curr.status == CollectionsStatus.loaded && prev.debts != curr.debts,
      listener: (_, state) => _syncFromDebts(state.debts),
      child: BlocListener<CollectorDebtsCubit, DebtsState>(
        listenWhen: (prev, curr) =>
            curr.status == CollectionsStatus.loaded && prev.debts != curr.debts,
        listener: (_, state) => _syncFromDebts(state.debts),
        child: Scaffold(
          appBar: AppBar(
            title: Text('debt_details'.tr()),
            actions: [
              if (isAdmin && !_isTerminal)
                _AdminActionsMenu(debt: _debt),
              if (isAdmin && !_isTerminal)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'edit_debt'.tr(),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    RouteNames.editDebt,
                    arguments: {'debt': _debt},
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DebtModel.formatAmountIls(_debt.originalAmount),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DebtStatusBadge(status: _debt.status),
                        ],
                      ),
                      const Divider(height: AppSizes.lg),
                      _InfoRow('customer_details'.tr(), _debt.customerName),
                      _InfoRow('collector_role'.tr(), _debt.assignedCollectorName),
                      _InfoRow('original_amount'.tr(), DebtModel.formatAmountIls(_debt.originalAmount)),
                      _InfoRow('paid_amount'.tr(), DebtModel.formatAmountIls(_debt.paidAmount)),
                      _InfoRow('remaining_balance'.tr(), DebtModel.formatAmountIls(_debt.remainingBalance)),
                      if (_debt.dueDate != null)
                        _InfoRow('due_date'.tr(), DateFormat.yMMMd().format(_debt.dueDate!)),
                      if (_debt.description != null)
                        _InfoRow('description'.tr(), _debt.description!),
                      if (_debt.notes != null)
                        _InfoRow('notes'.tr(), _debt.notes!),
                      _InfoRow(
                        'created_by'.tr(),
                        '${_debt.createdByName} · ${DateFormat.yMMMd().format(_debt.createdAt)}',
                      ),
                    ],
                  ),
                ),
                if (_debt.isCancelled) ...[
                  const SizedBox(height: AppSizes.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('cancel_debt'.tr(), style: Theme.of(context).textTheme.titleSmall),
                        if (_debt.cancellationReason != null)
                          _InfoRow('cancellation_reason'.tr(), _debt.cancellationReason!),
                        if (_debt.cancelledAt != null)
                          _InfoRow('date'.tr(), DateFormat.yMMMd().format(_debt.cancelledAt!)),
                      ],
                    ),
                  ),
                ],
                if (_debt.status == 'written_off' && _debt.writeOffReason != null) ...[
                  const SizedBox(height: AppSizes.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('write_off_debt'.tr(), style: Theme.of(context).textTheme.titleSmall),
                        _InfoRow('write_off_reason'.tr(), _debt.writeOffReason!),
                      ],
                    ),
                  ),
                ],
                if (_debt.status == 'settled' && _debt.settlementAmount != null) ...[
                  const SizedBox(height: AppSizes.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('settle_for_less'.tr(), style: Theme.of(context).textTheme.titleSmall),
                        _InfoRow('settlement_amount'.tr(), DebtModel.formatAmountIls(_debt.settlementAmount!)),
                        if (_debt.settlementNotes != null)
                          _InfoRow('settlement_notes'.tr(), _debt.settlementNotes!),
                      ],
                    ),
                  ),
                ],
                // Payment history
                const SizedBox(height: AppSizes.md),
                Text('payments'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSizes.sm),
                BlocBuilder<PaymentsCubit, PaymentsState>(
                  builder: (context, payState) {
                    if (payState.status == CollectionsStatus.loading) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSizes.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (payState.status == CollectionsStatus.error) {
                      return EmptyStateWidget(
                        icon: Icons.error_outline,
                        titleKey: payState.error ?? 'unknown_error',
                      );
                    }
                    if (payState.payments.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        titleKey: 'no_payments_found',
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payState.payments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, i) {
                        final p = payState.payments[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openPaymentDetail(p),
                          child: AppCard(
                            child: _DebtPaymentRow(payment: p),
                          ),
                        );
                      },
                    );
                  },
                ),
                if (!isAdmin && !_isTerminal) ...[
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.payments_outlined),
                      label: Text('record_payment'.tr()),
                      onPressed: _openRecordPayment,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionsMenu extends StatelessWidget {
  final DebtModel debt;

  const _AdminActionsMenu({required this.debt});

  Future<void> _showReasonDialog(
    BuildContext context,
    String titleKey,
    String hintKey,
    void Function(String reason) onConfirm,
  ) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titleKey.tr()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hintKey.tr()),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm(ctrl.text.trim());
  }

  Future<void> _showSettleDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? amountError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('settle_for_less'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(
                  labelText: 'settlement_amount'.tr(),
                  prefixText: '₪ ',
                  errorText: amountError,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
                onChanged: (_) {
                  if (amountError != null) setDialogState(() => amountError = null);
                },
              ),
              const SizedBox(height: AppSizes.sm),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(labelText: 'settlement_notes'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final agorot = DebtModel.parseAmountIls(amountCtrl.text);
                if (agorot <= 0 || agorot > debt.remainingBalance) {
                  setDialogState(() => amountError = 'amount_required'.tr());
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text('confirm'.tr()),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final agorot = DebtModel.parseAmountIls(amountCtrl.text);
      context.read<DebtsAdminCubit>().updateDebtStatus(
        debt.id,
        debt.customerId,
        'settled',
        settlementAmount: agorot,
        settlementNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case 'cancel':
            await _showReasonDialog(
              context,
              'cancel_debt',
              'cancellation_reason',
              (reason) => context.read<DebtsAdminCubit>().updateDebtStatus(
                debt.id, debt.customerId, 'cancelled', reason: reason,
              ),
            );
          case 'write_off':
            await _showReasonDialog(
              context,
              'write_off_debt',
              'write_off_reason',
              (reason) => context.read<DebtsAdminCubit>().updateDebtStatus(
                debt.id, debt.customerId, 'written_off', reason: reason,
              ),
            );
          case 'settle':
            await _showSettleDialog(context);
          case 'dispute':
            context.read<DebtsAdminCubit>().updateDebtStatus(
              debt.id, debt.customerId, 'disputed',
            );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'settle', child: Text('settle_for_less'.tr())),
        PopupMenuItem(value: 'dispute', child: Text('dispute_debt'.tr())),
        PopupMenuItem(value: 'write_off', child: Text('write_off_debt'.tr())),
        PopupMenuItem(value: 'cancel', child: Text('cancel_debt'.tr())),
      ],
    );
  }
}

class _DebtPaymentRow extends StatelessWidget {
  final PaymentModel payment;

  const _DebtPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DebtModel.formatAmountIls(payment.amount),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('dd/MM/yyyy').format(payment.collectedAt)}  ·  ${'payment_method_${payment.paymentMethod}'.tr()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (payment.receiptNumber.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  payment.receiptNumber,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (payment.isCancelled)
          Icon(Icons.cancel_outlined,
              size: 16, color: Theme.of(context).colorScheme.error)
        else if (payment.isReceiptPending)
          const Icon(Icons.hourglass_empty_outlined, size: 16),
      ],
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
            width: 140,
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
