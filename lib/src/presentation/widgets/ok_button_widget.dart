// lib/src/presentation/widgets/ok_button_widget.dart

import 'package:flutter/material.dart';

class OkButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const OkButtonWidget({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.check),
      color: Colors.white,
      onPressed: onPressed,
    );
  }
}