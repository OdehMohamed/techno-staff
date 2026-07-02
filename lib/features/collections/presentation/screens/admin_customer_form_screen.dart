import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/customer_model.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';

class AdminCustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer;

  const AdminCustomerFormScreen({super.key, this.customer});

  @override
  State<AdminCustomerFormScreen> createState() => _AdminCustomerFormScreenState();
}

class _AdminCustomerFormScreenState extends State<AdminCustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _phone2Ctrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _guarantorCtrl;
  late final TextEditingController _guarantorPhoneCtrl;
  late final TextEditingController _externalRefCtrl;
  late final TextEditingController _notesCtrl;

  String? _selectedCollectorId;
  String? _selectedCollectorName;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _phone2Ctrl = TextEditingController(text: c?.phone2 ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _guarantorCtrl = TextEditingController(text: c?.guarantor ?? '');
    _guarantorPhoneCtrl = TextEditingController(text: c?.guarantorPhone ?? '');
    _externalRefCtrl = TextEditingController(text: c?.externalReference ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _selectedCollectorId = c?.assignedCollectorId;
    _selectedCollectorName = c?.assignedCollectorName;

    if (context.read<CustomersCubit>().state.collectors.isEmpty) {
      context.read<CustomersCubit>().loadCustomers(silent: true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _addressCtrl.dispose();
    _guarantorCtrl.dispose();
    _guarantorPhoneCtrl.dispose();
    _externalRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthCubit>().state.user!;
    final cubit = context.read<CustomersCubit>();

    if (_isEditing) {
      final phone2Val = _phone2Ctrl.text.trim();
      final addressVal = _addressCtrl.text.trim();
      final guarantorVal = _guarantorCtrl.text.trim();
      final guarantorPhoneVal = _guarantorPhoneCtrl.text.trim();
      final externalRefVal = _externalRefCtrl.text.trim();
      final notesVal = _notesCtrl.text.trim();
      final updated = widget.customer!.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        phone2: phone2Val.isEmpty ? null : phone2Val,
        clearPhone2: phone2Val.isEmpty,
        address: addressVal.isEmpty ? null : addressVal,
        clearAddress: addressVal.isEmpty,
        assignedCollectorId: _selectedCollectorId!,
        assignedCollectorName: _selectedCollectorName!,
        guarantor: guarantorVal.isEmpty ? null : guarantorVal,
        clearGuarantor: guarantorVal.isEmpty,
        guarantorPhone: guarantorPhoneVal.isEmpty ? null : guarantorPhoneVal,
        clearGuarantorPhone: guarantorPhoneVal.isEmpty,
        externalReference: externalRefVal.isEmpty ? null : externalRefVal,
        clearExternalReference: externalRefVal.isEmpty,
        notes: notesVal.isEmpty ? null : notesVal,
        clearNotes: notesVal.isEmpty,
      );
      cubit.updateCustomer(updated);
    } else {
      final created = CustomerModel(
        id: '',
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        phone2: _phone2Ctrl.text.trim().isEmpty ? null : _phone2Ctrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        assignedCollectorId: _selectedCollectorId!,
        assignedCollectorName: _selectedCollectorName!,
        guarantor: _guarantorCtrl.text.trim().isEmpty ? null : _guarantorCtrl.text.trim(),
        guarantorPhone: _guarantorPhoneCtrl.text.trim().isEmpty ? null : _guarantorPhoneCtrl.text.trim(),
        externalReference: _externalRefCtrl.text.trim().isEmpty ? null : _externalRefCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        accountStatus: 'good_standing',
        createdBy: auth.id,
        createdByName: auth.name,
        createdAt: DateTime.now(),
        isActive: true,
      );
      cubit.createCustomer(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_isEditing ? 'edit_customer' : 'add_customer').tr()),
      ),
      body: BlocConsumer<CustomersCubit, CustomersState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == CollectionsStatus.loaded) {
            context.read<CustomersCubit>().clearFormStatus();
            Navigator.pop(context, true);
          }
          if (state.formStatus == CollectionsStatus.error && state.formError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.formError!.tr())),
            );
            context.read<CustomersCubit>().clearFormStatus();
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
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(labelText: 'name'.tr()),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'name_required'.tr() : null,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: InputDecoration(labelText: 'phone'.tr()),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'phone_required'.tr() : null,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _phone2Ctrl,
                        decoration: InputDecoration(labelText: 'phone2'.tr()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: InputDecoration(labelText: 'address'.tr()),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCollectorId,
                        decoration: InputDecoration(labelText: 'collector_role'.tr()),
                        items: state.collectors.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final c = state.collectors.firstWhere((e) => e.id == id);
                          setState(() {
                            _selectedCollectorId = c.id;
                            _selectedCollectorName = c.name;
                          });
                        },
                        validator: (v) => v == null ? 'collector_required'.tr() : null,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _guarantorCtrl,
                        decoration: InputDecoration(labelText: 'guarantor'.tr()),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _guarantorPhoneCtrl,
                        decoration: InputDecoration(labelText: 'guarantor_phone'.tr()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _externalRefCtrl,
                        decoration: InputDecoration(labelText: 'external_reference'.tr()),
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
      ),
    );
  }
}
