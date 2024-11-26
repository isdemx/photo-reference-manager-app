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
      left: 150.0,
      right: 50.0,
      child: Column(
        children: [
          Slider(
            value: columnCount.toDouble(),
            inactiveColor: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
            activeColor:
                const Color.fromARGB(255, 107, 107, 107).withOpacity(0.7),
            thumbColor:
                const Color.fromARGB(255, 117, 116, 116).withOpacity(0.8),
            min: 2,
            max: 5,
            divisions: 3,
            label: 'Columns: $columnCount',
            onChanged: (value) {
              onChanged(value.toInt());
            },
          ),
        ],
      ),
    );
  }
}
