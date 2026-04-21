// collage_save_helper.dart
import 'dart:io';
import 'dart:math' as math;
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

      // 3. Сохраняем во временную папку. Репозиторий сам перенесет файл
      // в постоянную photos-директорию, без повторного copy в тот же путь.
      final tempDir = await getTemporaryDirectory();

      final fileName = 'collage_${DateTime.now().millisecondsSinceEpoch}.png';
      final outPath = p.join(tempDir.path, fileName);
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

      await repo.addPhoto(newPhoto, compressSizeKb: 0);
      try {
        await File(outPath).delete();
      } catch (_) {}
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

  static Future<int> saveCollageCarouselSlices(
    GlobalKey boundaryKey,
    BuildContext context, {
    required Rect cropRect,
    required int sliceCount,
    required Color backgroundColor,
  }) async {
    final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
    final photoBloc = context.read<PhotoBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("No boundary found for collageKey");
      if (sliceCount <= 0) throw Exception("No carousel slices to export");

      final tempDir = await getTemporaryDirectory();

      final exported = <Photo>[];
      const targetSliceAspect = 4 / 5;
      final sliceWidth = cropRect.height * targetSliceAspect;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < sliceCount; i++) {
        final sliceLeft = cropRect.left + i * sliceWidth;
        final availableWidth = cropRect.right - sliceLeft;
        if (availableWidth <= 0) break;
        final sourceWidth = math.min(sliceWidth, availableWidth);
        final sliceRect = Rect.fromLTWH(
          sliceLeft,
          cropRect.top,
          sourceWidth,
          cropRect.height,
        );
        final pngBytes = sourceWidth >= sliceWidth - 0.5
            ? await _renderBoundaryPngBytes(
                boundary,
                pixelRatio: 3.0,
                cropRect: sliceRect,
                targetSize: const Size(1080, 1350),
              )
            : await _renderPaddedBoundaryPngBytes(
                boundary,
                pixelRatio: 3.0,
                cropRect: sliceRect,
                fullSliceWidth: sliceWidth,
                targetSize: const Size(1080, 1350),
                backgroundColor: backgroundColor,
              );

        final fileName =
            'insta_carousel_${timestamp}_${(i + 1).toString().padLeft(2, '0')}.png';
        final outPath = p.join(tempDir.path, fileName);
        await File(outPath).writeAsBytes(pngBytes);

        final photo = Photo(
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
        await repo.addPhoto(photo, compressSizeKb: 0);
        try {
          await File(outPath).delete();
        } catch (_) {}
        exported.add(photo);
      }

      photoBloc.add(LoadPhotos());
      messenger?.showSnackBar(
        SnackBar(content: Text('Carousel saved: ${exported.length} images')),
      );
      return exported.length;
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Error generating carousel: $e')),
      );
      rethrow;
    }
  }

  static Future<Uint8List> _renderBoundaryPngBytes(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
    Rect? cropRect,
    Size? targetSize,
  }) async {
    final effectivePixelRatio = _effectivePixelRatio(
      cropRect: cropRect,
      targetSize: targetSize,
      fallbackPixelRatio: pixelRatio,
    );
    final image = await _renderBoundaryImage(
      boundary,
      pixelRatio: effectivePixelRatio,
      cropRect: cropRect,
    );

    ui.Image? outputImage;
    try {
      outputImage = targetSize == null
          ? image
          : await _resizeImage(image, targetSize: targetSize);
      final byteData =
          await outputImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to convert finalImage");

      return byteData.buffer.asUint8List();
    } finally {
      if (outputImage != null && outputImage != image) {
        outputImage.dispose();
      }
      image.dispose();
    }
  }

  static Future<Uint8List> _renderPaddedBoundaryPngBytes(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
    required Rect cropRect,
    required double fullSliceWidth,
    required Size targetSize,
    required Color backgroundColor,
  }) async {
    final targetContentWidth =
        targetSize.width * (cropRect.width / fullSliceWidth);
    final effectivePixelRatio = _effectivePixelRatio(
      cropRect: cropRect,
      targetSize: Size(targetContentWidth, targetSize.height),
      fallbackPixelRatio: pixelRatio,
    );
    final image = await _renderBoundaryImage(
      boundary,
      pixelRatio: effectivePixelRatio,
      cropRect: cropRect,
    );

    final outWidth = targetSize.width.round().clamp(1, 10000).toInt();
    final outHeight = targetSize.height.round().clamp(1, 10000).toInt();
    final contentWidth =
        targetContentWidth.round().clamp(1, outWidth).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()..color = backgroundColor,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, contentWidth.toDouble(), outHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    ui.Image? outputImage;
    try {
      outputImage = await picture.toImage(outWidth, outHeight);
      final byteData =
          await outputImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to convert finalImage");
      return byteData.buffer.asUint8List();
    } finally {
      outputImage?.dispose();
      image.dispose();
      picture.dispose();
    }
  }

  static double _effectivePixelRatio({
    required Rect? cropRect,
    required Size? targetSize,
    required double fallbackPixelRatio,
  }) {
    if (cropRect == null ||
        cropRect.isEmpty ||
        targetSize == null ||
        targetSize.width <= 0 ||
        targetSize.height <= 0) {
      return fallbackPixelRatio;
    }

    final ratio = math.max(
      targetSize.width / cropRect.width,
      targetSize.height / cropRect.height,
    );
    return math.max(fallbackPixelRatio, ratio);
  }

  static Future<ui.Image> _resizeImage(
    ui.Image image, {
    required Size targetSize,
  }) async {
    final outWidth = targetSize.width.round().clamp(1, 10000).toInt();
    final outHeight = targetSize.height.round().clamp(1, 10000).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcBounds =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstBounds = Rect.fromLTWH(
      0,
      0,
      outWidth.toDouble(),
      outHeight.toDouble(),
    );
    var srcRect = srcBounds;
    final srcAspect = srcBounds.width / srcBounds.height;
    final dstAspect = dstBounds.width / dstBounds.height;
    if ((srcAspect - dstAspect).abs() > 0.0001) {
      if (srcAspect > dstAspect) {
        final cropWidth = srcBounds.height * dstAspect;
        srcRect = Rect.fromLTWH(
          (srcBounds.width - cropWidth) / 2,
          0,
          cropWidth,
          srcBounds.height,
        );
      } else {
        final cropHeight = srcBounds.width / dstAspect;
        srcRect = Rect.fromLTWH(
          0,
          (srcBounds.height - cropHeight) / 2,
          srcBounds.width,
          cropHeight,
        );
      }
    }
    canvas.drawImageRect(
      image,
      srcRect,
      dstBounds,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(outWidth, outHeight);
    picture.dispose();
    return resized;
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
