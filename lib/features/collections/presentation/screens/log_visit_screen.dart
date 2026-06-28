import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/visit_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/visit_cubit.dart';
import '../cubit/visit_state.dart';

class LogVisitScreen extends StatefulWidget {
  final DebtModel debt;

  const LogVisitScreen({super.key, required this.debt});

  @override
  State<LogVisitScreen> createState() => _LogVisitScreenState();
}

class _LogVisitScreenState extends State<LogVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ptpAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _contactType = 'in_person';
  String _outcome = 'customer_unavailable';
  DateTime _visitedAt = DateTime.now();
  DateTime _ptpDate = DateTime.now().add(const Duration(days: 7));

  bool get _isPtp => _outcome == 'promise_to_pay';

  @override
  void dispose() {
    _ptpAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _visitedAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _visitedAt.hour,
            _visitedAt.minute,
          ));
    }
  }

  Future<void> _pickPtpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ptpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _ptpDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthCubit>().state.user!;

    PtpData? ptp;
    if (_isPtp) {
      ptp = PtpData(
        amount: DebtModel.parseAmountIls(_ptpAmountCtrl.text),
        promisedDate: _ptpDate,
      );
    }

    context.read<VisitCubit>().createVisit(
          VisitModel(
            id: '',
            customerId: widget.debt.customerId,
            customerName: widget.debt.customerName,
            debtId: widget.debt.id,
            collectorId: user.id,
            collectorName: user.name,
            visitedAt: _visitedAt,
            createdAt: DateTime.now(),
            contactType: _contactType,
            outcome: _outcome,
            promiseToPay: ptp,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('log_visit'.tr())),
      body: BlocConsumer<VisitCubit, VisitState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == CollectionsStatus.loaded) {
            context.read<VisitCubit>().clearFormStatus();
            Navigator.pop(context, true);
          }
          if (state.formStatus == CollectionsStatus.error &&
              state.formError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.formError!.tr())),
            );
            context.read<VisitCubit>().clearFormStatus();
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
                            widget.debt.customerName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _contactType,
                        decoration:
                            InputDecoration(labelText: 'contact_type'.tr()),
                        items: [
                          DropdownMenuItem(
                            value: 'in_person',
                            child: Text('contact_in_person'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'phone',
                            child: Text('contact_by_phone'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _contactType = v);
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _outcome,
                        decoration:
                            InputDecoration(labelText: 'visit_outcome'.tr()),
                        items: [
                          DropdownMenuItem(
                            value: 'customer_unavailable',
                            child: Text('outcome_not_available'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'promise_to_pay',
                            child: Text('outcome_promise_to_pay'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'payment_collected',
                            child: Text('outcome_payment_collected'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'partial_payment',
                            child: Text('outcome_partial_payment'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'refused',
                            child: Text('outcome_refused'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'no_answer',
                            child: Text('outcome_no_answer'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'wrong_contact',
                            child: Text('outcome_wrong_contact'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _outcome = v);
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('collected_at'.tr()),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy  HH:mm').format(_visitedAt),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: _pickVisitDate,
                        ),
                      ),
                      if (_isPtp) ...[
                        const SizedBox(height: AppSizes.sm),
                        TextFormField(
                          controller: _ptpAmountCtrl,
                          decoration: InputDecoration(
                            labelText: 'promised_amount'.tr(),
                            prefixText: '₪ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (v) {
                            if (!_isPtp) return null;
                            final agorot = DebtModel.parseAmountIls(v ?? '');
                            if (agorot <= 0) return 'amount_required'.tr();
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.sm),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('promised_date'.tr()),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(_ptpDate),
                          ),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.calendar_today_outlined),
                            onPressed: _pickPtpDate,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration:
                            InputDecoration(labelText: 'notes'.tr()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      FilledButton(
                        onPressed: isSaving ? null : _save,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('log_visit'.tr()),
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
