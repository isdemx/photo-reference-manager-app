import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_ui.dart';

class MacosTopCenterAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;

  const MacosTopCenterAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          icon,
          size: 15,
          color: color ?? MacosPalette.text(context),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(
      message: tooltip!,
      child: child,
    );
  }
}
