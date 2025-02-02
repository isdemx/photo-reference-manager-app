import 'package:flutter/material.dart';

class PhotoViewerOverlay extends StatefulWidget {
  final Widget child;

  const PhotoViewerOverlay({super.key, required this.child});

  @override
  _PhotoViewerOverlayState createState() => _PhotoViewerOverlayState();
}

class _PhotoViewerOverlayState extends State<PhotoViewerOverlay> {
  double _offsetY = 0.0; // Отслеживание положения по Y
  double _opacity = 1.0; // Начальная прозрачность - полностью видимый

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // setState(() {
        //   _offsetY += details.delta.dy; // Двигаем виджет вверх/вниз
        // });
      },
      onVerticalDragEnd: (details) {
        if (_offsetY.abs() > 120) {
          // Запускаем анимацию уменьшения прозрачности
          setState(() {
            _opacity = 0.0;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            Navigator.of(context).pop(); // Закрываем виджет после анимации
          });
        } else {
          setState(() {
            _offsetY = 0; // Возвращаем виджет на место, если свайп слабый
          });
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.translationValues(0, _offsetY, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

void showPhotoViewerOverlay(BuildContext context, Widget child) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => PhotoViewerOverlay(child: child),
    ),
  );
}
