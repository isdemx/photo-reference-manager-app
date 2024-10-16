import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoGridView extends StatefulWidget {
  final List<Photo> photos;
  final Widget? actionFromParent;
  final String title;
  final bool? showShareBtn;

  const PhotoGridView({
    Key? key,
    required this.photos,
    this.actionFromParent,
    required this.title,
    this.showShareBtn,
  }) : super(key: key);

  @override
  _PhotoGridViewState createState() => _PhotoGridViewState();
}

class _PhotoGridViewState extends State<PhotoGridView> {
  bool _isMultiSelect = false;
  final List<Photo> _selectedPhotos = [];
  int _columnCount = 3; // Начальное значение колонок
  bool _isPinterestLayout = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Загружаем значения при инициализации
  }

  void _onPhotoTap(BuildContext context, int index) {
    if (_isMultiSelect) {
      _toggleSelection(widget.photos[index]);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoViewerScreen(
            photos: widget.photos,
            initialIndex: index,
          ),
        ),
      );
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
    String titleText = widget.title;
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
                backgroundColor: Colors.black.withOpacity(0.5),
                pinned: true,
                title: Row(
                  children: [
                    Expanded(child: Text(titleText)),
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
                        if (widget.showShareBtn == true)
                          IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () => ImagesHelpers.sharePhotos(
                                  context, _selectedPhotos))
                      ]
                    : [
                        IconButton(
                          icon: const Icon(Icons.done),
                          onPressed: _onDonePressed,
                        )
                      ]),
            SliverPadding(
                padding: const EdgeInsets.all(8.0),
                sliver: _isPinterestLayout
                    ? SliverMasonryGrid.count(
                        crossAxisCount: _columnCount,
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                        childCount: widget.photos.length,
                        itemBuilder: (context, index) {
                          final photo = widget.photos[index];
                          return Container(
                            decoration: BoxDecoration(
                              border: _isMultiSelect &&
                                      _selectedPhotos.contains(photo)
                                  ? Border.all(color: Colors.white, width: 3.0)
                                  : null, // Добавляем белую рамку, если выполняются условия
                            ),
                            child: PhotoThumbnail(
                                photo: photo,
                                onPhotoTap: () => _onPhotoTap(context, index),
                                isPinterestLayout: true,
                                onLongPress: () => {
                                      vibrate(),
                                      _onThumbnailLongPress(context, photo),
                                    }),
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
                            final photo = widget.photos[index];
                            return Container(
                              decoration: BoxDecoration(
                                border: _isMultiSelect &&
                                        _selectedPhotos.contains(photo)
                                    ? Border.all(
                                        color: Colors.white, width: 3.0)
                                    : null, // Добавляем белую рамку, если выполняются условия
                              ),
                              child: PhotoThumbnail(
                                  photo: photo,
                                  onPhotoTap: () => _onPhotoTap(context, index),
                                  isPinterestLayout: false,
                                  onLongPress: () => {
                                        vibrate(),
                                        _onThumbnailLongPress(context, photo),
                                      }),
                            );
                          },
                          childCount: widget.photos.length,
                        ),
                      )),
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
                    icon: const Icon(Icons.delete,
                        color: Color.fromARGB(255, 120, 13, 13)),
                    onPressed: () => _onDeletePressed(context, _selectedPhotos),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
