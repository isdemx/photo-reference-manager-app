import 'dart:convert';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

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

    final controller =
        await DesktopMultiWindow.createWindow(jsonEncode(payload));
    final windowId = controller.windowId;

    await controller.setTitle(title);
    await controller.setFrame(frame);
    if (center) await controller.center();
    if (show) await controller.show();

    debugPrint(
        '[Multi-Window] created windowId=${controller.windowId} payload=$payload');

    return windowId!;
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
}
