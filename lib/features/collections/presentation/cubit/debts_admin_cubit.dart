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

  Future<void> markDisputed(
    String debtId,
    String customerId, {
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.markDisputed(debtId,
          reason: reason, adminId: adminId, adminName: adminName);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
          formStatus: CollectionsStatus.error, formError: 'failed_to_save_debt'));
    }
  }

  Future<void> writeOff(
    String debtId,
    String customerId, {
    required String reason,
    required int remainingBalance,
    required String adminId,
    required String adminName,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.writeOff(debtId,
          reason: reason,
          remainingBalance: remainingBalance,
          adminId: adminId,
          adminName: adminName);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
          formStatus: CollectionsStatus.error, formError: 'failed_to_save_debt'));
    }
  }

  Future<void> settleForLess(
    String debtId,
    String customerId, {
    required int settledAmount,
    required int originalBalance,
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.settleForLess(debtId,
          settledAmount: settledAmount,
          originalBalance: originalBalance,
          reason: reason,
          adminId: adminId,
          adminName: adminName);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
          formStatus: CollectionsStatus.error, formError: 'failed_to_save_debt'));
    }
  }

  Future<void> approveSettlementRequest(
    String debtId,
    String customerId, {
    required int settledAmount,
    required String adminName,
    required String collectorId,
    required String collectorName,
    required String customerName,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.approveSettlementRequest(
        debtId,
        settledAmount: settledAmount,
        adminName: adminName,
        collectorId: collectorId,
        collectorName: collectorName,
        customerId: customerId,
        customerName: customerName,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_approve_settlement',
      ));
    }
  }

  Future<void> rejectSettlementRequest(
    String debtId,
    String customerId, {
    required String adminId,
    required String adminName,
    String? rejectionReason,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.rejectSettlementRequest(
        debtId,
        adminId: adminId,
        adminName: adminName,
        rejectionReason: rejectionReason,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomerDebts(customerId);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_reject_settlement',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(formStatus: CollectionsStatus.initial, clearFormError: true));
  }
}
