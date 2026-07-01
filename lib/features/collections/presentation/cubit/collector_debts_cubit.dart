import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/collections/data/repositories/debts_repository.dart';
import 'customers_state.dart';
import 'debts_state.dart';

class CollectorDebtsCubit extends Cubit<DebtsState> {
  final DebtsRepository _repo;

  CollectorDebtsCubit({required DebtsRepository debtsRepository})
    : _repo = debtsRepository,
      super(const DebtsState());

  Future<void> loadCollectorDebts(String collectorId) async {
    emit(state.copyWith(status: CollectionsStatus.loading, clearError: true));
    try {
      final debts = await _repo.getByCollector(collectorId);
      emit(state.copyWith(status: CollectionsStatus.loaded, debts: debts));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_debts',
      ));
    }
  }

  Future<void> requestSettlement(
    String debtId, {
    required int requestedAmount,
    required String reason,
    required String collectorId,
    required String collectorName,
  }) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.requestSettlement(
        debtId,
        requestedAmount: requestedAmount,
        reason: reason,
        collectorId: collectorId,
        collectorName: collectorName,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_request_settlement',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(formStatus: CollectionsStatus.initial, clearFormError: true));
  }
}
