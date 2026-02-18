import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:window_manager/window_manager.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/services/navigation_history_service.dart';

class MacosPalette {
  static Color canvas(BuildContext context) => context.appThemeColors.canvas;
  static Color surface(BuildContext context) => context.appThemeColors.surface;
  static Color surfaceAlt(BuildContext context) =>
      context.appThemeColors.surfaceAlt;
  static Color border(BuildContext context) => context.appThemeColors.border;
  static Color subtle(BuildContext context) => context.appThemeColors.subtle;
  static Color text(BuildContext context) => context.appThemeColors.text;
  static Color accent(BuildContext context) => context.appThemeColors.accent;
}

class MacosTypography {
  static TextStyle title(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: MacosPalette.text(context),
        letterSpacing: 0.2,
      );

  static TextStyle section(BuildContext context) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: MacosPalette.text(context),
        letterSpacing: 0.2,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: MacosPalette.subtle(context),
        letterSpacing: 0.2,
      );
}

class MacosTopBar extends StatelessWidget implements PreferredSizeWidget {
  static const double barHeight = 44.0;
  final VoidCallback onToggleSidebar;
  final VoidCallback onOpenNewWindow;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onUpload;
  final VoidCallback onAllPhotos;
  final VoidCallback onCollages;
  final VoidCallback onTags;
  final VoidCallback onSettings;
  final String title;
  final Widget? centerActions;
  final Widget? rightAfterSettings;

  const MacosTopBar({
    super.key,
    required this.onToggleSidebar,
    required this.onOpenNewWindow,
    required this.onBack,
    required this.onForward,
    required this.canGoBack,
    required this.canGoForward,
    required this.onUpload,
    required this.onAllPhotos,
    required this.onCollages,
    required this.onTags,
    required this.onSettings,
    this.title = 'Library',
    this.centerActions,
    this.rightAfterSettings,
  });

  @override
  Widget build(BuildContext context) {
    final leftInset = _macosLeftInset();
    final navHistory = NavigationHistoryService.instance;
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _toggleMaximize,
        child: Stack(
          children: [
            DragToMoveArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MacosPalette.surface(context),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const SizedBox(height: barHeight),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(leftInset, 6, 16, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TopBarIcon(
                      icon: Iconsax.sidebar_left,
                      onTap: onToggleSidebar,
                    ),
                    const SizedBox(width: 8),
                    _TopBarIcon(
                      icon: CupertinoIcons.arrow_up_right_square,
                      onTap: onOpenNewWindow,
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: navHistory.revision,
                      builder: (_, __, ___) => _TopBarIcon(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack,
                        enabled: canGoBack && navHistory.canGoBack(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: navHistory.revision,
                      builder: (_, __, ___) => _TopBarIcon(
                        icon: Icons.arrow_forward_rounded,
                        onTap: onForward,
                        enabled: canGoForward && navHistory.canGoForward(),
                      ),
                    ),
                    const Spacer(),
                    _TopBarIcon(icon: Iconsax.import_1, onTap: onUpload),
                    const SizedBox(width: 8),
                    _TopBarIcon(icon: Iconsax.gallery, onTap: onAllPhotos),
                    const SizedBox(width: 8),
                    _TopBarIcon(icon: Iconsax.grid_3, onTap: onCollages),
                    const SizedBox(width: 8),
                    _TopBarIcon(icon: Iconsax.tag_2, onTap: onTags),
                    const SizedBox(width: 8),
                    _TopBarIcon(icon: Iconsax.setting_2, onTap: onSettings),
                    if (rightAfterSettings != null) ...[
                      const SizedBox(width: 8),
                      rightAfterSettings!,
                    ],
                  ],
                ),
              ),
            ),
            IgnorePointer(
              ignoring: centerActions == null,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: MacosTypography.title(context)),
                    if (centerActions != null) ...[
                      const SizedBox(width: 10),
                      centerActions!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _TopBarIcon({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          icon,
          size: 17,
          color: enabled
              ? MacosPalette.text(context)
              : MacosPalette.subtle(context),
        ),
      ),
    );
  }
}

double _macosLeftInset() {
  if (!kIsWeb && Platform.isMacOS) {
    return 82;
  }
  return 16;
}

Future<void> _toggleMaximize() async {
  if (kIsWeb || !Platform.isMacOS) return;
  try {
    final isMax = await windowManager.isMaximized();
    if (isMax) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  } catch (_) {}
}

class MacosSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget? trailing;

  const MacosSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.collapsible = true,
    this.expanded = true,
    this.onToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: collapsible ? onToggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              if (collapsible) ...[
                Icon(
                  expanded ? Iconsax.arrow_down_1 : Iconsax.arrow_right_3,
                  size: 14,
                  color: MacosPalette.text(context),
                ),
                const SizedBox(width: 6),
              ],
              Text(title, style: MacosTypography.section(context)),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MacosPalette.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: MacosTypography.caption(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MacosSidebar extends StatelessWidget {
  final VoidCallback onMain;
  final VoidCallback onAllPhotos;
  final VoidCallback onCollages;
  final VoidCallback onTags;

  const MacosSidebar({
    super.key,
    required this.onMain,
    required this.onAllPhotos,
    required this.onCollages,
    required this.onTags,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: MacosPalette.surface(context),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Navigate', style: MacosTypography.section(context)),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Iconsax.gallery,
                  label: 'All Photos',
                  onTap: onAllPhotos,
                ),
                _SidebarItem(
                  icon: Iconsax.grid_3,
                  label: 'Collages',
                  onTap: onCollages,
                ),
                _SidebarItem(
                  icon: Iconsax.tag_2,
                  label: 'Tags',
                  onTap: onTags,
                ),
                const SizedBox(height: 24),
                Text('Workspace', style: MacosTypography.section(context)),
                const SizedBox(height: 8),
                Text(
                  'Use Categories and Folders in the main view. Drag files anywhere to import.',
                  style: MacosTypography.caption(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Divider(height: 1, color: MacosPalette.border(context)),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Iconsax.home,
                  label: 'Main Screen',
                  onTap: onMain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: MacosPalette.text(context)),
            const SizedBox(width: 10),
            Text(label, style: MacosTypography.caption(context)),
          ],
        ),
      ),
    );
  }
}
