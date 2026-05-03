import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

bool get isMobilePlatform => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

bool get isAppleMobilePlatform => !kIsWeb && Platform.isIOS;

bool get isMacOSDesktopPlatform => !kIsWeb && Platform.isMacOS;
