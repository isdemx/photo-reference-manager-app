import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;
  bool _showActions = true;
  bool _selectPhotoMode = false;
  bool isInitScrolling =
      true; // Флаг для отключения обновления главной картинки
  final double _miniatureWidth = 20.0;
  
  final List<Photo> _selectedPhotos = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    // Прокручиваем миниатюры к текущему индексу при запуске
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailsToCenter(_currentIndex).then((_) {
        // После прокрутки сбрасываем флаг, чтобы главная картинка снова обновлялась
        setState(() {
          isInitScrolling = false;
        });
      });
    });
  }

  Future<void> _scrollThumbnailsToCenter(int index) async {
    final double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = _miniatureWidth;

    // Рассчитываем отступ, чтобы текущая миниатюра оказалась в центре
    final double offset =
        (index * itemWidth - (screenWidth / 2) + (itemWidth / 2)) +
            (screenWidth / 2);

    // Используем jumpTo для мгновенного скролла
    if (_thumbnailScrollController.hasClients) {
      _thumbnailScrollController.jumpTo(
        offset.clamp(
          _thumbnailScrollController.position.minScrollExtent,
          _thumbnailScrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _selectedPhotos.clear();
    super.dispose();
  }

  void _enableSelectPhotoMode(bool enable) {
    setState(() {
      _selectPhotoMode = enable;
      // Добавляем текущую фотографию сразу при включении режима выбора
      _toggleSelection(widget.photos[_currentIndex]);
    });
  }

  Future<void> _deleteImageWithConfirmation(BuildContext context) async {
    List<Photo> photos =
        _selectPhotoMode ? _selectedPhotos : [widget.photos[_currentIndex]];
    var res = await ImagesHelpers.deleteImagesWithConfirmation(context, photos);

    if (res) {
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
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        // Показываем статус бар
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        WakelockPlus.disable();

        // Используем addPostFrameCallback, чтобы дождаться полной отрисовки виджетов
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_thumbnailScrollController.hasClients) {
            print('_currentIndex $_currentIndex');
            _scrollThumbnailsToCenter(_currentIndex);
          }
        });
      } else {
        // Скрываем статус бар
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        WakelockPlus.enable();
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

  void _shareSelectedPhotos() async {
    var res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
    if (res) {
      _clearSelection();
    }
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
    if (!isInitScrolling) {
      // Только если не в процессе инициализации
      final double screenWidth = MediaQuery.of(context).size.width;
      double itemWidth = _miniatureWidth;
      final double scrollOffset = _thumbnailScrollController.offset;
      final double centerPosition =
          (scrollOffset + screenWidth / 2) - (screenWidth / 2);

      int index = (centerPosition / itemWidth)
          .floor()
          .clamp(0, widget.photos.length - 1);

      if (_currentIndex != index) {
        _pageController.jumpToPage(index);
        setState(() {
          _currentIndex = index;
        });
      }
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
        onLongPress: () => {vibrate(), _enableSelectPhotoMode(!_selectPhotoMode)},
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
            // Галерея миниатюр
            if (_showActions)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                height: 40,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollUpdateNotification) {
                      _onThumbnailScroll(); // Отслеживаем прокрутку и обновляем большую фотографию
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.photos.length + 2, // Добавляем паддинги
                    itemBuilder: (context, index) {
                      if (index == 0 || index == widget.photos.length + 1) {
                        return SizedBox(
                          width: MediaQuery.of(context).size.width *
                              0.5, // Паддинг в начале и конце
                        );
                      }

                      final photo = widget.photos[
                          index - 1]; // Корректируем индекс для доступа к фото
                      final fullPath =
                          PhotoPathHelper().getFullPath(photo.fileName);

                      return GestureDetector(
                        onTap: () =>
                            _onThumbnailTap(index - 1), // Меняем фото при клике
                        child: Container(
                          width: _miniatureWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 0.0),
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
                  photos: photos,
                  isSelectionMode:
                      _selectedPhotos.isNotEmpty || _selectPhotoMode,
                  enableSelectPhotoMode: () => _enableSelectPhotoMode(!_selectPhotoMode),
                  onShare: () {
                    _shareSelectedPhotos();
                  },
                  deletePhoto: () => _deleteImageWithConfirmation(context),
                  onAddToFolder: () {},
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
}
