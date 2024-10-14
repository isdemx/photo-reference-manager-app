import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
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
  List<Photo> _selectedPhotos = [];
  int _columnCount = 3; // Начальное значение колонок
  bool _isPinterestLayout = false;
  final PhotoShareHelper _shareHelper = PhotoShareHelper();

  void _onDeleteTap(context, photo) {
    context.read<PhotoBloc>().add(DeletePhoto(photo.id));
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

  void _onViewPressed() {
    // Пустой метод для кнопки "view"
  }

  void _onAddToFolderPressed() {
    // Пустой метод для кнопки "add to folder"
  }

  void _onSharePressed() {
    // Пустой метод для кнопки "share"
  }

  void _onDeletePressed() {
    // Пустой метод для кнопки "delete"
  }

  void _onDonePressed() {
    setState(() {
      _isMultiSelect = false;
      _selectedPhotos.clear(); // Очистка списка после выхода из мультиселекта
    });
  }

  @override
  Widget build(BuildContext context) {
    String titleText = widget.title;
    return Stack(children: [
      CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black.withOpacity(0.5),
            pinned: true,
            title: Row(
              children: [
                Expanded(child: Text(titleText)),
                if (widget.actionFromParent != null) widget.actionFromParent!,
              ],
            ),
            actions: [
              IconButton(
                icon:
                    Icon(_isPinterestLayout ? Icons.grid_on : Icons.dashboard),
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
                  onPressed: () async {
                    final photoState = context.read<PhotoBloc>().state;
                    if (photoState is PhotoLoaded) {
                      if (widget.photos.isNotEmpty) {
                        try {
                          await _shareHelper.shareMultiplePhotos(widget.photos);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error while sharing photos: $e')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No photos for share')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
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
                                  ? Border.all(color: Colors.white, width: 3.0)
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
    ]);
  }
}

// class _PhotoGridViewState extends State<PhotoGridView> {

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: _isMultiSelect
//           ? AppBar(
//               leading: IconButton(
//                 icon: const Icon(Icons.done),
//                 onPressed: _onDonePressed,
//               ),
//               title: Text('${_selectedPhotos.length} selected'),
//             )
//           : null, // Если multiselect = false, AppBar не отображается
//       body: Stack(
//         children: [
//           _isPinterestLayout
//               ? SliverMasonryGrid.count(
//                   crossAxisCount: widget.columnCount,
//                   mainAxisSpacing: 8.0,
//                   crossAxisSpacing: 8.0,
//                   childCount: widget.photos.length,
//                   itemBuilder: (context, index) {
//                     final photo = widget.photos[index];
//                     return PhotoThumbnail(
//                       photo: photo,
//                       onPhotoTap: () => _onPhotoTap(context, index),
//                       isPinterestLayout: true,
//                       onLongPress: () => _onThumbnailLongPress(context, photo),
//                     );
//                   },
//                 )
//               : SliverGrid(
//                   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: widget.columnCount,
//                     mainAxisSpacing: 4.0,
//                     crossAxisSpacing: 4.0,
//                   ),
//                   delegate: SliverChildBuilderDelegate(
//                     (context, index) {
//                       final photo = widget.photos[index];
//                       return PhotoThumbnail(
//                         photo: photo,
//                         onPhotoTap: () => _onPhotoTap(context, index),
//                         isPinterestLayout: false,
//                         onLongPress: () => _onThumbnailLongPress(context, photo),
//                       );
//                     },
//                     childCount: widget.photos.length,
//                   ),
//                 ),
//           if (_isMultiSelect)
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: Container(
//                 color: Colors.black54,
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.remove_red_eye, color: Colors.white),
//                       onPressed: _onViewPressed,
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.folder, color: Colors.white),
//                       onPressed: _onAddToFolderPressed,
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.share, color: Colors.white),
//                       onPressed: _onSharePressed,
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.delete, color: Colors.white),
//                       onPressed: _onDeletePressed,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
