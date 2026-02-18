import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  dark,
  light,
  system,
}

class ThemeSettingsService {
  static const String _prefKey = 'app.theme.preference';

  Future<AppThemePreference> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    switch (raw) {
      case 'light':
        return AppThemePreference.light;
      case 'system':
        return AppThemePreference.system;
      case 'dark':
      default:
        return AppThemePreference.dark;
    }
  }

  Future<void> savePreference(AppThemePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (preference) {
      AppThemePreference.dark => 'dark',
      AppThemePreference.light => 'light',
      AppThemePreference.system => 'system',
    };
    await prefs.setString(_prefKey, raw);
  }
}
