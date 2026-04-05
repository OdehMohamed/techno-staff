import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit() : super(AppThemeMode.system);

  void setSystemTheme() => emit(AppThemeMode.system);

  void setLightTheme() => emit(AppThemeMode.light);

  void setDarkTheme() => emit(AppThemeMode.dark);
}
