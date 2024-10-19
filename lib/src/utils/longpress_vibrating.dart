import 'package:vibration/vibration.dart';

Future<void> vibrate() async {
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(duration: 10, pattern: [0, 10], intensities: [0, 255]);
  }
}
