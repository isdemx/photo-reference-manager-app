import 'package:flutter/material.dart';
import 'triangle_volume_slider_widget.dart';

class VideoControls extends StatelessWidget {
  /// значения в долях длительности (0..1)
  final double startFrac; // где начинается диапазон
  final double endFrac;   // где заканчивается диапазон
  final double positionFrac; // текущая позиция

  /// колбэки времени
  final ValueChanged<double> onSeekFrac;          // изменение текущей позиции
  final ValueChanged<RangeValues>? onChangeRange;  // изменение диапазона (start/end)

  /// громкость / скорость
  final ValueChanged<double>? onChangeVolume; // 0..1
  final ValueChanged<double>? onChangeSpeed;  // 0.1..4.0

  final double volume; // 0..1
  final double speed;  // 0.1..4.0

  final bool showLoopRange;
  final bool showVolume;
  final bool showSpeed;

  /// Полная длительность видео — сейчас не используется внутри,
  /// но сохраняем для совместимости сигнатуры.
  final Duration? totalDuration;

  const VideoControls({
    Key? key,
    required this.startFrac,
    required this.endFrac,
    required this.positionFrac,
    required this.onSeekFrac,
    this.onChangeRange,
    this.onChangeVolume,
    this.onChangeSpeed,
    required this.volume,
    required this.speed,
    this.showLoopRange = true,
    this.showVolume = true,
    this.showSpeed = true,
    this.totalDuration,
  })  : assert(!showLoopRange || onChangeRange != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final showVol = showVolume && onChangeVolume != null;
    final showSpd = showSpeed && onChangeSpeed != null;
    const speedMin = 0.1;
    const speedMax = 4.0;
    const speedMid = 1.0;
    final speed01 = _speedToFrac(speed, speedMin, speedMid, speedMax);

    final start = startFrac.clamp(0.0, 1.0);
    final end = endFrac.clamp(0.0, 1.0);
    final pos = positionFrac.clamp(0.0, 1.0);

    return SizedBox(
      height: 34, // компактная панель, чтобы не съедать место у видео
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // СЛЕВА — единая линия: позиция + (опционально) диапазон петли.
            Expanded(
              child: _VideoLoopTimeline(
                position: pos,
                loopStart: start,
                loopEnd: end,
                onPositionChanged: onSeekFrac,
                onLoopChanged: showLoopRange ? onChangeRange : null,
                enableLoopHandles: showLoopRange,
                height: 22.0,
              ),
            ),

            if (showVol) ...[
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 22,
                    child: TriangleVolumeSlider(
                      value: volume.clamp(0, 1),
                      onChanged: onChangeVolume!,
                      width: 20,
                      height: 16,
                      hitHeight: 22,
                    ),
                  ),
                ],
              ),
            ],
            if (showSpd) ...[
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 22,
                    child: TriangleVolumeSlider(
                      value: speed01,
                      labelBuilder: (v01) {
                        final value =
                            _fracToSpeed(v01, speedMin, speedMid, speedMax);
                        return '${value.toStringAsFixed(1)}';
                      },
                      onChanged: (v01) {
                        final next =
                            _fracToSpeed(v01, speedMin, speedMid, speedMax);
                        onChangeSpeed!(double.parse(next.toStringAsFixed(2)));
                      },
                      width: 20,
                      height: 16,
                      hitHeight: 22,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

double _speedToFrac(double speed, double min, double mid, double max) {
  final clamped = speed.clamp(min, max);
  if (clamped <= mid) {
    final t = (clamped - min) / (mid - min);
    return (t * 0.5).clamp(0.0, 0.5);
  }
  final t = (clamped - mid) / (max - mid);
  return (0.5 + t * 0.5).clamp(0.5, 1.0);
}

double _fracToSpeed(double frac, double min, double mid, double max) {
  final f = frac.clamp(0.0, 1.0);
  if (f <= 0.5) {
    final t = f / 0.5;
    return min + t * (mid - min);
  }
  final t = (f - 0.5) / 0.5;
  return mid + t * (max - mid);
}

enum _DragTarget {
  none,
  position,
  loopStart,
  loopEnd,
}

class _VideoLoopTimeline extends StatefulWidget {
  final double position;
  final double loopStart;
  final double loopEnd;
  final double minLoopSpan;
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<RangeValues>? onLoopChanged;
  final double height;
  final bool enableLoopHandles;

  const _VideoLoopTimeline({
    required this.position,
    required this.loopStart,
    required this.loopEnd,
    this.onPositionChanged,
    this.onLoopChanged,
    this.minLoopSpan = 0.001,
    this.height = 32.0,
    this.enableLoopHandles = true,
  });

  @override
  State<_VideoLoopTimeline> createState() => _VideoLoopTimelineState();
}

class _VideoLoopTimelineState extends State<_VideoLoopTimeline> {
  late double _position;
  late double _loopStart;
  late double _loopEnd;

  bool _isDragging = false;
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
  void didUpdateWidget(covariant _VideoLoopTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _position = widget.position.clamp(0.0, 1.0);
      _loopStart = widget.loopStart.clamp(0.0, 1.0);
      _loopEnd = widget.loopEnd.clamp(0.0, 1.0);
      _normalize();
    }
  }

  void _normalize() {
    _loopStart = _loopStart.clamp(0.0, 1.0);
    _loopEnd = _loopEnd.clamp(0.0, 1.0);
    _position = _position.clamp(0.0, 1.0);
    if (_loopEnd < _loopStart) {
      final tmp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = tmp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        const handleHit = 10.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final dx = local.dx.clamp(0.0, width);
            final frac = (dx / width).clamp(0.0, 1.0);
            setState(() {
              _position = frac;
              _normalize();
            });
            widget.onPositionChanged?.call(_position);
          },
          onPanStart: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final dx = local.dx.clamp(0.0, width);

            final startX = _loopStart * width;
            final endX = _loopEnd * width;
            final posX = _position * width;

            final distToStart = (dx - startX).abs();
            final distToEnd = (dx - endX).abs();
            final distToPos = (dx - posX).abs();

            _isDragging = true;

            if (widget.enableLoopHandles &&
                distToStart <= distToEnd &&
                distToStart <= distToPos &&
                distToStart <= handleHit) {
              _dragTarget = _DragTarget.loopStart;
            } else if (widget.enableLoopHandles &&
                distToEnd <= distToPos &&
                distToEnd <= handleHit) {
              _dragTarget = _DragTarget.loopEnd;
            } else if (distToPos <= handleHit) {
              _dragTarget = _DragTarget.position;
            } else {
              final frac = (dx / width).clamp(0.0, 1.0);
              setState(() {
                _position = frac;
                _normalize();
              });
              widget.onPositionChanged?.call(_position);
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
                _position = frac.clamp(0.0, 1.0);
              } else if (_dragTarget == _DragTarget.loopStart) {
                double newStart = frac.clamp(0.0, 1.0);
                if (_minSpan > 0) {
                  final maxStart = (_loopEnd - _minSpan).clamp(0.0, 1.0);
                  if (newStart > maxStart) {
                    newStart = maxStart;
                  }
                }
                _loopStart = newStart;
              } else if (_dragTarget == _DragTarget.loopEnd) {
                double newEnd = frac.clamp(0.0, 1.0);
                if (_minSpan > 0) {
                  final minEnd = (_loopStart + _minSpan).clamp(0.0, 1.0);
                  if (newEnd < minEnd) {
                    newEnd = minEnd;
                  }
                }
                _loopEnd = newEnd;
              }
              _normalize();
            });

            if (_dragTarget == _DragTarget.position) {
              widget.onPositionChanged?.call(_position);
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
                showLoopHandles: widget.enableLoopHandles,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoLoopTimelinePainter extends CustomPainter {
  final double position;
  final double loopStart;
  final double loopEnd;
  final bool showLoopHandles;

  _VideoLoopTimelinePainter({
    required this.position,
    required this.loopStart,
    required this.loopEnd,
    required this.showLoopHandles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final centerY = size.height / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final tailPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final handlePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Общий трек: белый, сверху рисуем прогресс красным.
    canvas.drawLine(
      Offset(0, centerY),
      Offset(width, centerY),
      trackPaint,
    );

    final posX = position * width;
    final loopEndX = loopEnd * width;
    final progressEndX = posX < loopEndX ? posX : loopEndX;
    final progressPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(progressEndX, centerY),
      progressPaint,
    );

    // После loopEnd — яркий хвост, чтобы явно отличался от белого.
    canvas.drawLine(
      Offset(loopEndX, centerY),
      Offset(width, centerY),
      tailPaint,
    );

    // Ручки старта/конца — прямоугольники без кругляшей.
    if (showLoopHandles) {
      const handleW = 4.0;
      const handleH = 12.0;
      final loopStartX = loopStart * width;
      final loopEndX = loopEnd * width;
      final rectStart = Rect.fromCenter(
        center: Offset(loopStartX, centerY),
        width: handleW,
        height: handleH,
      );
      final rectEnd = Rect.fromCenter(
        center: Offset(loopEndX, centerY),
        width: handleW,
        height: handleH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectStart, const Radius.circular(1)),
        handlePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectEnd, const Radius.circular(1)),
        handlePaint,
      );
    }

    // Текущая позиция — вертикальная линия.
    final posPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    const posW = 2.0;
    const posH = 3.0; // равен толщине линии, чтобы не выступал
    final posRect = Rect.fromCenter(
      center: Offset(posX, centerY),
      width: posW,
      height: posH,
    );
    canvas.drawRect(posRect, posPaint);
  }

  @override
  bool shouldRepaint(covariant _VideoLoopTimelinePainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.loopStart != loopStart ||
        oldDelegate.loopEnd != loopEnd ||
        oldDelegate.showLoopHandles != showLoopHandles;
  }
}
