// collage_save_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class CollageSaveHelper {
  static Future<void> saveCollage(GlobalKey boundaryKey, BuildContext context,
      {Rect? cropRect}) async {
    final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
    final photoBloc = context.read<PhotoBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      // 1. Ищем boundary
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("No boundary found for collageKey");

      // 2. Генерим PNG только для нужной зоны canvas.
      final pngBytes = await _renderBoundaryPngBytes(
        boundary,
        pixelRatio: 3.0,
        cropRect: cropRect,
      );

      // 3. Сохраняем в папку photos
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName = 'collage_${DateTime.now().millisecondsSinceEpoch}.png';
      final outPath = p.join(photosDir.path, fileName);
      await File(outPath).writeAsBytes(pngBytes);

      // 4. Добавляем в БД
      final newPhoto = Photo(
        id: const Uuid().v4(),
        path: outPath,
        fileName: fileName,
        folderIds: [],
        tagIds: [],
        comment: '',
        dateAdded: DateTime.now(),
        sortOrder: 0,
        isStoredInApp: true,
        geoLocation: null,
        mediaType: 'image',
      );

      await repo.addPhoto(newPhoto);
      photoBloc.add(LoadPhotos());

      // 5. SnackBar + закрытие (опционально)
      messenger?.showSnackBar(
        const SnackBar(content: Text('Snapshot saved')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Error generating collage: $e')),
      );
    }
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
      if (byteData == null) throw Exception("Failed to convert finalImage");

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
