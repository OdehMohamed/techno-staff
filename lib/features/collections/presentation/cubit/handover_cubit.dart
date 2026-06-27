import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/handover_model.dart';
import '../../data/repositories/handovers_repository.dart';
import 'customers_state.dart';
import 'handover_state.dart';

class HandoverCubit extends Cubit<HandoverState> {
  final HandoversRepository _repo;

  HandoverCubit(this._repo) : super(const HandoverState());

  Future<void> loadCollectorHandovers(String collectorId) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearError: true,
    ));
    try {
      final handovers = await _repo.getByCollector(collectorId);
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        handovers: handovers,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_initiate_handover',
      ));
    }
  }

  Future<void> loadAllHandovers() async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearError: true,
    ));
    try {
      final handovers = await _repo.getAll();
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        handovers: handovers,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_initiate_handover',
      ));
    }
  }

  Future<void> initiateHandover(HandoverModel handover) async {
    emit(state.copyWith(
      formStatus: CollectionsStatus.loading,
      clearFormError: true,
    ));
    try {
      await _repo.create(handover);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_initiate_handover',
      ));
    }
  }

  Future<void> verifyHandover({
    required String handoverId,
    required HandoverModel handover,
    required int actualAmount,
    required String receivedBy,
    required String receivedByName,
    String? discrepancyNotes,
    String? notes,
  }) async {
    emit(state.copyWith(
      formStatus: CollectionsStatus.loading,
      clearFormError: true,
    ));
    try {
      await _repo.verify(
        handoverId: handoverId,
        handover: handover,
        actualAmount: actualAmount,
        receivedBy: receivedBy,
        receivedByName: receivedByName,
        discrepancyNotes: discrepancyNotes,
        notes: notes,
      );
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_verify_handover',
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
