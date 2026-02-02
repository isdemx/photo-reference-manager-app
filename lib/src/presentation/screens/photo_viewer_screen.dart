import 'dart:io';
import 'dart:ui';

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
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_editor_overlay.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_view_action_bar.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_gallery_core.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/date_format.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  final Map<String, int> _reloadNonce = <String, int>{};

  // ------ Зум (PhotoViewGallery) ------
  bool _isZoomed = false;
  late PhotoViewScaleStateController _scaleStateController;

  // ------ Фокус для клавиатуры ------
  final FocusNode _focusNode = FocusNode(debugLabel: 'PhotoViewerFocusNode');
  bool _preventAutoScroll = false; // поле класса

  int _nonce(Photo p) => _reloadNonce[p.id] ?? 0;

  void _bumpNonce(Photo p) {
    _reloadNonce[p.id] = (_reloadNonce[p.id] ?? 0) + 1;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _extensionLabel(Photo photo) {
    final ext = p.extension(photo.path).replaceFirst('.', '').toLowerCase();
    return ext;
  }

  bool _isGifPath(String path) {
    return p.extension(path).toLowerCase() == '.gif';
  }

  String _fileSizeLabel(Photo photo) {
    try {
      final path = _resolvePhotoPath(photo);
      final file = File(path);
      if (file.existsSync()) {
        return _formatBytes(file.lengthSync());
      }
    } catch (_) {
      // ignore
    }
    return '';
  }

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

      if (state == PhotoViewScaleState.zoomedIn ||
          state == PhotoViewScaleState.zoomedOut ||
          state == PhotoViewScaleState.originalSize) {
        if (!_isZoomed) {
          setState(() {
            _isZoomed = true;
            _pageViewScrollable = false;
          });
        }
      } else {
        if (_isZoomed) {
          setState(() {
            _isZoomed = false;
            _pageViewScrollable = true;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }

      // Прокрутка миниатюр после построения
      _scrollThumbnailsToCenter(_currentIndex).then((_) {
        if (mounted) setState(() => isInitScrolling = false);
      });
    });

    if (Platform.isMacOS) {
      try {
        WakelockPlus.enable();
      } catch (_) {
        // ignore
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _focusNode.dispose();
    _scaleStateController.dispose();

    // Важно: если viewer закрыли, вернем системный UI в норму и отключим wakelock (на всякий случай)
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      WakelockPlus.disable();
    } catch (_) {
      // ignore
    }

    super.dispose();
  }

  // ------------------------------------------------------------------
  // ---------------------- Работа с миниатюрами -----------------------
  // ------------------------------------------------------------------
  Future<void> _scrollThumbnailsToCenter(int index) async {
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

  String _resolvePhotoPath(Photo p) {
    return p.isStoredInApp ? PhotoPathHelper().getFullPath(p.fileName) : p.path;
  }

  void _onThumbnailTap(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
      _isFlipped = false;
    });
    _scrollThumbnailsToCenter(index);
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
      });
    }
  }

  void _goToPreviousPhoto() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.jumpToPage(_currentIndex);
      });
    }
  }

  Future<void> _deleteImageWithConfirmation(BuildContext context) async {
    final photosToDelete =
        _selectPhotoMode ? _selectedPhotos : [widget.photos[_currentIndex]];

    final res = await ImagesHelpers.deleteImagesWithConfirmation(
      context,
      photosToDelete,
    );
    if (!res) return;

    setState(() {
      for (final p in photosToDelete) {
        widget.photos.remove(p);
      }

      if (widget.photos.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }

      _pageController.jumpToPage(_currentIndex);
      _isFlipped = false;
    });
  }

  // ------------------------------------------------------------------
  // ---------------------- Разные действия ----------------------------
  // ------------------------------------------------------------------
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
      if (!Platform.isMacOS) {
        if (_showActions) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          WakelockPlus.disable();
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          WakelockPlus.enable();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailsToCenter(_currentIndex);
    });
  }

  void _shareSelectedPhotos() async {
    final res = await ImagesHelpers.sharePhotos(context, _selectedPhotos);
    if (res) {
      _clearSelection();
    }
  }

  void _openCollageWithPhotos(List<Photo> photos) {
    if (photos.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: PhotoCollageWidget(
            key: ValueKey('photo_collage_from_view_${const Uuid().v4()}'),
            photos: photos,
            allPhotos: widget.photos,
            startWithSelectedPhotos: true,
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _clearSelection();
    });
  }

  double _galleryBottomPadding(Photo p) {
    if (!_showActions) return 0.0;
    if (p.mediaType == 'video' && (p.tagIds.isEmpty)) return 50.0;
    return 90.0;
  }

  Future<void> _openEditor(Photo photo) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.85),
        pageBuilder: (_, __, ___) {
          return PhotoEditorOverlay(
            key: ValueKey('editor_${photo.id}_${_nonce(photo)}'),
            photo: photo,
            onSave: (Uint8List bytes, bool overwrite, String comment) async {
              if (overwrite) {
                await _overwriteCurrentPhoto(photo, bytes, comment);
              } else {
                await _saveAsNewPhoto(photo, bytes, comment);
              }

              if (mounted) setState(() {});
            },
            onAddNewPhoto: (newPhoto) {
              if (!mounted) return;
              setState(() {
                widget.photos.insert(_currentIndex + 1, newPhoto);
              });
            },
          );
        },
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _overwriteCurrentPhoto(
    Photo photo,
    Uint8List bytes,
    String comment,
  ) async {
    final String fullPath = _resolvePhotoPath(photo);

    await File(fullPath).writeAsBytes(bytes, flush: true);

    final provider = FileImage(File(fullPath));

    PaintingBinding.instance.imageCache.evict(provider);
    PaintingBinding.instance.imageCache.clearLiveImages();

    // 3) Бамп nonce, чтобы дерево точно пересоздалось
    setState(() {
      _bumpNonce(photo);
    });

    final updatedPhoto = photo.copyWith(comment: comment);

    if (mounted) {
      context.read<PhotoBloc>().add(UpdatePhoto(updatedPhoto));
    }

    if (mounted) {
      setState(() {
        widget.photos[_currentIndex] = updatedPhoto;
      });
    }
  }

  Future<void> _saveAsNewPhoto(
    Photo source,
    Uint8List bytes,
    String comment,
  ) async {
    final id = const Uuid().v4();
    final newFileName = 'crop_$id.jpg';

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
      comment: comment,
    );

    if (mounted) {
      context.read<PhotoBloc>().add(AddPhoto(newPhoto));
    }

    if (mounted) {
      setState(() {
        widget.photos.insert(_currentIndex + 1, newPhoto);
      });
    }
  }

  // ------------------------------------------------------------------
  // ----------------------------- BUILD -------------------------------
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];
    final isSelected = _selectedPhotos.contains(currentPhoto);
    final sizeLabel = _fileSizeLabel(currentPhoto);
    final commentText = (currentPhoto.comment ?? '').trim();
    final titleParts = <String>[
      if (currentPhoto.mediaType == 'video') currentPhoto.fileName,
      '${_currentIndex + 1}/${widget.photos.length}',
      formatDate(currentPhoto.dateAdded),
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (_extensionLabel(currentPhoto).isNotEmpty)
        _extensionLabel(currentPhoto).toUpperCase(),
    ];

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
            appBar: _showActions
                ? AppBar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    title: Text(
                      titleParts.join(' • '),
                      style: const TextStyle(fontSize: 14.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              onVerticalDragEnd: (details) {
                if (Platform.isMacOS) return;

                const double velocityThreshold = 1000;
                if (details.primaryVelocity != null &&
                    details.primaryVelocity!.abs() > velocityThreshold) {
                  _closeWithAnimation(context);
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _showActions
                            ? kToolbarHeight +
                                MediaQuery.of(context).padding.top
                            : 0,
                        bottom:
                            _galleryBottomPadding(widget.photos[_currentIndex]),
                      ),
                      child: PhotoGalleryCore(
                        photos: widget.photos,
                        initialIndex: _currentIndex,
                        pageViewScrollable: _pageViewScrollable,
                        miniatureWidth: _miniatureWidth,
                        nonceOf: _nonce,
                        isFlipped: _isFlipped,
                        enableKeyboardNavigation: false,
                        pageController: _pageController,
                        thumbnailController: _thumbnailScrollController,
                        showThumbnails:
                            _showActions && !Platform.isMacOS,
                        scaleStateController: _scaleStateController,
                        onTap: _toggleActions,
                        onIndexChanged: (index) {
                          if (!_preventAutoScroll) {
                            _scrollThumbnailsToCenter(index);
                          }
                          setState(() {
                            _currentIndex = index;
                            _isFlipped = false;
                            _preventAutoScroll = false;
                          });
                        },
                        onThumbnailTap: _onThumbnailTap,
                        onThumbnailScrollUpdate: () {
                          setState(() {
                            _preventAutoScroll = true;
                          });
                          _onThumbnailScroll();
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _showActions ? 200 : 24,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Opacity(
                        opacity: commentText.isEmpty ? 0.0 : 1.0,
                        child: FractionallySizedBox(
                          widthFactor: 0.7,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              commentText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showActions)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomBar(currentPhoto),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Photo currentPhoto) {
    final bar = ActionBar(
      photo: currentPhoto,
      photos: widget.photos,
      isSelectionMode: _selectedPhotos.isNotEmpty || _selectPhotoMode,
      enableSelectPhotoMode: () => _enableSelectPhotoMode(!_selectPhotoMode),
      onShare: _shareSelectedPhotos,
      deletePhoto: () => _deleteImageWithConfirmation(context),
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
      onAddToCollage: () => _openCollageWithPhotos([currentPhoto]),
      onAddToCollageMulti: () => _openCollageWithPhotos(_selectedPhotos),
      onEdit: () => _openEditor(currentPhoto),
    );

    if (!_isZoomed) return bar;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: Colors.black.withOpacity(0.2),
          child: bar,
        ),
      ),
    );
  }

  void _closeWithAnimation(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Photo gallery and thumbnail rendering are handled by PhotoGalleryCore.
}
