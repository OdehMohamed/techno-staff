import '../../data/models/installment_model.dart';
import '../../data/models/installment_plan_model.dart';
import 'customers_state.dart';

class InstallmentState {
  final CollectionsStatus status;
  final InstallmentPlanModel? plan;
  final List<InstallmentModel> installments;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const InstallmentState({
    this.status = CollectionsStatus.initial,
    this.plan,
    this.installments = const [],
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  InstallmentState copyWith({
    CollectionsStatus? status,
    InstallmentPlanModel? plan,
    bool clearPlan = false,
    List<InstallmentModel>? installments,
    String? error,
    bool clearError = false,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearFormError = false,
  }) {
    return InstallmentState(
      status: status ?? this.status,
      plan: clearPlan ? null : (plan ?? this.plan),
      installments: installments ?? this.installments,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
