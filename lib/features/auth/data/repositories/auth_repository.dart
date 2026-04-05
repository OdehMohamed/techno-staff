import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/app_user.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('User not found after login.');
    }

    return AppUser(id: user.uid, email: user.email);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  AppUser? getCurrentUser() {
    final user = _firebaseAuth.currentUser;

    if (user == null) return null;

    return AppUser(id: user.uid, email: user.email);
  }
}
