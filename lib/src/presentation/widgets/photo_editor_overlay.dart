import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_adjustments_panel.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor/image_editor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/utils/compress_photo_isolate.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:photographers_reference_app/src/utils/edit_combined_color_filter.dart';
import 'package:photographers_reference_app/src/utils/handle_video_upload.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

class PhotoEditorOverlay extends StatefulWidget {
  final Photo photo;
  final void Function(Uint8List bytes, bool overwrite, String comment) onSave;
  final void Function(Photo newPhoto)? onAddNewPhoto;

  const PhotoEditorOverlay({
    super.key,
    required this.photo,
    required this.onSave,
    this.onAddNewPhoto,
  });

  @override
  State<PhotoEditorOverlay> createState() => _PhotoEditorOverlayState();
}

Uint8List cropEncodeJpgIsolate(Map<String, dynamic> job) {
  final Uint8List bytes = job['bytes'] as Uint8List;
  final int x = job['x'] as int;
  final int y = job['y'] as int;
  final int w = job['w'] as int;
  final int h = job['h'] as int;
  final int quality = job['quality'] as int? ?? 95;
  final double rotationDeg =
      (job['rotationDeg'] as double? ?? 0.0) % 360.0;
  final bool flipX = job['flipX'] as bool? ?? false;
  final bool flipY = job['flipY'] as bool? ?? false;
  final double brightness = job['brightness'] as double? ?? 1.0;
  final double saturation = job['saturation'] as double? ?? 1.0;
  final double temp = job['temp'] as double? ?? 0.0;
  final double hueDeg = job['hueDeg'] as double? ?? 0.0;
  final double contrast = job['contrast'] as double? ?? 1.0;
  final double opacity = job['opacity'] as double? ?? 1.0;
  final String format = (job['format'] as String? ?? 'jpg').toLowerCase();

  final image = img.decodeImage(bytes);
  if (image == null) return Uint8List(0);

  final int safeX = x.clamp(0, image.width - 1);
  final int safeY = y.clamp(0, image.height - 1);
  final int safeW = w.clamp(1, image.width - safeX);
  final int safeH = h.clamp(1, image.height - safeY);

  img.Image working = img.copyCrop(
    image,
    x: safeX,
    y: safeY,
    width: safeW,
    height: safeH,
  );

  if (rotationDeg != 0.0) {
    working = img.copyRotate(working, angle: rotationDeg);
  }
  if (flipX) {
    working = img.flipHorizontal(working);
  }
  if (flipY) {
    working = img.flipVertical(working);
  }

  final bool needsColorAdjustments =
      brightness != 1.0 || saturation != 1.0 || contrast != 1.0 || hueDeg != 0.0;
  if (needsColorAdjustments) {
    working = img.adjustColor(
      working,
      brightness: brightness,
      saturation: saturation,
      contrast: contrast,
      hue: hueDeg,
    );
  }

  if (temp != 0.0 || opacity != 1.0) {
    final double tempDelta = 2.0 * temp;
    final double op = opacity.clamp(0.0, 1.0);
    for (final p in working) {
      double r = p.r.toDouble();
      double g = p.g.toDouble();
      double b = p.b.toDouble();

      if (temp != 0.0) {
        r = (r + tempDelta).clamp(0.0, 255.0);
        b = (b - tempDelta).clamp(0.0, 255.0);
      }

      if (op != 1.0) {
        // JPEG не поддерживает альфа, поэтому компонуем на белый фон.
        r = (r * op + 255.0 * (1.0 - op)).clamp(0.0, 255.0);
        g = (g * op + 255.0 * (1.0 - op)).clamp(0.0, 255.0);
        b = (b * op + 255.0 * (1.0 - op)).clamp(0.0, 255.0);
      }

      p.setRgb(r, g, b);
    }
  }

  if (format == 'png') {
    final encoded = img.encodePng(working);
    return Uint8List.fromList(encoded);
  }

  final encoded = img.encodeJpg(working, quality: quality);
  return Uint8List.fromList(encoded);
}

