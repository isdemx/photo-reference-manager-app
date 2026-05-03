// column_slider.dart
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/utils/platform_utils.dart';

class ColumnSlider extends StatelessWidget {
  final int columnCount;
  final ValueChanged<int> onChanged;
  final int initialCount;
  final double bottomInset; // <— добавили

  const ColumnSlider({
    super.key,
    required this.columnCount,
    required this.onChanged,
    required this.initialCount,
    this.bottomInset = 26.0, // дефолт
  });

  bool get _isDesktop => isDesktopPlatform;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    const minTileW = 80.0;
    final dynamicMaxForDesktop = (screenW / minTileW).floor().clamp(1, 100);

    final min = _isDesktop ? 5 : 2;
    final max = _isDesktop ? dynamicMaxForDesktop : 8;
    final divisions = (max - min) > 0 ? (max - min) : null;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      bottom: bottomInset, // <— тут магия
      left: _isDesktop ? null : 150.0,
      right: 50.0,
      width: _isDesktop ? 200.0 : null,
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              valueIndicatorColor: Colors.black,
            ),
            child: Slider(
              value: columnCount.clamp(min, max).toDouble(),
              inactiveColor:
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              activeColor:
                  const Color.fromARGB(255, 107, 107, 107).withOpacity(0.7),
              thumbColor:
                  const Color.fromARGB(255, 117, 116, 116).withOpacity(0.8),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: divisions,
              label: 'Columns: $columnCount',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
