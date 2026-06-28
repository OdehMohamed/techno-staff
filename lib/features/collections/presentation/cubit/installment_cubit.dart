import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/installment_plan_model.dart';
import '../../data/repositories/installments_repository.dart';
import 'customers_state.dart';
import 'installment_state.dart';

class InstallmentCubit extends Cubit<InstallmentState> {
  final InstallmentsRepository _repo;

  InstallmentCubit(this._repo) : super(const InstallmentState());

  Future<void> loadPlanForDebt(String debtId) async {
    emit(state.copyWith(
      status: CollectionsStatus.loading,
      clearPlan: true,
      installments: const [],
      clearError: true,
    ));
    try {
      final plan = await _repo.getPlanForDebt(debtId);
      if (plan == null) {
        emit(state.copyWith(status: CollectionsStatus.loaded));
        return;
      }
      final installments = await _repo.getInstallments(plan.id);
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        plan: plan,
        installments: installments,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_installments',
      ));
    }
  }

  Future<void> createPlan(InstallmentPlanModel plan) async {
    emit(state.copyWith(
      formStatus: CollectionsStatus.loading,
      clearFormError: true,
    ));
    try {
      await _repo.createPlan(plan);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_create_plan',
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
