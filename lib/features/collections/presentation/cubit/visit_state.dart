import '../../data/models/visit_model.dart';
import 'customers_state.dart';

class VisitState {
  final CollectionsStatus status;
  final List<VisitModel> visits;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const VisitState({
    this.status = CollectionsStatus.initial,
    this.visits = const [],
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  VisitState copyWith({
    CollectionsStatus? status,
    List<VisitModel>? visits,
    String? error,
    bool clearError = false,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearFormError = false,
  }) {
    return VisitState(
      status: status ?? this.status,
      visits: visits ?? this.visits,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
