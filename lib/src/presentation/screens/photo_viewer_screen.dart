import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
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
  late ScrollController _thumbnailScrollController;
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
    _thumbnailScrollController = ScrollController();

    // Прокручиваем миниатюры к текущему индексу при запуске
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _selectedPhotos.clear();
    super.dispose();
  }

  void _enableSelectPhotoMode() {
    setState(() {
      _selectPhotoMode = true;
      // Добавляем текущую фотографию сразу при включении режима выбора
      _toggleSelection(widget.photos[_currentIndex]);
    });
  }

  void _update() {
    setState(() {
      // Обновление состояния при добавлении тегов или папок
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
        _scrollToThumbnail(_currentIndex);
      }
    });
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        // Показываем статус бар
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        // Скрываем статус бар
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
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

  void _onThumbnailTap(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
    _scrollToThumbnail(index);
  }

  void _scrollToThumbnail(int index) {
    // final double screenWidth = MediaQuery.of(context).size.width;
    // final double itemWidth = 50.0; // Ширина миниатюры
    // final double offset =
    //     index * itemWidth - (screenWidth / 2) + (itemWidth / 2);
    // _thumbnailScrollController.animateTo(
    //   offset.clamp(_thumbnailScrollController.position.minScrollExtent,
    //       _thumbnailScrollController.position.maxScrollExtent),
    //   duration: const Duration(milliseconds: 300),
    //   curve: Curves.easeInOut,
    // );
  }

  // Метод для обновления основного фото при прокрутке миниатюр
  void _onThumbnailScroll() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = 50.0; // Ширина миниатюры
    final double scrollOffset = _thumbnailScrollController.offset;
    final double centerPosition = scrollOffset + screenWidth / 2;

    int index =
        (centerPosition / itemWidth).floor().clamp(0, widget.photos.length - 1);

    if (_currentIndex != index) {
      _pageController.jumpToPage(index);
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final currentPhoto = photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _showActions
          ? AppBar(
              title: Text(
                '${_currentIndex + 1}/${widget.photos.length}, ${formatDate(currentPhoto.dateAdded)}',
                style: const TextStyle(
                  fontSize: 14.0,
                ),
              ),
              actions: [
                if (_selectPhotoMode)
                  GestureDetector(
                    onTap: () {
                      _toggleSelection(currentPhoto);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
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
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleActions,
        child: Stack(
          children: [
            Column(
              children: [
                // Основное фото
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      _scrollToThumbnail(index);
                    },
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      final fullPath =
                          PhotoPathHelper().getFullPath(photo.fileName);
                      return PhotoView(
                        imageProvider: FileImage(File(fullPath)),
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return const Center(
                            child: Icon(Icons.broken_image,
                                size: 50, color: Colors.red),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // Фиксированные миниатюры
            if (_showActions) // Галерея миниатюр
              Positioned(
                bottom: 120, // Зафиксировано вверху экрана
                left: 0,
                right: 0,
                height: 50,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollUpdateNotification) {
                      _onThumbnailScroll();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      final fullPath =
                          PhotoPathHelper().getFullPath(photo.fileName);

                      return GestureDetector(
                        onTap: () => _onThumbnailTap(index),
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: Image.file(
                            File(fullPath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Actions
            if (_showActions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ActionBar(
                  photo: photos[_currentIndex],
                  isSelectionMode:
                      _selectedPhotos.isNotEmpty || _selectPhotoMode,
                  enableSelectPhotoMode: _enableSelectPhotoMode,
                  onShare: () {
                    _shareSelectedPhotos();
                  },
                  update: _update,
                  deletePhoto: () => _confirmDelete(context),
                  onCancel: () {
                    _clearSelection();
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
              content: Text('Shared successfully'),
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


