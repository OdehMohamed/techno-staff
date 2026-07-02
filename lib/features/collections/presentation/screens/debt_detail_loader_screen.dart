import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/routes/route_names.dart';
import '../../data/repositories/debts_repository.dart';

/// Accepts a raw debtId string (from an FCM push tap or in-app notification)
/// and fetches the full DebtModel before pushing DebtDetailScreen.
/// Mirrors the PaymentDetailLoaderScreen pattern.
class DebtDetailLoaderScreen extends StatefulWidget {
  final String debtId;
  const DebtDetailLoaderScreen({super.key, required this.debtId});

  @override
  State<DebtDetailLoaderScreen> createState() => _DebtDetailLoaderScreenState();
}

class _DebtDetailLoaderScreenState extends State<DebtDetailLoaderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final debt = await DebtsRepository().getById(widget.debtId);
      if (!mounted) return;
      if (debt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('debt_not_found'.tr())),
        );
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacementNamed(
        context,
        RouteNames.debtDetail,
        arguments: debt,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('debt_details'.tr())),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
