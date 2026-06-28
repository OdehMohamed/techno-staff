import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payments_repository.dart';
import 'customers_state.dart';
import 'payments_state.dart';

class PaymentsCubit extends Cubit<PaymentsState> {
  final PaymentsRepository _repo;

  PaymentsCubit(this._repo) : super(const PaymentsState());

  // Load payments for a specific debt (debt detail payment history tab).
  // Collectors must pass their own uid as forCollectorId — required by Firestore
  // security rules (collection query must constrain collectorId for non-admin reads).
  // Does NOT reset cashOnHand — preserves the collector's running total.
  Future<void> loadDebtPayments(String debtId, {String? forCollectorId}) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      payments: const [],
      clearError: true,
    ));
    try {
      final payments =
          await _repo.getByDebt(debtId, forCollectorId: forCollectorId);
      emit(state.copyWith(status: CollectionsStatus.loaded, payments: payments));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        payments: const [],
        error: 'failed_to_load_payments',
      ));
    }
  }

  // Load collector's pending_handover payments.
  // Also computes cashOnHand as the sum of those payments.
  Future<void> loadCollectorPendingPayments(String collectorId) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearError: true,
    ));
    try {
      final payments = await _repo.getCollectorPending(collectorId);
      final cash = payments.fold<int>(0, (sum, p) => sum + p.amount);
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        payments: payments,
        cashOnHand: cash,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_payments',
      ));
    }
  }

  // Collector records a new payment.
  Future<void> createPayment(PaymentModel payment) async {
    emit(state.copyWith(
      formStatus: CollectionsStatus.loading,
      clearFormError: true,
    ));
    try {
      await _repo.create(payment);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_record_payment',
      ));
    }
  }

  // Admin cancels a payment. CF reverses debt balances.
  Future<void> cancelPayment({
    required String paymentId,
    required String reason,
    required String cancelledBy,
  }) async {
    emit(state.copyWith(
      formStatus: CollectionsStatus.loading,
      clearFormError: true,
    ));
    try {
      await _repo.cancel(
        paymentId: paymentId,
        reason: reason,
        cancelledBy: cancelledBy,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_record_payment',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(
      formStatus: CollectionsStatus.initial,
      clearFormError: true,
    ));
  }
}
