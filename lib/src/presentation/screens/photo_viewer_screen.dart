import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  bool _showActions = true;
  bool _selectPhotoMode = false;
  bool isInitScrolling =
      true; // Флаг для отключения обновления главной картинки
  bool _isFlipped = false; // Флаг для переворота фото

  final double _miniatureWidth = 20.0;
  final List<Photo> _selectedPhotos = [];

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailsToCenter(_currentIndex).then((_) {
        setState(() {
          isInitScrolling = false;
        });
        _initializeVideoIfNeeded(_currentIndex);
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _videoController?.dispose();
    _selectedPhotos.clear();
    super.dispose();
  }

  /// Инициализация видео, если mediaType == 'video'
  Future<void> _initializeVideoIfNeeded(int index) async {
    _videoController?.dispose();
    _videoController = null;

    final photo = widget.photos[index];
    if (photo.mediaType == 'video') {
      final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
      final controller = VideoPlayerController.file(File(fullPath));
      _videoController = controller;

      try {
        await controller.initialize();

        // Подпишемся на изменения, чтобы таймер/прогресс обновлялись
        controller.addListener(() => setState(() {}));

        // Автоматически запускаем видео
        controller.play();
        // Зациклить (опционально):
        controller.setLooping(true);

        setState(() {});
      } catch (e) {
        // обработка ошибок
      }
    }
  }

  Future<void> _scrollThumbnailsToCenter(int index) async {
    final double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = _miniatureWidth;

    final double offset =
        (index * itemWidth - (screenWidth / 2) + (itemWidth / 2)) +
            (screenWidth / 2);

    if (_thumbnailScrollController.hasClients) {
      _thumbnailScrollController.jumpTo(
        offset.clamp(
          _thumbnailScrollController.position.minScrollExtent,
          _thumbnailScrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  void _flipPhoto() {
    final currentPhoto = widget.photos[_currentIndex];
    if (currentPhoto.mediaType == 'video') return;

    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _enableSelectPhotoMode(bool enable) {
    setState(() {
      _selectPhotoMode = enable;
      if (enable) {
        _toggleSelection(widget.photos[_currentIndex]);
      }
    });
  }

  Future<void> _deleteImageWithConfirmation(BuildContext context) async {
    List<Photo> photos =
        _selectPhotoMode ? _selectedPhotos : [widget.photos[_currentIndex]];

    var res = await ImagesHelpers.deleteImagesWithConfirmation(context, photos);
    if (!res) return;

    setState(() {
      for (final p in photos) {
        widget.photos.remove(p);
      }

      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }

      if (widget.photos.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _pageController.jumpToPage(_currentIndex);
        _initializeVideoIfNeeded(_currentIndex);
        _scrollToThumbnail(_currentIndex);
      }
    });
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        WakelockPlus.disable();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_thumbnailScrollController.hasClients) {
            _scrollThumbnailsToCenter(_currentIndex);
          }
        });
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        WakelockPlus.enable();
      }
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
    // Можно автоскроллить, если нужно
  }

  void _onThumbnailScroll() {
    if (!isInitScrolling) {
      final double screenWidth = MediaQuery.of(context).size.width;
      double itemWidth = _miniatureWidth;
      final double scrollOffset = _thumbnailScrollController.offset;
      final double centerPosition =
          (scrollOffset + screenWidth / 2) - (screenWidth / 2);

      int index = (centerPosition / itemWidth)
          .floor()
          .clamp(0, widget.photos.length - 1);

      if (_currentIndex != index) {
        vibrate(3);
        _pageController.jumpToPage(index);
        setState(() {
          _currentIndex = index;
          _isFlipped = false;
        });
        _initializeVideoIfNeeded(index);
      }
    }
  }

  Future<String?> _getVideoThumbnail(Photo photo) async {
    try {
      final path = PhotoPathHelper().getFullPath(photo.fileName);
      final xfile = await VideoThumbnail.thumbnailFile(
        video: path,
        imageFormat: ImageFormat.JPEG,
        quality: 25,
      );
      if (xfile == null) return null;
      return xfile.path;
    } catch (e) {
      return null;
    }
  }

  // Форматируем время (mm:ss)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final currentPhoto = photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);

    bool notScroll = false;

    return RawKeyboardListener(
        focusNode: FocusNode(), // FocusNode для прослушивания клавиш
        autofocus: true, // Автоматически включаем фокус на виджете
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            // Проверяем, какая клавиша была нажата
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goToNextPhoto(); // Переключаемся на следующую фотографию
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _goToPreviousPhoto(); // Переключаемся на предыдущую фотографию
            }
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _showActions
              ? AppBar(
                  title: Text(
                    '${_currentIndex + 1}/${widget.photos.length}, '
                    '${formatDate(currentPhoto.dateAdded)}',
                    style: const TextStyle(fontSize: 14.0),
                  ),
                  actions: [
                    if (_selectPhotoMode)
                      GestureDetector(
                        onTap: () => _toggleSelection(currentPhoto),
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
                                    child: Icon(Icons.check,
                                        size: 16, color: Colors.blue),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    if (currentPhoto.mediaType == 'image')
                      IconButton(
                        icon: const Icon(Icons.flip),
                        onPressed: _flipPhoto,
                      ),
                  ],
                )
              : null,
          body: GestureDetector(
            onTap: _toggleActions,
            onLongPress: () {
              vibrate();
              _enableSelectPhotoMode(!_selectPhotoMode);
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: photos.length,
                        onPageChanged: (index) async {
                          setState(() {
                            _currentIndex = index;
                            _isFlipped = false;
                          });
                          if (!notScroll) {
                            await _scrollThumbnailsToCenter(index);
                          }
                          _initializeVideoIfNeeded(index);
                        },
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          final fullPath =
                              PhotoPathHelper().getFullPath(photo.fileName);

                          // ======= ВИДЕО =======
                          if (photo.mediaType == 'video') {
                            if (index == _currentIndex &&
                                _videoController != null) {
                              if (_videoController!.value.isInitialized) {
                                final duration =
                                    _videoController!.value.duration;
                                final position =
                                    _videoController!.value.position;

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Сам видеоплеер
                                    AspectRatio(
                                      aspectRatio:
                                          _videoController!.value.aspectRatio,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                    // Прогресс-бар + перемотка (нативный Widget)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          // Текущее время слева
                                          Text(_formatDuration(position)),
                                          const SizedBox(width: 8),
                                          // Расширяем, чтобы занять всё оставшееся место
                                          Expanded(
                                            child: VideoProgressIndicator(
                                              _videoController!,
                                              allowScrubbing: true,
                                              colors: VideoProgressColors(
                                                playedColor: Colors.blue,
                                                bufferedColor: Colors.white54,
                                                backgroundColor: Colors.black26,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Общая длительность справа
                                          Text(_formatDuration(duration)),
                                        ],
                                      ),
                                    ),
                                    // Кнопка Play/Pause
                                    IconButton(
                                      icon: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (_videoController!
                                              .value.isPlaying) {
                                            _videoController!.pause();
                                          } else {
                                            _videoController!.play();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                );
                              } else {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                            } else {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                          }

                          // ======= ИЗОБРАЖЕНИЕ =======
                          else {
                            return Transform(
                              alignment: Alignment.center,
                              transform: _isFlipped
                                  ? Matrix4.rotationY(3.14159)
                                  : Matrix4.identity(),
                              child: PhotoView(
                                imageProvider: FileImage(File(fullPath)),
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 50, color: Colors.red),
                                  );
                                },
                              ),
                            );
                          }
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
                      onNotification: (scrollInfo) {
                        if (scrollInfo is ScrollUpdateNotification) {
                          setState(() {
                            notScroll = true;
                          });
                          _onThumbnailScroll();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _thumbnailScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.photos.length + 2,
                        itemBuilder: (context, index) {
                          // Паддинги в начале/конце
                          if (index == 0 || index == widget.photos.length + 1) {
                            return SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                            );
                          }

                          final photo = widget.photos[index - 1];
                          return GestureDetector(
                            onTap: () => _onThumbnailTap(index - 1),
                            child: Container(
                              width: _miniatureWidth,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 0.0),
                              child: photo.mediaType == 'video'
                                  ? FutureBuilder<String?>(
                                      future: _getVideoThumbnail(photo),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          );
                                        }
                                        return Image.file(
                                          File(snapshot.data!),
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                  : Image.file(
                                      File(
                                        PhotoPathHelper()
                                            .getFullPath(photo.fileName),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Нижняя панель кнопок (ActionBar)
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
                      enableSelectPhotoMode: () =>
                          _enableSelectPhotoMode(!_selectPhotoMode),
                      onShare: _shareSelectedPhotos,
                      deletePhoto: () => _deleteImageWithConfirmation(context),
                      onAddToFolder: () {
                        // Ваша логика
                      },
                      onCancel: _clearSelection,
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  void _goToNextPhoto() {
    if (_currentIndex < widget.photos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 10),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex++;
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }

  void _goToPreviousPhoto() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 10),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex--;
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }
}
