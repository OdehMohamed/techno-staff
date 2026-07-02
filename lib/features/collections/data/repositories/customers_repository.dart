import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import 'package:techno_staff/features/auth/domain/models/app_user.dart';
import '../models/customer_model.dart';

class CustomersRepository {
  final FirebaseFirestore _firestore;

  CustomersRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CustomerModel>> getAll() async {
    final snap = await _firestore
        .collection(FirebasePaths.customers)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs.map((d) => CustomerModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<({List<CustomerModel> items, DocumentSnapshot? lastDoc, bool hasMore})>
      getPaged(int limit, {DocumentSnapshot? startAfter}) async {
    var query = _firestore
        .collection(FirebasePaths.customers)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.get(const GetOptions(source: Source.server));
    final items = snap.docs.map((d) => CustomerModel.fromMap(d.data(), d.id)).toList();
    return (
      items: items,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == limit,
    );
  }

  Future<String> create(CustomerModel customer) async {
    final ref = _firestore.collection(FirebasePaths.customers).doc();
    await ref.set(customer.toCreateMap());
    return ref.id;
  }

  Future<void> update(CustomerModel customer) async {
    await _firestore
        .collection(FirebasePaths.customers)
        .doc(customer.id)
        .update(customer.toUpdateMap());
  }

  Future<CustomerModel?> getById(String id) async {
    final snap = await _firestore
        .collection(FirebasePaths.customers)
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists || snap.data() == null) return null;
    return CustomerModel.fromMap(snap.data()!, snap.id);
  }

  Future<List<AppUser>> getCollectors() async {
    final snap = await _firestore
        .collection(FirebasePaths.users)
        .where(FirebasePaths.role, isEqualTo: 'collector')
        .where('isActive', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
    return snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();
  }
}
