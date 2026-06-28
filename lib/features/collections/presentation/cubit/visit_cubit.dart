import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/visit_model.dart';
import '../../data/repositories/visits_repository.dart';
import 'customers_state.dart';
import 'visit_state.dart';

class VisitCubit extends Cubit<VisitState> {
  final VisitsRepository _repo;

  VisitCubit(this._repo) : super(const VisitState());

  Future<void> loadDebtVisits(
    String debtId, {
    String? forCollectorId,
  }) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      visits: const [],
      clearError: true,
    ));
    try {
      final visits =
          await _repo.getByDebt(debtId, forCollectorId: forCollectorId);
      emit(state.copyWith(status: CollectionsStatus.loaded, visits: visits));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        visits: const [],
        error: 'failed_to_log_visit',
      ));
    }
  }

  Future<void> loadCustomerVisits(String customerId) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      visits: const [],
      clearError: true,
    ));
    try {
      final visits = await _repo.getByCustomer(customerId);
      emit(state.copyWith(status: CollectionsStatus.loaded, visits: visits));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        visits: const [],
        error: 'failed_to_log_visit',
      ));
    }
  }

  Future<void> createVisit(VisitModel visit) async {
    emit(state.copyWith(
        formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.create(visit);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_log_visit',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(
        formStatus: CollectionsStatus.initial, clearFormError: true));
  }
}
