import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

/// Маленькая иконка-кнопка с тултипом
class ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const ActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appThemeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: appColors.surfaceAlt.withValues(alpha: isDark ? 0.78 : 0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: appColors.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: appColors.text),
        ),
      ),
    );
  }
}
