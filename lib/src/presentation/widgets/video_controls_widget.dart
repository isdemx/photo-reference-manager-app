import 'package:flutter/material.dart';
import 'video_loop_timeline.dart';

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

class VideoControls extends StatelessWidget {
  /// значения в долях длительности (0..1)
  final double startFrac; // где начинается диапазон
  final double endFrac;   // где заканчивается диапазон
  final double positionFrac; // текущая позиция

  /// колбэки времени
  final ValueChanged<double> onSeekFrac;          // изменение текущей позиции
  final ValueChanged<RangeValues> onChangeRange;  // изменение диапазона (start/end)

  /// громкость / скорость
  final ValueChanged<double> onChangeVolume; // 0..1
  final ValueChanged<double> onChangeSpeed;  // 0.1..4.0

  final double volume; // 0..1
  final double speed;  // 0.1..4.0

  /// Полная длительность видео — сейчас не используется внутри,
  /// но сохраняем для совместимости сигнатуры.
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

  SliderThemeData _sliderTheme(BuildContext context) {
    final base = SliderTheme.of(context);
    return base.copyWith(
      trackHeight: 3,
      thumbShape: const RectThumbShape(),
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayColor: Colors.white12,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
    );
  }

  String _fmtSpeed(double v) {
      return '${v.round()}×';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _sliderTheme(context);
    final volPct = (volume.clamp(0, 1) * 100).round();
    final speedStr = _fmtSpeed(speed);

    final start = startFrac.clamp(0.0, 1.0);
    final end = endFrac.clamp(0.0, 1.0);
    final pos = positionFrac.clamp(0.0, 1.0);

    return SizedBox(
      height: 80, // общая высота панели с ползунками
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // СЛЕВА — общий комбинированный ползунок,
          // занимает всё свободное место по ширине.
          Expanded(
            child: VideoLoopTimeline(
              position: pos,
              loopStart: start,
              loopEnd: end,
              onPositionChanged: onSeekFrac,
              onLoopChanged: onChangeRange,
              height: 32.0,
            ),
          ),

          const SizedBox(width: 8),

          // СПРАВА — вертикальная громкость
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$volPct%',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 60,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: theme,
                    child: Slider(
                      min: 0,
                      max: 1,
                      divisions: 10,
                      value: volume.clamp(0, 1),
                      onChanged: onChangeVolume,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // СПРАВА — вертикальная скорость
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedStr,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 60,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: theme,
                    child: Slider(
                      min: 0.1,
                      max: 4.0,
                      divisions: 39, // ~0.1x
                      value: speed.clamp(0.1, 4.0),
                      onChanged: (v) =>
                          onChangeSpeed(double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
