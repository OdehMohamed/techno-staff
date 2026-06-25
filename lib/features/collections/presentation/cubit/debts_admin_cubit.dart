import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/collections/data/models/debt_model.dart';
import 'package:techno_staff/features/collections/data/repositories/debts_repository.dart';
import 'customers_state.dart';
import 'debts_state.dart';

class DebtsAdminCubit extends Cubit<DebtsState> {
  final DebtsRepository _repo;

  DebtsAdminCubit({required DebtsRepository debtsRepository})
    : _repo = debtsRepository,
      super(const DebtsState());

  Future<void> loadCustomerDebts(String customerId) async {
    emit(state.copyWith(status: CollectionsStatus.loading, clearError: true));
    try {
      final debts = await _repo.getByCustomer(customerId);
      emit(state.copyWith(status: CollectionsStatus.loaded, debts: debts));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_debts',
      ));
    }
  }

  Future<void> createDebt(DebtModel debt) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.create(debt);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(debt.customerId);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_save_debt',
      ));
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.update(debt);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(debt.customerId);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_save_debt',
      ));
    }
  }

  Future<void> updateDebtStatus(
    String debtId,
    String customerId,
    String status, {
    String? reason,
    int? settlementAmount,
    String? settlementNotes,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.updateStatus(
        debtId,
        status,
        reason: reason,
        settlementAmount: settlementAmount,
        settlementNotes: settlementNotes,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_save_debt',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(formStatus: CollectionsStatus.initial, clearFormError: true));
  }
}
