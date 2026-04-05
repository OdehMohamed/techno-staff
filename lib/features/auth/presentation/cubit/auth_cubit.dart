import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState());

  Future<void> checkAuthStatus() async {
    final currentUser = _authRepository.getCurrentUser();

    if (currentUser != null) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: currentUser,
          clearErrorMessage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          clearErrorMessage: true,
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, clearErrorMessage: true));

    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearErrorMessage: true,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
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
