import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<AppThemeMode> {
  static const _prefsKey = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeCubit({
    required SharedPreferences prefs,
    required AppThemeMode initialMode,
  }) : _prefs = prefs,
       super(initialMode);

  Future<void> setSystemTheme() => _setMode(AppThemeMode.system);

  Future<void> setLightTheme() => _setMode(AppThemeMode.light);

  Future<void> setDarkTheme() => _setMode(AppThemeMode.dark);

  Future<void> _setMode(AppThemeMode mode) async {
    emit(mode);
    try {
      await _prefs.setString(_prefsKey, mode.name);
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }
}
