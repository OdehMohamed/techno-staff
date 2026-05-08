import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSub;

  AuthCubit({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       super(const AuthState()) {
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) {
    // Only react to server-initiated invalidation while we currently believe
    // we are authenticated. Explicit signOut() / deleteAccount() paths emit
    // unauthenticated themselves; double-emits with equal state are deduped
    // by Bloc and BlocListener, so this is idempotent.
    if (state.status != AuthStatus.authenticated) return;
    if (firebaseUser != null) return;

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> checkAuthStatus({String? languageCode}) async {
    final firebaseUser = _authRepository.currentFirebaseUser;

    if (firebaseUser == null) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final appUser = await _userRepository.getUserById(firebaseUser.uid);

    if (appUser == null || !appUser.isActive) {
      await _authRepository.signOut();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          errorMessage: 'not_authorized',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        user: appUser,
        clearErrorMessage: true,
      ),
    );
    await _setupFCM(firebaseUser.uid);
    await _syncLanguageCode(firebaseUser.uid, languageCode);
  }

  Future<void> signIn({
    required String email,
    required String password,
    String? languageCode,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, clearErrorMessage: true));

    try {
      final credential = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'login_failed',
          ),
        );
        return;
      }

      final appUser = await _userRepository.getUserById(firebaseUser.uid);

      if (appUser == null || !appUser.isActive) {
        await _authRepository.signOut();
        emit(
          state.copyWith(
            status: AuthStatus.error,
            clearUser: true,
            errorMessage: 'not_authorized',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: appUser,
          clearErrorMessage: true,
        ),
      );
      await _setupFCM(firebaseUser.uid);
      await _syncLanguageCode(firebaseUser.uid, languageCode);
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'invalid_login_credentials',
        ),
      );
    }
  }

  Future<void> signOut() async {
    final firebaseUser = _authRepository.currentFirebaseUser;

    if (firebaseUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebasePaths.users)
            .doc(firebaseUser.uid)
            .update({
              'fcmToken': FieldValue.delete(),
            });
      } catch (e, stack) {
        await FirebaseCrashlytics.instance.recordError(e, stack);
      }
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }

    await FirebaseCrashlytics.instance.setUserIdentifier('');
    await _authRepository.signOut();

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> deleteAccount() async {
    if (state.user == null) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteUserAccount')
          .call();

      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e, stack) {
        await FirebaseCrashlytics.instance.recordError(e, stack);
      }

      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await _authRepository.signOut();

      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          clearErrorMessage: true,
        ),
      );
    } on FirebaseFunctionsException catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'failed_to_delete_account',
        ),
      );
      rethrow;
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'failed_to_delete_account',
        ),
      );
      rethrow;
    }
  }

  Future<void> _setupFCM(String userId) async {
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection(FirebasePaths.users).doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  Future<void> _syncLanguageCode(String userId, String? languageCode) async {
    final resolvedLanguageCode = languageCode == 'ar' ? 'ar' : 'en';

    try {
      await FirebaseFirestore.instance
          .collection(FirebasePaths.users)
          .doc(userId)
          .update({FirebasePaths.languageCode: resolvedLanguageCode});
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  Future<void> updateName(String name) async {
    final user = state.user;
    if (user == null) return;

    try {
      await _userRepository.updateName(user.id, name.trim());
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user.copyWith(name: name.trim()),
          clearErrorMessage: true,
        ),
      );
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'failed_to_update_profile',
        ),
      );
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authRepository.reauthenticate(currentPassword);
    } on FirebaseAuthException catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
      final key = e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'current_password_incorrect'
          : e.code == 'network-request-failed'
              ? 'network_error'
              : 'failed_to_update_password';
      emit(state.copyWith(status: AuthStatus.error, errorMessage: key));
      rethrow;
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'failed_to_update_password',
        ),
      );
      rethrow;
    }

    try {
      await _authRepository.updatePassword(newPassword);
    } on FirebaseAuthException catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
      final key = e.code == 'weak-password'
          ? 'password_too_short_min_8'
          : e.code == 'network-request-failed'
              ? 'network_error'
              : 'failed_to_update_password';
      emit(state.copyWith(status: AuthStatus.error, errorMessage: key));
      rethrow;
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'failed_to_update_password',
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