Uint8List compressToMaxBytesIsolate(Map<String, dynamic> job) {
  final Uint8List bytes = job['bytes'] as Uint8List;
  final int maxBytes = job['maxBytes'] as int? ?? 0;
  final int minQuality = job['minQuality'] as int? ?? 40;
  if (maxBytes <= 0 || bytes.isEmpty) return bytes;

  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  img.Image working = image;
  int quality = 95;
  List<int> encoded = img.encodeJpg(working, quality: quality);

  while (encoded.length > maxBytes && quality > minQuality) {
    quality -= 5;
    encoded = img.encodeJpg(working, quality: quality);
  }

  // If still too large, downscale gradually.
  while (encoded.length > maxBytes &&
      working.width > 200 &&
      working.height > 200) {
    final nextW = (working.width * 0.9).round().clamp(1, working.width);
    final nextH = (working.height * 0.9).round().clamp(1, working.height);
    if (nextW == working.width && nextH == working.height) break;
    working = img.copyResize(working, width: nextW, height: nextH);
    encoded = img.encodeJpg(working, quality: quality);
  }

  return Uint8List.fromList(encoded);
}

class _PhotoEditorOverlayState extends State<PhotoEditorOverlay> {
  final GlobalKey<ExtendedImageEditorState> _editorKey =
      GlobalKey<ExtendedImageEditorState>();
  late final TextEditingController _commentController;

  bool _saving = false;
  String _savingText = 'Processing…';
  bool _compressOnSave = false;
  bool _compressing = false;
  int? _currentSizeBytes;
  int? _compressedPreviewBytes;

  VideoPlayerController? _videoController;
  Future<void>? _videoInit;
  double _trimStartFrac = 0.0;
  double _trimEndFrac = 1.0;
  double _videoPositionFrac = 0.0;
  DateTime _lastVideoTick = DateTime.fromMillisecondsSinceEpoch(0);

  double _rotation = 0.0;
  bool _flipX = false;
  bool _flipY = false;
  double _brightness = 1.0;
  double _saturation = 1.0;
  double _temp = 0.0;
  double _hue = 0.0;
  double _contrast = 1.0;
  double _opacity = 1.0;

