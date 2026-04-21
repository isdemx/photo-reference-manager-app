import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CollageControlAction {
  const CollageControlAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.color = Colors.white,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color color;
  final bool active;
}

class CollageGlassPanel extends StatelessWidget {
  const CollageGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    this.borderRadius = 999,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class CollageActionButtons extends StatelessWidget {
  const CollageActionButtons({
    super.key,
    required this.actions,
    this.horizontal = true,
    this.scrollable = false,
  });

  final List<CollageControlAction> actions;
  final bool horizontal;
  final bool scrollable;

  static const _iconShadow = [
    Shadow(
      color: Colors.black54,
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      padding: const EdgeInsets.all(7),
      minimumSize: const Size(33, 33),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    final buttons = [
      for (final action in actions)
        _CollageActionButton(action: action, style: buttonStyle),
    ];

    final content = horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                if (i != 0) const SizedBox(width: 4),
                buttons[i],
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          );

    return Opacity(
      opacity: 0.9,
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: content,
            )
          : content,
    );
  }
}

class _CollageActionButton extends StatelessWidget {
  const _CollageActionButton({
    required this.action,
    required this.style,
  });

  final CollageControlAction action;
  final ButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      style: style,
      icon: Icon(
        action.icon,
        size: 20,
        color: action.color,
        shadows: CollageActionButtons._iconShadow,
      ),
      tooltip: action.tooltip,
      onPressed: action.onPressed,
    );

    if (action.onLongPress == null) return button;

    return GestureDetector(
      onLongPress: action.onLongPress,
      child: button,
    );
  }
}
