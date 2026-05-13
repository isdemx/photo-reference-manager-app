import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/action_icon_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage/mini_slider_widget.dart';

class CollageTextToolbar extends StatelessWidget {
  const CollageTextToolbar({
    super.key,
    required this.color,
    required this.fontSize,
    required this.width,
    required this.opacity,
    required this.fontFamily,
    required this.bold,
    required this.italic,
    required this.textAlign,
    required this.onColorChanged,
    required this.onFontSizeChanged,
    required this.onWidthChanged,
    required this.onOpacityChanged,
    required this.onFontFamilyChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onTextAlignChanged,
    required this.onDelete,
    required this.onDone,
  });

  final Color color;
  final double fontSize;
  final double width;
  final double opacity;
  final String fontFamily;
  final bool bold;
  final bool italic;
  final int textAlign;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<int> onTextAlignChanged;
  final VoidCallback onDelete;
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
              _TextToggleButton(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                selected: bold,
                onTap: () => onBoldChanged(!bold),
              ),
              _TextToggleButton(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                selected: italic,
                onTap: () => onItalicChanged(!italic),
              ),
              _TextToggleButton(
                icon: Icons.format_align_left,
                tooltip: 'Left align',
                selected: textAlign == CollageTextItem.alignLeft,
                onTap: () => onTextAlignChanged(CollageTextItem.alignLeft),
              ),
              _TextToggleButton(
                icon: Icons.format_align_center,
                tooltip: 'Center align',
                selected: textAlign == CollageTextItem.alignCenter,
                onTap: () => onTextAlignChanged(CollageTextItem.alignCenter),
              ),
              _TextToggleButton(
                icon: Icons.format_align_right,
                tooltip: 'Right align',
                selected: textAlign == CollageTextItem.alignRight,
                onTap: () => onTextAlignChanged(CollageTextItem.alignRight),
              ),
              ActionIcon(
                icon: Icons.delete_outline,
                tooltip: 'Delete text',
                onPressed: onDelete,
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

            final fontPicker = _FontPicker(
              value: fontFamily,
              onChanged: onFontFamilyChanged,
            );

            final swatches = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final swatch in _swatches)
                  _ColorSwatch(
                    color: swatch,
                    selected: swatch.toARGB32() == color.toARGB32(),
                    onTap: () => onColorChanged(swatch),
                  ),
              ],
            );

            final sliders = [
              MiniSlider(
                label: 'Size',
                value: fontSize,
                min: 2,
                max: 24,
                divisions: 44,
                centerValue: 8,
                format: (v) => v.round().toString(),
                onChanged: onFontSizeChanged,
              ),
              MiniSlider(
                label: 'Box',
                value: width,
                min: 46,
                max: 220,
                divisions: 58,
                centerValue: 92,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      fontPicker,
                      const SizedBox(width: 10),
                      Flexible(child: swatches),
                    ],
                  ),
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
                fontPicker,
                const SizedBox(width: 12),
                swatches,
                const SizedBox(width: 14),
                for (final slider in sliders) ...[
                  SizedBox(width: 140, child: slider),
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

class _FontPicker extends StatelessWidget {
  const _FontPicker({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.text, fontSize: 12),
          iconSize: 16,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System')),
            DropdownMenuItem(value: 'serif', child: Text('Serif')),
            DropdownMenuItem(value: 'monospace', child: Text('Mono')),
          ],
          onChanged: (next) {
            if (next == null) return;
            onChanged(next);
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

class _TextToggleButton extends StatelessWidget {
  const _TextToggleButton({
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
    final colors = context.appThemeColors;
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
                ? colors.text.withValues(alpha: 0.92)
                : colors.surfaceAlt.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? colors.text : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: selected ? colors.surface : colors.text,
          ),
        ),
      ),
    );
  }
}
