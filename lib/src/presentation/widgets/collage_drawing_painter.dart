import 'dart:math' as math;

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

      switch (stroke.tool) {
        case CollageDrawingStroke.toolBrush:
          if (stroke.isEraser) {
            _drawSimpleStroke(canvas, stroke, paint);
          } else {
            _drawBrushStroke(canvas, stroke, paint);
          }
        case CollageDrawingStroke.toolGraffiti:
          if (stroke.isEraser) {
            _drawSimpleStroke(canvas, stroke, paint);
          } else {
            _drawGraffitiStroke(canvas, stroke, paint);
          }
        case CollageDrawingStroke.toolNeon:
          if (stroke.isEraser) {
            _drawSimpleStroke(canvas, stroke, paint);
          } else {
            _drawNeonStroke(canvas, stroke, paint);
          }
        case CollageDrawingStroke.toolHighlighter:
          _drawHighlighterStroke(canvas, stroke, paint);
        case CollageDrawingStroke.toolArrow:
          _drawArrowStroke(canvas, stroke, paint);
        case CollageDrawingStroke.toolPencil:
        default:
          _drawSimpleStroke(canvas, stroke, paint);
      }
    }
    canvas.restore();
  }

  static void _drawSimpleStroke(
    Canvas canvas,
    CollageDrawingStroke stroke,
    Paint paint,
  ) {
    final points = _pointsFromValues(stroke.pointValues);
    if (points.length < 2) return;
    canvas.drawPath(_smoothPath(points), paint);
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

  static void _drawGraffitiStroke(
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
      final direction = b.offset - a.offset;
      final normal = direction.distance == 0
          ? Offset.zero
          : Offset(-direction.dy, direction.dx) / direction.distance;
      final wobble = ((i % 5) - 2) * width * 0.16;

      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 2.2
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver
        ..color = basePaint.color.withValues(
          alpha: basePaint.color.a * 0.18,
        );
      canvas.drawLine(a.offset, b.offset, shadowPaint);

      final bodyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 1.22
        ..isAntiAlias = true
        ..blendMode = basePaint.blendMode
        ..color = basePaint.color.withValues(
          alpha: (basePaint.color.a * 0.88).clamp(0.0, 1.0),
        );
      canvas.drawLine(a.offset, b.offset, bodyPaint);

      final edgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 0.38
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver
        ..color = basePaint.color.withValues(
          alpha: basePaint.color.a * 0.28,
        );
      final edgeOffset = normal * wobble;
      canvas.drawLine(a.offset + edgeOffset, b.offset + edgeOffset, edgePaint);
    }
  }

  static void _drawNeonStroke(
    Canvas canvas,
    CollageDrawingStroke stroke,
    Paint basePaint,
  ) {
    final points = _brushPointsFromValues(stroke.pointValues);
    if (points.length < 2) return;

    for (final multiplier in const [5.0, 3.0, 1.8]) {
      for (var i = 0; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];
        final width = ((a.width + b.width) / 2) * _renderWidthScale;
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width * multiplier
          ..isAntiAlias = true
          ..blendMode = BlendMode.plus
          ..color = basePaint.color.withValues(
            alpha: basePaint.color.a * (0.07 + 0.04 / multiplier),
          );
        canvas.drawLine(a.offset, b.offset, glowPaint);
      }
    }

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final width = ((a.width + b.width) / 2) * _renderWidthScale;
      final bodyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 0.9
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver
        ..color = basePaint.color;
      canvas.drawLine(a.offset, b.offset, bodyPaint);

      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 0.28
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver
        ..color = Colors.white.withValues(
          alpha: basePaint.color.a * 0.72,
        );
      canvas.drawLine(a.offset, b.offset, corePaint);
    }
  }

  static void _drawHighlighterStroke(
    Canvas canvas,
    CollageDrawingStroke stroke,
    Paint basePaint,
  ) {
    final points = _pointsFromValues(stroke.pointValues);
    if (points.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.width * _renderWidthScale * 3.2
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver
      ..color = basePaint.color.withValues(
        alpha: basePaint.color.a * 0.34,
      );
    canvas.drawPath(_smoothPath(points), paint);
  }

  static void _drawArrowStroke(
    Canvas canvas,
    CollageDrawingStroke stroke,
    Paint basePaint,
  ) {
    final points = _pointsFromValues(stroke.pointValues);
    if (points.length < 2) return;
    canvas.drawPath(_smoothPath(points), basePaint);

    final end = points.last;
    Offset? previous;
    for (var i = points.length - 2; i >= 0; i--) {
      if ((end - points[i]).distance >= 0.5) {
        previous = points[i];
        break;
      }
    }
    if (previous == null) return;

    final direction = end - previous;
    if (direction.distance == 0) return;
    final angle = direction.direction;
    final headLength = (basePaint.strokeWidth * 5.5).clamp(7.0, 34.0);
    final wingAngle = 0.68;
    final left = end -
        Offset(
              math.cos(angle - wingAngle),
              math.sin(angle - wingAngle),
            ) *
            headLength;
    final right = end -
        Offset(
              math.cos(angle + wingAngle),
              math.sin(angle + wingAngle),
            ) *
            headLength;
    canvas.drawLine(end, left, basePaint);
    canvas.drawLine(end, right, basePaint);
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
