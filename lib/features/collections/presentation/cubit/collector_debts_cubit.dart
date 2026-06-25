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
}
