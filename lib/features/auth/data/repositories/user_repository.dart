import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';
import '../../domain/models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<AppUser?> getUserById(String uid) async {
    final doc = await _firestore.collection(FirebasePaths.users).doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return AppUser.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateName(String uid, String name) async {
    await _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .update({'name': name.trim()});
  }
}
