import 'package:flutter/material.dart';

/// Shows a compact desktop context menu anchored at the pointer position.
class DesktopContextMenu {
  DesktopContextMenu._();

  static const TextStyle _itemTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.05,
    letterSpacing: 0,
  );

  static RelativeRect _menuPosition(
      BuildContext context, Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = overlay.globalToLocal(globalPosition);
    return RelativeRect.fromLTRB(
      origin.dx,
      origin.dy,
      overlay.size.width - origin.dx,
      overlay.size.height - origin.dy,
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Offset globalPosition,
    required List<PopupMenuEntry<T>> items,
    double? elevation,
    ShapeBorder? shape,
    Color? color,
    String? semanticLabel,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        color ?? (isDark ? const Color(0xF21F1F1F) : scheme.surface);
    final borderColor = isDark
        ? const Color(0xFF4A4A4A)
        : scheme.outlineVariant.withValues(alpha: 0.9);

    return showMenu<T>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: items,
      elevation: elevation ?? 10,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
      surfaceTintColor: Colors.transparent,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints(minWidth: 196, maxWidth: 320),
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor, width: 1),
          ),
      color: backgroundColor,
      semanticLabel: semanticLabel,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      requestFocus: false,
    );
  }

  static PopupMenuItem<T> item<T>({
    required BuildContext context,
    required T value,
    required String label,
    bool destructive = false,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = destructive
        ? scheme.error
        : (theme.popupMenuTheme.textStyle?.color ?? scheme.onSurface);
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : scheme.primary.withValues(alpha: 0.10);

    return PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      height: 28,
      padding: EdgeInsets.zero,
      child: _DesktopContextMenuItemLabel(
        label: label,
        textStyle: _itemTextStyle.copyWith(color: textColor),
        hoverColor: hoverColor,
      ),
    );
  }

  static PopupMenuDivider divider<T>() {
    return const PopupMenuDivider(height: 7);
  }
}

class _DesktopContextMenuItemLabel extends StatefulWidget {
  final String label;
  final TextStyle textStyle;
  final Color hoverColor;

  const _DesktopContextMenuItemLabel({
    required this.label,
    required this.textStyle,
    required this.hoverColor,
  });

  @override
  State<_DesktopContextMenuItemLabel> createState() =>
      _DesktopContextMenuItemLabelState();
}

class _DesktopContextMenuItemLabelState
    extends State<_DesktopContextMenuItemLabel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: double.infinity,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        color: _hovered ? widget.hoverColor : Colors.transparent,
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.textStyle,
        ),
      ),
    );
  }
}
