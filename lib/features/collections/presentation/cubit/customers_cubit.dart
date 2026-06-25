import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/collections/data/models/customer_model.dart';
import 'package:techno_staff/features/collections/data/repositories/customers_repository.dart';
import 'customers_state.dart';

class CustomersCubit extends Cubit<CustomersState> {
  final CustomersRepository _repo;

  CustomersCubit({required CustomersRepository customersRepository})
    : _repo = customersRepository,
      super(const CustomersState());

  Future<void> loadCustomers({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: CollectionsStatus.loading, clearError: true));
    }
    try {
      final customersFuture = _repo.getAll();
      final collectorsFuture = _repo.getCollectors();
      final customers = await customersFuture;
      final collectors = await collectorsFuture;
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        customers: customers,
        collectors: collectors,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_customers',
      ));
    }
  }

  Future<void> createCustomer(CustomerModel customer) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.create(customer);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomers(silent: true);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_save_customer',
      ));
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    emit(state.copyWith(formStatus: CollectionsStatus.loading, clearFormError: true));
    try {
      await _repo.update(customer);
      emit(state.copyWith(formStatus: CollectionsStatus.loaded));
      loadCustomers(silent: true);
    } catch (_) {
      emit(state.copyWith(
        formStatus: CollectionsStatus.error,
        formError: 'failed_to_save_customer',
      ));
    }
  }

  void clearFormStatus() {
    emit(state.copyWith(formStatus: CollectionsStatus.initial, clearFormError: true));
  }
}
