// lib/src/presentation/widgets/photo_grid_view.dart
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:path/path.dart' as p;

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';

import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';

import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/video_generator.dart';

import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/filter_panel.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_overlay.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

// Быстрое чтение размеров из заголовков (без полного декода пикселей)
import 'package:image_size_getter/image_size_getter.dart';

class PhotoGridView extends StatefulWidget {
  final List<Photo> photos;
  final List<Tag> tags;
  final Widget? actionFromParent;
  final String title;
  final bool? showShareBtn;
  final bool showFilter;
  final bool showInternalAppBar;

  const PhotoGridView({
    super.key,
    required this.photos,
    required this.tags,
    this.actionFromParent,
    required this.title,
    this.showShareBtn,
    this.showFilter = true,
    this.showInternalAppBar = true,
  });

  @override
  PhotoGridViewState createState() => PhotoGridViewState();
}

class PhotoGridViewState extends State<PhotoGridView> {
  // ---------------- Multi-select ----------------
  bool _isMultiSelect = false;
  final List<Photo> _selectedPhotos = [];

  // Drag-select
  bool _isDragSelecting = false;
  final Set<int> _dragToggledIndices = {};
  final GlobalKey _scrollKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _dragToggledIds = {};

  // ---------------- Layout / prefs ----------------
  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  static const double _multiBarHeight = 96.0;

  int _columnCount = 3;
  bool _isPinterestLayout = true;
  bool _showFilterPanel = false;
  bool _isSharing = false;

  // ---------------- Производительность ----------------
  static const int _pageSize = 180;
  int _visibleCount = 0;

  // ---------------- Meta cache (ratio by photo.id) ----------------
  // ratio = width / height
  final Map<String, double> _ratioById = {};
  final Set<String> _ratioLoading = {}; // чтобы не дублировать задачи

  /// Режим логики фильтра по тегам: false = OR, true = AND
  bool _filterAndMode = false;

  // ---------------- Sort by file size ----------------
  bool _sortByFileSize = false;
  bool _fileSizesLoading = false;
  final Map<String, int> _fileSizeById = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ---------------- Helpers: размер файла ----------------
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static Future<Map<String, int>> _computeFileSizesInIsolate(
      List<Map<String, String>> items) async {
    return await Isolate.run<Map<String, int>>(() {
      final result = <String, int>{};

      for (final item in items) {
        final String id = item['id']!;
        final String path = item['path']!;
        try {
          final file = File(path);
          if (file.existsSync()) {
            final size = file.lengthSync();
            result[id] = size;
          }
        } catch (_) {
          // игнорируем ошибки доступа к конкретным файлам
        }
      }

      return result;
    });
  }

  Future<void> _toggleSortByFileSize() async {
    // если уже включено — выключаем и возвращаемся к обычному порядку
    if (_sortByFileSize) {
      setState(() {
        _sortByFileSize = false;
        _visibleCount = 0; // сброс пагинации
      });
      return;
    }

    // Включаем сортировку: надо посчитать размеры для тех фото, которых нет в кэше
    final helper = PhotoPathHelper();

    final missing =
        widget.photos.where((p) => !_fileSizeById.containsKey(p.id)).map((p) {
      final effectivePath =
          p.isStoredInApp ? helper.getFullPath(p.fileName) : p.path;
      return {
        'id': p.id,
        'path': effectivePath,
      };
    }).toList();

    if (missing.isEmpty) {
      // все размеры уже есть, просто включаем сортировку
      setState(() {
        _sortByFileSize = true;
        _visibleCount = 0;
      });
      return;
    }

    setState(() {
      _fileSizesLoading = true;
    });

    try {
      final newSizes = await _computeFileSizesInIsolate(missing);
      if (!mounted) return;
      setState(() {
        _fileSizeById.addAll(newSizes);
        _sortByFileSize = true;
        _fileSizesLoading = false;
        _visibleCount = 0; // сброс пагинации
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileSizesLoading = false;
      });
    }
  }

  Future<void> toggleSortByFileSizeFromHost() => _toggleSortByFileSize();

  void toggleLayoutFromHost() => _togglePinterestLayout();

  void toggleFilterPanelFromHost() {
    setState(() => _showFilterPanel = !_showFilterPanel);
  }

