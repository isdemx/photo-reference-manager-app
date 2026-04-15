import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as image_size_getter;
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/services/lite_folder_viewer_service.dart';
import 'package:video_player/video_player.dart';
import 'package:window_manager/window_manager.dart';

class ToggleFullScreenIntent extends Intent {
  const ToggleFullScreenIntent();
}

class LitePhotoViewerScreen extends StatefulWidget {
  const LitePhotoViewerScreen({
    super.key,
    required this.initialFilePath,
    this.initialViewportAspectRatio,
  });

  final String initialFilePath;
  final double? initialViewportAspectRatio;

  @override
  State<LitePhotoViewerScreen> createState() => _LitePhotoViewerScreenState();
}

class _LitePhotoViewerScreenState extends State<LitePhotoViewerScreen> {
  late final Future<LiteFolderViewerData> _dataFuture;
  final FocusNode _focusNode = FocusNode(debugLabel: 'LitePhotoViewer');
  final Map<String, _LiteMediaMetadata> _metadataByPath = {};
  final Map<String, ImageProvider> _imageProviderByPath = {};
  final List<_LiteCanvasItem> _canvasItems = [];

  int _currentIndex = 0;
  int _displayedIndex = 0;
  bool _isImporting = false;
  bool _isSwitching = false;
  bool _canvasInitialized = false;
  int? _queuedStep;
  int? _lastPrecachingIndex;
  String? _activeCanvasItemId;
  Size _canvasSize = Size.zero;

