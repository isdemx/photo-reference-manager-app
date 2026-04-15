import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as p;

class WindowService {
  /// Открыть новое окно приложения с произвольным роутом/аргументами.
  /// Возвращает windowId созданного окна.
  static Future<int> openWindow({
    String? route,
    Map<String, dynamic>? args,
    String title = 'Refma',
    Rect frame = const Rect.fromLTWH(160, 120, 1100, 800),
    bool center = true,
    bool show = true,
  }) async {
    final payload = <String, dynamic>{
      if (route != null) 'route': route,
      if (args != null) ...args,
    };
    debugPrint(
        '[RefmaOpenFiles][dart] openWindow route=$route title=$title payload=$payload');

    final controller =
        await DesktopMultiWindow.createWindow(jsonEncode(payload));
    final windowId = controller.windowId;
    debugPrint('[RefmaOpenFiles][dart] createWindow -> windowId=$windowId');

    await controller.setTitle(title);
    await controller.setFrame(frame);
    if (center) await controller.center();
    if (show) await controller.show();

    debugPrint(
        '[Multi-Window] created windowId=${controller.windowId} payload=$payload');

    return windowId;
  }

  /// Упрощённый хелпер: открыть окно просмотрщика по photoId.
  static Future<int> openPhotoWindow({
    required String photoId,
    String title = 'Refma — Viewer',
    Rect frame = const Rect.fromLTWH(200, 160, 1100, 800),
  }) {
    return openWindow(
      route: '/photoById',
      args: {'photoId': photoId},
      title: title,
      frame: frame,
    );
  }

  static Future<int> openLiteViewerWindow({
    required String filePath,
  }) {
    return _openLiteViewerWindow(filePath: filePath);
  }

  static Future<int> _openLiteViewerWindow({
    required String filePath,
  }) async {
    final fileName = p.basename(filePath);
    final geometry = await _computeLiteViewerGeometry(filePath);
    return openWindow(
      route: '/lite_viewer',
      args: {
        'filePath': filePath,
        'initialViewportAspectRatio': geometry.aspectRatio,
      },
      title: 'Refma — $fileName',
      frame: geometry.frame,
    );
  }

  static Future<_LiteViewerGeometry> _computeLiteViewerGeometry(
    String filePath,
  ) async {
    final screenSize = _currentScreenSize();
    const horizontalChrome = 28.0;
    const verticalChrome = 34.0;
    const minWindowWidth = 360.0;
    const minWindowHeight = 260.0;
    const minMediaWidth = 240.0;
    const minMediaHeight = 180.0;
    const sideInset = 32.0;
    const topBarHeight = 32.0;

    final maxMediaWidth =
        (screenSize.width - (sideInset * 2)).clamp(minMediaWidth, 4096.0);
    final maxMediaHeight = ((screenSize.height * (7 / 9)) - topBarHeight)
        .clamp(minMediaHeight, 4096.0);

    final aspectRatio = _readMediaAspectRatio(filePath);

    var mediaWidth = maxMediaWidth.toDouble();
    var mediaHeight = mediaWidth / aspectRatio;

    if (mediaHeight > maxMediaHeight) {
      mediaHeight = maxMediaHeight.toDouble();
      mediaWidth = mediaHeight * aspectRatio;
    }

    final windowWidth = (mediaWidth + horizontalChrome)
        .clamp(minWindowWidth, screenSize.width - 8);
    final windowHeight = (mediaHeight + verticalChrome)
        .clamp(minWindowHeight, screenSize.height - 8);

    return _LiteViewerGeometry(
      aspectRatio: aspectRatio,
      frame: Rect.fromLTWH(0, 0, windowWidth, windowHeight),
    );
  }

  static double _readMediaAspectRatio(String filePath) {
    final mediaType = _inferMediaType(filePath);
    if (mediaType == 'video') {
      return 16 / 9;
    }

    try {
      final result = ImageSizeGetter.getSizeResult(FileInput(File(filePath)));
      if (result.size.height > 0) {
        return result.size.width / result.size.height;
      }
    } catch (_) {}

    return 4 / 3;
  }

  static String _inferMediaType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    const videoExts = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.m4v',
      '.webm',
      '.wmv',
      '.vmv'
    ];
    return videoExts.contains(ext) ? 'video' : 'image';
  }

  static ui.Size _currentScreenSize() {
    final views = ui.PlatformDispatcher.instance.views;
    final view = views.isNotEmpty ? views.first : null;
    if (view == null) {
      return const ui.Size(1440, 900);
    }
    final display = view.display;
    final size = display.size / display.devicePixelRatio;
    if (size.width > 0 && size.height > 0) {
      return size;
    }
    return view.physicalSize / view.devicePixelRatio;
  }
}

class _LiteViewerGeometry {
  const _LiteViewerGeometry({
    required this.aspectRatio,
    required this.frame,
  });

  final double aspectRatio;
  final Rect frame;
}
