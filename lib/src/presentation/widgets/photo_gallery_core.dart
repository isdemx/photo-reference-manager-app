import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoGalleryCore extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;
  final bool pageViewScrollable;
  final double miniatureWidth;
  final double? thumbnailWidth;
  final int Function(Photo p) nonceOf;
  final VoidCallback? onTap;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<int>? onThumbnailTap;
  final bool showThumbnails;
  final ScrollController? thumbnailController;
  final void Function(int index)? onScrollThumbnailsToCenter;
  final VoidCallback? onThumbnailScrollUpdate;
  final PhotoViewScaleStateController? scaleStateController;
  final bool isFlipped;
  final PageController? pageController;
  final bool enableKeyboardNavigation;
  final FocusNode? focusNode;
  final bool autofocus;
  final GlobalKey? thumbnailsKey;
  final double thumbnailsBottomPadding;

  const PhotoGalleryCore({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.pageViewScrollable,
    required this.miniatureWidth,
    required this.nonceOf,
    required this.isFlipped,
    this.onTap,
    this.onIndexChanged,
    this.onThumbnailTap,
    this.showThumbnails = true,
    this.thumbnailController,
    this.onScrollThumbnailsToCenter,
    this.onThumbnailScrollUpdate,
    this.scaleStateController,
    this.pageController,
    this.enableKeyboardNavigation = false,
    this.focusNode,
    this.autofocus = false,
    this.thumbnailsKey,
    this.thumbnailWidth,
    this.thumbnailsBottomPadding = 0.0,
  });

  @override
  State<PhotoGalleryCore> createState() => _PhotoGalleryCoreState();
}

class _PhotoGalleryCoreState extends State<PhotoGalleryCore> {
  late final PageController _pageController;
  bool _ownsController = false;
  Timer? _keyRepeatDelay;
  Timer? _keyRepeatTick;
  LogicalKeyboardKey? _heldArrowKey;

  @override
  void initState() {
    super.initState();
    if (widget.pageController != null) {
      _pageController = widget.pageController!;
      _ownsController = false;
    } else {
      _pageController = PageController(initialPage: widget.initialIndex);
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _cancelKeyRepeat();
    if (_ownsController) {
      _pageController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(child: _buildGallery()),
        if (widget.showThumbnails) _buildThumbnails(),
      ],
    );

    if (!widget.enableKeyboardNavigation) {
      return content;
    }

    return Focus(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToRelative(-1);
            _startKeyRepeat(LogicalKeyboardKey.arrowLeft);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToRelative(1);
            _startKeyRepeat(LogicalKeyboardKey.arrowRight);
            return KeyEventResult.handled;
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _cancelKeyRepeat();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: content,
    );
  }

  Widget _buildGallery() {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return PhotoViewGallery.builder(
      backgroundDecoration: BoxDecoration(color: bg),
      pageController: _pageController,
      scrollPhysics: widget.pageViewScrollable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.photos.length,
      onPageChanged: (index) {
        widget.onIndexChanged?.call(index);
        widget.onScrollThumbnailsToCenter?.call(index);
      },
      builder: (context, index) {
        final photo = widget.photos[index];

        if (photo.mediaType == 'video') {
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained,
            onTapUp: (_, __, ___) => widget.onTap?.call(),
            heroAttributes: PhotoViewHeroAttributes(tag: 'video_${photo.id}'),
            child: GalleryVideoPage(
              index: index,
              currentIndex: index,
              photo: photo,
              autoplay: true,
              looping: true,
              volume: 0.0,
            ),
          );
        } else {
          final fullPath = _resolvePhotoPath(photo);
          final isGif = _isGifPath(fullPath);

          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            onTapUp: (_, __, ___) => widget.onTap?.call(),
            heroAttributes: PhotoViewHeroAttributes(
              tag: 'image_${photo.id}_${widget.nonceOf(photo)}',
            ),
            child: KeyedSubtree(
              key: ValueKey('image_${photo.id}_${widget.nonceOf(photo)}'),
              child: Transform(
                alignment: Alignment.center,
                transform: widget.isFlipped
                    ? Matrix4.rotationY(3.14159)
                    : Matrix4.identity(),
                child: isGif
                    ? InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.file(
                          File(fullPath),
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                        ),
                      )
                    : PhotoView(
                        imageProvider: FileImage(File(fullPath)),
                        backgroundDecoration: BoxDecoration(color: bg),
                        gaplessPlayback: true,
                        scaleStateController: widget.scaleStateController,
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
            ),
          );
        }
      },
    );
  }

  Widget _buildThumbnails() {
    final controller = widget.thumbnailController ?? ScrollController();
    final thumbWidth = widget.thumbnailWidth ?? widget.miniatureWidth;
    return SizedBox(
      key: widget.thumbnailsKey,
      height: widget.miniatureWidth + widget.thumbnailsBottomPadding,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo is ScrollUpdateNotification) {
            widget.onThumbnailScrollUpdate?.call();
          }
          return false;
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: widget.miniatureWidth,
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length + 2,
              itemBuilder: (context, index) {
                if (index == 0 || index == widget.photos.length + 1) {
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                  );
                }

                final photo = widget.photos[index - 1];
                final thumbPath = photo.mediaType == 'video' &&
                        photo.videoPreview != null &&
                        photo.videoPreview!.isNotEmpty
                    ? PhotoPathHelper().getFullPath(photo.videoPreview!)
                    : _resolvePhotoPath(photo);

                return GestureDetector(
                  onTap: () => widget.onThumbnailTap?.call(index - 1),
                  child: Container(
                    width: thumbWidth,
                    margin: const EdgeInsets.symmetric(horizontal: 0.0),
                    child: Image.file(
                      File(thumbPath),
                      key: ValueKey(
                          'thumb_${photo.id}_${widget.nonceOf(photo)}'),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _resolvePhotoPath(Photo photo) {
    if (photo.path.isNotEmpty && File(photo.path).existsSync()) {
      return photo.path;
    }
    return PhotoPathHelper().getFullPath(photo.fileName);
  }

  bool _isGifPath(String path) => path.toLowerCase().endsWith('.gif');

  void _goToRelative(int delta) {
    if (widget.photos.isEmpty) return;
    if (!_pageController.hasClients) return;
    final current =
        (_pageController.page ?? widget.initialIndex.toDouble()).round();
    final target = (current + delta).clamp(0, widget.photos.length - 1).toInt();
    if (target == current) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _startKeyRepeat(LogicalKeyboardKey key) {
    if (_heldArrowKey == key && _keyRepeatTick != null) return;
    _heldArrowKey = key;
    _keyRepeatDelay?.cancel();
    _keyRepeatTick?.cancel();
    _keyRepeatDelay = Timer(const Duration(seconds: 1), () {
      _keyRepeatTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_heldArrowKey == LogicalKeyboardKey.arrowLeft) {
          _goToRelative(-1);
        } else if (_heldArrowKey == LogicalKeyboardKey.arrowRight) {
          _goToRelative(1);
        }
      });
    });
  }

  void _cancelKeyRepeat() {
    _heldArrowKey = null;
    _keyRepeatDelay?.cancel();
    _keyRepeatTick?.cancel();
    _keyRepeatDelay = null;
    _keyRepeatTick = null;
  }
}
