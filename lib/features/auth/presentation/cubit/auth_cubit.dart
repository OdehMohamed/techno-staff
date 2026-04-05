import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState());

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  void resetState() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
