import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

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
    super.key,
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
    final appColors = context.appThemeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(color: appColors.subtle, fontSize: 11)),
            const Spacer(),
            Text(txt,
                style: TextStyle(
                    color: appColors.text,
                    fontSize: 11,
                    fontFeatures: [ui.FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 1),
        GestureDetector(
          onDoubleTap: () => onChanged(centerValue),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 1.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: appColors.text,
              inactiveTrackColor:
                  appColors.border.withValues(alpha: isDark ? 0.9 : 0.7),
              thumbColor: appColors.text,
              overlayColor:
                  appColors.surfaceAlt.withValues(alpha: isDark ? 0.18 : 0.12),
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
