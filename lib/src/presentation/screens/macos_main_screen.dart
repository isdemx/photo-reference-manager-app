import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/categories_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_ui.dart';
import 'package:photographers_reference_app/src/services/navigation_history_service.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

class MacosMainScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;

  const MacosMainScreen({
    super.key,
    required this.onOpenSettings,
  });

  @override
  State<MacosMainScreen> createState() => _MacosMainScreenState();
}

class _MacosMainScreenState extends State<MacosMainScreen> {
  static const _prefSidebarOpen = 'macos.sidebar.open';

  bool _sidebarOpen = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sidebarOpen = prefs.getBool(_prefSidebarOpen) ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
    _saveBool(_prefSidebarOpen, _sidebarOpen);
  }

  @override
  Widget build(BuildContext context) {
    final navHistory = NavigationHistoryService.instance;
    return Scaffold(
      backgroundColor: MacosPalette.canvas(context),
      appBar: MacosTopBar(
        onToggleSidebar: _toggleSidebar,
        onOpenNewWindow: () {
          WindowService.openWindow(
            route: '/my_collages',
            args: {},
            title: 'Refma — Collage',
          );
        },
        onBack: () => navHistory.goBack(context),
        onForward: () => navHistory.goForward(context),
        canGoBack: true,
        canGoForward: true,
        onUpload: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const UploadScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return child;
            },
          ),
        ),
        onAllPhotos: () => Navigator.pushNamed(context, '/all_photos'),
        onCollages: () => Navigator.pushNamed(context, '/my_collages'),
        onTags: () => Navigator.pushNamed(context, '/all_tags'),
        onSettings: widget.onOpenSettings,
        title: 'Main',
      ),
      body: Row(
        children: [
          AnimatedContainer(
            width: _sidebarOpen ? 220 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _sidebarOpen
                ? MacosSidebar(
                    onMain: () {},
                    onAllPhotos: () =>
                        Navigator.pushNamed(context, '/all_photos'),
                    onCollages: () =>
                        Navigator.pushNamed(context, '/my_collages'),
                    onTags: () => Navigator.pushNamed(context, '/all_tags'),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _MacosMainContent(
              categoriesOpen: true,
              onToggleCategories: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _MacosMainContent extends StatelessWidget {
  final bool categoriesOpen;
  final VoidCallback onToggleCategories;

  const _MacosMainContent({
    required this.categoriesOpen,
    required this.onToggleCategories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, categoryState) {
        return BlocBuilder<FolderBloc, FolderState>(
          builder: (context, folderState) {
            return BlocBuilder<PhotoBloc, PhotoState>(
              builder: (context, photoState) {
                if (categoryState is! CategoryLoaded ||
                    folderState is! FolderLoaded ||
                    photoState is! PhotoLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final session = context.watch<SessionBloc>().state;
                final showPrivate = session.showPrivate;

                final categories = categoryState.categories
                    .where((c) => showPrivate || c.isPrivate != true)
                    .toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                final folders = folderState.folders
                    .where((f) =>
                        showPrivate ||
                        (f.isPrivate == null || f.isPrivate == false))
                    .toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                final photos = photoState.photos;

                final folderCounts = <String, int>{};
                final folderCover = <String, Photo>{};
                for (final photo in photos) {
                  for (final folderId in photo.folderIds) {
                    folderCounts[folderId] = (folderCounts[folderId] ?? 0) + 1;
                    folderCover.putIfAbsent(folderId, () => photo);
                  }
                }

                final categoryCounts = <String, int>{};
                for (final folder in folders) {
                  categoryCounts[folder.categoryId] =
                      (categoryCounts[folder.categoryId] ?? 0) +
                          (folderCounts[folder.id] ?? 0);
                }

                final isEmpty =
                    categories.isEmpty && folders.isEmpty && photos.isEmpty;

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MacosPalette.canvas(context),
                        MacosPalette.surface(context),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 22),
                    children: [
                      if (isEmpty) _buildEmptyState(context),
                      MacosSectionHeader(
                        title: 'Categories',
                        count: categories.length,
                        collapsible: false,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            _ActionButton(
                              onPressed: () {
                                for (final category in categories) {
                                  if ((category.collapsed ?? false) == false) {
                                    continue;
                                  }
                                  context.read<CategoryBloc>().add(
                                      UpdateCategory(
                                          category.copyWith(collapsed: false)));
                                }
                              },
                              icon: Iconsax.arrow_down_1,
                              label: 'Expand all',
                            ),
                            _ActionButton(
                              onPressed: () {
                                for (final category in categories) {
                                  if ((category.collapsed ?? false) == true) {
                                    continue;
                                  }
                                  context.read<CategoryBloc>().add(
                                      UpdateCategory(
                                          category.copyWith(collapsed: true)));
                                }
                              },
                              icon: Iconsax.arrow_up_1,
                              label: 'Collapse all',
                            ),
                            _ActionButton(
                              onPressed: () =>
                                  CategoriesHelpers.showAddCategoryDialog(
                                      context),
                              icon: Iconsax.add,
                              label: 'Add Category',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CategoryList(
                        categories: categories,
                        countsByCategory: categoryCounts,
                        allFolders: folders,
                        countsByFolder: folderCounts,
                        coverByFolder: folderCover,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MacosPalette.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Iconsax.folder, size: 28, color: MacosPalette.text(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Start by importing photos or creating your first category.',
                style: MacosTypography.caption(context).copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/upload'),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<Category> categories;
  final Map<String, int> countsByCategory;
  final List<Folder> allFolders;
  final Map<String, int> countsByFolder;
  final Map<String, Photo> coverByFolder;

  const _CategoryList({
    required this.categories,
    required this.countsByCategory,
    required this.allFolders,
    required this.countsByFolder,
    required this.coverByFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: categories.map((category) {
        final categoryFolders = allFolders
            .where((folder) => folder.categoryId == category.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _CategorySection(
            category: category,
            photoCount: countsByCategory[category.id] ?? 0,
            folders: categoryFolders,
            countsByFolder: countsByFolder,
            coverByFolder: coverByFolder,
          ),
        );
      }).toList(),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final Category category;
  final int photoCount;
  final List<Folder> folders;
  final Map<String, int> countsByFolder;
  final Map<String, Photo> coverByFolder;

  const _CategorySection({
    required this.category,
    required this.photoCount,
    required this.folders,
    required this.countsByFolder,
    required this.coverByFolder,
  });

  @override
  Widget build(BuildContext context) {
    final isCollapsed = category.collapsed ?? false;
    return GestureDetector(
      onLongPress: () =>
          CategoriesHelpers.showEditCategoryDialog(context, category),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () {
                    final next = category.copyWith(collapsed: !isCollapsed);
                    context.read<CategoryBloc>().add(UpdateCategory(next));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isCollapsed
                          ? Iconsax.arrow_right_3
                          : Iconsax.arrow_down_1,
                      size: 14,
                      color: MacosPalette.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${category.name} · $photoCount photos',
                    style: MacosTypography.section(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ActionButton(
                  onPressed: () =>
                      CategoriesHelpers.showAddFolderDialog(context, category),
                  icon: Iconsax.add,
                  label: 'Add Folder',
                ),
              ],
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 10),
              if (folders.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    color: MacosPalette.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No folders in this category',
                    style: MacosTypography.caption(context),
                  ),
                )
              else
                _FolderGrid(
                  folders: folders,
                  countsByFolder: countsByFolder,
                  coverByFolder: coverByFolder,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FolderGrid extends StatelessWidget {
  final List<Folder> folders;
  final Map<String, int> countsByFolder;
  final Map<String, Photo> coverByFolder;

  const _FolderGrid({
    required this.folders,
    required this.countsByFolder,
    required this.coverByFolder,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth = 186.0;
    const cardHeight = 132.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: folders.map((folder) {
          final count = countsByFolder[folder.id] ?? 0;
          final coverPhoto = coverByFolder[folder.id];
          return SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: _FolderCard(
              folder: folder,
              photoCount: count,
              coverPhoto: coverPhoto,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final Folder folder;
  final int photoCount;
  final Photo? coverPhoto;

  const _FolderCard({
    required this.folder,
    required this.photoCount,
    required this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final coverPath = _resolveCoverPath(coverPhoto);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/folder', arguments: folder),
      onLongPress: () => FoldersHelpers.showEditFolderDialog(context, folder),
      child: Container(
        decoration: BoxDecoration(
          color: MacosPalette.surfaceAlt(context),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: coverPath != null
                  ? Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: MacosPalette.surfaceAlt(context),
                      child: Icon(
                        Iconsax.folder,
                        size: 36,
                        color: MacosPalette.text(context),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF000000).withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$photoCount photos',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveCoverPath(Photo? photo) {
    if (photo == null) return null;
    if (!photo.isStoredInApp) return photo.path;
    final helper = PhotoPathHelper();
    if (photo.mediaType == 'video' &&
        photo.videoPreview != null &&
        photo.videoPreview!.isNotEmpty) {
      return helper.getFullPath(photo.videoPreview!);
    }
    return helper.getFullPath(photo.fileName);
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: MacosPalette.text(context)),
      label: Text(
        label,
        style: TextStyle(
          color: MacosPalette.text(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: MacosPalette.surfaceAlt(context),
        foregroundColor: MacosPalette.text(context),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
