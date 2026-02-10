import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:window_manager/window_manager.dart';

class MacosPalette {
  static const Color canvas = Color(0xFF0B0C0F);
  static const Color surface = Color(0xFF121318);
  static const Color surfaceAlt = Color(0xFF161820);
  static const Color border = Color(0x16FFFFFF);
  static const Color subtle = Color(0xFF8A8F98);
  static const Color text = Color(0xFFE7E9ED);
  static const Color accent = Color(0xFF58C1FF);
}

class MacosTypography {
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: MacosPalette.text,
    letterSpacing: 0.2,
  );

  static const TextStyle section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: MacosPalette.text,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: MacosPalette.subtle,
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
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _toggleMaximize,
        child: Stack(
          children: [
            DragToMoveArea(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: MacosPalette.surface,
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
                    _TopBarIcon(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                      enabled: canGoBack,
                    ),
                    const SizedBox(width: 8),
                    _TopBarIcon(
                      icon: Icons.arrow_forward_rounded,
                      onTap: onForward,
                      enabled: canGoForward,
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
                    Text(title, style: MacosTypography.title),
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
          color: enabled ? MacosPalette.text : MacosPalette.subtle,
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
                  color: MacosPalette.text,
                ),
                const SizedBox(width: 6),
              ],
              Text(title, style: MacosTypography.section),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MacosPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: MacosTypography.caption,
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
      decoration: const BoxDecoration(
        color: MacosPalette.surface,
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
                const Text('Navigate', style: MacosTypography.section),
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
                const Text('Workspace', style: MacosTypography.section),
                const SizedBox(height: 8),
                Text(
                  'Use Categories and Folders in the main view. Drag files anywhere to import.',
                  style: MacosTypography.caption,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                const Divider(height: 1, color: MacosPalette.border),
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
            Icon(icon, size: 16, color: MacosPalette.text),
            const SizedBox(width: 10),
            Text(label, style: MacosTypography.caption),
          ],
        ),
      ),
    );
  }
}
