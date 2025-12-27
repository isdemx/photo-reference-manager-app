import 'dart:io';

import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  bool get _supportedPlatform => Platform.isIOS || Platform.isMacOS;

  Future<bool> isAvailable() async {
    if (!_supportedPlatform) return false;
    final deviceSupported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return deviceSupported && canCheck;
  }

  Future<bool> authenticate() async {
    if (!_supportedPlatform) return false;
    return _auth.authenticate(
      localizedReason: 'Unlock Refma',
    );
  }
}
