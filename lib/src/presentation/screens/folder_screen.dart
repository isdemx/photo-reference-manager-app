import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_ui.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_top_center_action.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/presentation/widgets/settings_dialog.dart';
import 'package:photographers_reference_app/src/services/navigation_history_service.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({super.key, required this.folder});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  static const _prefSidebarOpen = 'macos.sidebar.open';
  bool _dragOver = false;
  bool _sidebarOpen = true;
  bool _isMasonryLayout = true;
  bool _sortBySizeEnabled = false;
  final GlobalKey<PhotoGridViewState> _photoGridKey =
      GlobalKey<PhotoGridViewState>();

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

  void _openFolderUpload() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => UploadScreen(folder: widget.folder),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  void _openEditFolderDialog() {
    FoldersHelpers.showEditFolderDialog(context, widget.folder);
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

  Widget _emptyFolderBody() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'No images in this folder. You can upload new images or select from the "All Images" section.\n\n'
                'Drag & drop files here to quickly upload them to this folder (on desktop).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _openFolderUpload,
                  child: const Text('Upload'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/all_photos');
                  },
                  child: const Text('Images'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _desktopTopBar() {
    final navHistory = NavigationHistoryService.instance;
    return MacosTopBar(
      onToggleSidebar: _toggleSidebar,
      onOpenNewWindow: () {
        WindowService.openWindow(
          route: '/all_photos',
          args: const {},
          title: 'Refma - Images',
        );
      },
      onBack: () => navHistory.goBack(context),
      onForward: () => navHistory.goForward(context),
      canGoBack: true,
      canGoForward: true,
      onUpload: _openFolderUpload,
      onAllPhotos: () => Navigator.pushNamed(context, '/all_photos'),
      onCollages: () => Navigator.pushNamed(context, '/my_collages'),
      onTags: () => Navigator.pushNamed(context, '/all_tags'),
      onSettings: _openSettings,
      title: widget.folder.name,
      centerActions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MacosTopCenterAction(
            icon: Iconsax.import_1,
            onTap: _openFolderUpload,
            tooltip: 'Upload to this folder',
          ),
          const SizedBox(width: 4),
          MacosTopCenterAction(
            icon: Iconsax.edit,
            onTap: _openEditFolderDialog,
            tooltip: 'Edit folder properties',
          ),
          const SizedBox(width: 4),
          MacosTopCenterAction(
            icon: _isMasonryLayout ? Icons.grid_on : Icons.dashboard,
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
    );
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
    return BlocProvider.value(
      value: BlocProvider.of<PhotoBloc>(context),
      child: DropTarget(
        onDragDone: (details) async {
          for (final xfile in details.files) {
            final file = File(xfile.path);
            final bytes = await file.readAsBytes();
            final fileName = p.basename(file.path);
            final mediaType = getMediaType(file.path);

            final newPhoto = await PhotoSaveHelper.savePhoto(
                fileName: fileName,
                bytes: bytes,
                context: context,
                mediaType: mediaType);

            newPhoto.folderIds.add(widget.folder.id);
            context.read<PhotoBloc>().add(AddPhoto(newPhoto));
          }
        },
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        child: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (context, tagState) {
                if (photoState is PhotoLoading || tagState is TagLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
                  final List<Photo> photos = photoState.photos
                      .where(
                          (photo) => photo.folderIds.contains(widget.folder.id))
                      .toList();

                  final pageContent = photos.isEmpty
                      ? _emptyFolderBody()
                      : PhotoGridView(
                          key: _photoGridKey,
                          showFilter: false,
                          showInternalAppBar: !_isDesktop,
                          tags: tagState.tags,
                          title: widget.folder.name,
                          showShareBtn: true,
                          photos: photos,
                          actionFromParent: null,
                        );

                  return Scaffold(
                    backgroundColor: _dragOver ? Colors.black12 : null,
                    appBar: _isDesktop
                        ? _desktopTopBar()
                        : (photos.isEmpty
                            ? AppBar(
                                title: Text(widget.folder.name),
                                actions: [
                                  IconButton(
                                    icon: const Icon(Iconsax.import_1),
                                    tooltip: 'Upload to this folder',
                                    onPressed: _openFolderUpload,
                                  ),
                                  IconButton(
                                    icon: const Icon(Iconsax.edit),
                                    tooltip: 'Edit folder properties',
                                    onPressed: _openEditFolderDialog,
                                  ),
                                ],
                              )
                            : null),
                    body: _isDesktop ? _desktopBody(pageContent) : pageContent,
                  );
                } else {
                  return const Scaffold(
                    body: Center(child: Text('Failed to load images.')),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