  // ---------------- Фильтрация ----------------
  List<Photo> _filterPhotos({
    required List<Photo> photos,
    required List<Tag> tags,
    required FilterState filterState,
  }) {
    return photos.where((photo) {
      final filters = filterState.filters;

      // --- включённые теги (true) ---
      final includeIds = filters.entries
          .where((e) => e.value == TagFilterState.trueState)
          .map((e) => e.key)
          .toSet();

      if (includeIds.isNotEmpty) {
        final photoTagIds = photo.tagIds.toSet();

        final matches = _filterAndMode
            ? includeIds.every(photoTagIds.contains) // AND
            : includeIds.any(photoTagIds.contains); // OR

        if (!matches) return false;
      }

      // --- исключённые теги (false) ---
      if (filters.values.contains(TagFilterState.falseState)) {
        final excludeIds = filters.entries
            .where((e) => e.value == TagFilterState.falseState)
            .map((e) => e.key)
            .toSet();

        final hasExcluded = photo.tagIds.any(excludeIds.contains);
        if (hasExcluded) return false;
      }

      return true;
    }).toList();
  }

  // ---------------- Навигация / действия ----------------
  void _showPhotoViewerOverlay(
      BuildContext context, int index, List<Photo> currentList) {
    showPhotoViewerOverlay(
      context,
      PhotoViewerScreen(photos: currentList, initialIndex: index),
    );
  }

  void _onPhotoTap(BuildContext context, int index, List<Photo> currentList) {
    if (_isMultiSelect) {
      _toggleSelection(currentList[index]);
    } else {
      _showPhotoViewerOverlay(context, index, currentList);
    }
  }

