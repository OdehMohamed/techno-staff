import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/debt_model.dart';
import '../cubit/debts_admin_cubit.dart';
import '../cubit/debts_state.dart';
import '../widgets/debt_status_badge.dart';

class DebtDetailScreen extends StatelessWidget {
  final DebtModel debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthCubit>().state.user?.role ?? '';
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('debt_details'.tr()),
        actions: [
          if (isAdmin && !debt.isCancelled && debt.status != 'settled')
            _AdminActionsMenu(debt: debt),
          if (isAdmin && debt.status != 'settled' && !debt.isCancelled)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'edit_debt'.tr(),
              onPressed: () => Navigator.pushNamed(
                context,
                RouteNames.editDebt,
                arguments: {'debt': debt},
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
                        DebtModel.formatAmountIls(debt.originalAmount),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DebtStatusBadge(status: debt.status),
                    ],
                  ),
                  const Divider(height: AppSizes.lg),
                  _InfoRow('customer_details'.tr(), debt.customerName),
                  _InfoRow('collector_role'.tr(), debt.assignedCollectorName),
                  _InfoRow(
                    'original_amount'.tr(),
                    DebtModel.formatAmountIls(debt.originalAmount),
                  ),
                  _InfoRow(
                    'paid_amount'.tr(),
                    DebtModel.formatAmountIls(debt.paidAmount),
                  ),
                  _InfoRow(
                    'remaining_balance'.tr(),
                    DebtModel.formatAmountIls(debt.remainingBalance),
                  ),
                  if (debt.dueDate != null)
                    _InfoRow('due_date'.tr(), DateFormat.yMMMd().format(debt.dueDate!)),
                  if (debt.description != null)
                    _InfoRow('description'.tr(), debt.description!),
                  if (debt.notes != null)
                    _InfoRow('notes'.tr(), debt.notes!),
                  _InfoRow(
                    'created_by'.tr(),
                    '${debt.createdByName} · ${DateFormat.yMMMd().format(debt.createdAt)}',
                  ),
                ],
              ),
            ),
            if (debt.isCancelled) ...[
              const SizedBox(height: AppSizes.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('cancel_debt'.tr(), style: Theme.of(context).textTheme.titleSmall),
                    if (debt.cancellationReason != null)
                      _InfoRow('cancellation_reason'.tr(), debt.cancellationReason!),
                    if (debt.cancelledAt != null)
                      _InfoRow('date'.tr(), DateFormat.yMMMd().format(debt.cancelledAt!)),
                  ],
                ),
              ),
            ],
            if (debt.status == 'written_off' && debt.writeOffReason != null) ...[
              const SizedBox(height: AppSizes.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('write_off_debt'.tr(), style: Theme.of(context).textTheme.titleSmall),
                    _InfoRow('write_off_reason'.tr(), debt.writeOffReason!),
                  ],
                ),
              ),
            ],
            if (debt.status == 'settled' && debt.settlementAmount != null) ...[
              const SizedBox(height: AppSizes.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settle_for_less'.tr(), style: Theme.of(context).textTheme.titleSmall),
                    _InfoRow(
                      'settlement_amount'.tr(),
                      DebtModel.formatAmountIls(debt.settlementAmount!),
                    ),
                    if (debt.settlementNotes != null)
                      _InfoRow('settlement_notes'.tr(), debt.settlementNotes!),
                  ],
                ),
              ),
            ],
            if (!isAdmin && debt.status != 'settled' && !debt.isCancelled) ...[
              const SizedBox(height: AppSizes.lg),
              BlocBuilder<DebtsAdminCubit, DebtsState>(
                builder: (_, __) => SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.payments_outlined),
                    label: Text('record_payment'.tr()),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      RouteNames.recordPayment,
                      arguments: debt,
                    ),
                  ),
                ),
              ),
            ],
          ],
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
    void Function(String reason) onConfirm, {
    bool required = true,
  }) async {
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
              if (required && ctrl.text.trim().isEmpty) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settle_for_less'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(
                labelText: 'settlement_amount'.tr(),
                prefixText: '₪ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final agorot = DebtModel.parseAmountIls(amountCtrl.text);
      context.read<DebtsAdminCubit>().updateDebtStatus(
        debt.id,
        debt.customerId,
        'settled',
        settlementAmount: agorot > 0 ? agorot : null,
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
                debt.id,
                debt.customerId,
                'cancelled',
                reason: reason,
              ),
            );
          case 'write_off':
            await _showReasonDialog(
              context,
              'write_off_debt',
              'write_off_reason',
              (reason) => context.read<DebtsAdminCubit>().updateDebtStatus(
                debt.id,
                debt.customerId,
                'written_off',
                reason: reason,
              ),
            );
          case 'settle':
            await _showSettleDialog(context);
          case 'dispute':
            context.read<DebtsAdminCubit>().updateDebtStatus(
              debt.id,
              debt.customerId,
              'disputed',
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
