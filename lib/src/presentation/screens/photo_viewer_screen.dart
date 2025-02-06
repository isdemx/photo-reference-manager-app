import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/handle_video_upload.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart';

// --- Интенты для горячих клавиш ---
class ArrowLeftIntent extends Intent {}

class ArrowRightIntent extends Intent {}

class EscapeIntent extends Intent {}

class BackspaceIntent extends Intent {}

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

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  bool _showActions = true;
  bool _selectPhotoMode = false;
  bool isInitScrolling = true;
  bool _isFlipped = false;

  final double _miniatureWidth = 20.0;
  final List<Photo> _selectedPhotos = [];

  VideoPlayerController? _videoController;
  bool _isDismissing = false;
  double _verticalDrag = 0.0;
  double _opacity = 1.0;
  late AnimationController? _opacityController;
  bool _pageViewScrollable = true;

  // --- Фокус-узел, чтобы получать события клавиатуры ---
  final FocusNode _focusNode = FocusNode(debugLabel: 'PhotoViewerFocusNode');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacityController!.addListener(() {
      setState(() {
        _opacity = 1.0 - _opacityController!.value;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Запрашиваем фокус, чтобы клавиатура сразу работала
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }

      // Скроллим миниатюры после построения
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
    _opacityController?.dispose();
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _videoController?.dispose();
    _selectedPhotos.clear();
    _focusNode.dispose();
    super.dispose();
  }

  // ------------ Видео ------------
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
        controller.addListener(() => setState(() {}));
        controller.play();
        controller.setLooping(true);
        setState(() {});
      } catch (e) {
        // обработка ошибок
      }
    }
  }

  // ------------ Миниатюры ------------
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

  void _scrollToThumbnail(int index) {
    // Можно автоскроллить, если нужно
  }

  void _onThumbnailTap(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
    _scrollToThumbnail(index);
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

  // ------------ Листание вперёд/назад ------------
  void _goToNextPhoto([bool jump = false]) {
    if (_currentIndex < widget.photos.length - 1) {
      setState(() {
        _currentIndex++;
        if (jump) {
          _pageController.jumpToPage(_currentIndex);
        } else {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 10),
            curve: Curves.easeInOut,
          );
        }
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }

  void _goToPreviousPhoto([bool jump = false]) {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        if (jump) {
          _pageController.jumpToPage(_currentIndex);
        } else {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 10),
            curve: Curves.easeInOut,
          );
        }
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }

  // ------------ Удаление фото ------------
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

  // ------------ Вспомогательные действия ------------
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

  void _shareSelectedPhotos() async {
    var res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
    if (res) {
      _clearSelection();
    }
  }

  void _animateDragToZero() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    final animation = Tween<double>(begin: _verticalDrag, end: -1230.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    animation.addListener(() {
      setState(() {
        _verticalDrag = animation.value;
      });
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  // --------------------- САМОЕ ГЛАВНОЕ: Shortcuts + Actions ---------------------
  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final currentPhoto = photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);

    bool notScroll = false;

    return Shortcuts(
      // 1) Связываем клавиши с нашими Intent
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): ArrowLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): ArrowRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): EscapeIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): BackspaceIntent(),
      },
      child: Actions(
        // 2) Определяем, что делать при срабатывании каждого Intent
        actions: {
          ArrowLeftIntent: CallbackAction<ArrowLeftIntent>(
            onInvoke: (ArrowLeftIntent intent) {
              _goToPreviousPhoto(true); // листаем назад
              return null;
            },
          ),
          ArrowRightIntent: CallbackAction<ArrowRightIntent>(
            onInvoke: (ArrowRightIntent intent) {
              _goToNextPhoto(true); // листаем вперёд
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (EscapeIntent intent) {
              if (_selectPhotoMode) {
                setState(() {
                  _selectPhotoMode = false;
                });
              } else {
                Navigator.of(context).pop(); // закрываем окно
              }

              return null;
            },
          ),
          BackspaceIntent: CallbackAction<BackspaceIntent>(
            onInvoke: (BackspaceIntent intent) {
              _deleteImageWithConfirmation(context); // удаляем фото
              return null;
            },
          ),
        },
        child: Focus(
          // 3) Делегируем фокус на этот виджет
          focusNode: _focusNode,
          autofocus: true,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (Platform.isMacOS) return;
              if (_pageViewScrollable && !_isDismissing) {
                setState(() {
                  _verticalDrag += details.delta.dy;
                });
              }
            },
            onVerticalDragEnd: (details) {
              if (Platform.isMacOS) return;
              if (_pageViewScrollable && !_isDismissing) {
                if (_verticalDrag.abs() > 150) {
                  _isDismissing = true;
                  _opacityController?.forward().then((_) {
                    Navigator.of(context).pop();
                  });
                } else {
                  _animateDragToZero();
                }
              }
            },
            child: Transform.translate(
              offset: Offset(0, _verticalDrag),
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 0),
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
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey,
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
                            if (currentPhoto.mediaType == 'image')
                              IconButton(
                                icon: const Icon(Iconsax.arrange_circle),
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
                                physics: _pageViewScrollable
                                    ? const ClampingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
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
                                  final fullPath = PhotoPathHelper()
                                      .getFullPath(photo.fileName);

                                  // ======= ВИДЕО =======
                                  if (photo.mediaType == 'video') {
                                    if (index == _currentIndex &&
                                        _videoController != null) {
                                      if (_videoController!
                                          .value.isInitialized) {
                                        final duration =
                                            _videoController!.value.duration;
                                        final position =
                                            _videoController!.value.position;

                                        return Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AspectRatio(
                                              aspectRatio: _videoController!
                                                  .value.aspectRatio,
                                              child: VideoPlayer(
                                                  _videoController!),
                                            ),
                                            // Прогресс-бар + перемотка
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                              child: Row(
                                                children: [
                                                  Text(
                                                      formatDuration(position)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child:
                                                        VideoProgressIndicator(
                                                      _videoController!,
                                                      allowScrubbing: true,
                                                      colors:
                                                          const VideoProgressColors(
                                                        playedColor:
                                                            Colors.blue,
                                                        bufferedColor:
                                                            Colors.white54,
                                                        backgroundColor:
                                                            Colors.black26,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                      formatDuration(duration)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                _videoController!
                                                        .value.isPlaying
                                                    ? Iconsax.pause
                                                    : Iconsax.play,
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
                                        imageProvider:
                                            FileImage(File(fullPath)),
                                        gaplessPlayback: true,
                                        loadingBuilder: (context, progress) =>
                                            const Center(child: null),
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 50,
                                              color: Color.fromARGB(
                                                  255, 171, 244, 54),
                                            ),
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

                        // Галерея миниатюр (прячем на macOS)
                        if (!Platform.isMacOS && _showActions)
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
                                  if (index == 0 ||
                                      index == widget.photos.length + 1) {
                                    return SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.5,
                                    );
                                  }

                                  final photo = widget.photos[index - 1];
                                  return GestureDetector(
                                    onTap: () => _onThumbnailTap(index - 1),
                                    child: Container(
                                      width: _miniatureWidth,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 0.0),
                                      child: photo.mediaType == 'video'
                                          ? Image.file(
                                              File(
                                                PhotoPathHelper().getFullPath(
                                                    photo.videoPreview!),
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(
                                                PhotoPathHelper().getFullPath(
                                                    photo.fileName),
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
                              isSelectionMode: _selectedPhotos.isNotEmpty ||
                                  _selectPhotoMode,
                              enableSelectPhotoMode: () =>
                                  _enableSelectPhotoMode(!_selectPhotoMode),
                              onShare: _shareSelectedPhotos,
                              deletePhoto: () =>
                                  _deleteImageWithConfirmation(context),
                              onAddToFolder: () {
                                // Ваша логика
                              },
                              onCancel: _clearSelection,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
