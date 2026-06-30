import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payments_repository.dart';
import 'customers_state.dart';
import 'payments_state.dart';

class PaymentsCubit extends Cubit<PaymentsState> {
  final PaymentsRepository _repo;
  StreamSubscription<List<PaymentModel>>? _debtPaymentsSubscription;

  PaymentsCubit(this._repo) : super(const PaymentsState());

  // Subscribe to real-time updates for a debt's payments (debt detail screen).
  // Automatically reflects CF updates (e.g. receiptNumber assignment) without a
  // manual reload. Cancels any previous subscription before starting a new one.
  // Does NOT reset cashOnHand — preserves the collector's running total.
  Future<void> loadDebtPayments(String debtId, {String? forCollectorId}) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      payments: const [],
      clearError: true,
    ));
    await _debtPaymentsSubscription?.cancel();
    _debtPaymentsSubscription = _repo
        .streamByDebt(debtId, forCollectorId: forCollectorId)
        .listen(
          (payments) => emit(state.copyWith(
            status: CollectionsStatus.loaded,
            payments: payments,
          )),
          onError: (_) => emit(state.copyWith(
            status: CollectionsStatus.error,
            payments: const [],
            error: 'failed_to_load_payments',
          )),
        );
  }

  @override
  Future<void> close() async {
    await _debtPaymentsSubscription?.cancel();
    return super.close();
  }

  // Load collector's pending_handover payments and re-read maxCashOnHand from
  // the user doc so the admin-set limit is enforced without a logout/login cycle.
  Future<void> loadCollectorPendingPayments(String collectorId) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearError: true,
    ));
    try {
      final results = await Future.wait([
        _repo.getCollectorPending(collectorId),
        FirebaseFirestore.instance
            .collection(FirebasePaths.users)
            .doc(collectorId)
            .get(const GetOptions(source: Source.server)),
      ]);
      final payments = results[0] as List<PaymentModel>;
      final userSnap = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final cash = payments.fold<int>(0, (acc, p) => acc + p.amount);
      final maxCash =
          (userSnap.data()?['maxCashOnHand'] as num?)?.toInt();
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        payments: payments,
        cashOnHand: cash,
        maxCashOnHand: maxCash,
        clearMaxCashOnHand: maxCash == null,
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
