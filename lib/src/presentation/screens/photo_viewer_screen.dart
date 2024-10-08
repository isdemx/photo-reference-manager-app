// lib/src/presentation/screens/photo_viewer_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_tag_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_tags_view_widget.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showActions = true;
  bool _selectPhotoMode = false;

  // Список выбранных фотографий для шаринга
  final List<Photo> _selectedPhotos = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    // Сброс выбранных фотографий при уничтожении виджета
    _selectedPhotos.clear();
    super.dispose();
  }

  void _enableSelectPhotoMode() {
    print('SETTTT bef $_selectPhotoMode');
    setState(() {
      _selectPhotoMode = true;
      // Добавляем текущую фотографию сразу при включении режима выбора
      _toggleSelection(widget.photos[_currentIndex]);
    });
    print('SETTTT $_selectPhotoMode');
  }

  void _update() {
    setState(() {
      // Здесь обновляем состояние
      // Например, если у вас есть теги или папки, которые были добавлены,
      // они будут перерендерены в виджете.
    });
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Photo"),
          content: const Text("Are you sure you want to delete this photo?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Удалить фото и закрыть диалог
                _deletePhoto(context);
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

void _deletePhoto(BuildContext context) {
  BlocProvider.of<PhotoBloc>(context)
      .add(DeletePhoto(widget.photos[_currentIndex].id));

  setState(() {
    widget.photos.removeAt(_currentIndex); // Убираем фото из списка

    // Проверяем, чтобы индекс не вышел за пределы списка после удаления
    if (_currentIndex >= widget.photos.length) {
      _currentIndex = widget.photos.length - 1; // Ставим на предыдущее фото
    }

    // Если после удаления не осталось фотографий, можно закрыть экран
    if (widget.photos.isEmpty) {
      Navigator.of(context).pop();
    } else {
      _pageController.jumpToPage(_currentIndex); // Переключаем галерею
    }
  });
}


  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
    });
  }

  // Метод для добавления/удаления фотографии из выбранных
  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }
    });
  }

  // Метод для сброса выбранных фотографий
  void _clearSelection() {
    setState(() {
      _selectedPhotos.clear();
      _selectPhotoMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final currentPhoto = photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleActions,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = photos[index];
                final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
                return PhotoView(
                  imageProvider: FileImage(File(fullPath)),
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return const Center(
                      child:
                          Icon(Icons.broken_image, size: 50, color: Colors.red),
                    );
                  },
                );
              },
            ),
            // Чекбокс в верхнем левом углу
            if (_selectPhotoMode)
              Positioned(
                top: 10,
                left: 0, // Чекбокс теперь слева
                child: GestureDetector(
                  onTap: () {
                    _toggleSelection(currentPhoto);
                  },
                  child: SafeArea(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            if (_showActions)
              Positioned(
                top: 16,
                left: 40,
                child: SafeArea(
                  child: Text(
                    '${_currentIndex + 1}/${widget.photos.length}, ${formatDate(currentPhoto.dateAdded)}', // Индекс и дата
                    style: const TextStyle(
                      fontSize: 10.0,
                    ),
                  ),
                ),
              ),

            if (_showActions)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            if (_showActions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ActionBar(
                  photo: photos[_currentIndex],
                  isSelectionMode:
                      _selectedPhotos.isNotEmpty || _selectPhotoMode,
                  enableSelectPhotoMode:
                      _enableSelectPhotoMode, // Передаем метод для включения режима выбора
                  onShare: () {
                    _shareSelectedPhotos(); // Шаринг выбранных фото
                  },
                  update: _update,
                  deletePhoto: () =>
                      _confirmDelete(context), // Передаем функцию как указатель
                  onCancel: () {
                    _clearSelection(); // Сброс выбора фото
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _shareSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;

    final PhotoShareHelper _shareHelper = PhotoShareHelper();

    try {
      var shared = await _shareHelper.shareMultiplePhotos(_selectedPhotos);
      if (shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Shared uccessfully'),
              duration: Duration(seconds: 1)),
        );
      }

      _clearSelection();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing error: $e')),
      );
    }
  }
}

class ActionBar extends StatelessWidget {
  final Photo photo;
  final bool isSelectionMode;
  final VoidCallback onShare;
  final VoidCallback onCancel;
  final VoidCallback enableSelectPhotoMode; // Новый параметр
  final VoidCallback update; // Новый параметр
  final VoidCallback deletePhoto; // Новый параметр

  const ActionBar({
    Key? key,
    required this.photo,
    required this.isSelectionMode,
    required this.onShare,
    required this.onCancel,
    required this.enableSelectPhotoMode,
    required this.update,
    required this.deletePhoto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhotoTagsViewWidget(photo: photo),
            const SizedBox(height: 8.0),
            if (isSelectionMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AddTagWidget(
                      photo: photo,
                      onTagAdded: () {
                        update();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: AddToFolderWidget(
                      photo: photo,
                      onFolderAdded: () {
                        update();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed:
                          enableSelectPhotoMode, // Вызываем метод из родительского виджета
                      tooltip: 'Share Photos',
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Color.fromARGB(255, 120, 13, 13)),
                      onPressed:
                          deletePhoto, // Вызываем метод из родительского виджета
                      tooltip: 'Share Photos',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}
