import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';

class CollageDrawingPainter extends CustomPainter {
  const CollageDrawingPainter({
    required this.strokes,
  });

  static const double _renderWidthScale = 0.5;

  final List<CollageDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width * _renderWidthScale
        ..isAntiAlias = true
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
        ..color = Color(stroke.colorValue).withValues(
          alpha: stroke.opacity.clamp(0.0, 1.0),
        );

      if (stroke.tool == CollageDrawingStroke.toolBrush && !stroke.isEraser) {
        _drawBrushStroke(canvas, stroke, paint);
      } else {
        final points = _pointsFromValues(stroke.pointValues);
        if (points.length < 2) continue;
        canvas.drawPath(_smoothPath(points), paint);
      }
    }
    canvas.restore();
  }

  static List<Offset> _pointsFromValues(List<double> values) {
    final points = <Offset>[];
    for (var i = 0; i + 1 < values.length; i += 2) {
      points.add(Offset(values[i], values[i + 1]));
    }
    return points;
  }

  static List<_BrushPoint> _brushPointsFromValues(List<double> values) {
    final points = <_BrushPoint>[];
    for (var i = 0; i + 2 < values.length; i += 3) {
      points.add(_BrushPoint(
        Offset(values[i], values[i + 1]),
        values[i + 2],
      ));
    }
    return points;
  }

  static void _drawBrushStroke(
    Canvas canvas,
    CollageDrawingStroke stroke,
    Paint basePaint,
  ) {
    final points = _brushPointsFromValues(stroke.pointValues);
    if (points.length < 2) return;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final width = ((a.width + b.width) / 2) * _renderWidthScale;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..isAntiAlias = true
        ..blendMode = basePaint.blendMode
        ..color = basePaint.color;
      canvas.drawLine(a.offset, b.offset, paint);
    }
  }

  static Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant CollageDrawingPainter oldDelegate) {
    return true;
  }
}

class _BrushPoint {
  const _BrushPoint(this.offset, this.width);

  final Offset offset;
  final double width;
}
