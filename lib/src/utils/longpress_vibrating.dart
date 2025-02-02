import 'package:vibration/vibration.dart';

Future<void> vibrate([intensivity = 10]) async {
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(duration: 10, pattern: [0, intensivity], intensities: [0, 255]);
  }
}