  String? _scalingItemId;
  double _scaleStartScale = 1.0;
  Offset _scaleStartOffset = Offset.zero;
  Offset _scaleStartFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[RefmaOpenFiles][dart] LitePhotoViewerScreen init initialFilePath=${widget.initialFilePath}',
    );
    _dataFuture = LiteFolderViewerService().load(widget.initialFilePath);
    _dataFuture.then((data) {
      if (!mounted) return;
      setState(() {
        _currentIndex = data.initialIndex;
        _displayedIndex = data.initialIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }).catchError((error, stackTrace) {
      debugPrint(
        '[RefmaOpenFiles][dart] LitePhotoViewerScreen load error=$error',
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  _LiteCanvasItem? get _activeCanvasItem {
    if (_activeCanvasItemId == null) return null;
    for (final item in _canvasItems) {
      if (item.id == _activeCanvasItemId) return item;
    }
    return null;
  }

  LiteViewerItem _viewerItemFor(
    LiteFolderViewerData data,
    _LiteCanvasItem item,
  ) {
    return data.items[item.folderIndex];
  }

  _LiteMediaMetadata _metadataForCanvasItem(
    LiteFolderViewerData data,
    _LiteCanvasItem item,
  ) {
    return _readMetadata(_viewerItemFor(data, item));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleFullScreen() async {
    try {
      final isFullScreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullScreen);
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _importCurrentItem(LiteViewerItem item) async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    try {
      await PhotoSaveHelper.importExternalFile(
        sourcePath: item.path,
        context: context,
      );
      _showMessage('${item.name} added to Refma');
    } catch (_) {
      _showMessage('Failed to add file to Refma');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  _LiteMediaMetadata _readMetadata(LiteViewerItem item) {
    final cached = _metadataByPath[item.path];
    if (cached != null) return cached;

    final file = File(item.path);
    final fileSizeBytes = file.existsSync() ? file.lengthSync() : null;
    int? pixelWidth;
    int? pixelHeight;
    double? aspectRatio;

    if (item.isVideo) {
      aspectRatio = 16 / 9;
    } else {
      try {
        final result =
            image_size_getter.ImageSizeGetter.getSizeResult(FileInput(file));
        pixelWidth = result.size.width.round();
        pixelHeight = result.size.height.round();
        if (result.size.height > 0) {
          aspectRatio = result.size.width / result.size.height;
        }
      } catch (_) {}
    }

    final metadata = _LiteMediaMetadata(
      fileSizeBytes: fileSizeBytes,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      aspectRatio: aspectRatio,
    );
    _metadataByPath[item.path] = metadata;
    return metadata;
  }

  String _formatBytes(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}kb';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)}mb';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)}gb';
  }

  String _buildTopBarText(
    LiteFolderViewerData data,
    LiteViewerItem currentItem,
    _LiteMediaMetadata metadata,
  ) {
    final parts = <String>[
      '${_currentIndex + 1}/${data.items.length}',
      currentItem.name.toUpperCase(),
    ];

    if (metadata.pixelWidth != null && metadata.pixelHeight != null) {
      parts.add('${metadata.pixelWidth}x${metadata.pixelHeight}');
    }

    if (metadata.fileSizeBytes != null) {
      parts.add(_formatBytes(metadata.fileSizeBytes!));
    }

    parts.add('Refma');
    return parts.join(' ');
  }

  ImageProvider _imageProviderFor(LiteViewerItem item) {
    return _imageProviderByPath.putIfAbsent(
      item.path,
      () => FileImage(File(item.path)),
    );
  }

  Future<void> _prepareItem(LiteViewerItem item) async {
    if (item.isVideo) return;
    try {
      await precacheImage(_imageProviderFor(item), context).timeout(
        const Duration(milliseconds: 700),
      );
    } catch (_) {}
  }

  void _precacheNearbyItems(LiteFolderViewerData data, int centerIndex) {
    if (!mounted || _lastPrecachingIndex == centerIndex) return;
    _lastPrecachingIndex = centerIndex;

    final indices = <int>{
      centerIndex,
      if (centerIndex > 0) centerIndex - 1,
      if (centerIndex < data.items.length - 1) centerIndex + 1,
    };

    for (final index in indices) {
      final item = data.items[index];
      if (!item.isImage) continue;
      precacheImage(_imageProviderFor(item), context);
    }
  }

  _LiteCanvasItem _createCanvasItem({required int folderIndex}) {
    return _LiteCanvasItem(
      id: UniqueKey().toString(),
      folderIndex: folderIndex,
      zIndex: _canvasItems.length,
    );
  }

  double _fitScaleForMetadata(_LiteMediaMetadata metadata, Size canvasSize) {
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        metadata.pixelWidth == null ||
        metadata.pixelHeight == null ||
        metadata.pixelWidth == 0 ||
        metadata.pixelHeight == 0) {
      return 1;
    }
    return math.min(
      canvasSize.width / metadata.pixelWidth!,
      canvasSize.height / metadata.pixelHeight!,
    );
  }

  double _scaledWidthForItem(
    _LiteCanvasItem item,
    LiteFolderViewerData data,
  ) {
    final metadata = _metadataForCanvasItem(data, item);
    return (metadata.pixelWidth ?? 1000).toDouble() * item.scale;
  }

  void _fitSingleCanvasItemToCanvas(
    _LiteCanvasItem item,
    LiteFolderViewerData data,
  ) {
    final canvasSize = _canvasSize;
    final metadata = _metadataForCanvasItem(data, item);
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    final baseWidth = (metadata.pixelWidth ?? 1000).toDouble();
    final baseHeight = (metadata.pixelHeight ?? 1000).toDouble();
    final scale = _fitScaleForMetadata(metadata, canvasSize);
    final scaledWidth = baseWidth * scale;
    final scaledHeight = baseHeight * scale;

    item
      ..scale = scale
      ..offset = Offset(
        (canvasSize.width - scaledWidth) / 2,
        (canvasSize.height - scaledHeight) / 2,
      );
  }

  void _placeNewCanvasItemCentered(
    _LiteCanvasItem newItem,
    LiteFolderViewerData data,
  ) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) return;

    final metadata = _metadataForCanvasItem(data, newItem);
    final baseWidth = (metadata.pixelWidth ?? 1000).toDouble();
    final baseHeight = (metadata.pixelHeight ?? 1000).toDouble();
    final scale = _fitScaleForMetadata(metadata, _canvasSize);
    final scaledWidth = baseWidth * scale;
    final scaledHeight = baseHeight * scale;
    final centeredOffset = Offset(
      (_canvasSize.width - scaledWidth) / 2,
      (_canvasSize.height - scaledHeight) / 2,
    );

    const gap = 32.0;
    var shiftLeft = 0.0;

    for (final item in _canvasItems) {
      if (item.id == newItem.id) continue;
      final itemMetadata = _metadataForCanvasItem(data, item);
      final itemWidth = (itemMetadata.pixelWidth ?? 1000) * item.scale;
      final itemRight = item.offset.dx + itemWidth;
      shiftLeft = math.max(shiftLeft, itemRight + gap - centeredOffset.dx);
    }

    if (shiftLeft > 0) {
      for (final item in _canvasItems) {
        if (item.id == newItem.id) continue;
        item.offset = Offset(item.offset.dx - shiftLeft, item.offset.dy);
      }
    }

    newItem
      ..scale = scale
      ..offset = centeredOffset;
  }

  void _activateCanvasItem(
    LiteFolderViewerData data,
    _LiteCanvasItem item,
  ) {
    setState(() {
      _activeCanvasItemId = item.id;
      final topZ = _canvasItems.fold<int>(
        0,
        (maxZ, current) => math.max(maxZ, current.zIndex),
      );
      item.zIndex = topZ + 1;
      _currentIndex = item.folderIndex;
      _displayedIndex = item.folderIndex;
    });
  }

  void _translateCanvas(Offset delta) {
    if (delta == Offset.zero || _canvasItems.isEmpty) return;
    setState(() {
      for (final item in _canvasItems) {
        item.offset = item.offset + delta;
      }
    });
  }

  Future<void> _expandWindowForCanvasItems(double desiredCanvasWidth) async {
    if (desiredCanvasWidth <= 0) return;
    final screenSize = MediaQuery.sizeOf(context);
    try {
      final currentSize = await windowManager.getSize();
      final maxWidth = screenSize.width - 8;
      final desiredWidth =
          math.min(maxWidth, math.max(currentSize.width, desiredCanvasWidth));
      if (desiredWidth > currentSize.width + 8) {
        await windowManager.setSize(Size(desiredWidth, currentSize.height));
        await windowManager.center();
      }
    } catch (_) {}
  }

  Future<void> _addNextPhotoToCollage(LiteFolderViewerData data) async {
    final activeItem = _activeCanvasItem;
    final baseIndex = activeItem?.folderIndex ?? _displayedIndex;
    final nextIndex = baseIndex + 1;
    if (nextIndex >= data.items.length) return;

    await _prepareItem(data.items[nextIndex]);
    if (!mounted) return;

    final nextMetadata = _readMetadata(data.items[nextIndex]);
    final nextScale = _fitScaleForMetadata(nextMetadata, _canvasSize);
    final nextWidth = (nextMetadata.pixelWidth ?? 1000).toDouble() * nextScale;

    var minLeft = double.infinity;
    var maxRight = double.negativeInfinity;
    for (final item in _canvasItems) {
      minLeft = math.min(minLeft, item.offset.dx);
      maxRight =
          math.max(maxRight, item.offset.dx + _scaledWidthForItem(item, data));
    }

    const gap = 32.0;
    final existingSpan =
        minLeft.isFinite && maxRight.isFinite ? (maxRight - minLeft) : 0.0;
    final desiredCanvasWidth =
        math.max(_canvasSize.width, (existingSpan * 2) + (gap * 2) + nextWidth);

    final canvasItem = _createCanvasItem(folderIndex: nextIndex);
    setState(() {
      _canvasItems.add(canvasItem);
      _activeCanvasItemId = canvasItem.id;
      _currentIndex = nextIndex;
      _displayedIndex = nextIndex;
    });

    await _expandWindowForCanvasItems(desiredCanvasWidth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _placeNewCanvasItemCentered(canvasItem, data);
      });
    });
  }

  Future<void> _requestStep(LiteFolderViewerData data, int step) async {
    final activeItem = _activeCanvasItem;
    final baseIndex = _isSwitching
        ? _currentIndex
        : (activeItem?.folderIndex ?? _displayedIndex);
    final targetIndex =
        (baseIndex + step).clamp(0, data.items.length - 1).toInt();

    if (targetIndex == baseIndex) return;

    if (_isSwitching) {
      _queuedStep = step;
      return;
    }

    await _switchToIndex(data, targetIndex);
  }

  Future<void> _switchToIndex(
    LiteFolderViewerData data,
    int targetIndex,
  ) async {
    final activeItem = _activeCanvasItem;
    final activeIndex = activeItem?.folderIndex ?? _displayedIndex;
    if (_isSwitching || targetIndex == activeIndex) return;

    _isSwitching = true;
    _currentIndex = targetIndex;

    try {
      await _prepareItem(data.items[targetIndex]);
      if (!mounted) return;

      setState(() {
        if (activeItem != null) {
          activeItem.folderIndex = targetIndex;
        } else {
          _displayedIndex = targetIndex;
        }
        _currentIndex = targetIndex;
      });

      if (activeItem != null) {
        setState(() {
          if (_canvasItems.length == 1) {
            _fitSingleCanvasItemToCanvas(activeItem, data);
          }
        });
      }

      _precacheNearbyItems(data, targetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    } finally {
      _isSwitching = false;
    }

    final queuedStep = _queuedStep;
    _queuedStep = null;
    if (queuedStep != null && mounted) {
      await _requestStep(data, queuedStep);
    }
  }

  Widget _buildCanvasItemWidget(
    LiteFolderViewerData data,
    _LiteCanvasItem item,
  ) {
    final appColors = context.appThemeColors;
    final viewerItem = _viewerItemFor(data, item);
    final metadata = _metadataForCanvasItem(data, item);
    final width = (metadata.pixelWidth ?? 1000).toDouble() * item.scale;
    final height = (metadata.pixelHeight ?? 1000).toDouble() * item.scale;
    final isActive = item.id == _activeCanvasItemId;

    final mediaChild = viewerItem.isVideo
        ? _LiteVideoPage(filePath: viewerItem.path)
        : Image(
            key: ValueKey(viewerItem.path),
            image: _imageProviderFor(viewerItem),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) {
              return Center(
                child: Text(
                  'Unable to render file',
                  style: TextStyle(color: appColors.subtle),
                ),
              );
            },
          );

    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            _activateCanvasItem(data, item);
            final factor = math.exp(-event.scrollDelta.dy * 0.0025);
            setState(() {
              item.scale = (item.scale * factor).clamp(0.05, 12.0);
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _activateCanvasItem(data, item),
            onScaleStart: (details) {
              _activateCanvasItem(data, item);
              _scalingItemId = item.id;
              _scaleStartScale = item.scale;
              _scaleStartOffset = item.offset;
              _scaleStartFocalPoint = details.focalPoint;
            },
            onScaleUpdate: (details) {
              if (_scalingItemId != item.id) return;
              setState(() {
                item.scale =
                    (_scaleStartScale * details.scale).clamp(0.05, 12.0);
                item.offset = _scaleStartOffset +
                    (details.focalPoint - _scaleStartFocalPoint);
              });
            },
            onScaleEnd: (_) {
              if (_scalingItemId != item.id) return;
              _scalingItemId = null;
            },
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(child: mediaChild),
                  if (isActive)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x886C665E),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
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

  Widget _buildCanvasMedia(LiteFolderViewerData data) {
    final appColors = context.appThemeColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (!_canvasInitialized &&
            constraints.maxWidth > 0 &&
            constraints.maxHeight > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _canvasInitialized) return;
            final item = _createCanvasItem(folderIndex: _displayedIndex);
            setState(() {
              _canvasItems
                ..clear()
                ..add(item);
              _activeCanvasItemId = item.id;
              _canvasInitialized = true;
              _fitSingleCanvasItemToCanvas(item, data);
            });
          });
        }

        final sortedItems = List<_LiteCanvasItem>.from(_canvasItems)
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerPanZoomStart: (_) {},
            onPointerPanZoomUpdate: (event) => _translateCanvas(event.panDelta),
            onPointerPanZoomEnd: (_) {},
            child: ColoredBox(
              color: appColors.canvas,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: appColors.canvas),
                  ),
                  ...sortedItems
                      .map((item) => _buildCanvasItemWidget(data, item)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appThemeColors;

    return FutureBuilder<LiteFolderViewerData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: appColors.canvas,
            body: const SizedBox.expand(),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          final message = snapshot.error is LiteFolderViewerException
              ? (snapshot.error as LiteFolderViewerException).message
              : 'Unable to open this folder in lite viewer.';
          return Scaffold(
            backgroundColor: appColors.canvas,
            appBar: AppBar(
              title: const Text('Lite Viewer'),
              backgroundColor: appColors.surface,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  style: TextStyle(color: appColors.subtle, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final activeItem = _activeCanvasItem;
        final currentFolderIndex = activeItem?.folderIndex ?? _displayedIndex;
        final currentItem = data.items[currentFolderIndex];
        final currentMetadata = _readMetadata(currentItem);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _precacheNearbyItems(data, currentFolderIndex);
        });

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                const DirectionalFocusIntent(TraversalDirection.left),
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                const DirectionalFocusIntent(TraversalDirection.right),
            const SingleActivator(LogicalKeyboardKey.keyF):
                const ToggleFullScreenIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                onInvoke: (intent) {
                  if (intent.direction == TraversalDirection.left) {
                    _requestStep(data, -1);
                  } else if (intent.direction == TraversalDirection.right) {
                    _requestStep(data, 1);
                  }
                  return null;
                },
              ),
              ToggleFullScreenIntent: CallbackAction<ToggleFullScreenIntent>(
                onInvoke: (intent) {
                  _toggleFullScreen();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              focusNode: _focusNode,
              child: Scaffold(
                backgroundColor: appColors.canvas,
                body: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: _toggleMaximize,
                        child: SizedBox(
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 240,
                                  ),
                                  child: Text(
                                    _buildTopBarText(
                                      data,
                                      currentItem,
                                      currentMetadata,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF6C665E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Compare\nAdd next photo',
                                      waitDuration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: IconButton(
                                        onPressed: () =>
                                            _addNextPhotoToCollage(data),
                                        icon: const Icon(
                                          Icons.compare_rounded,
                                          size: 16,
                                        ),
                                        color: const Color(0xFF6C665E),
                                        splashRadius: 14,
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message:
                                          'Add to Refma\nImport current file',
                                      waitDuration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: IconButton(
                                        onPressed: _isImporting
                                            ? null
                                            : () =>
                                                _importCurrentItem(currentItem),
                                        icon: _isImporting
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 1.6,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.library_add_outlined,
                                                size: 16,
                                              ),
                                        color: const Color(0xFF6C665E),
                                        disabledColor: const Color(
                                          0xFF5C5750,
                                        ),
                                        splashRadius: 14,
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildCanvasMedia(data),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiteVideoPage extends StatefulWidget {
  const _LiteVideoPage({required this.filePath});

  final String filePath;

  @override
  State<_LiteVideoPage> createState() => _LiteVideoPageState();
}

class _LiteVideoPageState extends State<_LiteVideoPage> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const SizedBox.expand();
        }

        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0
                ? 1
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}

class _LiteMediaMetadata {
  const _LiteMediaMetadata({
    this.fileSizeBytes,
    this.pixelWidth,
    this.pixelHeight,
    this.aspectRatio,
  });

  final int? fileSizeBytes;
  final int? pixelWidth;
  final int? pixelHeight;
  final double? aspectRatio;
}

class _LiteCanvasItem {
  _LiteCanvasItem({
    required this.id,
    required this.folderIndex,
    required this.zIndex,
  });

  final String id;
  int folderIndex;
  int zIndex;
  Offset offset = Offset.zero;
  double scale = 1;
}
