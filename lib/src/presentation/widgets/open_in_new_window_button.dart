import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

/// Универсальная кнопка "Открыть в новом окне".
/// Пример 1 (по photoId):
///   OpenInNewWindowButton.photo(photoId: photo.id)
///
/// Пример 2 (произвольный роут):
///   OpenInNewWindowButton.route(
///     route: '/someRoute',
///     args: {'foo': 'bar'},
///     title: 'Refma — Tools',
///   )
class OpenInNewWindowButton extends StatelessWidget {
  // Режимы
  final String? photoId;               // если задан — открываем '/photoById'
  final String? route;                 // альтернативно — явный роут
  final Map<String, dynamic>? args;    // аргументы для route

  // UI настройки
  final String tooltip;
  final bool iconOnly;                 // true -> IconButton, false -> ElevatedButton
  final IconData icon;
  final String label;                  // текст для not iconOnly
  final String title;                  // заголовок окна
  final Rect frame;

  const OpenInNewWindowButton.photo({
    super.key,
    required this.photoId,
    this.tooltip = 'Открыть в новом окне',
    this.iconOnly = true,
    this.icon = Icons.open_in_new,
    this.label = 'Открыть в новом окне',
    this.title = 'Refma — Viewer',
    this.frame = const Rect.fromLTWH(200, 160, 1100, 800),
  })  : route = null,
        args = null;

  const OpenInNewWindowButton.route({
    super.key,
    required this.route,
    this.args,
    this.tooltip = 'Открыть в новом окне',
    this.iconOnly = true,
    this.icon = Icons.open_in_new,
    this.label = 'Открыть в новом окне',
    this.title = 'Refma',
    this.frame = const Rect.fromLTWH(160, 120, 1100, 800),
  }) : photoId = null;

  Future<void> _open() async {
    if (photoId != null && photoId!.isNotEmpty) {
      await WindowService.openPhotoWindow(photoId: photoId!, title: title, frame: frame);
    } else {
      await WindowService.openWindow(
        route: route,
        args: args,
        title: title,
        frame: frame,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: _open,
      );
    }
    return ElevatedButton.icon(
      onPressed: _open,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
