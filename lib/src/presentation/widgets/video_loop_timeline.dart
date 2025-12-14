import 'package:flutter/material.dart';

/// Сложный ползунок для видео:
/// - один общий трек 0..1
/// - два маркера начала/конца петли (loopStart/loopEnd)
/// - один маркер текущей позиции (position)
///
/// Внешнее управление:
///   position   — текущее время (0..1)
///   loopStart  — начало петли (0..1)
///   loopEnd    — конец петли (0..1)
///
/// Обратная связь:
///   onPositionChanged(frac)
///   onLoopChanged(RangeValues(start, end))
class VideoLoopTimeline extends StatefulWidget {
  /// Текущая позиция проигрывания (0..1)
  final double position;

  /// Начало петли (0..1)
  final double loopStart;

  /// Конец петли (0..1)
  final double loopEnd;

  /// Минимальная длина петли (в долях 0..1).
  /// По умолчанию 0.001 (0.1% длины). Можно передать 0, чтобы отключить ограничение.
  final double minLoopSpan;

  /// Слушатель изменения позиции
  final ValueChanged<double>? onPositionChanged;

  /// Слушатель изменения начала/конца петли
  final ValueChanged<RangeValues>? onLoopChanged;

  /// Высота виджета
  final double height;

  const VideoLoopTimeline({
    Key? key,
    required this.position,
    required this.loopStart,
    required this.loopEnd,
    this.onPositionChanged,
    this.onLoopChanged,
    this.minLoopSpan = 0.001,
    this.height = 32.0,
  }) : super(key: key);

  @override
  State<VideoLoopTimeline> createState() => _VideoLoopTimelineState();
}

class _VideoLoopTimelineState extends State<VideoLoopTimeline> {
  late double _position;
  late double _loopStart;
  late double _loopEnd;

  bool _isDragging = false;

  /// Что сейчас двигаем
  _DragTarget _dragTarget = _DragTarget.none;

