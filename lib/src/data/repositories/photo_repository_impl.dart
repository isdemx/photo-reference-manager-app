// lib/src/data/repositories/photo_repository_impl.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:photographers_reference_app/src/data/utils/compress_photo_isolate.dart';
import 'package:photographers_reference_app/src/data/utils/get_ios_temporary_directory.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/repositories/photo_repository.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final Box<Photo> photoBox;

  PhotoRepositoryImpl(this.photoBox);

  Future<String> _copyPhotoToAppDirectory(String originalPhotoPath) async {
    final photosDir = await _getAppPhotosDirectory();

    final fileName = path_package.basename(originalPhotoPath);

    String newFilePath = path_package.join(photosDir.path, fileName);

    int counter = 1;
    while (await File(newFilePath).exists()) {
      newFilePath = path_package.join(photosDir.path, '${counter}_$fileName');
      counter++;
    }

    final newFile = await File(originalPhotoPath).copy(newFilePath);
    print('Photo copied to: ${newFile.path}'); // Логирование

    return newFile.path;
  }

  @override
  Future<void> addPhoto(Photo photo, {int compressSizeKb = 300}) async {
    try {
      if (photo.isStoredInApp) {
        final fileName = path_package.basename(photo.path);
        final photosDir = await _getAppPhotosDirectory();
        final newFilePath = path_package.join(photosDir.path, fileName);

        // Копируем файл из исходного пути в директорию приложения
        File newFile = await File(photo.path).copy(newFilePath);

        if (photo.mediaType == 'image') {
          // Обрабатываем только изображения
          if (compressSizeKb != 0) {
            final fileSizeKb = newFile.lengthSync() ~/ 1024;
            if (fileSizeKb > compressSizeKb) {
              // Сжимаем файл до compressSizeKb КБ в изоляте
              await compute(
                compressPhotoIsolate,
                {'filePath': newFile.path, 'compressSizeKb': compressSizeKb},
              );
            }
          }
        } else {
          // Если это видео, просто логируем
          print('Video file copied without compression: ${newFile.path}');
        }

        // Обновляем имя файла
        photo.fileName = path_package.basename(newFile.path);
      }

      await photoBox.put(photo.id, photo);
      print('Photo saved with id: ${photo.id}, type: ${photo.mediaType}');
    } catch (e) {
      print('Error adding photo: $e');
      rethrow;
    }
  }

  Future<Directory> _getAppPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos');
    if (!(await photosDir.exists())) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  @override
  Future<List<Photo>> getPhotos() async {
    final photos = photoBox.values.toList();
    photos.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return photos;
  }

  @override
  Future<void> deletePhoto(String id) async {
    try {
      final photo = photoBox.get(id);
      if (photo != null) {
        if (photo.isStoredInApp) {
          final photosDir = await _getAppPhotosDirectory();
          final filePath = path_package.join(photosDir.path, photo.fileName);
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            print('Deleted photo file at: $filePath');
          } else {
            print('Photo file does not exist at: $filePath');
          }
        }
        await photoBox.delete(id);
        print('Deleted photo with id: $id from Hive');
      } else {
        print('Photo with id: $id not found');
      }
    } catch (e) {
      print('Error deleting photo: $e');
    }
  }

  @override
  Future<void> updatePhoto(Photo photo) async {
    await photo.save();
  }

  @override
  Future<void> clearTemporaryFiles() async {
    final tempDir = await getIosTemporaryDirectory();
    print('Temporary directory path: ${tempDir.path}');

    if (await tempDir.exists()) {
      try {
        await for (var entity in tempDir.list(recursive: true)) {
          try {
            if (entity is File) {
              await entity.delete();
              print('Deleted cache file');
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
              print('Deleted cache directory');
            }
          } catch (e) {
            print('Error deleting ${entity.path}: $e');
          }
        }
        print('Temporary files deleted');
      } catch (e) {
        print('Error while deleting temporary files: $e');
      }
    }
  }
}
