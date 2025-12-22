import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Компактный слайдер: тонкий трек, подпись + значение, двойной тап — сброс к центру
class MiniSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final double centerValue;
  final ValueChanged<double> onChanged;
  final String Function(double v)? format;

  const MiniSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.centerValue,
    required this.onChanged,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final txt = (format ?? ((v) => v.toStringAsFixed(2)))(value);

    final bool isIOS = Platform.isIOS;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок + значение
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text(txt,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 2),
        // Сам слайдер + «магнит» к центру
        GestureDetector(
          onDoubleTap: () => onChanged(centerValue),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white12,
              tickMarkShape:
                  const RoundSliderTickMarkShape(tickMarkRadius: 0.0),
            ),
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value.clamp(min, max),
              onChanged: (v) {
                // «магнит» к центру (3% диапазона)
                final threshold = (max - min) * 0.03;
                if ((v - centerValue).abs() < threshold) {
                  onChanged(centerValue);
                } else {
                  onChanged(v);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}