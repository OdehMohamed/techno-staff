import 'package:techno_staff/features/collections/data/models/debt_model.dart';
import 'customers_state.dart';

class DebtsState {
  final CollectionsStatus status;
  final List<DebtModel> debts;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const DebtsState({
    this.status = CollectionsStatus.initial,
    this.debts = const [],
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  DebtsState copyWith({
    CollectionsStatus? status,
    List<DebtModel>? debts,
    String? error,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearError = false,
    bool clearFormError = false,
  }) {
    return DebtsState(
      status: status ?? this.status,
      debts: debts ?? this.debts,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
