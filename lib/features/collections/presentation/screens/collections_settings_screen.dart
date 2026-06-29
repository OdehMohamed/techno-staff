import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_sizes.dart';

class CollectionsSettingsScreen extends StatefulWidget {
  const CollectionsSettingsScreen({super.key});

  @override
  State<CollectionsSettingsScreen> createState() =>
      _CollectionsSettingsScreenState();
}

class _CollectionsSettingsScreenState
    extends State<CollectionsSettingsScreen> {
  final _daysCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _triggeringStaleCash = false;
  bool _triggeringAging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('collection_settings')
          .get(const GetOptions(source: Source.server));
      final days = (snap.data()?['staleCashWarningDays'] as num?)?.toInt() ?? 3;
      _daysCtrl.text = days.toString();
    } catch (_) {
      _daysCtrl.text = '3';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _triggerCallable(String name, {required void Function(bool) setBusy}) async {
    setBusy(true);
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name completed')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.code}: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    setBusy(false);
  }

  Future<void> _save() async {
    final days = int.tryParse(_daysCtrl.text.trim());
    if (days == null || days < 1) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('collection_settings')
          .set({'staleCashWarningDays': days}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('save'.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving settings')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('collection_settings'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _daysCtrl,
                    decoration: InputDecoration(
                      labelText: 'stale_cash_warning_days'.tr(),
                      suffixText: 'days'.tr(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: AppSizes.lg),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('save'.tr()),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  const Divider(),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Dev Testing',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  OutlinedButton(
                    onPressed: _triggeringStaleCash
                        ? null
                        : () => _triggerCallable(
                              'testSendStaleCashWarnings',
                              setBusy: (v) =>
                                  setState(() => _triggeringStaleCash = v),
                            ),
                    child: _triggeringStaleCash
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Trigger: Stale Cash Warnings'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  OutlinedButton(
                    onPressed: _triggeringAging
                        ? null
                        : () => _triggerCallable(
                              'testUpdateDebtAgingBuckets',
                              setBusy: (v) =>
                                  setState(() => _triggeringAging = v),
                            ),
                    child: _triggeringAging
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Trigger: Aging Bucket Update'),
                  ),
                ],
              ),
            ),
    );
  }
}
