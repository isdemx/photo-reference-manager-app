import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/video_generator.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_grid_photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/filter_panel.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_overlay.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class PhotoGridView extends StatefulWidget {
  final List<Photo> photos;
  final List<Tag> tags;
  final Widget? actionFromParent;
  final String title;
  final bool? showShareBtn;
  final bool showFilter;

  const PhotoGridView({
    super.key,
    required this.photos,
    required this.tags,
    this.actionFromParent,
    required this.title,
    this.showShareBtn,
    this.showFilter = true,
  });

  @override
  _PhotoGridViewState createState() => _PhotoGridViewState();
}

class _PhotoGridViewState extends State<PhotoGridView> {
  bool _isMultiSelect = false;
  final List<Photo> _selectedPhotos = [];

  // --- Новые поля для drag-select ---
  bool _isDragSelecting = false; // Активен ли сейчас «свайповый» выбор
  final Set<int> _dragToggledIndices =
      {}; // Индексы уже переключённые в текущем «протаскивании»
  final GlobalKey _scrollKey = GlobalKey(); // Ключ для ScrollView
  final Map<String, GlobalKey> _itemKeys = {}; // вместо List

  final Set<String> _dragToggledIds = {};

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  int _columnCount = 3;
  bool _isPinterestLayout = false;
  bool _showFilterPanel = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Логика фильтрации фотографий
  List<Photo> _filterPhotos({
    required List<Photo> photos,
    required List<Tag> tags,
    required FilterState filterState,
  }) {
    return photos.where((photo) {
      final filters = filterState.filters;
      // Теги со значением true
      if (filters.values.contains(TagFilterState.trueState)) {
        final hasRequiredTag = photo.tagIds.any((tagId) {
          return filters[tagId] == TagFilterState.trueState;
        });
        if (!hasRequiredTag) {
          return false;
        }
      }
      // Теги со значением false
      if (filters.values.contains(TagFilterState.falseState)) {
        final hasExcludedTag = photo.tagIds.any((tagId) {
          return filters[tagId] == TagFilterState.falseState;
        });
        if (hasExcludedTag) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showPhotoViewerOverlay(
      BuildContext context, int index, List<Photo> currentList) {
    showPhotoViewerOverlay(
      context,
      PhotoViewerScreen(
        photos: currentList,
        initialIndex: index,
      ),
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
    setState(() {
      _isMultiSelect = true;
    });
    _toggleSelection(photo);
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }

      if (_selectedPhotos.isEmpty) {
        _isMultiSelect = false;
      }
    });
  }

  // Завершаем мультиселект
  void _turnMultiSelectModeOff() {
    setState(() {
      _isMultiSelect = false;
      _selectedPhotos.clear();
    });
  }

  void _onDonePressed() {
    _turnMultiSelectModeOff();
  }

  void _onSelectedViewPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: _selectedPhotos,
          initialIndex: 0,
        ),
      ),
    );
  }

  Future<void> _onSelectedSharePressed(BuildContext context) async {
    setState(() {
      _isSharing = true;
    });
    try {
      bool res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
      if (res) {
        _turnMultiSelectModeOff();
      }
    } catch (e) {
      print('Error while sharing: $e');
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _onDeletePressed(
      BuildContext context, List<Photo> photos) async {
    var res = await ImagesHelpers.deleteImagesWithConfirmation(context, photos);
    if (res) {
      _turnMultiSelectModeOff();
    }
  }

  void _onVideoGeneratorPressed(BuildContext context) {
    // showModalBottomSheet(
    //   context: context,
    //   builder: (context) => VideoGeneratorWidget(photos: _selectedPhotos),
    // );
  }

  void _onCollageGeneratorPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: PhotoCollageWidget(
            key: const ValueKey('photo_collage_widget'),
            photos: _selectedPhotos,
            allPhotos: widget.photos,
          ),
        ),
      ),
    );
  }

  // Если хотите вернуть Grid-коллаж, раскомментируйте
  // void _onCollageGridGeneratorPressed(BuildContext context) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => Scaffold(
  //         body: GridCollageWidget(photos: _selectedPhotos),
  //       ),
  //     ),
  //   );
  // }

  // --- Обработка свайпа для drag-select ---
  void _onPanStart(DragStartDetails details, List<Photo> currentList) {
    // Начинаем отслеживать только если в мультиселекте
    if (_isMultiSelect) {
      setState(() {
        _isDragSelecting = true;
        _dragToggledIndices.clear();
      });
      _handleDrag(details.globalPosition, currentList);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, List<Photo> currentList) {
    if (_isDragSelecting) {
      _handleDrag(details.globalPosition, currentList);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragSelecting = false;
    _dragToggledIndices.clear();
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
          // true если добавилось впервые
          vibrate();
          _toggleSelection(photo);
        }
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _columnCount = prefs.getInt('columnCount') ?? 3;
      _isPinterestLayout = prefs.getBool('isPinterestLayout') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('columnCount', _columnCount);
    await prefs.setBool('isPinterestLayout', _isPinterestLayout);
  }

  void _togglePinterestLayout() {
    setState(() {
      _isPinterestLayout = !_isPinterestLayout;
      _savePreferences();
    });
  }

  void _updateColumnCount(int value) {
    setState(() {
      _columnCount = value;
      _savePreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterState = context.watch<FilterBloc>().state;

    final List<Photo> photosFiltered = widget.showFilter
        ? _filterPhotos(
            photos: widget.photos,
            tags: widget.tags,
            filterState: filterState,
          )
        : widget.photos;

    // Список ключей для каждого элемента (каждый рендерится в том же порядке, что и в списке)
    // _itemKeys = List.generate(photosFiltered.length, (_) => GlobalKey());

    final titleText = '${widget.title} (${photosFiltered.length})';
    final hasActiveFilters =
        filterState.filters.isNotEmpty && widget.showFilter;

    return Stack(
      children: [
        // GestureDetector для обработки драга
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: _scrollKey,
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) => _onPanStart(details, photosFiltered),
                onPanUpdate: (details) => _onPanUpdate(details, photosFiltered),
                onPanEnd: _onPanEnd,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      pinned: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                _isMultiSelect
                                    ? 'Selected: ${_selectedPhotos.length}/${widget.photos.length}'
                                    : titleText,
                                style: TextStyle(
                                  color: _isMultiSelect
                                      ? Colors.yellow
                                      : (hasActiveFilters
                                          ? Colors.yellow
                                          : Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: !_isMultiSelect
                          ? [
                              if (widget.actionFromParent != null)
                                widget.actionFromParent!,
                              IconButton(
                                icon: Icon(_isPinterestLayout
                                    ? Icons.grid_on
                                    : Icons.dashboard),
                                onPressed: _togglePinterestLayout,
                                tooltip: _isPinterestLayout
                                    ? 'Switch to Grid View'
                                    : 'Switch to Masonry View',
                              ),
                              if (widget.showFilter)
                                IconButton(
                                  icon: Icon(Icons.filter_list,
                                      color: hasActiveFilters
                                          ? Colors.yellow
                                          : Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showFilterPanel = !_showFilterPanel;
                                    });
                                  },
                                  tooltip: 'Filters',
                                ),
                              if (widget.showShareBtn == true)
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  onPressed: () => ImagesHelpers.sharePhotos(
                                    context,
                                    _selectedPhotos,
                                  ),
                                ),
                            ]
                          : [
                              IconButton(
                                icon: const Icon(Icons.cancel),
                                onPressed: _onDonePressed,
                              ),
                            ],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 8.0,
                        right: 8.0,
                        top: 8.0,
                        bottom: _isMultiSelect
                            ? 80.0
                            : 8.0, // Увеличиваем отступ, если включен мультиселект
                      ),
                      sliver: _isPinterestLayout
                          ? SliverMasonryGrid.count(
                              crossAxisCount: _columnCount,
                              mainAxisSpacing: 8.0,
                              crossAxisSpacing: 8.0,
                              childCount: photosFiltered.length,
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
                                mainAxisSpacing: 4.0,
                                crossAxisSpacing: 4.0,
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
                                childCount: photosFiltered.length,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isMacOS)
              AnimatedContainer(
                width: _showFilterPanel ? 300 : 0,
                duration: const Duration(milliseconds: 300),
                decoration: const BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black54)],
                ),
                curve: Curves.easeInOut,
                child: _showFilterPanel
                    ? FilterPanel(tags: widget.tags)
                    : const SizedBox.shrink(),
              ),
          ],
        ),

        if (_isSharing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

        ColumnSlider(
          initialCount: _columnCount,
          columnCount: _columnCount,
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
                  // Пример кнопки для Grid-коллажа
                  // IconButton(
                  //   icon: const Icon(Iconsax.grid_2, color: Colors.white),
                  //   tooltip: 'Create grid collage',
                  //   onPressed: () => _onCollageGridGeneratorPressed(context),
                  // ),
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
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              margin: const EdgeInsets.only(top: kToolbarHeight + 40),
              width: double.infinity,
              color: Colors.black54,
              child: FilterPanel(tags: widget.tags),
            ),
          ),
      ],
    );
  }

  /// Виджет одного элемента сетки
  Widget _buildGridItem(
    BuildContext context,
    int index,
    Photo photo, {
    required bool isPinterest,
    required List<Photo> currentList,
  }) {
    final GlobalKey itemKey =
        _itemKeys.putIfAbsent(photo.id, () => GlobalKey());

    return Container(
      key: itemKey, // ключ теперь постоянный
      child: Stack(
        children: [
          PhotoThumbnail(
            key: ValueKey(
                'thumb_${photo.id}'), // можно оставить, но не обязателен
            photo: photo,
            isPinterestLayout: isPinterest,
            isSelected: _isMultiSelect && _selectedPhotos.contains(photo),
            onPhotoTap: () => _onPhotoTap(context, index, currentList),
            onLongPress: () {
              vibrate();
              _onThumbnailLongPress(context, photo);
            },
          ),
          if (_isMultiSelect && _selectedPhotos.contains(photo))
            const Positioned(
              bottom: 8,
              right: 8,
              child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
            ),
        ],
      ),
    );
  }
}
