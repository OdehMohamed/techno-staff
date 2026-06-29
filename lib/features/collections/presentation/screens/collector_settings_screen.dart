import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../data/models/debt_model.dart';
import '../../../auth/domain/models/app_user.dart';

class CollectorSettingsScreen extends StatefulWidget {
  final AppUser collector;

  const CollectorSettingsScreen({super.key, required this.collector});

  @override
  State<CollectorSettingsScreen> createState() =>
      _CollectorSettingsScreenState();
}

class _CollectorSettingsScreenState extends State<CollectorSettingsScreen> {
  final _limitCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int? _currentLimit; // agorot, null = no limit

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirebasePaths.users)
          .doc(widget.collector.id)
          .get(const GetOptions(source: Source.server));
      final raw = (snap.data()?['maxCashOnHand'] as num?)?.toInt();
      setState(() {
        _currentLimit = raw;
        _limitCtrl.text =
            raw != null ? (raw / 100).toStringAsFixed(2) : '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final text = _limitCtrl.text.trim();
    final int? newAgorot;
    if (text.isEmpty) {
      newAgorot = null;
    } else {
      final agorot = DebtModel.parseAmountIls(text);
      if (agorot < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('amount_required'.tr())),
        );
        return;
      }
      newAgorot = agorot;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirebasePaths.users)
          .doc(widget.collector.id)
          .update({'maxCashOnHand': newAgorot});
      setState(() => _currentLimit = newAgorot);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('saved'.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('collector_settings'.tr()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                Text(
                  widget.collector.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  widget.collector.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'max_cash_on_hand_limit'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.sm),
                TextFormField(
                  controller: _limitCtrl,
                  decoration: InputDecoration(
                    prefixText: '₪ ',
                    hintText: 'no_limit'.tr(),
                    helperText: _currentLimit != null
                        ? '${'max_cash_on_hand_limit'.tr()}: ${DebtModel.formatAmountIls(_currentLimit!)}'
                        : 'no_limit'.tr(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  'max_cash_on_hand_hint'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSizes.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('save'.tr()),
                  ),
                ),
                if (_currentLimit != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _limitCtrl.clear();
                              _save();
                            },
                      child: Text('no_limit'.tr()),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
