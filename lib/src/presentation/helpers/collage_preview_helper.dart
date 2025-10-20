// collage_preview_helper.dart
import 'dart:io';
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
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('No boundary for preview');

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode preview');

    final bytes = byteData.buffer.asUint8List();

    final supportDir = await getApplicationSupportDirectory();
    final previewsDir = Directory(p.join(supportDir.path, 'collages', 'previews'));
    if (!previewsDir.existsSync()) {
      previewsDir.createSync(recursive: true);
    }

    final outPath = p.join(previewsDir.path, 'collage_$collageId.png');
    final file = File(outPath);
    await file.writeAsBytes(bytes, flush: true);
    return outPath;
  }
}
