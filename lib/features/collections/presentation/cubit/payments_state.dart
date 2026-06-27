import '../../data/models/payment_model.dart';
import 'customers_state.dart';

class PaymentsState {
  final CollectionsStatus status;
  final List<PaymentModel> payments;
  // Sum of pending_handover payments; set by loadCollectorPendingPayments.
  // Preserved (not reset) when loadDebtPayments is called.
  final int cashOnHand;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const PaymentsState({
    this.status = CollectionsStatus.initial,
    this.payments = const [],
    this.cashOnHand = 0,
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  PaymentsState copyWith({
    CollectionsStatus? status,
    List<PaymentModel>? payments,
    int? cashOnHand,
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
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
