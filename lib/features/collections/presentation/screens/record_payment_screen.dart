import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/payment_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/payments_cubit.dart';
import '../cubit/payments_state.dart';

class RecordPaymentScreen extends StatefulWidget {
  final DebtModel debt;

  const RecordPaymentScreen({super.key, required this.debt});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _checkNumCtrl = TextEditingController();
  final _bankRefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _paymentMethod = 'cash';
  DateTime _collectedAt = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _checkNumCtrl.dispose();
    _bankRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _collectedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _collectedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _collectedAt.hour,
        _collectedAt.minute,
      ));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_collectedAt),
    );
    if (picked != null) {
      setState(() => _collectedAt = DateTime(
        _collectedAt.year,
        _collectedAt.month,
        _collectedAt.day,
        picked.hour,
        picked.minute,
      ));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthCubit>().state.user!;
    final agorot = DebtModel.parseAmountIls(_amountCtrl.text);

    final payment = PaymentModel(
      id: '',
      debtId: widget.debt.id,
      customerId: widget.debt.customerId,
      customerName: widget.debt.customerName,
      collectorId: user.id,
      collectorName: user.name,
      recordedById: user.id,
      recordedByName: user.name,
      amount: agorot,
      paymentMethod: _paymentMethod,
      checkNumber: _paymentMethod == 'check' ? _checkNumCtrl.text.trim() : null,
      bankReference: _paymentMethod == 'bank_transfer' ? _bankRefCtrl.text.trim() : null,
      collectedAt: _collectedAt,
      createdAt: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    context.read<PaymentsCubit>().createPayment(payment);
  }

  @override
  Widget build(BuildContext context) {
    final maxIls = widget.debt.remainingBalance / 100;

    return Scaffold(
      appBar: AppBar(title: Text('record_payment'.tr())),
      body: BlocConsumer<PaymentsCubit, PaymentsState>(
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Debt summary card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.debt.customerName,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                '${'remaining_balance'.tr()}: ${DebtModel.formatAmountIls(widget.debt.remainingBalance)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      // Amount
                      TextFormField(
                        controller: _amountCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'amount'.tr(),
                          prefixText: '₪ ',
                          helperText: '${'remaining_balance'.tr()}: ${DebtModel.formatAmountIls(widget.debt.remainingBalance)}',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'amount_required'.tr();
                          }
                          final agorot = DebtModel.parseAmountIls(v);
                          if (agorot <= 0) return 'amount_required'.tr();
                          if (agorot > widget.debt.remainingBalance) {
                            return 'payment_overpayment_error'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      // Payment method
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration:
                            InputDecoration(labelText: 'payment_method'.tr()),
                        items: [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('payment_method_cash'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'check',
                            child: Text('payment_method_check'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('payment_method_bank_transfer'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentMethod = v);
                        },
                      ),
                      if (_paymentMethod == 'check') ...[
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _checkNumCtrl,
                          decoration:
                              InputDecoration(labelText: 'check_number'.tr()),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      if (_paymentMethod == 'bank_transfer') ...[
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _bankRefCtrl,
                          decoration:
                              InputDecoration(labelText: 'bank_reference'.tr()),
                        ),
                      ],
                      const SizedBox(height: AppSizes.md),
                      // Collection date/time
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('collected_at'.tr()),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy  HH:mm').format(_collectedAt),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: _pickDate,
                            ),
                            IconButton(
                              icon: const Icon(Icons.access_time_outlined),
                              onPressed: _pickTime,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration:
                            InputDecoration(labelText: 'notes'.tr()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      // Overpayment max hint
                      Text(
                        '${'payment_overpayment_error'.tr().split('—').first.trim()} (max ₪${maxIls.toStringAsFixed(2)})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      FilledButton(
                        onPressed: isSaving ? null : _save,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('record_payment'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
