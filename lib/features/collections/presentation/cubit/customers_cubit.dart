import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:techno_staff/features/collections/data/models/customer_model.dart';
import 'package:techno_staff/features/collections/data/repositories/customers_repository.dart';
import 'customers_state.dart';

const _kPageSize = 20;

class CustomersCubit extends Cubit<CustomersState> {
  final CustomersRepository _repo;
  DocumentSnapshot? _lastDoc;
  bool _loadingMore = false;

  CustomersCubit({required CustomersRepository customersRepository})
    : _repo = customersRepository,
      super(const CustomersState());

  Future<void> loadCustomers({bool silent = false}) async {
    _lastDoc = null;
    if (!silent) {
      emit(state.copyWith(status: CollectionsStatus.loading, clearError: true));
    }
    try {
      final (items: customers, lastDoc: last, hasMore: more) =
          await _repo.getPaged(_kPageSize);
      final collectors = await _repo.getCollectors();
      _lastDoc = last;
      emit(state.copyWith(
        status: CollectionsStatus.loaded,
        customers: customers,
        collectors: collectors,
        hasMore: more,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CollectionsStatus.error,
        error: 'failed_to_load_customers',
      ));
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !state.hasMore || _lastDoc == null) return;
    _loadingMore = true;
    try {
      final (items: newItems, lastDoc: last, hasMore: more) =
          await _repo.getPaged(_kPageSize, startAfter: _lastDoc);
      _lastDoc = last ?? _lastDoc;
      emit(state.copyWith(
        customers: [...state.customers, ...newItems],
        hasMore: more,
      ));
    } catch (_) {
      // silently ignore load-more failures — list remains intact
    } finally {
      _loadingMore = false;
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
