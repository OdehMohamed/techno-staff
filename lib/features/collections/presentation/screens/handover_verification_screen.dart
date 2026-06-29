import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/handover_model.dart';
import '../../data/repositories/payments_repository.dart';
import '../../data/services/collections_report_service.dart';
import '../cubit/customers_state.dart';
import '../cubit/handover_cubit.dart';
import '../cubit/handover_state.dart';

class HandoverVerificationScreen extends StatefulWidget {
  final HandoverModel handover;

  const HandoverVerificationScreen({super.key, required this.handover});

  @override
  State<HandoverVerificationScreen> createState() =>
      _HandoverVerificationScreenState();
}

class _HandoverVerificationScreenState
    extends State<HandoverVerificationScreen> {
  late HandoverModel _handover;
  final _actualAmountCtrl = TextEditingController();
  final _discrepancyNotesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _amountError;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _handover = widget.handover;
    // Pre-fill actual amount with claimed amount as starting point
    _actualAmountCtrl.text =
        (_handover.claimedAmount / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _actualAmountCtrl.dispose();
    _discrepancyNotesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportReconciliation() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final repo = PaymentsRepository();
      final payments = await repo.getByIds(_handover.paymentIds);
      if (!mounted) return;
      final locale = context.locale.languageCode;
      final file = await generateHandoverReconciliationPdf(
        handover: _handover,
        payments: payments,
        locale: locale,
      );
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'reconciliation_${_handover.id}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_generate_pdf'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _verify() async {
    final agorot = DebtModel.parseAmountIls(_actualAmountCtrl.text);
    if (agorot < 0) {
      setState(() => _amountError = 'amount_required'.tr());
      return;
    }

    final user = context.read<AuthCubit>().state.user!;
    final hasDiscrepancy = agorot != _handover.claimedAmount;

    if (hasDiscrepancy && _discrepancyNotesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('discrepancy_notes_required'.tr())),
      );
      return;
    }

    context.read<HandoverCubit>().verifyHandover(
      handoverId: _handover.id,
      handover: _handover,
      actualAmount: agorot,
      receivedBy: user.id,
      receivedByName: user.name,
      discrepancyNotes: hasDiscrepancy
          ? _discrepancyNotesCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HandoverCubit, HandoverState>(
      listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
      listener: (context, state) {
        if (state.formStatus == CollectionsStatus.loaded) {
          context.read<HandoverCubit>().clearFormStatus();
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
      builder: (context, state) {
        final isSaving = state.formStatus == CollectionsStatus.loading;
        final isTerminal = !_handover.isPending;

        return Scaffold(
          appBar: AppBar(
            title: Text('handover_details'.tr()),
            actions: [
              _exportingPdf
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'reconciliation_report'.tr(),
                      onPressed: _exportReconciliation,
                    ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status chip
                _HandoverStatusChip(status: _handover.status),
                const SizedBox(height: AppSizes.md),
                // Summary card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                          'collector_role'.tr(), _handover.collectorName),
                      _InfoRow(
                        'handover_claimed_amount'.tr(),
                        DebtModel.formatAmountIls(_handover.claimedAmount),
                      ),
                      _InfoRow(
                        'date'.tr(),
                        DateFormat('dd/MM/yyyy  HH:mm')
                            .format(_handover.initiatedAt),
                      ),
                      _InfoRow(
                          'payments'.tr(),
                          '${_handover.paymentIds.length}'),
                      if (_handover.actualAmount != null)
                        _InfoRow(
                          'handover_actual_amount'.tr(),
                          DebtModel.formatAmountIls(_handover.actualAmount!),
                        ),
                      if (_handover.receivedByName != null)
                        _InfoRow('verified_by'.tr(), _handover.receivedByName!),
                      if (_handover.verifiedAt != null)
                        _InfoRow(
                          'date'.tr(),
                          DateFormat('dd/MM/yyyy').format(_handover.verifiedAt!),
                        ),
                      if (_handover.hasDiscrepancy &&
                          _handover.discrepancyAmount != null)
                        _InfoRow(
                          'discrepancy_amount'.tr(),
                          DebtModel.formatAmountIls(
                              _handover.discrepancyAmount!.abs()),
                        ),
                      if (_handover.discrepancyNotes != null)
                        _InfoRow(
                            'discrepancy_notes'.tr(),
                            _handover.discrepancyNotes!),
                    ],
                  ),
                ),
                // Verification form (only for pending handovers)
                if (!isTerminal) ...[
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    'verify_handover'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _actualAmountCtrl,
                    decoration: InputDecoration(
                      labelText: 'handover_actual_amount'.tr(),
                      prefixText: '₪ ',
                      errorText: _amountError,
                      helperText:
                          '${'handover_claimed_amount'.tr()}: ${DebtModel.formatAmountIls(_handover.claimedAmount)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _discrepancyNotesCtrl,
                    decoration: InputDecoration(
                      labelText: 'discrepancy_notes'.tr(),
                      helperText: 'discrepancy_notes_hint'.tr(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration:
                        InputDecoration(labelText: 'notes'.tr()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text('verify_handover'.tr()),
                      onPressed: isSaving ? null : _verify,
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

class _HandoverStatusChip extends StatelessWidget {
  final String status;

  const _HandoverStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String key;
    switch (status) {
      case 'verified':
        color = Colors.teal;
        icon = Icons.check_circle_outline;
        key = 'handover_status_verified';
      case 'discrepancy':
        color = Colors.orange;
        icon = Icons.warning_amber_outlined;
        key = 'handover_discrepancy';
      default: // pending_verification
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.hourglass_empty_outlined;
        key = 'handover_status_pending';
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(key.tr(), style: TextStyle(color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
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
