import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/action_icon_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/mini_slider_widget.dart';

class CollageDrawingToolbar extends StatelessWidget {
  const CollageDrawingToolbar({
    super.key,
    required this.color,
    required this.width,
    required this.opacity,
    required this.isMobile,
    required this.isBrush,
    required this.isGraffiti,
    required this.isNeon,
    required this.isHighlighter,
    required this.isArrow,
    required this.isEraser,
    required this.isSelect,
    required this.canUndo,
    required this.canClear,
    required this.hasSelection,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onOpacityChanged,
    required this.onSelectPencil,
    required this.onSelectBrush,
    required this.onSelectGraffiti,
    required this.onSelectNeon,
    required this.onSelectHighlighter,
    required this.onSelectArrow,
    required this.onSelectEraser,
    required this.onSelectArea,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onUndo,
    required this.onClear,
    required this.onDone,
  });

  final Color color;
  final double width;
  final double opacity;
  final bool isMobile;
  final bool isBrush;
  final bool isGraffiti;
  final bool isNeon;
  final bool isHighlighter;
  final bool isArrow;
  final bool isEraser;
  final bool isSelect;
  final bool canUndo;
  final bool canClear;
  final bool hasSelection;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onSelectPencil;
  final VoidCallback onSelectBrush;
  final VoidCallback onSelectGraffiti;
  final VoidCallback onSelectNeon;
  final VoidCallback onSelectHighlighter;
  final VoidCallback onSelectArrow;
  final VoidCallback onSelectEraser;
  final VoidCallback onSelectArea;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onDone;

  static const List<Color> _swatches = [
    Colors.white,
    Colors.black,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.cyanAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: colors.surface.withValues(alpha: isDark ? 0.94 : 0.97),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final controls = <Widget>[
              _ToolModeButton(
                icon: Icons.edit,
                tooltip: 'Pencil',
                selected: !isBrush &&
                    !isGraffiti &&
                    !isNeon &&
                    !isHighlighter &&
                    !isArrow &&
                    !isEraser &&
                    !isSelect,
                onTap: onSelectPencil,
              ),
              _ToolModeButton(
                icon: Icons.brush,
                tooltip: 'Brush',
                selected: isBrush && !isEraser && !isSelect,
                onTap: onSelectBrush,
              ),
              _ToolModeButton(
                icon: Icons.format_paint,
                tooltip: 'Graffiti',
                selected: isGraffiti && !isEraser && !isSelect,
                onTap: onSelectGraffiti,
              ),
              _ToolModeButton(
                icon: Icons.auto_awesome,
                tooltip: 'Neon brush',
                selected: isNeon && !isEraser && !isSelect,
                onTap: onSelectNeon,
              ),
              _ToolModeButton(
                icon: Icons.border_color,
                tooltip: 'Highlighter',
                selected: isHighlighter && !isEraser && !isSelect,
                onTap: onSelectHighlighter,
              ),
              _ToolModeButton(
                icon: Icons.arrow_forward,
                tooltip: 'Arrow',
                selected: isArrow && !isEraser && !isSelect,
                onTap: onSelectArrow,
              ),
              _ToolModeButton(
                icon: Icons.auto_fix_off,
                tooltip: 'Eraser',
                selected: isEraser && !isSelect,
                onTap: onSelectEraser,
              ),
              _ToolModeButton(
                icon: Icons.select_all,
                tooltip: 'Select drawing',
                selected: isSelect,
                onTap: onSelectArea,
              ),
              if (hasSelection)
                ActionIcon(
                  icon: Icons.backspace_outlined,
                  tooltip: 'Delete selected',
                  onPressed: onDeleteSelected,
                ),
              if (hasSelection)
                ActionIcon(
                  icon: Icons.deselect,
                  tooltip: 'Clear selection',
                  onPressed: onClearSelection,
                ),
              ActionIcon(
                icon: Icons.undo,
                tooltip: 'Undo drawing action',
                onPressed: canUndo ? onUndo : () {},
              ),
              ActionIcon(
                icon: Icons.delete_outline,
                tooltip: 'Clear drawing',
                onPressed: canClear ? onClear : () {},
              ),
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: colors.surfaceAlt.withValues(alpha: 0.92),
                    foregroundColor: colors.text,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ];

            final swatches = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final swatch in _swatches)
                  _ColorSwatch(
                    color: swatch,
                    selected:
                        !isEraser && swatch.toARGB32() == color.toARGB32(),
                    onTap: () => onColorChanged(swatch),
                  ),
              ],
            );

            final sliders = [
              MiniSlider(
                label: 'Size',
                value: width,
                min: 1,
                max: 18,
                divisions: 34,
                centerValue: 2,
                format: (v) => v.round().toString(),
                onChanged: onWidthChanged,
              ),
              MiniSlider(
                label: 'Op',
                value: opacity,
                min: 0.1,
                max: 1,
                divisions: 18,
                centerValue: 1,
                format: (v) => '${(v * 100).round()}%',
                onChanged: onOpacityChanged,
              ),
            ];

            if (isMobile) {
              final sliderTheme = SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: colors.text,
                inactiveTrackColor: colors.border,
                thumbColor: colors.text,
                overlayColor: colors.text.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: controls
                                .map((w) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: w,
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        swatches,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    height: 138,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: sliderTheme,
                        child: Slider(
                          min: 1,
                          max: 18,
                          divisions: 34,
                          value: width.clamp(1, 18),
                          onChanged: onWidthChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: controls
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: w,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  swatches,
                  const SizedBox(height: 6),
                  for (final slider in sliders)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: slider,
                    ),
                ],
              );
            }

            return Row(
              children: [
                ...controls.map((w) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: w,
                    )),
                const SizedBox(width: 8),
                swatches,
                const SizedBox(width: 14),
                for (final slider in sliders) ...[
                  SizedBox(width: 150, child: slider),
                  const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        color.computeLuminance() > 0.8 ? Colors.black26 : Colors.white24;
    return Tooltip(
      message: 'Color',
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _ToolModeButton extends StatelessWidget {
  const _ToolModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appThemeColors;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected
                ? appColors.text.withValues(alpha: 0.92)
                : appColors.surfaceAlt.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? appColors.text : appColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: selected ? appColors.surface : appColors.text,
          ),
        ),
      ),
    );
  }
}
