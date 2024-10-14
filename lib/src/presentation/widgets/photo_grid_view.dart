import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

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
  final PhotoShareHelper _shareHelper = PhotoShareHelper();

  Future<bool> _onShareTap(BuildContext context, List<Photo> photos) async {
    if (photos.isNotEmpty) {
      try {
        return await _shareHelper.shareMultiplePhotos(photos);
      } catch (e) {
        CustomSnackBar.showError(context, 'Error while sharing photos: $e');
        return false;
      }
    } else {
      CustomSnackBar.showError(context, 'No photos for share');
      return false;
    }
  }

  void _onPhotoDelete(BuildContext context, Photo photo) {
    BlocProvider.of<PhotoBloc>(context).add(DeletePhoto(photo.id));
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
    print('SERT MUL');
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
    bool shareResult = await _onShareTap(context, _selectedPhotos);
    if (shareResult) {
      _turnMultiSelectModeOff();
      CustomSnackBar.showSuccess(context, 'Images were sucessfully shared');
    }
  }

  void _onDeletePressed(BuildContext context, List<Photo> photos) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content:
              const Text('Are you sure you want to delete these pictures?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог без удаления
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Если подтверждено, удаляем фотографии
                for (var photo in photos) {
                  _onPhotoDelete(context, photo);
                }
                Navigator.of(context).pop(); // Закрыть диалог после удаления
                _turnMultiSelectModeOff();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
                          onPressed: () {
                            setState(() {
                              _isPinterestLayout = !_isPinterestLayout;
                            });
                          },
                          tooltip: _isPinterestLayout
                              ? 'Switch to Grid View'
                              : 'Switch to Pinterest View',
                        ),
                        if (widget.showShareBtn == true)
                          IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () =>
                                  _onShareTap(context, widget.photos)),
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
                              onLongPress: () =>
                                  _onThumbnailLongPress(context, photo),
                            ),
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
                                onLongPress: () =>
                                    _onThumbnailLongPress(context, photo),
                              ),
                            );
                          },
                          childCount: widget.photos.length,
                        ),
                      )),
          ],
        ),
        ColumnSlider(
          initialCount: 3,
          columnCount: _columnCount,
          onChanged: (value) {
            setState(() {
              _columnCount = value;
            });
          },
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
