// lib/src/presentation/widgets/color_picker_widget.dart

import 'package:flutter/material.dart';

class ColorPickerWidget extends StatelessWidget {
  final Function(Color) onColorSelected;

  const ColorPickerWidget({
    Key? key,
    required this.onColorSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
    ];

    return Wrap(
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
        );
      }).toList(),
    );
  }
}
