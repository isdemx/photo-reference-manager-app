import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_ui.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_top_center_action.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/presentation/widgets/settings_dialog.dart';
import 'package:photographers_reference_app/src/services/navigation_history_service.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

class TagScreen extends StatefulWidget {
  final Tag tag;

  const TagScreen({super.key, required this.tag});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  static const _prefSidebarOpen = 'macos.sidebar.open';

  final GlobalKey<PhotoGridViewState> _photoGridKey =
      GlobalKey<PhotoGridViewState>();

  bool _sidebarOpen = true;
  bool _isMasonryLayout = true;
  bool _sortBySizeEnabled = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    _loadSidebarPref();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sidebarOpen = prefs.getBool(_prefSidebarOpen) ?? true;
    });
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarOpen;
    setState(() {
      _sidebarOpen = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSidebarOpen, next);
  }

  void _openSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: context.appThemeColors.overlay.withValues(alpha: 0.7),
      builder: (_) => const SettingsDialog(appVersion: null),
    );
  }

  void _toggleGridLayout() {
    final grid = _photoGridKey.currentState;
    if (grid == null) return;
    grid.toggleLayoutFromHost();
    setState(() {
      _isMasonryLayout = !_isMasonryLayout;
    });
  }

  Future<void> _toggleSortBySize() async {
    final grid = _photoGridKey.currentState;
    if (grid == null) return;
    await grid.toggleSortByFileSizeFromHost();
    if (!mounted) return;
    setState(() {
      _sortBySizeEnabled = !_sortBySizeEnabled;
    });
  }

  Widget _desktopBody(Widget content) {
    return Row(
      children: [
        AnimatedContainer(
          width: _sidebarOpen ? 220 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _sidebarOpen
              ? MacosSidebar(
                  onMain: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainScreen(),
                    ),
                    (_) => false,
                  ),
                  onAllPhotos: () =>
                      Navigator.pushNamed(context, '/all_photos'),
                  onCollages: () =>
                      Navigator.pushNamed(context, '/my_collages'),
                  onTags: () => Navigator.pushNamed(context, '/all_tags'),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhotoBloc, PhotoState>(
      builder: (context, photoState) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (photoState is PhotoLoading || tagState is TagLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (photoState is! PhotoLoaded || tagState is! TagLoaded) {
              return const Scaffold(
                body: Center(child: Text('Failed to load images.')),
              );
            }

            final activeTag = tagState.tags.firstWhere(
              (t) => t.id == widget.tag.id,
              orElse: () => widget.tag,
            );
            final photos = photoState.photos
                .where((photo) => photo.tagIds.contains(widget.tag.id))
                .toList();
            final title = activeTag.name.isEmpty
                ? 'Tag'
                : '${activeTag.name[0].toUpperCase()}${activeTag.name.length > 1 ? activeTag.name.substring(1) : ''}';

            final grid = photos.isEmpty
                ? const Center(child: Text('No images with this tag.'))
                : PhotoGridView(
                    key: _photoGridKey,
                    showFilter: false,
                    showInternalAppBar: !_isDesktop,
                    tags: tagState.tags,
                    photos: photos,
                    title: title,
                    showShareBtn: true,
                  );

            return Scaffold(
              appBar: _isDesktop
                  ? MacosTopBar(
                      onToggleSidebar: _toggleSidebar,
                      onOpenNewWindow: () {
                        WindowService.openWindow(
                          route: '/all_photos',
                          args: const {},
                          title: 'Refma - Tag',
                        );
                      },
                      onBack: () =>
                          NavigationHistoryService.instance.goBack(context),
                      onForward: () =>
                          NavigationHistoryService.instance.goForward(context),
                      canGoBack: true,
                      canGoForward: true,
                      onUpload: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const UploadScreen(),
                          transitionsBuilder: (_, __, ___, child) => child,
                        ),
                      ),
                      onAllPhotos: () =>
                          Navigator.pushNamed(context, '/all_photos'),
                      onCollages: () =>
                          Navigator.pushNamed(context, '/my_collages'),
                      onTags: () => Navigator.pushNamed(context, '/all_tags'),
                      onSettings: _openSettings,
                      title: title,
                      centerActions: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MacosTopCenterAction(
                            icon: Iconsax.edit,
                            onTap: () => TagsHelpers.showEditTagDialog(
                                context, activeTag),
                            tooltip: 'Edit tag',
                          ),
                          const SizedBox(width: 4),
                          MacosTopCenterAction(
                            icon: _isMasonryLayout
                                ? Icons.grid_on
                                : Icons.dashboard,
                            onTap: _toggleGridLayout,
                            tooltip: _isMasonryLayout
                                ? 'Switch to Grid View'
                                : 'Switch to Masonry View',
                          ),
                          const SizedBox(width: 4),
                          MacosTopCenterAction(
                            icon: Icons.swap_vert,
                            color: _sortBySizeEnabled ? Colors.yellow : null,
                            onTap: _toggleSortBySize,
                            tooltip: 'Sort by file size',
                          ),
                        ],
                      ),
                    )
                  : null,
              body: _isDesktop ? _desktopBody(grid) : grid,
            );
          },
        );
      },
    );
  }
}