  static const double _bottomBarHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _commentController =
        TextEditingController(text: widget.photo.comment ?? '');
    _loadCurrentSize();
    if (_isVideo) {
      _initVideoController();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.photo.mediaType == 'video';

  Future<void> _loadCurrentSize() async {
    final String path = widget.photo.isStoredInApp
        ? PhotoPathHelper().getFullPath(widget.photo.fileName)
        : widget.photo.path;

    final file = File(path);
    if (await file.exists()) {
      if (!mounted) return;
      setState(() => _currentSizeBytes = file.lengthSync());
      debugPrint(
          '[EditSave] original file: $path size=${file.lengthSync()} bytes');
    } else {
      debugPrint('[EditSave] original file missing: $path');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<Uint8List> _compressBytesLikeUpload(
    Uint8List bytes, {
    int compressSizeKb = 300,
  }) async {
    debugPrint(
        '[EditSave] compressBytesLikeUpload: in=${bytes.length} bytes, target=${compressSizeKb}KB');
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(
      tempDir.path,
      'refma_edit_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      await compute(
        compressPhotoIsolate,
        {'filePath': tempFile.path, 'compressSizeKb': compressSizeKb},
      );
      final compressed = await tempFile.readAsBytes();
      debugPrint(
          '[EditSave] compressBytesLikeUpload: out=${compressed.length} bytes');
      return Uint8List.fromList(compressed);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<Uint8List> _getEditorBytesOrFile() async {
    final editorState = _editorKey.currentState;
    if (editorState != null) {
      final ui.Image? uiImage = editorState.image;
      if (uiImage != null) {
        final byteData = await uiImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      }
    }

    final String path = widget.photo.isStoredInApp
        ? PhotoPathHelper().getFullPath(widget.photo.fileName)
        : widget.photo.path;
    return File(path).readAsBytes();
  }

  Future<Uint8List> _ensureNotLargerThanOriginal(
    Uint8List bytes,
    int maxBytes,
  ) async {
    debugPrint(
        '[EditSave] ensureNotLargerThanOriginal: in=${bytes.length}, max=$maxBytes');
    if (maxBytes <= 0 || bytes.length <= maxBytes) return bytes;
    final compressed = await compute(
      compressToMaxBytesIsolate,
      {'bytes': bytes, 'maxBytes': maxBytes},
    );
    debugPrint(
        '[EditSave] ensureNotLargerThanOriginal: out=${compressed.length}');
    return compressed.length <= bytes.length ? compressed : bytes;
  }

  Future<Uint8List?> _cropWithNativeLibrary({
    required ExtendedImageEditorState state,
    required Rect cropRect,
    required bool needCrop,
    required double rotationDeg,
    required bool flipX,
    required bool flipY,
    required String format,
  }) async {
    debugPrint(
        '[EditSave] nativeCrop: needCrop=$needCrop rot=$rotationDeg flipX=$flipX flipY=$flipY rect=$cropRect');
    if (!needCrop &&
        rotationDeg.abs() < 0.1 &&
        !flipX &&
        !flipY) {
      return null;
    }

    final ImageEditorOption option = ImageEditorOption();

    if (rotationDeg.abs() >= 0.1) {
      option.addOption(RotateOption(rotationDeg.round()));
    }

    if (flipX || flipY) {
      option.addOption(FlipOption(horizontal: flipX, vertical: flipY));
    }

    if (needCrop) {
      Rect rect = cropRect;
      final provider = state.widget.extendedImageState.imageProvider;
      if (provider is ExtendedResizeImage && state.image != null) {
        final ui.ImmutableBuffer buffer =
            await ui.ImmutableBuffer.fromUint8List(state.rawImageData);
        final ui.ImageDescriptor descriptor =
            await ui.ImageDescriptor.encoded(buffer);
        final double widthRatio = descriptor.width / state.image!.width;
        final double heightRatio = descriptor.height / state.image!.height;
        rect = Rect.fromLTRB(
          rect.left * widthRatio,
          rect.top * heightRatio,
          rect.right * widthRatio,
          rect.bottom * heightRatio,
        );
      }
      option.addOption(ClipOption.fromRect(rect));
    }

    if (format == 'png') {
      option.outputFormat = const OutputFormat.png(100);
    } else {
      option.outputFormat = const OutputFormat.jpeg(100);
    }

    final Uint8List? result = await ImageEditor.editImage(
      image: state.rawImageData,
      imageEditorOption: option,
    );
    debugPrint(
        '[EditSave] nativeCrop: out=${result?.length ?? 0} bytes');
    return result;
  }

  Future<void> _prepareCompression() async {
    if (_compressing) return;
    setState(() => _compressing = true);

    try {
      final bytes = await _getEditorBytesOrFile();
      final compressed = await _compressBytesLikeUpload(bytes);
      if (!mounted) return;
      setState(() {
        _compressOnSave = true;
        _compressedPreviewBytes = compressed.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _compressOnSave = false;
        _compressedPreviewBytes = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _compressing = false);
    }
  }

  String _resolveVideoPath(Photo p) {
    if (p.path.isNotEmpty && File(p.path).existsSync()) return p.path;
    final byFileName = PhotoPathHelper().getFullPath(p.fileName);
    if (File(byFileName).existsSync()) return byFileName;
    return p.path;
  }

  void _initVideoController() {
    final path = _resolveVideoPath(widget.photo);
    final file = File(path);
    if (!file.existsSync()) {
      return;
    }

    final controller = VideoPlayerController.file(file);
    _videoController = controller;
    _videoInit = controller.initialize().then((_) async {
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.play();
      _videoPositionFrac = 0.0;
      controller.addListener(_handleVideoTick);
      setState(() {});
    });
  }

  void _handleVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final now = DateTime.now();
    if (now.difference(_lastVideoTick).inMilliseconds < 80) return;
    _lastVideoTick = now;

    final duration = c.value.duration;
    if (duration == Duration.zero) return;
    final pos = c.value.position;
    final frac =
        (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    if (frac > _trimEndFrac) {
      c.pause();
      final endMs = (duration.inMilliseconds * _trimEndFrac).round();
      c.seekTo(Duration(milliseconds: endMs));
    }

    if (mounted) {
      setState(() {
        _videoPositionFrac = frac;
      });
    }
  }

  Future<void> _trimVideoToNewFile() async {
    final c = _videoController;
    if (_saving || c == null || !c.value.isInitialized) return;

    final duration = c.value.duration;
    final startMs = (duration.inMilliseconds * _trimStartFrac).round();
    final endMs = (duration.inMilliseconds * _trimEndFrac).round();
    if (endMs <= startMs + 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trim range is too small')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _savingText = 'Cutting video…';
    });

    final inputPath = _resolveVideoPath(widget.photo);
    final ext = p.extension(inputPath).isNotEmpty
        ? p.extension(inputPath)
        : '.mp4';
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final id = const Uuid().v4();
    final newFileName = 'trim_$id$ext';
    final outPath = p.join(photosDir.path, newFileName);

    final startSec = (startMs / 1000).toStringAsFixed(3);
    final endSec = (endMs / 1000).toStringAsFixed(3);
    final cmd =
        '-ss $startSec -to $endSec -i "$inputPath" -c copy -avoid_negative_ts 1 "$outPath"';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trim failed')),
        );
      }
      return;
    }

    final outFile = File(outPath);
    if (!await outFile.exists() || await outFile.length() == 0) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trim failed')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final newPhoto = widget.photo.copyWith(
      id: id,
      fileName: newFileName,
      path: outPath,
      mediaType: 'video',
      dateAdded: now,
      isStoredInApp: true,
      comment: _commentController.text.trim(),
      videoPreview: null,
      videoDuration: null,
      videoWidth: null,
      videoHeight: null,
    );

    final thumb = await generateVideoThumbnail(newPhoto);
    if (thumb != null) {
      newPhoto.videoPreview = thumb['videoPreview'] as String?;
      newPhoto.videoDuration = thumb['videoDuration'] as String?;
      newPhoto.videoWidth = (thumb['videoWidth'] as num?)?.toDouble();
      newPhoto.videoHeight = (thumb['videoHeight'] as num?)?.toDouble();
    }

    if (mounted) {
      widget.onAddNewPhoto?.call(newPhoto);
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    }
  }

