import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class PhotoSaveHelper {
  /// Сохраняет фото из байтов [bytes] с именем [fileName] в папку "photos" приложения,
  /// создаёт объект [Photo], добавляет его в базу данных и возвращает.
  static Future<Photo> savePhoto({
    required String fileName,
    required Uint8List bytes,
    required BuildContext context,
    required String mediaType,
  }) async {
    try {
      // 1. Получаем директорию приложения и создаём папку "photos".
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }

      // 2. Создаём путь для сохранения файла.
      final outPath = p.join(photosDir.path, fileName);
      final outFile = File(outPath);

      // 3. Записываем байты в файл.
      await outFile.writeAsBytes(bytes);

      // 4. Создаём объект [Photo].
      final newPhoto = Photo(
        id: const Uuid().v4(),
        fileName: fileName,
        path: outPath,
        mediaType: mediaType,
        dateAdded: DateTime.now(),
        folderIds: [],
        comment: '',
        tagIds: [],
        sortOrder: 0,
      );

      // 5. Добавляем фото в базу данных.
      final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
      await repo.addPhoto(newPhoto);

      // 6. Обновляем состояние блока PhotoBloc.
      context.read<PhotoBloc>().add(LoadPhotos());

      return newPhoto;
    } catch (e) {
      debugPrint('Ошибка сохранения фото: $e');
      throw Exception('Не удалось сохранить фото');
    }
  }
}
