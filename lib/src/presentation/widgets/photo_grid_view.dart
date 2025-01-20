// photo_grid_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/video_generator.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/filter_panel.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_overlay.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _columnCount = 3; // Начальное значение колонок
  bool _isPinterestLayout = false;

  bool _showFilterPanel = false; // Для отображения панели фильтров

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Загружаем значения при инициализации
  }

  // Логика фильтрации фотографий
  List<Photo> _filterPhotos({
    required List<Photo> photos,
    required List<Tag> tags,
    required FilterState filterState,
  }) {
    return photos.where((photo) {
      // Фильтрация по тегам из фильтров
      final filters = filterState.filters;

      // Если есть теги со значением true
      if (filters.values.contains(TagFilterState.trueState)) {
        final hasRequiredTag = photo.tagIds.any((tagId) {
          return filters[tagId] == TagFilterState.trueState;
        });
        if (!hasRequiredTag) {
          return false;
        }
      }

      // Если есть теги со значением false
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

  void _showPhotoViewerOverlay(BuildContext context, int index) {
    showPhotoViewerOverlay(
      context,
      PhotoViewerScreen(
        photos: _filterPhotos(
          photos: widget.photos,
          tags: widget.tags,
          filterState: context.read<FilterBloc>().state,
        ),
        initialIndex: index,
      ),
    );
  }

  // void _onPhotoTap(BuildContext context, int index) {
  //   if (_isMultiSelect) {
  //     _toggleSelection(widget.photos[index]);
  //   } else {
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => PhotoViewerScreen(
  //           photos: widget.photos,
  //           initialIndex: index,
  //         ),
  //       ),
  //     );
  //   }
  // }
  void _onPhotoTap(BuildContext context, int index) {
    if (_isMultiSelect) {
      _toggleSelection(widget.photos[index]);
    } else {
      _showPhotoViewerOverlay(context, index); // Показываем оверлей
    }
  }

  void _onThumbnailLongPress(BuildContext context, Photo photo) {
    setState(() {
      _isMultiSelect = true;
    });

    _toggleSelection(photo);
  }

  void _onDeleteLongTap() {
    setState(() {
      _selectedPhotos
          .clear(); // Очистка списка выбранных при начале мультиселекта
    });
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }

      // Если список пуст, выключаем режим мультиселекта
      if (_selectedPhotos.isEmpty) {
        _isMultiSelect = false;
      }
    });
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

  // Новый метод _onVideoGeneratorPressed
  void _onVideoGeneratorPressed(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VideoGeneratorWidget(photos: _selectedPhotos),
    );
  }

  void _onCollageGeneratorPressed(BuildContext context) {
    showModalBottomSheet(
      context: context,
      enableDrag: false, // Запрещает закрытие свайпом вниз
      isScrollControlled:
          true, // Позволяет модальному окну растягиваться на весь экран
      builder: (context) {
        return Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height, // Полная высота экрана
          color: Colors.black, // Фон (опционально)
          child: PhotoCollageWidget(photos: _selectedPhotos),
        );
      },
    );
  }

  Future<void> _onSelectedSharePressed(BuildContext context) async {
    bool res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
    if (res) {
      _turnMultiSelectModeOff();
    }
  }

  Future<void> _onDeletePressed(
      BuildContext context, List<Photo> photos) async {
    var res = await ImagesHelpers.deleteImagesWithConfirmation(context, photos);
    if (res) {
      _turnMultiSelectModeOff();
    }
  }

  void _turnMultiSelectModeOff() {
    setState(() {
      _isMultiSelect = false;
      _selectedPhotos.clear(); // Очистка списка после выхода из мультиселекта
    });
  }

  void _onDonePressed() {
    _turnMultiSelectModeOff();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _columnCount = prefs.getInt('columnCount') ?? 3;
      _isPinterestLayout = prefs.getBool('isPinterestLayout') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('columnCount', _columnCount);
    await prefs.setBool('isPinterestLayout', _isPinterestLayout);
  }

  void _togglePinterestLayout() {
    setState(() {
      _isPinterestLayout = !_isPinterestLayout;
      _savePreferences(); // Сохраняем при изменении
    });
  }

  void _updateColumnCount(int value) {
    setState(() {
      _columnCount = value;
      _savePreferences(); // Сохраняем при изменении
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterState = context.watch<FilterBloc>().state;

    // Применяем фильтрацию только если showFilter = true
    final List<Photo> photosFiltered = widget.showFilter
        ? _filterPhotos(
            photos: widget.photos,
            tags: widget.tags,
            filterState: filterState,
          )
        : widget.photos;

    // Debugging: print the number of filtered photos
    print('Filtered photos count !!: ${photosFiltered.length}');

    // Используем отфильтрованный список для подсчета количества фотографий
    String titleText = '${widget.title} (${photosFiltered.length})';

    print('titleText !!: ${titleText}');

    bool hasActiveFilters = filterState.filters.isNotEmpty && widget.showFilter;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              pinned: true,
              title: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _isMultiSelect
                            ? 'Selected: ${_selectedPhotos.length}/${widget.photos.length}'
                            : '${widget.title} (${photosFiltered.length})',
                        style: TextStyle(
                          color: _isMultiSelect
                              ? Colors.yellow
                              : (filterState.filters.isNotEmpty &&
                                      widget.showFilter
                                  ? Colors.yellow
                                  : Colors.white), // Подсветка заголовка
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
                              color: filterState.filters.isNotEmpty
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
                              context, _selectedPhotos),
                        ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: _onDonePressed,
                      ),
                    ],
            ),
            // Остальная часть вашего SliverPadding и SliverGrid

            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: _isPinterestLayout
                  ? SliverMasonryGrid.count(
                      crossAxisCount: _columnCount,
                      mainAxisSpacing: 8.0,
                      crossAxisSpacing: 8.0,
                      childCount: photosFiltered.length,
                      itemBuilder: (context, index) {
                        final photo = photosFiltered[index];
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: _isMultiSelect &&
                                        _selectedPhotos.contains(photo)
                                    ? Border.all(
                                        color: Colors.white, width: 3.0)
                                    : null,
                              ),
                              child: PhotoThumbnail(
                                photo: photo,
                                onPhotoTap: () => _onPhotoTap(context, index),
                                isPinterestLayout: true,
                                onLongPress: () => {
                                  vibrate(),
                                  _onThumbnailLongPress(context, photo),
                                },
                              ),
                            ),
                            if (_isMultiSelect &&
                                _selectedPhotos.contains(photo))
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue, // Синий фон
                                    shape: BoxShape.circle, // Круглая форма
                                  ),
                                  child: const Icon(
                                    Icons.check, // Иконка галочки
                                    color: Colors.white, // Белый цвет иконки
                                    size: 16, // Размер иконки
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columnCount,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 4.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final photo = photosFiltered[index];
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: _isMultiSelect &&
                                          _selectedPhotos.contains(photo)
                                      ? Border.all(
                                          color: Colors.white, width: 3.0)
                                      : null,
                                ),
                                child: PhotoThumbnail(
                                  photo: photo,
                                  onPhotoTap: () => _onPhotoTap(context, index),
                                  isPinterestLayout: false,
                                  onLongPress: () => {
                                    vibrate(),
                                    _onThumbnailLongPress(context, photo),
                                  },
                                ),
                              ),
                              if (_isMultiSelect &&
                                  _selectedPhotos.contains(photo))
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.blue, // Синий фон
                                      shape: BoxShape.circle, // Круглая форма
                                    ),
                                    child: const Icon(
                                      Icons.check, // Иконка галочки
                                      color: Colors.white, // Белый цвет иконки
                                      size: 16, // Размер иконки
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        childCount: photosFiltered.length,
                      ),
                    ),
            ),
          ],
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                    onPressed: _onSelectedViewPressed,
                  ),
                  AddToFolderWidget(
                    photos: _selectedPhotos,
                    onFolderAdded: () {
                      CustomSnackBar.showSuccess(context, 'Applied');
                      _turnMultiSelectModeOff();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _onSelectedSharePressed(context),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.video_collection, color: Colors.white),
                    onPressed: () =>
                        _onVideoGeneratorPressed(context), // Генерация видео
                  ),
                  IconButton(
                    icon: const Icon(Icons.grid_on,
                        color: Colors.white), // Пример иконки коллажа
                    onPressed: () => _onCollageGeneratorPressed(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        color: Color.fromARGB(255, 120, 13, 13)),
                    onPressed: () => _onDeletePressed(context, _selectedPhotos),
                  ),
                ],
              ),
            ),
          ),
        if (_showFilterPanel &&
            widget.showFilter) // Проверяем, нужно ли показывать панель фильтров
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              margin: const EdgeInsets.only(
                  top: kToolbarHeight + 40), // Отступ от AppBar
              width: double.infinity, // Занять 100% ширины
              color: Colors.black54,
              child: FilterPanel(tags: widget.tags),
            ),
          ),
      ],
    );
  }
}
