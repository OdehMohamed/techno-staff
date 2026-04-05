import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/app.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/user_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authRepository = AuthRepository();
  final userRepository = UserRepository();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(
            create: (_) => AuthCubit(
              authRepository: authRepository,
              userRepository: userRepository,
            ),
          ),
        ],
        child: const TechnoStaffApp(),
      ),
    ),
  );
}
