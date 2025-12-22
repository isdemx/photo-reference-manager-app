import 'dart:math' as math;
import 'package:flutter/material.dart';

class TriangleVolumeSlider extends StatelessWidget {
  /// 0..1
  final double value;

  /// callback 0..1
  final ValueChanged<double> onChanged;

  /// Визуальные размеры треугольника (НЕ хит-зона).
  final double width;
  final double height;

  /// Хит-зона (чтобы удобно попадать пальцем), треугольник рисуем снизу.
  final double hitHeight;

  final Color trackColor;
  final Color fillColor;

  /// Если true — добавит тонкий “бордер” треугольника.
  final bool showOutline;
  final Color outlineColor;
  final double outlineWidth;

  const TriangleVolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 26,
    this.height = 10, // в 3 раза ниже, чем 30
    this.hitHeight = 30, // удобная зона для тача
    this.trackColor = const Color.fromRGBO(200, 200, 200, 0.5),
    this.fillColor = const Color.fromRGBO(255, 0, 0, 0.7),
    this.showOutline = false,
    this.outlineColor = const Color.fromRGBO(255, 255, 255, 0.25),
    this.outlineWidth = 1.0,
  });

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  double _valueFromLocal(Offset local) {
    // local.dx: 0..width => 0..1
    final dx = local.dx.clamp(0.0, width);
    return _clamp01(dx / math.max(width, 0.0001));
  }

  @override
  Widget build(BuildContext context) {
    final v = _clamp01(value);

    return SizedBox(
      width: width,
      height: hitHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onChanged(_valueFromLocal(d.localPosition)),
        onHorizontalDragStart: (d) => onChanged(_valueFromLocal(d.localPosition)),
        onHorizontalDragUpdate: (d) => onChanged(_valueFromLocal(d.localPosition)),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            size: Size(width, height),
            painter: _TriangleVolumePainter(
              value: v,
              trackColor: trackColor,
              fillColor: fillColor,
              showOutline: showOutline,
              outlineColor: outlineColor,
              outlineWidth: outlineWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _TriangleVolumePainter extends CustomPainter {
  final double value; // 0..1
  final Color trackColor;
  final Color fillColor;

  final bool showOutline;
  final Color outlineColor;
  final double outlineWidth;

  _TriangleVolumePainter({
    required this.value,
    required this.trackColor,
    required this.fillColor,
    required this.showOutline,
    required this.outlineColor,
    required this.outlineWidth,
  });

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final v = _clamp01(value);

    // Базовый треугольник:
    // нижняя грань горизонтально (0,h) -> (w,h)
    // правая грань вертикально (w,h) -> (w,0)
    // гипотенуза (0,h) -> (w,0)
    final baseTriangle = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();

    final trackPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = trackColor;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = fillColor;

    // Серый трек
    canvas.drawPath(baseTriangle, trackPaint);

    // Красная заливка: растёт слева -> вправо
    final xFill = (w * v).clamp(0.0, w);

    // y на гипотенузе: y = h - (h/w)*x
    final yOnHypotenuse = h - (h / math.max(w, 0.0001)) * xFill;

    // Левый клин: A(0,h) -> (xFill,h) -> (xFill, yOnHypotenuse)
    final fillTriangle = Path()
      ..moveTo(0, h)
      ..lineTo(xFill, h)
      ..lineTo(xFill, yOnHypotenuse)
      ..close();

    // Клип по базе, чтобы никогда не “вылезало” за треугольник
    canvas.save();
    canvas.clipPath(baseTriangle);
    canvas.drawPath(fillTriangle, fillPaint);
    canvas.restore();

    if (showOutline) {
      final outlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..isAntiAlias = true
        ..color = outlineColor;

      canvas.drawPath(baseTriangle, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TriangleVolumePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.showOutline != showOutline ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.outlineWidth != outlineWidth;
  }
}
