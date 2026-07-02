import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/debt_model.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';
import '../cubit/debts_admin_cubit.dart';
import '../cubit/debts_state.dart';

class AdminDebtFormScreen extends StatefulWidget {
  final CustomerModel customer;
  final DebtModel? debt;

  const AdminDebtFormScreen({super.key, required this.customer, this.debt});

  @override
  State<AdminDebtFormScreen> createState() => _AdminDebtFormScreenState();
}

class _AdminDebtFormScreenState extends State<AdminDebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _notesCtrl;

  DateTime? _dueDate;
  String? _selectedCollectorId;
  String? _selectedCollectorName;

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    final amountIls = d != null ? (d.originalAmount / 100).toStringAsFixed(2) : '';
    _amountCtrl = TextEditingController(text: amountIls);
    _descriptionCtrl = TextEditingController(text: d?.description ?? '');
    _notesCtrl = TextEditingController(text: d?.notes ?? '');
    _dueDate = d?.dueDate;
    _selectedCollectorId = d?.assignedCollectorId ?? widget.customer.assignedCollectorId;
    _selectedCollectorName = d?.assignedCollectorName ?? widget.customer.assignedCollectorName;

    if (context.read<CustomersCubit>().state.collectors.isEmpty) {
      context.read<CustomersCubit>().loadCustomers(silent: true);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthCubit>().state.user!;
    final cubit = context.read<DebtsAdminCubit>();
    final amountAgorot = DebtModel.parseAmountIls(_amountCtrl.text);

    if (_isEditing) {
      final updated = widget.debt!.copyWith(
        assignedCollectorId: _selectedCollectorId!,
        assignedCollectorName: _selectedCollectorName!,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      cubit.updateDebt(updated);
    } else {
      final debt = DebtModel(
        id: '',
        customerId: widget.customer.id,
        customerName: widget.customer.name,
        originalAmount: amountAgorot,
        remainingBalance: amountAgorot,
        assignedCollectorId: _selectedCollectorId!,
        assignedCollectorName: _selectedCollectorName!,
        dueDate: _dueDate,
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdBy: auth.id,
        createdByName: auth.name,
        createdAt: DateTime.now(),
      );
      cubit.createDebt(debt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_isEditing ? 'edit_debt' : 'add_debt').tr()),
      ),
      body: BlocConsumer<DebtsAdminCubit, DebtsState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == CollectionsStatus.loaded) {
            context.read<DebtsAdminCubit>().clearFormStatus();
            Navigator.pop(context, true);
          }
          if (state.formStatus == CollectionsStatus.error && state.formError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.formError!.tr())),
            );
            context.read<DebtsAdminCubit>().clearFormStatus();
          }
        },
        builder: (context, debtState) {
          final isSaving = debtState.formStatus == CollectionsStatus.loading;
          return BlocBuilder<CustomersCubit, CustomersState>(
            builder: (context, customerState) {
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
                          // Customer name (read-only context)
                          Text(
                            widget.customer.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          TextFormField(
                            controller: _amountCtrl,
                            decoration: InputDecoration(
                              labelText: 'amount'.tr(),
                              prefixText: '₪ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            enabled: !_isEditing,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'amount_required'.tr();
                              final parsed = double.tryParse(v.replaceAll(',', ''));
                              if (parsed == null || parsed <= 0) return 'amount_required'.tr();
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.md),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCollectorId,
                            decoration: InputDecoration(labelText: 'collector_role'.tr()),
                            items: customerState.collectors.map((c) {
                              return DropdownMenuItem(value: c.id, child: Text(c.name));
                            }).toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              final c = customerState.collectors.firstWhere((e) => e.id == id);
                              setState(() {
                                _selectedCollectorId = c.id;
                                _selectedCollectorName = c.name;
                              });
                            },
                            validator: (v) => v == null ? 'collector_required'.tr() : null,
                          ),
                          const SizedBox(height: AppSizes.md),
                          // Due date picker
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'due_date'.tr(),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_dueDate != null)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() => _dueDate = null),
                                      ),
                                    const Icon(Icons.calendar_today_outlined, size: 18),
                                  ],
                                ),
                              ),
                              child: Text(
                                _dueDate != null
                                    ? DateFormat.yMd().format(_dueDate!)
                                    : '',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          TextFormField(
                            controller: _descriptionCtrl,
                            decoration: InputDecoration(labelText: 'description'.tr()),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: AppSizes.md),
                          TextFormField(
                            controller: _notesCtrl,
                            decoration: InputDecoration(labelText: 'notes'.tr()),
                            maxLines: 3,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          FilledButton(
                            onPressed: isSaving ? null : _save,
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text('save'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