  void _onThumbnailLongPress(BuildContext context, Photo photo) {
    setState(() => _isMultiSelect = true);
    _toggleSelection(photo);
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }
      if (_selectedPhotos.isEmpty) _isMultiSelect = false;
    });
  }

  void _turnMultiSelectModeOff() {
    setState(() {
      _isMultiSelect = false;
      _selectedPhotos.clear();
    });
  }

  void _onDonePressed() => _turnMultiSelectModeOff();

  void _onSelectedViewPressed() {
    if (_selectedPhotos.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PhotoViewerScreen(photos: _selectedPhotos, initialIndex: 0),
      ),
    );
  }

  Future<void> _onSelectedSharePressed(BuildContext context) async {
    if (_selectedPhotos.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      final ok = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
      if (ok) _turnMultiSelectModeOff();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _onDeletePressed(
      BuildContext context, List<Photo> photos) async {
    if (photos.isEmpty) return;
    final ok =
        await ImagesHelpers.deleteImagesWithConfirmation(context, photos);
    if (ok) _turnMultiSelectModeOff();
  }

  void _onVideoGeneratorPressed(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VideoGeneratorWidget(photos: _selectedPhotos),
    );
  }

  void _onCollageGeneratorPressed(BuildContext context) {
    if (_selectedPhotos.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: PhotoCollageWidget(
            key: const ValueKey('photo_collage_widget'),
            photos: _selectedPhotos,
            allPhotos: widget.photos,
            startWithSelectedPhotos: true,
          ),
        ),
      ),
    );
  }

  // ---------------- Drag-select ----------------
  void _onPanStart(DragStartDetails details, List<Photo> currentList) {
    if (!_isMultiSelect) return;
    setState(() {
      _isDragSelecting = true;
      _dragToggledIndices.clear();
      _dragToggledIds.clear();
    });
    _handleDrag(details.globalPosition, currentList);
  }

  void _onPanUpdate(DragUpdateDetails details, List<Photo> currentList) {
    if (_isDragSelecting) _handleDrag(details.globalPosition, currentList);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragSelecting = false;
    _dragToggledIndices.clear();
    _dragToggledIds.clear();
  }

  void _handleDrag(Offset globalPosition, List<Photo> list) {
    final scrollBox =
        _scrollKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;
    final localPos = scrollBox.globalToLocal(globalPosition);

    for (final photo in list) {
      final key = _itemKeys[photo.id];
      if (key == null) continue;
      final ctx = key.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final topLeft = box.localToGlobal(Offset.zero, ancestor: scrollBox);
      final rect = topLeft & box.size;
      if (rect.contains(localPos)) {
        if (_dragToggledIds.add(photo.id)) {
          vibrate();
          _toggleSelection(photo);
        }
      }
    }
  }

  // ---------------- Prefs ----------------
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _columnCount = prefs.getInt('columnCount') ?? 3;
      _isPinterestLayout = prefs.getBool('isPinterestLayout') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('columnCount', _columnCount);
    await prefs.setBool('isPinterestLayout', _isPinterestLayout);
  }

  void _togglePinterestLayout() {
    setState(() => _isPinterestLayout = !_isPinterestLayout);
    _savePreferences();
  }

  void _updateColumnCount(int value) {
    setState(() => _columnCount = value);
    _savePreferences();
  }

  // ---------------- Пагинация видимого списка ----------------
  void _ensureMoreVisible(int total) {
    if (_visibleCount >= total) return;
    final next = _visibleCount == 0 ? _pageSize : (_visibleCount + _pageSize);
    _visibleCount = next > total ? total : next;
  }

  // ---------------- Ratio: чтение «на лету» в изоляте ----------------
  void _prefetchRatios(List<Photo> items, int count) {
    final upto = count.clamp(0, items.length);
    for (int i = 0; i < upto; i++) {
      _ensureRatio(items[i]);
    }
  }

  void _ensureRatio(Photo photo) {
    if (_ratioById.containsKey(photo.id)) return;
    if (_ratioLoading.contains(photo.id)) return;

    final helper = PhotoPathHelper();

    // ✅ 1) Для видео пытаемся взять ratio из превью-файла
    if (photo.isVideo) {
      String? previewPath;

      if (photo.videoPreview != null && photo.videoPreview!.isNotEmpty) {
        // videoPreview у тебя хранится как имя файла в documents/photos
        previewPath = helper.getFullPath(photo.videoPreview!);
      }

      if (previewPath == null ||
          previewPath.isEmpty ||
          !File(previewPath).existsSync()) {
        // превью нет — даём временно квадрат, но не навсегда
        _ratioById[photo.id] = 1.0;
        return;
      }

      _ratioLoading.add(photo.id);
      _readImageRatioInIsolate(previewPath).then((ratio) {
        _ratioLoading.remove(photo.id);
        if (!mounted) return;
        setState(() {
          _ratioById[photo.id] = ratio <= 0 ? 1.0 : ratio;
        });
      }).catchError((_) {
        _ratioLoading.remove(photo.id);
        if (!mounted) return;
        setState(() {
          _ratioById[photo.id] = 1.0;
        });
      });

      return;
    }

    // ✅ 2) Для фото — как было
    final String path =
        photo.isStoredInApp ? helper.getFullPath(photo.fileName) : photo.path;

    if (path.isEmpty || !File(path).existsSync()) {
      _ratioById[photo.id] = 1.0;
      return;
    }

    _ratioLoading.add(photo.id);
    _readImageRatioInIsolate(path).then((ratio) {
      _ratioLoading.remove(photo.id);
      if (!mounted) return;
      setState(() {
        _ratioById[photo.id] = ratio <= 0 ? 1.0 : ratio;
      });
    }).catchError((_) {
      _ratioLoading.remove(photo.id);
      if (!mounted) return;
      setState(() {
        _ratioById[photo.id] = 1.0;
      });
    });
  }

  static Future<double> _readImageRatioInIsolate(String path) async {
    return await Isolate.run<double>(() {
      try {
        final file = File(path);
        if (!file.existsSync()) return 1.0;

        // Поддерживаемые форматы
        final ext = p.extension(path).toLowerCase();
        const exts = [
          '.jpg',
          '.jpeg',
          '.png',
          '.webp',
          '.gif',
          '.heic',
          '.heif'
        ];
        if (!exts.contains(ext)) return 1.0;

        final sz = ImageSizeGetter.getSize(FileInput(file));
        final w = sz.width;
        final h = sz.height;
        if (w <= 0 || h <= 0) return 1.0;
        return w / h;
      } catch (_) {
        return 1.0;
      }
    });
  }

  double _ratioFor(Photo photo) {
    return _ratioById[photo.id] ?? 1.0;
  }

  void _showFullTitleBottomSheet(String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Full title',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final filterState = context.watch<FilterBloc>().state;

    final List<Photo> photosFiltered = widget.showFilter
        ? _filterPhotos(
            photos: widget.photos,
            tags: widget.tags,
            filterState: filterState,
          )
        : widget.photos;

    // --- Сортировка по размеру файла (если включена) ---
    if (_sortByFileSize) {
      photosFiltered.sort((a, b) {
        final sa = _fileSizeById[a.id] ?? 0;
        final sb = _fileSizeById[b.id] ?? 0;
        final bySize = sb.compareTo(sa); // большие сначала
        if (bySize != 0) return bySize;
        return b.dateAdded.compareTo(a.dateAdded);
      });
    }

    // 🔧 КЛАМПИМ visibleCount, если список сузился
    if (_visibleCount > photosFiltered.length) {
      _visibleCount = photosFiltered.length;
    }

    // первая порция и предзагрузка ratio для видимой области
    _ensureMoreVisible(photosFiltered.length);
    _prefetchRatios(photosFiltered, _visibleCount);

    // --- Заголовок: в режиме сортировки по размеру показываем общий вес ---
    String titleText;
    if (_sortByFileSize) {
      int totalBytes = 0;
      for (final p in photosFiltered) {
        totalBytes += _fileSizeById[p.id] ?? 0;
      }
      final sizeText = _formatBytes(totalBytes);
      titleText = '${widget.title} (${photosFiltered.length}) • $sizeText';
    } else {
      titleText = '${widget.title} (${photosFiltered.length})';
    }

    final hasActiveFilters =
        filterState.filters.isNotEmpty && widget.showFilter;
    final sliderBottom = _isMultiSelect ? (_multiBarHeight + 16.0) : 26.0;

    // Внутри build(), перед return Stack(...)
// можно вычислить один раз текущий title:
    final String currentTitle = _isMultiSelect
        ? 'Selected: ${_selectedPhotos.length}/${widget.photos.length}'
        : titleText;

    final Color currentTitleColor = _isMultiSelect
        ? colors.accent
        : (hasActiveFilters ? colors.accent : colors.text);

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: _scrollKey,
                behavior: HitTestBehavior.translucent,
                onPanStart: (d) => _onPanStart(d, photosFiltered),
                onPanUpdate: (d) => _onPanUpdate(d, photosFiltered),
                onPanEnd: _onPanEnd,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification) {
                      final m = n.metrics;
                      if (m.pixels >= m.maxScrollExtent - 200) {
                        setState(
                            () => _ensureMoreVisible(photosFiltered.length));
                        _prefetchRatios(
                            photosFiltered, _visibleCount + _pageSize);
                      }
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      if (widget.showInternalAppBar)
                        SliverAppBar(
                          backgroundColor: colors.surfaceAlt.withOpacity(0.92),
                          foregroundColor: colors.text,
                          surfaceTintColor: Colors.transparent,
                          shadowColor: colors.overlay.withOpacity(0.12),
                          pinned: true,
                          title: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: GestureDetector(
                                    onLongPress: () =>
                                        _showFullTitleBottomSheet(currentTitle),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: Text(
                                        currentTitle,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          color: currentTitleColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: !_isMultiSelect
                              ? [
                                  IconButton(
                                    icon: Icon(
                                      _isPinterestLayout
                                          ? Icons.grid_on
                                          : Icons.dashboard,
                                      color: colors.text,
                                    ),
                                    onPressed: _togglePinterestLayout,
                                    tooltip: _isPinterestLayout
                                        ? 'Switch to Grid View'
                                        : 'Switch to Masonry View',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.swap_vert,
                                      color: _sortByFileSize
                                          ? colors.accent
                                          : colors.text,
                                    ),
                                    tooltip: 'Sort by file size',
                                    onPressed: _toggleSortByFileSize,
                                  ),
                                  if (widget.showFilter)
                                    IconButton(
                                      icon: Icon(
                                        Icons.filter_list,
                                        color: hasActiveFilters
                                            ? colors.accent
                                            : colors.text,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showFilterPanel = !_showFilterPanel),
                                      tooltip: 'Filters',
                                    ),
                                  if (widget.showShareBtn == true)
                                    IconButton(
                                      icon: Icon(
                                        Icons.share,
                                        color: colors.text,
                                      ),
                                      onPressed: () => ImagesHelpers.sharePhotos(
                                        context,
                                        _selectedPhotos,
                                      ),
                                    ),
                                ]
                              : [
                                  IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      color: colors.text,
                                    ),
                                    onPressed: _onDonePressed,
                                  ),
                                ],
                        ),
                      SliverPadding(
                        padding: EdgeInsets.only(
                          left: 8.0,
                          right: 8.0,
                          top: 8.0,
                          bottom: _isMultiSelect ? _multiBarHeight : 8.0,
                        ),
                        sliver: _isPinterestLayout
                            ? SliverMasonryGrid.count(
                                crossAxisCount: _columnCount,
                                mainAxisSpacing: 8.0,
                                crossAxisSpacing: 8.0,
                                childCount: _visibleCount,
                                itemBuilder: (context, index) {
                                  final photo = photosFiltered[index];
                                  return _buildGridItem(
                                    context,
                                    index,
                                    photo,
                                    isPinterest: true,
                                    currentList: photosFiltered,
                                  );
                                },
                              )
                            : SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _columnCount,
                                  mainAxisSpacing: 8.0,
                                  crossAxisSpacing: 8.0,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final photo = photosFiltered[index];
                                    return _buildGridItem(
                                      context,
                                      index,
                                      photo,
                                      isPinterest: false,
                                      currentList: photosFiltered,
                                    );
                                  },
                                  childCount: _visibleCount,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isMacOS)
              AnimatedContainer(
                width: _showFilterPanel ? 300 : 0,
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.only(bottom: 50),
                decoration: const BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black54)],
                ),
                curve: Curves.easeInOut,
                child: _showFilterPanel
                    ? FilterPanel(
                        tags: widget.tags,
                        useAndMode: _filterAndMode,
                        onToggleLogic: () {
                          setState(() => _filterAndMode = !_filterAndMode);
                        },
                        extraAction: widget.actionFromParent,
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        if (_isSharing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
        if (_fileSizesLoading)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ColumnSlider(
          initialCount: _columnCount,
          columnCount: _columnCount,
          bottomInset: sliderBottom,
          onChanged: (value) => _updateColumnCount(value),
        ),
        if (_isMultiSelect)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.eye, color: Colors.white),
                    tooltip: 'View chosen media in Fullscreen',
                    onPressed: _onSelectedViewPressed,
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.tag, color: Colors.white),
                    tooltip: 'Add / remove tag for selected photos',
                    onPressed: () async {
                      final changed =
                          await TagsHelpers.showAddTagToImagesDialog(
                              context, _selectedPhotos);
                      if (changed) _turnMultiSelectModeOff();
                    },
                  ),
                  AddToFolderWidget(
                    photos: _selectedPhotos,
                    onFolderAdded: () {
                      CustomSnackBar.showSuccess(context, 'Applied');
                      _turnMultiSelectModeOff();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.video_add, color: Colors.white),
                    tooltip: 'Create video slideshow',
                    onPressed: () => _onVideoGeneratorPressed(context),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.grid_3, color: Colors.white),
                    tooltip: 'Create free collage',
                    onPressed: () => _onCollageGeneratorPressed(context),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.export, color: Colors.white),
                    tooltip: 'Share chosen media',
                    onPressed: () => _onSelectedSharePressed(context),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.trash,
                        color: Color.fromARGB(255, 255, 0, 0)),
                    tooltip: 'Delete chosen media',
                    onPressed: () => _onDeletePressed(context, _selectedPhotos),
                  ),
                ],
              ),
            ),
          ),
        if (!_isMacOS && _showFilterPanel && widget.showFilter)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              margin: const EdgeInsets.only(top: kToolbarHeight + 40),
              width: double.infinity,
              color: Colors.black54,
              child: FilterPanel(
                tags: widget.tags,
                useAndMode: _filterAndMode,
                onToggleLogic: () {
                  setState(() => _filterAndMode = !_filterAndMode);
                },
                extraAction: widget.actionFromParent,
              ),
            ),
          ),
      ],
    );
  }

  /// Элемент сетки.
  Widget _buildGridItem(
    BuildContext context,
    int index,
    Photo photo, {
    required bool isPinterest,
    required List<Photo> currentList,
  }) {
    final GlobalKey itemKey =
        _itemKeys.putIfAbsent(photo.id, () => GlobalKey());

    _ensureRatio(photo);

    // 🟡 ВАЖНО: для Masonry — настоящий ratio, для квадратиков — строго 1:1
    final double ratio = isPinterest ? _ratioFor(photo) : 1.0;

    final bool isSelected = _isMultiSelect && _selectedPhotos.contains(photo);
    String? sizeLabel;
    if (_sortByFileSize) {
      final sizeBytes = _fileSizeById[photo.id];
      if (sizeBytes != null && sizeBytes > 0) {
        sizeLabel = _formatBytes(sizeBytes);
      }
    }

    return Container(
      key: itemKey,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: ratio > 0 ? ratio : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PhotoThumbnail(
                key: ValueKey('thumb_${photo.id}'),
                photo: photo,
                isPinterestLayout: isPinterest,
                isSelected: isSelected,
                fileSizeLabel: sizeLabel,
                onPhotoTap: () => _onPhotoTap(context, index, currentList),
                onLongPress: () {
                  vibrate();
                  _onThumbnailLongPress(context, photo);
                },
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              bottom: 6,
              right: 6,
              child: IgnorePointer(
                ignoring: true,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
