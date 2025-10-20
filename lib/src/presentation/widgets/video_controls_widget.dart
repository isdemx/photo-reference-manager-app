import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Узкий прямоугольный слайдер-thumb для обычного Slider/RangeSlider.
class RectThumbShape extends SliderComponentShape {
  final Size size;
  const RectThumbShape({this.size = const Size(4, 18)}); // тонкая палка

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

/// Прямоугольные “палочки” для RangeSlider — СТАРАЯ сигнатура paint().
class RectRangeThumbShape extends RangeSliderThumbShape {
  final Size size;
  const RectRangeThumbShape({this.size = const Size(4, 18)});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => size;

  // ⬇⬇⬇ ВАЖНО: сигнатура соответствует ожидаемой в твоём SDK
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
  final double startFrac; // где начинается диапазон
  final double endFrac; // где заканчивается
  final double positionFrac; // текущая позиция

  final ValueChanged<double> onSeekFrac; // верхняя линия (позиция)
  final ValueChanged<RangeValues> onChangeRange; // нижняя линия (диапазон)
  final ValueChanged<double> onChangeVolume; // 0..1
  final ValueChanged<double> onChangeSpeed; // 0.1..4.0

  final double volume; // 0..1
  final double speed; // 0.1..4.0

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
  }) : super(key: key);

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
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
    // 1.0 -> "1×", 1.25 -> "1.25×", 2 -> "2×"
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return '$s×';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(context);
    final volPct = (widget.volume.clamp(0, 1) * 100).round();
    final speedStr = _fmtSpeed(widget.speed.clamp(0.1, 4.0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // верхняя — позиция (scrub)
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

        // нижняя — диапазон (range)
        SliderTheme(
          data: theme,
          child: RangeSlider(
            min: 0,
            max: 1,
            values: RangeValues(
              widget.startFrac.clamp(0, 1),
              widget.endFrac.clamp(0, 1),
            ),
            onChanged: (rv) {
              const minWidth = 0.001;
              final start = rv.start;
              final end =
                  rv.end <= start + minWidth ? (start + minWidth) : rv.end;
              widget.onChangeRange(RangeValues(start, end.clamp(0, 1)));
            },
          ),
        ),

        const SizedBox(height: 8),

        // громкость + скорость
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
