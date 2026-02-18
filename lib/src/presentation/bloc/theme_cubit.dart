import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/services/theme_settings_service.dart';

class ThemeState {
  final AppThemePreference preference;

  const ThemeState({
    required this.preference,
  });

  ThemeMode get themeMode {
    switch (preference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeCubit extends Cubit<ThemeState> {
  final ThemeSettingsService _settingsService;

  ThemeCubit({
    required ThemeSettingsService settingsService,
  })  : _settingsService = settingsService,
        super(const ThemeState(preference: AppThemePreference.dark));

  Future<void> load() async {
    final pref = await _settingsService.loadPreference();
    emit(ThemeState(preference: pref));
  }

  Future<void> setPreference(AppThemePreference preference) async {
    await _settingsService.savePreference(preference);
    emit(ThemeState(preference: preference));
  }
}
