import '../../data/models/handover_model.dart';
import 'customers_state.dart';

class HandoverState {
  final CollectionsStatus status;
  final List<HandoverModel> handovers;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const HandoverState({
    this.status = CollectionsStatus.initial,
    this.handovers = const [],
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  HandoverState copyWith({
    CollectionsStatus? status,
    List<HandoverModel>? handovers,
    String? error,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearError = false,
    bool clearFormError = false,
  }) {
    return HandoverState(
      status: status ?? this.status,
      handovers: handovers ?? this.handovers,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
