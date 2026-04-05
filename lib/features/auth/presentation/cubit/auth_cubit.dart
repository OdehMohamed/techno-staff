import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  AuthCubit({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       super(const AuthState());

  Future<void> checkAuthStatus() async {
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
  }

  Future<void> signIn({required String email, required String password}) async {
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
    await _authRepository.signOut();

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearErrorMessage: true,
      ),
    );
  }
}
