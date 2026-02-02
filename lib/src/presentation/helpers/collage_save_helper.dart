// collage_save_helper.dart
import 'dart:io';
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
  static Future<void> saveCollage(
    GlobalKey boundaryKey,
    BuildContext context,
  ) async {
    try {
      // 1. Ищем boundary
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("No boundary found for collageKey");

      // 2. Генерим ui.Image
      final ui.Image fullImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to convert finalImage");

      final pngBytes = byteData.buffer.asUint8List();

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

      final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
      await repo.addPhoto(newPhoto);
      context.read<PhotoBloc>().add(LoadPhotos());

      // 5. SnackBar + закрытие (опционально)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating collage: $e')),
      );
    }
  }
}
