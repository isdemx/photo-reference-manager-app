import 'dart:io';

import 'package:flutter/material.dart';

class ColumnSlider extends StatelessWidget {
  final int columnCount;
  final ValueChanged<int> onChanged;
  final int initialCount;

  const ColumnSlider({
    super.key,
    required this.columnCount,
    required this.onChanged,
    required this.initialCount,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 26.0,
      left: Platform.isMacOS
          ? null
          : 150.0, // Если macOS, то left=null, иначе 150.0
      right: 50.0,
      width: Platform.isMacOS
          ? 200.0
          : null, // Если macOS, то width=200, иначе null
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white, // Цвет текста в лейбле
                fontWeight: FontWeight.bold,
              ),
              valueIndicatorColor: Colors.black, // Цвет фона лейбла
            ),
            child: Slider(
              value: columnCount.toDouble(),
              inactiveColor:
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              activeColor:
                  const Color.fromARGB(255, 107, 107, 107).withOpacity(0.7),
              thumbColor:
                  const Color.fromARGB(255, 117, 116, 116).withOpacity(0.8),
              min: Platform.isMacOS ? 5 : 2,
              max: Platform.isMacOS ? 12 : 5,
              divisions: Platform.isMacOS ? 7 : 3,
              label: 'Columns: $columnCount',
              onChanged: (value) {
                onChanged(value.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }
}
