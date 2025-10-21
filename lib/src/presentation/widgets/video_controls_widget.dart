import 'package:flutter/material.dart';

/// Узкий прямоугольный слайдер-thumb для обычного Slider.
class RectThumbShape extends SliderComponentShape {
  final Size size;
  const RectThumbShape({this.size = const Size(4, 18)});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      const Radius.circular(2),
    );
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = PaintingStyle.fill;
    context.canvas.drawRRect(rrect, paint);
  }
}

/// Прямоугольные “палочки” для RangeSlider — сигнатура paint под Flutter stable.
class RectRangeThumbShape extends RangeSliderThumbShape {
  final Size size;
  const RectRangeThumbShape({this.size = const Size(4, 18)});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = true,
    bool isOnTop = false,
    bool isPressed = false,
    required SliderThemeData sliderTheme,
    TextDirection textDirection = TextDirection.ltr,
    Thumb thumb = Thumb.start,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      const Radius.circular(2),
    );
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = PaintingStyle.fill;
    context.canvas.drawRRect(rrect, paint);
  }
}

class VideoControls extends StatefulWidget {
  /// значения в долях длительности (0..1)
  final double startFrac;       // где начинается диапазон
  final double endFrac;         // где заканчивается
  final double positionFrac;    // текущая позиция

  final ValueChanged<double> onSeekFrac;          // верхняя линия (позиция)
  final ValueChanged<RangeValues> onChangeRange;  // нижняя линия (диапазон)
  final ValueChanged<double> onChangeVolume;      // 0..1
  final ValueChanged<double> onChangeSpeed;       // 0.1..4.0

  final double volume;          // 0..1
  final double speed;           // 0.1..4.0

  /// Полная длительность видео — нужна для перевода секунд в доли
  final Duration? totalDuration;

  const VideoControls({
    Key? key,
    required this.startFrac,
    required this.endFrac,
    required this.positionFrac,
    required this.onSeekFrac,
    required this.onChangeRange,
    required this.onChangeVolume,
    required this.onChangeSpeed,
    required this.volume,
    required this.speed,
    this.totalDuration,
  }) : super(key: key);

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  // Для распознавания “короткого клика” по бегунку диапазона
  Offset? _downLocalOnRange;
  DateTime? _downAtOnRange;
  bool _movedOnRange = false;
  Thumb? _pressedThumb; // какой бегунок кликнули (для UX), но логика всегда фиксит end

  SliderThemeData _theme(BuildContext context) {
    final base = SliderTheme.of(context);
    return base.copyWith(
      trackHeight: 3,
      thumbShape: const RectThumbShape(),
      rangeThumbShape: const RectRangeThumbShape(),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayColor: Colors.white12,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
    );
  }

  String _fmtSpeed(double v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return '$s×';
  }

  /// Применить короткий диапазон: всегда **фиксируем start** и двигаем только end.
  void _applyShortRangeSeconds(double seconds) {
    final total = widget.totalDuration ?? Duration.zero;
    if (total == Duration.zero) return;

    const minWidth = 0.001; // минимальная ширина в долях
    final start = widget.startFrac.clamp(0.0, 1.0);

    final fracDelta = (seconds * 1000.0) / total.inMilliseconds;
    if (fracDelta <= 0) return;

    final desiredEnd = start + fracDelta;
    final newEnd = desiredEnd.clamp(start + minWidth, 1.0);
    widget.onChangeRange(RangeValues(start, newEnd));
  }

