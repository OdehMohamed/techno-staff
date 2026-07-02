import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/routes/route_names.dart';
import '../../data/repositories/payments_repository.dart';

/// Accepts a raw paymentId string (e.g. from an FCM push tap or an
/// in-app notification) and fetches the full PaymentModel before
/// pushing PaymentDetailScreen. Mirrors the TaskDetailsLoaderScreen pattern.
class PaymentDetailLoaderScreen extends StatefulWidget {
  final String paymentId;
  const PaymentDetailLoaderScreen({super.key, required this.paymentId});

  @override
  State<PaymentDetailLoaderScreen> createState() =>
      _PaymentDetailLoaderScreenState();
}

class _PaymentDetailLoaderScreenState
    extends State<PaymentDetailLoaderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final payment = await PaymentsRepository().getById(widget.paymentId);
      if (!mounted) return;
      if (payment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('payment_not_found'.tr())),
        );
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacementNamed(
        context,
        RouteNames.paymentDetail,
        arguments: payment,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('payment_details'.tr())),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
