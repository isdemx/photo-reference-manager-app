import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/utils/compress_photo_isolate.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

/// ✅ top-level function (обязательно!) для compute()
Uint8List cropEncodeJpgIsolate(Map<String, dynamic> job) {
  final Uint8List bytes = job['bytes'] as Uint8List;
  final int x = job['x'] as int;
  final int y = job['y'] as int;
  final int w = job['w'] as int;
  final int h = job['h'] as int;
  final int quality = job['quality'] as int;

  final img.Image? original = img.decodeImage(bytes);
  if (original == null) return Uint8List(0);

  final int safeX = x.clamp(0, original.width - 1);
  final int safeY = y.clamp(0, original.height - 1);
  final int safeW = w.clamp(1, original.width - safeX);
  final int safeH = h.clamp(1, original.height - safeY);

  final img.Image cropped = img.copyCrop(
    original,
    x: safeX,
    y: safeY,
    width: safeW,
    height: safeH,
  );

  return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
}

class PhotoEditorOverlay extends StatefulWidget {
  final Photo photo;
  final void Function(Uint8List bytes, bool overwrite, String comment) onSave;

  const PhotoEditorOverlay({
    super.key,
    required this.photo,
    required this.onSave,
  });

  @override
  State<PhotoEditorOverlay> createState() => _PhotoEditorOverlayState();
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

  static const double _bottomBarHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _commentController =
        TextEditingController(text: widget.photo.comment ?? '');
    _loadCurrentSize();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSize() async {
    final String path = widget.photo.isStoredInApp
        ? PhotoPathHelper().getFullPath(widget.photo.fileName)
        : widget.photo.path;

    final file = File(path);
    if (await file.exists()) {
      if (!mounted) return;
      setState(() => _currentSizeBytes = file.lengthSync());
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
      return Uint8List.fromList(compressed);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _prepareCompression() async {
    if (_compressing) return;
    setState(() => _compressing = true);

    try {
      final String path = widget.photo.isStoredInApp
          ? PhotoPathHelper().getFullPath(widget.photo.fileName)
          : widget.photo.path;
      final bytes = await File(path).readAsBytes();
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

  Future<void> _save(bool overwrite) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _savingText = overwrite ? 'Saving changes…' : 'Creating new photo…';
    });

    try {
      final editorState = _editorKey.currentState;
      if (editorState == null) {
        setState(() => _saving = false);
        return;
      }

      final Rect? cropRect = editorState.getCropRect();
      if (cropRect == null) {
        setState(() => _saving = false);
        return;
      }

      final String path = widget.photo.isStoredInApp
          ? PhotoPathHelper().getFullPath(widget.photo.fileName)
          : widget.photo.path;

      final Uint8List originBytes = await File(path).readAsBytes();

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
        'quality': 95,
      };

      Uint8List outBytes = await compute(cropEncodeJpgIsolate, job);

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
      }

      widget.onSave(outBytes, overwrite, _commentController.text.trim());

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
                child: ExtendedImage.file(
                  File(path),
                  fit: BoxFit.contain,
                  mode: ExtendedImageMode.editor,
                  extendedImageEditorKey: _editorKey,
                  initEditorConfigHandler: (_) => EditorConfig(
                    // ✅ Разрешаем нормальное перемещение и зум кропа на iOS
                    maxScale: 5.0,

                    // ✅ Сохраняем отзывчивость без залипания
                    speed: 1.0,
                    animationDuration: const Duration(milliseconds: 200),

                    // ✅ Резерв под нижний бар (чтобы снизу было чем тянуть)
                    cropRectPadding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + _bottomBarHeight + safeBottom,
                    ),

                    // ✅ Нормальные ручки
                    hitTestSize: 20,
                    cornerColor: Colors.white,
                    lineColor: Colors.white70,

                    // ✅ Не заставляем кроп “подстраиваться” под экран
                    initCropRectType: InitCropRectType.imageRect,

                    cropLayerPainter: const EditorCropLayerPainter(),
                  ),
                ),
              ),
              if (_currentSizeBytes != null)
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
}
