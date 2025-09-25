// lib/src/feature/screencap/services/screen_capture_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class ScreenCaptureService {
  static const List<int> _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  Future<T> _hideWindowDo<T>(Future<T> Function() action) async {
    bool hidden = false;
    try {
      try { await windowManager.setAlwaysOnTop(false); } catch (_) {}
      await windowManager.hide();
      hidden = true;
      await Future.delayed(const Duration(milliseconds: 120));
      return await action();
    } finally {
      if (hidden) {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }
    }
  }

  Future<Uint8List> captureExactRegionPx({
    required Rect pxRect,
  }) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('captureExactRegionPx is macOS-only');
    }

    final x = pxRect.left.round();
    final y = pxRect.top.round();
    final w = pxRect.width.round();
    final h = pxRect.height.round();

    if (w <= 0 || h <= 0) {
      throw ArgumentError('captureExactRegionPx: width/height must be > 0 (got $w x $h)');
    }

    final tmpDir = await getTemporaryDirectory();
    final outPath = p.join(tmpDir.path, 'shot_${DateTime.now().microsecondsSinceEpoch}.png');
    final outFile = File(outPath);

    debugPrint('[ScreenCapture] screencapture -R "$x,$y,$w,$h" -> $outPath');

    return _hideWindowDo<Uint8List>(() async {
      final result = await Process.run(
        'screencapture',
        ['-x', '-R', '$x,$y,$w,$h', outPath],
      );

      debugPrint('[ScreenCapture] exit=${result.exitCode} stdout="${result.stdout}" stderr="${result.stderr}"');

      if (result.exitCode != 0) {
        final stderrText = (result.stderr ?? '').toString();
        throw 'screencapture failed (${result.exitCode}): $stderrText';
      }

      final bytes = await _readWithWait(outFile, const Duration(seconds: 2));
      debugPrint('[ScreenCapture] file size: ${bytes.length} bytes');

      if (!_looksLikePng(bytes)) {
        final sig = _first8AsHex(bytes);
        throw 'Captured file is not PNG (header: $sig)';
      }

      return bytes;
    });
  }

  // ===== helpers =====

  Future<Uint8List> _readWithWait(File f, Duration timeout) async {
    final start = DateTime.now();
    while (true) {
      if (await f.exists()) {
        try {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {}
      }
      if (DateTime.now().difference(start) > timeout) {
        throw 'screencapture produced no file (check Screen Recording permission)';
      }
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  bool _looksLikePng(Uint8List b) {
    if (b.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (b[i] != _pngHeader[i]) return false;
    }
    return true;
  }

  String _first8AsHex(Uint8List b) {
    final n = b.length >= 8 ? 8 : b.length;
    return List<int>.generate(n, (i) => b[i]).map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
