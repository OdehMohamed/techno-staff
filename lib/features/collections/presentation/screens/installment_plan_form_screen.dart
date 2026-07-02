import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/installment_plan_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/installment_cubit.dart';
import '../cubit/installment_state.dart';

class InstallmentPlanFormScreen extends StatefulWidget {
  final DebtModel debt;

  const InstallmentPlanFormScreen({super.key, required this.debt});

  @override
  State<InstallmentPlanFormScreen> createState() =>
      _InstallmentPlanFormScreenState();
}

class _InstallmentPlanFormScreenState extends State<InstallmentPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _numCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _autoFillAmount() {
    final n = int.tryParse(_numCtrl.text.trim()) ?? 0;
    if (n > 0) {
      final ils = (widget.debt.remainingBalance / 100 / n);
      _amountCtrl.text = ils.toStringAsFixed(2);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthCubit>().state.user!;
    final n = int.parse(_numCtrl.text.trim());
    final amountAgorot = DebtModel.parseAmountIls(_amountCtrl.text);

    context.read<InstallmentCubit>().createPlan(
          InstallmentPlanModel(
            id: '',
            debtId: widget.debt.id,
            customerId: widget.debt.customerId,
            totalInstallments: n,
            installmentAmount: amountAgorot,
            frequency: _frequency,
            startDate: _startDate,
            createdBy: user.id,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = DebtModel.formatAmountIls(widget.debt.remainingBalance);
    return Scaffold(
      appBar: AppBar(title: Text('create_installment_plan'.tr())),
      body: BlocConsumer<InstallmentCubit, InstallmentState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == CollectionsStatus.loaded) {
            context.read<InstallmentCubit>().clearFormStatus();
            Navigator.pop(context, true);
          }
          if (state.formStatus == CollectionsStatus.error &&
              state.formError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.formError!.tr())),
            );
            context.read<InstallmentCubit>().clearFormStatus();
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Text(
                            '${'remaining_balance'.tr()}: $remaining',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _numCtrl,
                        decoration: InputDecoration(
                          labelText: 'total_installments'.tr(),
                          helperText: 'total_installments'.tr(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _autoFillAmount(),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 2) {
                            return 'amount_required'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _amountCtrl,
                        decoration: InputDecoration(
                          labelText: 'installment_amount'.tr(),
                          prefixText: '₪ ',
                          helperText: 'installment_amount'.tr(),
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
                          final agorot = DebtModel.parseAmountIls(v ?? '');
                          if (agorot <= 0) return 'amount_required'.tr();
                          if (agorot > widget.debt.remainingBalance) {
                            return 'payment_overpayment_error'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration:
                            InputDecoration(labelText: 'frequency'.tr()),
                        items: [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('frequency_weekly'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'biweekly',
                            child: Text('frequency_biweekly'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('frequency_monthly'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _frequency = v);
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('start_date'.tr()),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: _pickStart,
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
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
                            : Text('create_installment_plan'.tr()),
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
