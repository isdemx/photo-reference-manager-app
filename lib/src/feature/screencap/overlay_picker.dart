// lib/src/feature/screencap/overlay_picker.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

typedef AreaSelected = void Function(Rect area, String displayId);

abstract class OverlayPicker {
  static const MethodChannel _channel = MethodChannel('macos_overlay_picker');

  static Future<void> show(
    dynamic context, {
    required AreaSelected onShot,
    required AreaSelected onRecord,
  }) async {
    if (!Platform.isMacOS) {
      throw UnimplementedError('OverlayPicker is implemented only on macOS for now');
    }

    debugPrint('[OverlayPicker] invoking native overlay…');
    Map<dynamic, dynamic>? res;
    try {
      res = await _channel.invokeMethod<Map<dynamic, dynamic>>('show');
    } on PlatformException catch (e, st) {
      debugPrint('[OverlayPicker] PlatformException: $e\n$st');
      return;
    } catch (e, st) {
      debugPrint('[OverlayPicker] error: $e\n$st');
      return;
    }

    debugPrint('[OverlayPicker] payload from native: $res');
    if (res == null) return;

    final action = (res['action'] ?? 'cancel').toString();
    if (action == 'cancel') {
      debugPrint('[OverlayPicker] user cancelled');
      return;
    }

    final double x = (res['x'] as num).toDouble();
    final double y = (res['y'] as num).toDouble();
    final double w = (res['w'] as num).toDouble();
    final double h = (res['h'] as num).toDouble();
    final String displayId = (res['displayId'] ?? '').toString();

    final rect = Rect.fromLTWH(x, y, w, h);
    debugPrint('[OverlayPicker] rectPx = $rect, displayId=$displayId, action=$action');

    try {
      if (action == 'shot') {
        onShot(rect, displayId);
      } else {
        onRecord(rect, displayId);
      }
    } catch (e, st) {
      debugPrint('[OverlayPicker] callback error: $e\n$st');
    }
  }
}
