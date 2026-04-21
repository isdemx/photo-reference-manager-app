import 'package:flutter/material.dart';

List<Widget> buildMacOSCollageControlsOverlay({
  required bool isFullscreen,
  required Widget zoomControl,
  required Widget actionButtons,
  required bool leftHover,
  required bool rightHover,
  required ValueChanged<bool> onLeftHoverChanged,
  required ValueChanged<bool> onRightHoverChanged,
}) {
  if (!isFullscreen) {
    return [
      Positioned(
        left: 12,
        bottom: 12,
        child: zoomControl,
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: actionButtons,
      ),
    ];
  }

  final visible = leftHover || rightHover;

  return [
    Positioned(
      left: 12,
      bottom: 12,
      child: MouseRegion(
        onEnter: (_) {
          if (!leftHover) onLeftHoverChanged(true);
        },
        onExit: (_) {
          if (leftHover) onLeftHoverChanged(false);
        },
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: zoomControl,
          ),
        ),
      ),
    ),
    Positioned(
      right: 12,
      bottom: 12,
      child: MouseRegion(
        onEnter: (_) {
          if (!rightHover) onRightHoverChanged(true);
        },
        onExit: (_) {
          if (rightHover) onRightHoverChanged(false);
        },
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: actionButtons,
          ),
        ),
      ),
    ),
  ];
}
