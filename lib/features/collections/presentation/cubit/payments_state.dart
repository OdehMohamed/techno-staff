import '../../data/models/payment_model.dart';
import 'customers_state.dart';

class PaymentsState {
  final CollectionsStatus status;
  final List<PaymentModel> payments;
  // Sum of pending_handover payments; set by loadCollectorPendingPayments.
  // Preserved (not reset) when loadDebtPayments is called.
  final int cashOnHand;
  // Re-read from users/{uid} on each loadCollectorPendingPayments call so the
  // admin-set limit is enforced without requiring a logout/login cycle.
  final int? maxCashOnHand;
  // Cumulative unresolved discrepancy amount the collector owes the company.
  // Read from users/{uid}.discrepancyBalance; CF-maintained.
  final int discrepancyBalance;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const PaymentsState({
    this.status = CollectionsStatus.initial,
    this.payments = const [],
    this.cashOnHand = 0,
    this.maxCashOnHand,
    this.discrepancyBalance = 0,
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  bool get isAtCashLimit =>
      maxCashOnHand != null && cashOnHand >= maxCashOnHand!;

  bool get isApproachingCashLimit =>
      maxCashOnHand != null &&
      maxCashOnHand! > 0 &&
      cashOnHand / maxCashOnHand! >= 0.8;

  double get cashLimitFraction =>
      maxCashOnHand != null && maxCashOnHand! > 0
          ? (cashOnHand / maxCashOnHand!).clamp(0.0, 1.0)
          : 0.0;

  PaymentsState copyWith({
    CollectionsStatus? status,
    List<PaymentModel>? payments,
    int? cashOnHand,
    int? maxCashOnHand,
    bool clearMaxCashOnHand = false,
    int? discrepancyBalance,
    String? error,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearError = false,
    bool clearFormError = false,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      payments: payments ?? this.payments,
      cashOnHand: cashOnHand ?? this.cashOnHand,
      maxCashOnHand: clearMaxCashOnHand
          ? null
          : (maxCashOnHand ?? this.maxCashOnHand),
      discrepancyBalance: discrepancyBalance ?? this.discrepancyBalance,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
