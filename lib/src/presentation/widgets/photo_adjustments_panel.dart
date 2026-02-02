import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/action_icon_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/mini_slider_widget.dart';

class PhotoAdjustmentsPanel extends StatelessWidget {
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onFlipX;
  final VoidCallback? onFlipY;
  final VoidCallback? onSendBackward;
  final VoidCallback? onBringForward;
  final VoidCallback? onDone;

  final double brightness;
  final double saturation;
  final double temp;
  final double hue;
  final double contrast;
  final double opacity;

  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onTempChanged;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onOpacityChanged;

  const PhotoAdjustmentsPanel({
    super.key,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onFlipX,
    this.onFlipY,
    this.onSendBackward,
    this.onBringForward,
    this.onDone,
    required this.brightness,
    required this.saturation,
    required this.temp,
    required this.hue,
    required this.contrast,
    required this.opacity,
    required this.onBrightnessChanged,
    required this.onSaturationChanged,
    required this.onTempChanged,
    required this.onHueChanged,
    required this.onContrastChanged,
    required this.onOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            ActionIcon(
              icon: Icons.rotate_left,
              tooltip: 'Rotate -90°',
              onPressed: onRotateLeft,
            ),
            const SizedBox(width: 6),
            ActionIcon(
              icon: Icons.rotate_right,
              tooltip: 'Rotate +90°',
              onPressed: onRotateRight,
            ),
            ActionIcon(
              icon: Icons.flip,
              tooltip: 'Flip horizontal',
              onPressed: onFlipX,
            ),
            if (onFlipY != null)
              ActionIcon(
                icon: Icons.flip_camera_android,
                tooltip: 'Flip vertical',
                onPressed: onFlipY!,
              ),
            if (onSendBackward != null)
              ActionIcon(
                icon: Icons.vertical_align_bottom,
                tooltip: 'Send backward',
                onPressed: onSendBackward!,
              ),
            if (onBringForward != null)
              ActionIcon(
                icon: Icons.vertical_align_top,
                tooltip: 'Bring forward',
                onPressed: onBringForward!,
              ),
            const VerticalDivider(
              color: Colors.white24,
              thickness: 1,
              width: 16,
              indent: 6,
              endIndent: 6,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth > 900 ? 3 : 2;

                  final sliders = [
                    MiniSlider(
                      label: 'Brt',
                      value: brightness,
                      min: 0.0,
                      max: 4.0,
                      divisions: 20,
                      centerValue: 1.0,
                      onChanged: onBrightnessChanged,
                    ),
                    MiniSlider(
                      label: 'Sat',
                      value: saturation,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      centerValue: 1.0,
                      onChanged: onSaturationChanged,
                    ),
                    MiniSlider(
                      label: 'Tmp',
                      value: temp,
                      min: -5.0,
                      max: 5.0,
                      divisions: 20,
                      centerValue: 0.0,
                      onChanged: onTempChanged,
                    ),
                    MiniSlider(
                      label: 'Hue',
                      value: hue,
                      min: -math.pi / 4,
                      max: math.pi / 4,
                      divisions: 20,
                      centerValue: 0.0,
                      format: (v) =>
                          '${(v * 180 / math.pi).toStringAsFixed(0)}°',
                      onChanged: onHueChanged,
                    ),
                    MiniSlider(
                      label: 'Cnt',
                      value: contrast,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      centerValue: 1.0,
                      format: (v) => '${v.toStringAsFixed(2)}x',
                      onChanged: onContrastChanged,
                    ),
                    MiniSlider(
                      label: 'Op',
                      value: opacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      centerValue: 1.0,
                      format: (v) => '${(v * 100).round()}%',
                      onChanged: onOpacityChanged,
                    ),
                  ];

                  if (columns == 2) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: sliders
                          .map((w) => SizedBox(
                                width: c.maxWidth / 2 - 12,
                                child: w,
                              ))
                          .toList(),
                    );
                  }

                  final colW = (c.maxWidth - 24) / 3;
                  return Row(
                    children: [
                      SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            sliders[0],
                            const SizedBox(height: 6),
                            sliders[1],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            sliders[2],
                            const SizedBox(height: 6),
                            sliders[3],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            sliders[4],
                            const SizedBox(height: 6),
                            sliders[5],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (onDone != null) ...[
              const VerticalDivider(
                color: Colors.white24,
                thickness: 1,
                width: 16,
                indent: 6,
                endIndent: 6,
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 13, letterSpacing: 0.2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
