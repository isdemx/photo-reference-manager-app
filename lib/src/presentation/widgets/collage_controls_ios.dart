import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_controls_shared.dart';

List<Widget> buildIOSCollageControlsOverlay({
  required BuildContext context,
  required bool isFullscreen,
  required bool controlsExpanded,
  required double bottomInset,
  required double sliderValue,
  required ValueChanged<double> onSliderChanged,
  required Widget joystick,
  required List<CollageControlAction> actions,
  required VoidCallback onToggleControls,
  required VoidCallback onCollapseControls,
}) {
  final expanded = !isFullscreen || controlsExpanded;
  final bottom = 14.0 + bottomInset;
  final screenWidth = MediaQuery.sizeOf(context).width;
  final zoomWidth = math.min(screenWidth - 112, 300.0);

  return [
    if (isFullscreen && expanded)
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onCollapseControls,
          child: const SizedBox.expand(),
        ),
      ),
    if (expanded) ...[
      Positioned(
        right: 18,
        bottom: bottom + 76,
        child: joystick,
      ),
      Positioned(
        left: (screenWidth - zoomWidth) / 2,
        bottom: bottom,
        child: CollageIOSZoomControl(
          width: zoomWidth,
          value: sliderValue,
          onChanged: onSliderChanged,
        ),
      ),
      Positioned(
        left: 14,
        right: 74,
        bottom: bottom + 82,
        child: Align(
          alignment: Alignment.centerRight,
          child: CollageIOSActionDock(actions: actions),
        ),
      ),
    ],
    if (isFullscreen)
      Positioned(
        right: 18,
        bottom: bottom,
        child: CollageIOSControlsToggle(
          expanded: expanded,
          onTap: onToggleControls,
        ),
      ),
  ];
}

class CollageIOSControlsToggle extends StatelessWidget {
  const CollageIOSControlsToggle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: expanded ? 42 : 28,
        height: expanded ? 42 : 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: expanded ? 0.54 : 0.38),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: expanded ? 0.28 : 0.18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          expanded ? Icons.more_horiz : Icons.more_horiz,
          color: Colors.white.withValues(alpha: 0.86),
          size: expanded ? 18 : 16,
        ),
      ),
    );
  }
}

class CollageIOSActionDock extends StatelessWidget {
  const CollageIOSActionDock({
    super.key,
    required this.actions,
  });

  final List<CollageControlAction> actions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: CollageGlassPanel(
        child: CollageActionButtons(
          actions: actions,
          horizontal: true,
          scrollable: true,
        ),
      ),
    );
  }
}

class CollageIOSZoomControl extends StatelessWidget {
  const CollageIOSZoomControl({
    super.key,
    required this.width,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 7,
      activeTrackColor: Colors.white.withValues(alpha: 0.86),
      inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
      thumbColor: Colors.white,
      overlayColor: Colors.white.withValues(alpha: 0.16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: CollageGlassPanel(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: SizedBox(
          width: width,
          child: Row(
            children: [
              Icon(
                Icons.remove,
                size: 16,
                color: Colors.white.withValues(alpha: 0.62),
              ),
              Expanded(
                child: SliderTheme(
                  data: sliderTheme,
                  child: Slider(
                    min: 0.0,
                    max: 1.0,
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ),
              Icon(
                Icons.add,
                size: 16,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
