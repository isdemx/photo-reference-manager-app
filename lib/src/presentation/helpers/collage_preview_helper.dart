// collage_preview_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CollagePreviewHelper {
  /// Рендерит превью PNG в техпапку app support.
  /// Используем фиксированное имя по id, чтобы перезаписывать при апдейте.
  static Future<String> renderPreviewPng({
    required GlobalKey boundaryKey,
    required String collageId,
    double pixelRatio = 1.25, // достаточно для миниатюр
    Rect? cropRect,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('No boundary for preview');

    final bytes = await _renderBoundaryPngBytes(
      boundary,
      pixelRatio: pixelRatio,
      cropRect: cropRect,
    );

    final supportDir = await getApplicationSupportDirectory();
    final previewsDir =
        Directory(p.join(supportDir.path, 'collages', 'previews'));
    if (!previewsDir.existsSync()) {
      previewsDir.createSync(recursive: true);
    }

    final outPath = p.join(previewsDir.path, 'collage_$collageId.png');
    final file = File(outPath);
    await file.writeAsBytes(bytes, flush: true);
    return outPath;
  }

  static Future<Uint8List> _renderBoundaryPngBytes(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
    Rect? cropRect,
  }) async {
    final image = await _renderBoundaryImage(
      boundary,
      pixelRatio: pixelRatio,
      cropRect: cropRect,
    );

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode preview');

      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static Future<ui.Image> _renderBoundaryImage(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
    required Rect? cropRect,
  }) async {
    final rect = _normalizedCropRect(boundary, cropRect);
    // RenderObject.layer is the only Flutter API that can capture a crop
    // directly instead of rasterizing the whole canvas first.
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer;
    if (rect != null && layer is OffsetLayer) {
      return layer.toImage(rect, pixelRatio: pixelRatio);
    }
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  static Rect? _normalizedCropRect(
    RenderRepaintBoundary boundary,
    Rect? cropRect,
  ) {
    if (cropRect == null || cropRect.isEmpty) return null;

    final boundaryRect = Offset.zero & boundary.size;
    final rect = cropRect.intersect(boundaryRect);
    if (rect.width < 1 || rect.height < 1) return null;

    return rect;
  }
}