  /// Диалог с инпутом: показывает текущую длину лупа, применяет изменения лайвом.
  Future<void> _showShortRangeDialogAndApply() async {
    final total = widget.totalDuration ?? Duration.zero;
    if (total == Duration.zero) return;

    final start = widget.startFrac.clamp(0.0, 1.0);
    final end = widget.endFrac.clamp(0.0, 1.0);
    final loopSecs = ((end - start) * total.inMilliseconds) / 1000.0;

    String val = loopSecs.isFinite && loopSecs > 0
        ? loopSecs.toStringAsFixed(loopSecs >= 1 ? 2 : 3)
        : '1.0';

    final controller = TextEditingController(text: val);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? error;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void liveApply(String text) {
              final s = double.tryParse(text.replaceAll(',', '.'));
              if (s == null || s <= 0) {
                setLocal(() => error = 'Enter a positive number');
              } else {
                setLocal(() => error = null);
                // лайв-обновление: меняем только END
                _applyShortRangeSeconds(s);
              }
            }

            return AlertDialog(
              title: const Text('Short range (seconds)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g. 0.3, 1, 2.5',
                      errorText: error,
                    ),
                    onChanged: liveApply,
                    onSubmitted: (_) => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'END = START + seconds',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(context);
    final volPct = (widget.volume.clamp(0, 1) * 100).round();
    final speedStr = _fmtSpeed(widget.speed.clamp(0.1, 4.0));

    final start = widget.startFrac.clamp(0, 1);
    final end = widget.endFrac.clamp(0, 1);
    final range = RangeValues(start.toDouble(), end.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Верхняя — позиция (scrub)
        SliderTheme(
          data: theme,
          child: Slider(
            min: 0,
            max: 1,
            value: widget.positionFrac.clamp(0, 1),
            onChanged: widget.onSeekFrac,
          ),
        ),
        const SizedBox(height: 6),

        // Нижняя — диапазон (range) + детектор клика по бегунку
        LayoutBuilder(
          builder: (ctx, constraints) {
            Thumb _nearestThumb(Offset local) {
              final w = constraints.maxWidth;
              if (w <= 0) return Thumb.start;
              final fx = (local.dx / w).clamp(0.0, 1.0);
              final dStart = (fx - range.start).abs();
              final dEnd = (fx - range.end).abs();
              return (dStart <= dEnd) ? Thumb.start : Thumb.end;
            }

            void _resetClickState() {
              _downLocalOnRange = null;
              _downAtOnRange = null;
              _movedOnRange = false;
              _pressedThumb = null;
            }

            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                _downLocalOnRange = box.globalToLocal(e.position);
                _downAtOnRange = DateTime.now();
                _movedOnRange = false;
                _pressedThumb = _nearestThumb(_downLocalOnRange!);
              },
              onPointerMove: (e) {
                if (_downLocalOnRange == null) return;
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final nowLocal = box.globalToLocal(e.position);
                if ((nowLocal - _downLocalOnRange!).distance > 6) {
                  _movedOnRange = true;
                }
              },
              onPointerUp: (e) async {
                final down = _downAtOnRange;
                final wasMoved = _movedOnRange;
                _resetClickState();

                // Короткий клик (без движения) — показываем ввод секунд.
                if (down != null && !wasMoved) {
                  final elapsed = DateTime.now().difference(down);
                  if (elapsed.inMilliseconds <= 300) {
                    await _showShortRangeDialogAndApply();
                  }
                }
              },
              onPointerCancel: (_) => _resetClickState(),
              child: SliderTheme(
                data: theme,
                child: RangeSlider(
                  min: 0,
                  max: 1,
                  values: range,
                  onChanged: (rv) {
                    const minW = 0.001;
                    final s = rv.start;
                    final e = rv.end <= s + minW ? (s + minW) : rv.end;
                    widget.onChangeRange(RangeValues(s, e.clamp(0, 1)));
                  },
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Громкость + скорость
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Volume: $volPct%',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  SliderTheme(
                    data: theme,
                    child: Slider(
                      min: 0,
                      max: 1,
                      divisions: 10,
                      value: widget.volume.clamp(0, 1),
                      onChanged: widget.onChangeVolume,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Speed: $speedStr',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  SliderTheme(
                    data: theme,
                    child: Slider(
                      min: 0.1,
                      max: 4.0,
                      divisions: 39, // ~0.1x
                      value: widget.speed.clamp(0.1, 4.0),
                      onChanged: (v) => widget.onChangeSpeed(
                        double.parse(v.toStringAsFixed(2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
