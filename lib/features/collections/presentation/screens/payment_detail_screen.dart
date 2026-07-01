import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../cubit/customers_state.dart';
import '../cubit/payments_cubit.dart';
import '../cubit/payments_state.dart';

class PaymentDetailScreen extends StatefulWidget {
  final PaymentModel payment;

  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  late PaymentModel _payment;
  bool _sharingReceipt = false;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
  }

  Future<void> _shareReceipt() async {
    if (_sharingReceipt) return;
    setState(() => _sharingReceipt = true);
    try {
      final fs = FirebaseFirestore.instance;
      final customerSnap = await fs
          .collection(FirebasePaths.customers)
          .doc(_payment.customerId)
          .get(const GetOptions(source: Source.server));
      final phone = customerSnap.data()?['phone'] as String? ?? '';

      final debtSnap = await fs
          .collection(FirebasePaths.debts)
          .doc(_payment.debtId)
          .get(const GetOptions(source: Source.server));
      final remaining =
          (debtSnap.data()?['remainingBalance'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      final locale = context.locale.languageCode;
      final file = await generateReceiptPdf(
        payment: _payment,
        customerPhone: phone,
        remainingBalanceAfterPayment: remaining,
        locale: locale,
      );
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'receipt_${_payment.receiptNumber.replaceAll('-', '_')}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_generate_pdf'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingReceipt = false);
    }
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final cubit = context.read<PaymentsCubit>();
    final adminId = context.read<AuthCubit>().state.user!.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cancel_payment'.tr()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'cancellation_reason'.tr()),
          maxLines: 2,
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

    if (confirmed == true && mounted) {
      cubit.cancelPayment(
        paymentId: _payment.id,
        reason: ctrl.text.trim(),
        cancelledBy: adminId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthCubit>().state.user?.role == 'admin';

    return BlocConsumer<PaymentsCubit, PaymentsState>(
      listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
      listener: (context, state) {
        if (state.formStatus == CollectionsStatus.loaded) {
          context.read<PaymentsCubit>().clearFormStatus();
          Navigator.pop(context, true);
        }
        if (state.formStatus == CollectionsStatus.error &&
            state.formError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.formError!.tr())),
          );
          context.read<PaymentsCubit>().clearFormStatus();
        }
      },
      builder: (context, state) {
        final isSaving = state.formStatus == CollectionsStatus.loading;
        return Scaffold(
          appBar: AppBar(title: Text('payment_details'.tr())),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Receipt status
                if (_payment.isReceiptPending)
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_empty_outlined),
                      title: Text('receipt_pending'.tr()),
                      subtitle: const Text('…'),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_outlined),
                      title: Text('receipt_number'.tr()),
                      subtitle: Text(
                        _payment.receiptNumber,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DebtModel.formatAmountIls(_payment.amount),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          _PaymentStatusChip(status: _payment.status),
                        ],
                      ),
                      const Divider(height: AppSizes.lg),
                      _InfoRow('customer_details'.tr(), _payment.customerName),
                      _InfoRow(
                        'payment_method'.tr(),
                        'payment_method_${_payment.paymentMethod}'.tr(),
                      ),
                      if (_payment.checkNumber != null)
                        _InfoRow('check_number'.tr(), _payment.checkNumber!),
                      if (_payment.bankReference != null)
                        _InfoRow('bank_reference'.tr(), _payment.bankReference!),
                      _InfoRow(
                        'collected_at'.tr(),
                        DateFormat('dd/MM/yyyy  HH:mm')
                            .format(_payment.collectedAt),
                      ),
                      _InfoRow('recorded_by'.tr(), _payment.recordedByName),
                      _InfoRow('collector_role'.tr(), _payment.collectorName),
                      if (_payment.isAdminPayment)
                        _InfoRow('payment_type'.tr(), 'admin_payment'.tr()),
                      if (_payment.notes != null)
                        _InfoRow('notes'.tr(), _payment.notes!),
                    ],
                  ),
                ),
                if (_payment.isCancelled) ...[
                  const SizedBox(height: AppSizes.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'cancel_payment'.tr(),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (_payment.cancellationReason != null)
                          _InfoRow(
                            'cancellation_reason'.tr(),
                            _payment.cancellationReason!,
                          ),
                        if (_payment.cancelledAt != null)
                          _InfoRow(
                            'date'.tr(),
                            DateFormat.yMMMd()
                                .format(_payment.cancelledAt!),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!_payment.isReceiptPending && !_payment.isCancelled) ...[
                  const SizedBox(height: AppSizes.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _sharingReceipt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined),
                      label: Text('share_receipt'.tr()),
                      onPressed: _sharingReceipt ? null : _shareReceipt,
                    ),
                  ),
                ],
                if (isAdmin && _payment.isCancelable) ...[
                  if (_payment.isVerified)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.md),
                      child: Text(
                        'cancel_payment_warn_verified'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSizes.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text('cancel_payment'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: isSaving
                          ? null
                          : () => _showCancelDialog(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  final String status;

  const _PaymentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'verified':
        color = Colors.teal;
      case 'handed_over':
        color = Colors.blue;
      case 'cancelled':
      case 'invalid':
        color = Colors.grey;
      default: // pending_handover
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'payment_status_$status'.tr(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
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
