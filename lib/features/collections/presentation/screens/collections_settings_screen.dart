import 'package:cloud_firestore/cloud_firestore.dart';
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
                ],
              ),
            ),
    );
  }
}