  Future<void> _save(bool overwrite) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _savingText = overwrite ? 'Saving changes…' : 'Creating new photo…';
    });

    try {
      debugPrint('[EditSave] start overwrite=$overwrite');
      final editorState = _editorKey.currentState;
      if (editorState == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        return;
      }

      final Rect? cropRect = editorState.getCropRect();
      if (cropRect == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        return;
      }

      final String path = widget.photo.isStoredInApp
          ? PhotoPathHelper().getFullPath(widget.photo.fileName)
          : widget.photo.path;
      final int originalFileSize =
          File(path).existsSync() ? File(path).lengthSync() : 0;
      final String ext = p.extension(path).toLowerCase();
      final String format = ext == '.png' ? 'png' : 'jpg';
      debugPrint(
          '[EditSave] file=$path ext=$ext format=$format originalSize=$originalFileSize');

      // Всегда используем исходный файл, чтобы не терять качество и избежать
      // артефактов от рендеринга preview-изображения.
      final Uint8List originBytes = await File(path).readAsBytes();
      debugPrint('[EditSave] originBytes=${originBytes.length}');

      final ui.Image? uiImage = editorState.image;
      final editAction = editorState.editAction;
      final bool needCrop = editAction?.needCrop ?? false;
      if (uiImage != null) {
        debugPrint(
            '[EditSave] uiImageSize=${uiImage.width}x${uiImage.height}');
      }
      final bool noTransform =
          _rotation == 0.0 &&
          !_flipX &&
          !_flipY &&
          _brightness == 1.0 &&
          _saturation == 1.0 &&
          _contrast == 1.0 &&
          _temp == 0.0 &&
          _hue == 0.0 &&
          _opacity == 1.0 &&
          !_compressOnSave;
      debugPrint(
          '[EditSave] noTransform=$noTransform needCrop=$needCrop compressOnSave=$_compressOnSave');

      final bool noCrop = uiImage != null
          ? (cropRect.left <= 0.5 &&
              cropRect.top <= 0.5 &&
              (cropRect.width - uiImage.width).abs() <= 1.0 &&
              (cropRect.height - uiImage.height).abs() <= 1.0)
          : false;
      debugPrint('[EditSave] cropRect=$cropRect noCrop=$noCrop');

      if (noTransform && noCrop) {
        debugPrint('[EditSave] fast path: save original bytes');
        widget.onSave(originBytes, overwrite, _commentController.text.trim());
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final int x = cropRect.left.round();
      final int y = cropRect.top.round();
      final int w = cropRect.width.round();
      final int h = cropRect.height.round();

      final Map<String, dynamic> job = <String, dynamic>{
        'bytes': originBytes,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'quality': 100,
        'format': format,
        'rotationDeg': _rotation * 180 / math.pi,
        'flipX': _flipX,
        'flipY': _flipY,
        'brightness': _brightness,
        'saturation': _saturation,
        'temp': _temp,
        'hueDeg': _hue * 180 / math.pi,
        'contrast': _contrast,
        'opacity': _opacity,
      };
      debugPrint(
          '[EditSave] job=bytes:${originBytes.length} x:$x y:$y w:$w h:$h '
          'quality:100 format:$format rotationDeg:${_rotation * 180 / math.pi} '
          'flipX:$_flipX flipY:$_flipY brightness:$_brightness '
          'saturation:$_saturation temp:$_temp hueDeg:${_hue * 180 / math.pi} '
          'contrast:$_contrast opacity:$_opacity');

      final bool hasColorAdjustments =
          _brightness != 1.0 ||
          _saturation != 1.0 ||
          _contrast != 1.0 ||
          _temp != 0.0 ||
          _hue != 0.0 ||
          _opacity != 1.0;
      debugPrint('[EditSave] hasColorAdjustments=$hasColorAdjustments');

      Uint8List outBytes;
      if (!hasColorAdjustments) {
        final Uint8List? nativeCropped = await _cropWithNativeLibrary(
          state: editorState,
          cropRect: cropRect,
          needCrop: needCrop,
          rotationDeg: _rotation * 180 / math.pi,
          flipX: _flipX,
          flipY: _flipY,
          format: format,
        );
        if (nativeCropped != null && nativeCropped.isNotEmpty) {
          outBytes = nativeCropped;
          debugPrint('[EditSave] using nativeCrop bytes=${outBytes.length}');
        } else {
          outBytes = await compute(cropEncodeJpgIsolate, job);
          debugPrint('[EditSave] using image crop bytes=${outBytes.length}');
        }
      } else {
        outBytes = await compute(cropEncodeJpgIsolate, job);
        debugPrint('[EditSave] using image crop bytes=${outBytes.length}');
      }

      if (outBytes.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decode image')),
        );
        return;
      }

      if (_compressOnSave) {
        outBytes = await _compressBytesLikeUpload(outBytes);
        debugPrint('[EditSave] after compressOnSave bytes=${outBytes.length}');
      }

      if (originalFileSize > 0 && format != 'png') {
        outBytes = await _ensureNotLargerThanOriginal(
          outBytes,
          originalFileSize,
        );
        debugPrint('[EditSave] after sizeCap bytes=${outBytes.length}');
      }

      widget.onSave(outBytes, overwrite, _commentController.text.trim());
      debugPrint('[EditSave] done bytes=${outBytes.length}');

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String path = widget.photo.isStoredInApp
        ? PhotoPathHelper().getFullPath(widget.photo.fileName)
        : widget.photo.path;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Photo'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isVideo
                    ? _buildVideoEditor()
                    : Opacity(
                        opacity: _opacity.clamp(0.0, 1.0),
                        child: ColorFiltered(
                          colorFilter: combinedColorFilter(
                            _brightness,
                            _saturation,
                            _contrast,
                            _temp,
                            _hue,
                          ),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(_rotation)
                              ..scale(_flipX ? -1.0 : 1.0,
                                  _flipY ? -1.0 : 1.0),
                            child: ExtendedImage.file(
                              File(path),
                              fit: BoxFit.contain,
                              mode: ExtendedImageMode.editor,
                              cacheRawData: true,
                              extendedImageEditorKey: _editorKey,
                              initEditorConfigHandler: (_) => EditorConfig(
                                maxScale: 5.0,
                                speed: 1.0,
                                animationDuration:
                                    const Duration(milliseconds: 200),
                                cropRectPadding: EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  24 + _bottomBarHeight + safeBottom,
                                ),
                                hitTestSize: 20,
                                cornerColor: Colors.white,
                                lineColor: Colors.white70,
                                initCropRectType: InitCropRectType.imageRect,
                                cropLayerPainter:
                                    const EditorCropLayerPainter(),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              if (!_isVideo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PhotoAdjustmentsPanel(
                    onRotateLeft: () =>
                        setState(() => _rotation -= math.pi / 2),
                    onRotateRight: () =>
                        setState(() => _rotation += math.pi / 2),
                    onFlipX: () => setState(() => _flipX = !_flipX),
                    onFlipY: () => setState(() => _flipY = !_flipY),
                    brightness: _brightness,
                    saturation: _saturation,
                    temp: _temp,
                    hue: _hue,
                    contrast: _contrast,
                    opacity: _opacity,
                    onBrightnessChanged: (v) =>
                        setState(() => _brightness = v),
                    onSaturationChanged: (v) =>
                        setState(() => _saturation = v),
                    onTempChanged: (v) => setState(() => _temp = v),
                    onHueChanged: (v) => setState(() => _hue = v),
                    onContrastChanged: (v) =>
                        setState(() => _contrast = v),
                    onOpacityChanged: (v) =>
                        setState(() => _opacity = v),
                  ),
                ),
              if (!_isVideo && _currentSizeBytes != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Size: ${_formatBytes(_currentSizeBytes!)}'
                        '${_compressedPreviewBytes == null ? '' : ' → ${_formatBytes(_compressedPreviewBytes!)}'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (_currentSizeBytes! > 300 * 1024)
                        ElevatedButton(
                          onPressed: _compressing ? null : _prepareCompression,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _compressOnSave
                                ? Colors.green.shade600
                                : Colors.blueGrey.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: Text(
                            _compressOnSave
                                ? 'Compressed'
                                : _compressing
                                    ? 'Compressing...'
                                    : 'Compress',
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Comment',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              if (_isVideo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VideoControls(
                    startFrac: _trimStartFrac,
                    endFrac: _trimEndFrac,
                    positionFrac: _videoPositionFrac,
                    onSeekFrac: (value) async {
                      final c = _videoController;
                      if (c == null || !c.value.isInitialized) return;
                      final duration = c.value.duration;
                      final ms = (duration.inMilliseconds * value).round();
                      await c.seekTo(Duration(milliseconds: ms));
                    },
                    onChangeRange: (range) {
                      final start = range.start.clamp(0.0, 1.0);
                      final end = range.end.clamp(0.0, 1.0);
                      if (end <= start) return;
                      setState(() {
                        _trimStartFrac = start;
                        _trimEndFrac = end;
                      });
                    },
                    volume: 1.0,
                    speed: 1.0,
                    showLoopRange: true,
                    showVolume: false,
                    showSpeed: false,
                    totalDuration: _videoController?.value.duration,
                  ),
                ),
              SafeArea(
                top: false,
                child: SizedBox(
                  height: _bottomBarHeight,
                  child: IgnorePointer(
                    ignoring: _saving,
                    child: Opacity(
                      opacity: _saving ? 0.6 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black87,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isVideo)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _trimVideoToNewFile,
                                  child: const Text('Cut video to new file'),
                                ),
                              )
                            else ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _save(false),
                                  child: const Text('Save as New'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _save(true),
                                  child: const Text('Overwrite'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_saving) ...[
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 240,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _savingText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoEditor() {
    if (_videoInit == null) {
      return const Center(
        child: Text(
          'Video unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _videoInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}
