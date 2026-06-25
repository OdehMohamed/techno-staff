import 'package:techno_staff/features/auth/domain/models/app_user.dart';
import 'package:techno_staff/features/collections/data/models/customer_model.dart';

enum CollectionsStatus { initial, loading, loaded, error }

class CustomersState {
  final CollectionsStatus status;
  final List<CustomerModel> customers;
  final List<AppUser> collectors;
  final String? error;
  final CollectionsStatus formStatus;
  final String? formError;

  const CustomersState({
    this.status = CollectionsStatus.initial,
    this.customers = const [],
    this.collectors = const [],
    this.error,
    this.formStatus = CollectionsStatus.initial,
    this.formError,
  });

  CustomersState copyWith({
    CollectionsStatus? status,
    List<CustomerModel>? customers,
    List<AppUser>? collectors,
    String? error,
    CollectionsStatus? formStatus,
    String? formError,
    bool clearError = false,
    bool clearFormError = false,
  }) {
    return CustomersState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      collectors: collectors ?? this.collectors,
      error: clearError ? null : (error ?? this.error),
      formStatus: formStatus ?? this.formStatus,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}
