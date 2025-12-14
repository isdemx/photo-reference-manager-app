import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/images_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_editor_overlay.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/handle_video_upload.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart';

/// Интенты для горячих клавиш
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

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  // ---------------- Controllers и переменные ----------------
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;

  late int _currentIndex; // Текущий индекс фото/видео
  bool _showActions = true; // Показать/скрыть верхнюю панель и ActionBar
  bool _selectPhotoMode = false; // Режим множественного выбора
  bool isInitScrolling = true; // Для скролла миниатюр
  bool _isFlipped = false; // «Переворот» фото по горизонтали
  bool _pageViewScrollable = true; // Отключаем листание при зуме

  final double _miniatureWidth = 20.0;
  final List<Photo> _selectedPhotos = [];

  // ------ Видео ------
  VideoPlayerController? _videoController;

  // ------ Зум (PhotoViewGallery) ------
  // Для отслеживания, находимся ли мы в зуме (отключать листание)
  bool _isZoomed = false;
  late PhotoViewScaleStateController _scaleStateController;

  // ------ Фокус для клавиатуры ------
  final FocusNode _focusNode = FocusNode(debugLabel: 'PhotoViewerFocusNode');
  bool _preventAutoScroll = false; // поле класса

  // ------------------------------------------------------------------
  // ------------------------ initState / dispose ----------------------
  // ------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    // Контроллер состояния зума
    _scaleStateController = PhotoViewScaleStateController();
    _scaleStateController.addIgnorableListener(() {
      final state = _scaleStateController.scaleState;
      // Если PhotoView в состоянии, где масштаб больше 1 (zoomed)
      if (state == PhotoViewScaleState.zoomedIn ||
          state == PhotoViewScaleState.zoomedOut ||
          state == PhotoViewScaleState.originalSize) {
        if (!_isZoomed) {
          setState(() {
            _isZoomed = true;
            _pageViewScrollable = false; // Отключаем перелистывание
          });
        }
      } else {
        if (_isZoomed) {
          setState(() {
            _isZoomed = false;
            _pageViewScrollable = true; // Включаем обратно
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Запрашиваем фокус для клавиатуры
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      // Инициализируем видео, если нужно
      _initializeVideoIfNeeded(_currentIndex);

      // Прокрутка миниатюр после построения
      _scrollThumbnailsToCenter(_currentIndex).then((_) {
        setState(() => isInitScrolling = false);
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _videoController?.dispose();
    _focusNode.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // -------------------------- Видео ----------------------------------
  // ------------------------------------------------------------------
  Future<void> _initializeVideoIfNeeded(int index) async {
    // Предыдущий контроллер освобождаем
    _videoController?.dispose();
    _videoController = null;

    final photo = widget.photos[index];
    if (photo.mediaType == 'video') {
      final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
      final controller = VideoPlayerController.file(File(fullPath));
      _videoController = controller;

      try {
        await controller.initialize();
        controller.play();
        controller.setLooping(true);
        controller.addListener(() => setState(() {}));
      } catch (e) {
        // Обработка ошибок при загрузке
      }
    }
  }

  // ------------------------------------------------------------------
  // ---------------------- Работа с миниатюрами -----------------------
  // ------------------------------------------------------------------
  Future<void> _scrollThumbnailsToCenter(int index) async {
    print('_scrollThumbnailsToCenter $index');
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = _miniatureWidth;

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

  void _onThumbnailTap(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
      _isFlipped = false;
    });
    _scrollThumbnailsToCenter(index);
    _initializeVideoIfNeeded(index);
  }

  void _onThumbnailScroll() {
    if (!isInitScrolling) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = _miniatureWidth;
      final scrollOffset = _thumbnailScrollController.offset;
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

  // ------------------------------------------------------------------
  // --------------------- Управление фото/видео -----------------------
  // ------------------------------------------------------------------
  void _goToNextPhoto() {
    if (_currentIndex < widget.photos.length - 1) {
      setState(() {
        _currentIndex++;
        _pageController.jumpToPage(_currentIndex);
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }

  void _goToPreviousPhoto() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.jumpToPage(_currentIndex);
        _initializeVideoIfNeeded(_currentIndex);
      });
    }
  }

  Future<void> _deleteImageWithConfirmation(BuildContext context) async {
    final photosToDelete =
        _selectPhotoMode ? _selectedPhotos : [widget.photos[_currentIndex]];

    final res = await ImagesHelpers.deleteImagesWithConfirmation(
        context, photosToDelete);
    if (!res) return;

    setState(() {
      // Удаляем из общего списка
      for (final p in photosToDelete) {
        widget.photos.remove(p);
      }

      // Корректируем _currentIndex
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }

      // Если не осталось ни одного элемента – закрываем окно
      if (widget.photos.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _pageController.jumpToPage(_currentIndex);
        _initializeVideoIfNeeded(_currentIndex);
      }
    });
  }

  // ------------------------------------------------------------------
  // ---------------------- Разные действия ----------------------------
  // ------------------------------------------------------------------
  /// Переворот изображения
  void _flipPhoto() {
    final currentPhoto = widget.photos[_currentIndex];
    if (currentPhoto.mediaType == 'video') return;
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  /// Включить/выключить режим множественного выбора
  void _enableSelectPhotoMode(bool enable) {
    setState(() {
      _selectPhotoMode = enable;
      if (enable) {
        _toggleSelection(widget.photos[_currentIndex]);
      }
    });
  }

  /// Добавить/убрать фото из выбранных
  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }
    });
  }

  /// Очистить выбор
  void _clearSelection() {
    setState(() {
      _selectedPhotos.clear();
      _selectPhotoMode = false;
    });
  }

  /// Показать/скрыть верхний AppBar и нижний ActionBar
  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        WakelockPlus.disable();
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        WakelockPlus.enable();
      }
    });

    // Важно: после setState, чтобы скролл миниатюр был правильный
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailsToCenter(_currentIndex);
    });
  }

  /// Шарим выбранные фото
  void _shareSelectedPhotos() async {
    final res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
    if (res) {
      _clearSelection();
    }
  }

  Future<void> _openEditor(Photo photo) async {
    if (!photo.isImage) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.85),
        pageBuilder: (_, __, ___) {
          return PhotoEditorOverlay(
            photo: photo,
            onSave: (Uint8List bytes, bool overwrite) async {
              if (overwrite) {
                await _overwriteCurrentPhoto(photo, bytes);
              } else {
                await _saveAsNewPhoto(photo, bytes);
              }

              if (mounted) {
                // 🔥 Чтобы кроп точно отрисовался сразу в viewer
                setState(() {});
              }
            },
          );
        },
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _overwriteCurrentPhoto(Photo photo, Uint8List bytes) async {
    final String fullPath = photo.isStoredInApp
        ? PhotoPathHelper().getFullPath(photo.fileName)
        : photo.path;

    await File(fullPath).writeAsBytes(bytes, flush: true);

    // ✅ Сброс кеша, иначе FileImage может показать старое
    final provider = FileImage(File(fullPath));
    imageCache.evict(provider);

    // ✅ Ты просил "перезаписать в базу"
    if (mounted) {
      context.read<PhotoBloc>().add(UpdatePhoto(photo));
    }
  }

  Future<void> _saveAsNewPhoto(Photo source, Uint8List bytes) async {
    final id = const Uuid().v4();
    final newFileName = 'crop_$id.jpg';

    // Пишем в app storage (как и остальные локальные фотки)
    final newFullPath = PhotoPathHelper().getFullPath(newFileName);
    await File(newFullPath).writeAsBytes(bytes, flush: true);

    final now = DateTime.now();

    final newPhoto = source.copyWith(
      id: id,
      fileName: newFileName,
      path: newFullPath,
      dateAdded: now,
      mediaType: 'image',
      videoPreview: null,
      videoDuration: null,
      isStoredInApp: true,
    );

    if (mounted) {
      context.read<PhotoBloc>().add(AddPhoto(newPhoto));
    }

    // Если хочешь, чтобы сразу в этом viewer появился новый файл — добавим в список:
    widget.photos.insert(_currentIndex + 1, newPhoto);
  }

  // ------------------------------------------------------------------
  // ----------------------------- BUILD -------------------------------
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): ArrowLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): ArrowRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): EscapeIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): BackspaceIntent(),
      },
      child: Actions(
        actions: {
          ArrowLeftIntent: CallbackAction<ArrowLeftIntent>(
            onInvoke: (ArrowLeftIntent intent) {
              _goToPreviousPhoto();
              return null;
            },
          ),
          ArrowRightIntent: CallbackAction<ArrowRightIntent>(
            onInvoke: (ArrowRightIntent intent) {
              _goToNextPhoto();
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (EscapeIntent intent) {
              if (_selectPhotoMode) {
                setState(() => _selectPhotoMode = false);
              } else {
                Navigator.of(context).pop();
              }
              return null;
            },
          ),
          BackspaceIntent: CallbackAction<BackspaceIntent>(
            onInvoke: (BackspaceIntent intent) {
              _deleteImageWithConfirmation(context);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            // -------------------- AppBar --------------------
            appBar: _showActions
                ? AppBar(
                    title: Text(
                      '${_currentIndex + 1}/${widget.photos.length}, '
                      '${formatDate(currentPhoto.dateAdded)}',
                      style: const TextStyle(fontSize: 14.0),
                    ),
                    actions: [
                      // Если режим выбора – выводим чекбокс
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
                      // Кнопка "перевернуть" для картинок
                      if (currentPhoto.mediaType == 'image')
                        IconButton(
                          icon: const Icon(Iconsax.arrange_circle),
                          onPressed: _flipPhoto,
                        ),
                    ],
                  )
                : null,
            body: GestureDetector(
              // Тап по экрану – показать/скрыть панели
              onTap: _toggleActions,
              // Длинный тап – включить/выключить режим выбора
              onLongPress: () {
                vibrate();
                _enableSelectPhotoMode(!_selectPhotoMode);
              },
              onVerticalDragEnd: (details) {
                if (Platform.isMacOS) return;

                const double velocityThreshold =
                    1000; // Порог скорости для закрытия
                if (details.primaryVelocity != null &&
                    details.primaryVelocity!.abs() > velocityThreshold) {
                  _closeWithAnimation(context);
                }
              },
              child: Stack(
                children: [
                  // ------------ Основная область: PhotoViewGallery -----------
                  _buildPhotoGallery(),
                  // ------------ Миниатюры -----------
                  if (!Platform.isMacOS && _showActions)
                    Positioned(
                      bottom: 120,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: _buildThumbnails(),
                    ),
                  // ------------ Нижняя панель (ActionBar) -----------
                  if (_showActions)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ActionBar(
                        photo: currentPhoto,
                        photos: widget.photos,
                        isSelectionMode:
                            _selectedPhotos.isNotEmpty || _selectPhotoMode,
                        enableSelectPhotoMode: () =>
                            _enableSelectPhotoMode(!_selectPhotoMode),
                        onShare: _shareSelectedPhotos,
                        deletePhoto: () =>
                            _deleteImageWithConfirmation(context),
                        onAddToFolder: () {
                          // Ваш метод
                        },
                        onCancel: _clearSelection,
                        onAddToFolderMulti: () async {
                          if (_selectedPhotos.isEmpty) return;
                          final ok = await FoldersHelpers.showAddToFolderDialog(
                            context,
                            _selectedPhotos,
                          );
                          if (ok) _clearSelection();
                        },
                        onAddToTag: () async {
                          if (_selectedPhotos.isEmpty) return;
                          final ok = await TagsHelpers.showAddTagToImagesDialog(
                            context,
                            _selectedPhotos,
                          );
                          if (ok) _clearSelection();
                        },
                        onEdit: () => _openEditor(currentPhoto),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _closeWithAnimation(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Встроенная галерея для просмотра фото/видео
  Widget _buildPhotoGallery() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      scrollPhysics: _pageViewScrollable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.photos.length,
      onPageChanged: (index) {
        if (!_preventAutoScroll) {
          Future.delayed(const Duration(milliseconds: 1), () {
            _scrollThumbnailsToCenter(index);
            setState(() {
              _preventAutoScroll = false; // Только после завершения скролла
            });
          });
        }
        setState(() {
          _currentIndex = index;
          _isFlipped = false; // Сбрасываем переворот
          _preventAutoScroll = false;
        });
        _initializeVideoIfNeeded(index);
      },
      builder: (context, index) {
        final photo = widget.photos[index];

        // Если это видео — вернём customChild
        if (photo.mediaType == 'video') {
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained,
            onTapUp: (BuildContext context, TapUpDetails details,
                PhotoViewControllerValue controllerValue) {
              print('Photo tapped!');
              _toggleActions(); // ваш метод
            },
            // Можно разный heroTag задать, если нужно
            heroAttributes: PhotoViewHeroAttributes(tag: 'video_$index'),
            // Виджет отображения видео
            child: VideoView(index, photo, _currentIndex, _videoController),
          );
        } else {
          // Если это изображение — обычный PhotoView, но с "переворотом" при необходимости
          final fullPath = PhotoPathHelper().getFullPath(photo.fileName);

          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            onTapUp: (BuildContext context, TapUpDetails details,
                PhotoViewControllerValue controllerValue) {
              print('Photo tapped!');
              _toggleActions(); // ваш метод
            },
            heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
            child: Transform(
              alignment: Alignment.center,
              transform:
                  _isFlipped ? Matrix4.rotationY(3.14159) : Matrix4.identity(),
              child: PhotoView(
                imageProvider: FileImage(File(fullPath)),
                gaplessPlayback: true,
                scaleStateController: _scaleStateController,
                loadingBuilder: (context, progress) =>
                    const Center(child: null),
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Color.fromARGB(255, 171, 244, 54),
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
    );
  }

  /// Миниатюры внизу
  Widget _buildThumbnails() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollUpdateNotification) {
          setState(() {
            _preventAutoScroll =
                true; // пользователь «вручную» скроллит миниатюры
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
              margin: const EdgeInsets.symmetric(horizontal: 0.0),
              child: photo.mediaType == 'video'
                  ? Image.file(
                      File(PhotoPathHelper().getFullPath(photo.videoPreview!)),
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(PhotoPathHelper().getFullPath(photo.fileName)),
                      fit: BoxFit.cover,
                    ),
            ),
          );
        },
      ),
    );
  }
}