  double get _minSpan =>
      widget.minLoopSpan <= 0 ? 0.0 : widget.minLoopSpan.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _position = widget.position.clamp(0.0, 1.0);
    _loopStart = widget.loopStart.clamp(0.0, 1.0);
    _loopEnd = widget.loopEnd.clamp(0.0, 1.0);
    _normalize();
  }

  @override
  void didUpdateWidget(covariant VideoLoopTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если не тянем мышью — синхронизируемся с родителем как есть
    if (!_isDragging) {
      _position = widget.position.clamp(0.0, 1.0);
      _loopStart = widget.loopStart.clamp(0.0, 1.0);
      _loopEnd = widget.loopEnd.clamp(0.0, 1.0);
      _normalize();
    }
  }

  void _normalize() {
    // Держим значения в диапазоне 0..1
    _loopStart = _loopStart.clamp(0.0, 1.0);
    _loopEnd = _loopEnd.clamp(0.0, 1.0);
    _position = _position.clamp(0.0, 1.0);

    // Если приходит странное состояние (start > end) — просто меняем местами.
    if (_loopEnd < _loopStart) {
      final tmp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = tmp;
    }
    // ВАЖНО: здесь НЕ двигаем другой конец диапазона.
    // Ограничение по минимальной длине реализуем только в onPanUpdate
    // для конкретной тянущейся ручки, чтобы не было "подпрыгиваний".
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final dx = local.dx.clamp(0.0, width);

            final startX = _loopStart * width;
            final endX = _loopEnd * width;
            final posX = _position * width;

            const handleRadius = 8.0;

            final distToStart = (dx - startX).abs();
            final distToEnd = (dx - endX).abs();
            final distToPos = (dx - posX).abs();

            _isDragging = true;

            // Решаем, что тянем:
            if (distToStart <= distToEnd &&
                distToStart <= distToPos &&
                distToStart <= handleRadius * 1.6) {
              _dragTarget = _DragTarget.loopStart;
            } else if (distToEnd <= distToPos &&
                distToEnd <= handleRadius * 1.6) {
              _dragTarget = _DragTarget.loopEnd;
            } else if (distToPos <= handleRadius * 1.6) {
              _dragTarget = _DragTarget.position;
            } else {
              // Клик по треку — переносим позицию (scrub)
              final frac = (dx / width).clamp(0.0, 1.0);
              setState(() {
                _position = frac;
                _normalize();
              });
              if (widget.onPositionChanged != null) {
                widget.onPositionChanged!(_position);
              }
              _dragTarget = _DragTarget.position;
            }
          },
          onPanUpdate: (details) {
            if (_dragTarget == _DragTarget.none) return;

            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final x = local.dx.clamp(0.0, width);
            final frac = (x / width).clamp(0.0, 1.0);

            setState(() {
              if (_dragTarget == _DragTarget.position) {
                // Просто двигаем позицию, без влияния на петлю
                _position = frac.clamp(0.0, 1.0);
              } else if (_dragTarget == _DragTarget.loopStart) {
                // Двигаем только начало петли.
                double newStart = frac.clamp(0.0, 1.0);

                if (_minSpan > 0) {
                  // Не даём start зайти слишком близко к end
                  final maxStart = (_loopEnd - _minSpan).clamp(0.0, 1.0);
                  if (newStart > maxStart) {
                    newStart = maxStart;
                  }
                }

                _loopStart = newStart;
              } else if (_dragTarget == _DragTarget.loopEnd) {
                // Двигаем только конец петли.
                double newEnd = frac.clamp(0.0, 1.0);

                if (_minSpan > 0) {
                  // Не даём end зайти слишком близко к start
                  final minEnd = (_loopStart + _minSpan).clamp(0.0, 1.0);
                  if (newEnd < minEnd) {
                    newEnd = minEnd;
                  }
                }

                _loopEnd = newEnd;
              }

              _normalize();
            });

            // Коллбеки наружу
            if (_dragTarget == _DragTarget.position &&
                widget.onPositionChanged != null) {
              widget.onPositionChanged!(_position);
            }

            if ((_dragTarget == _DragTarget.loopStart ||
                    _dragTarget == _DragTarget.loopEnd) &&
                widget.onLoopChanged != null) {
              widget.onLoopChanged!(RangeValues(_loopStart, _loopEnd));
            }
          },
          onPanEnd: (_) {
            _isDragging = false;
            _dragTarget = _DragTarget.none;
          },
          onPanCancel: () {
            _isDragging = false;
            _dragTarget = _DragTarget.none;
          },
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              painter: _VideoLoopTimelinePainter(
                position: _position,
                loopStart: _loopStart,
                loopEnd: _loopEnd,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _DragTarget {
  none,
  position,
  loopStart,
  loopEnd,
}

class _VideoLoopTimelinePainter extends CustomPainter {
  final double position;
  final double loopStart;
  final double loopEnd;

  _VideoLoopTimelinePainter({
    required this.position,
    required this.loopStart,
    required this.loopEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final centerY = size.height / 2;

    final trackPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final loopPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final positionPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2;

    // Общий трек 0..1
    canvas.drawLine(
      Offset(0, centerY),
      Offset(width, centerY),
      trackPaint,
    );

    // Участок петли
    final loopStartX = loopStart * width;
    final loopEndX = loopEnd * width;
    canvas.drawLine(
      Offset(loopStartX, centerY),
      Offset(loopEndX, centerY),
      loopPaint,
    );

    // Маркеры начала/конца петли (кружки)
    const handleRadius = 6.0;
    canvas.drawCircle(Offset(loopStartX, centerY), handleRadius, handlePaint);
    canvas.drawCircle(Offset(loopEndX, centerY), handleRadius, handlePaint);

    // Текущая позиция (вертикальная линия + маленькая точка)
    final posX = position * width;
    canvas.drawLine(
      Offset(posX, centerY - 10),
      Offset(posX, centerY + 10),
      positionPaint,
    );
    canvas.drawCircle(
      Offset(posX, centerY),
      3.0,
      positionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoLoopTimelinePainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.loopStart != loopStart ||
        oldDelegate.loopEnd != loopEnd;
  }
}
