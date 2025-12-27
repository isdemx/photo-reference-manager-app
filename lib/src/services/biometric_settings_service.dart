import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricSettingsService {
  BiometricSettingsService._();

  static final BiometricSettingsService instance = BiometricSettingsService._();

  static const String _keyEnabled = 'biometric_lock_enabled';

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    enabledNotifier.value = prefs.getBool(_keyEnabled) ?? false;
    _loaded = true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    enabledNotifier.value = enabled;
  }
}
