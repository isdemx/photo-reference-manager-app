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
import 'package:photographers_reference_app/src/utils/_determine_media_type.dart';
import 'package:photographers_reference_app/src/utils/media_file_name_helper.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final Box<Photo> photoBox;

  PhotoRepositoryImpl(this.photoBox);

  @override
  Future<void> addPhoto(Photo photo, {int compressSizeKb = 300}) async {
    try {
      debugPrint('Add Pjoto, ${photo.fileName}');
      if (photo.isStoredInApp) {
        final originalFileName = photo.fileName.isNotEmpty
            ? photo.fileName
            : path_package.basename(photo.path);
        final photosDir = await _getAppPhotosDirectory();

        final sourceFile = File(photo.path);
        if (!await sourceFile.exists()) {
          throw FileSystemException('Source media file not found', photo.path);
        }

        final sourcePath = sourceFile.absolute.path;
        final photosDirPath = photosDir.absolute.path;
        final isAlreadyInPhotosDir =
            _isInsideDirectory(sourcePath, photosDirPath);

        // Копируем только внешние файлы. Экспорт/trim уже создают файл в
        // Documents/photos, и повторное copy раздувает storage или падает.
        File newFile;
        if (isAlreadyInPhotosDir) {
          newFile = sourceFile;
        } else {
          final desiredFileName =
              mediaFileNameWithId(originalFileName, photo.id);
          final uniqueFileName =
              uniqueFileNameInDirectory(photosDir, desiredFileName);
          final newFilePath = path_package.join(photosDir.path, uniqueFileName);
          debugPrint('newFilePatho, $newFilePath');
          newFile = await sourceFile.copy(newFilePath);
        }
        debugPrint('newFile, $newFile');

        final ext = path_package.extension(newFile.path).toLowerCase();
        final isGif = ext == '.gif';

        if (photo.mediaType == 'image' && Platform.isIOS && !isGif) {
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
          debugPrint('Video file copied without compression: ${newFile.path}');
        }

        // Обновляем имя файла
        photo.fileName = path_package.basename(newFile.path);
        photo.path = newFile.path;

        debugPrint('fileName, ${photo.fileName}');
      }

      await photoBox.put(photo.id, photo);
      debugPrint('Photo saved with id: ${photo.id}, type: ${photo.mediaType}');
    } catch (e) {
      debugPrint('Error adding photo: $e');
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
    for (final photo in photos) {
      if (photo.mediaType == 'image' || photo.mediaType == 'video') {
        continue;
      }

      final inferredType = determineMediaType(photo.fileName);
      if (inferredType == 'unknown') {
        continue;
      }

      photo.mediaType = inferredType;
      await photoBox.put(photo.id, photo);
    }
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
          final mediaPaths = <String>{
            if (photo.fileName.isNotEmpty)
              path_package.join(photosDir.path, photo.fileName),
            if (_isInsideDirectory(photo.path, photosDir.path)) photo.path,
          };

          for (final filePath in mediaPaths) {
            await _deleteFileIfExists(filePath, label: 'photo');
          }

          final previewName = photo.videoPreview;
          if (previewName != null && previewName.isNotEmpty) {
            final previewPath = path_package.isAbsolute(previewName)
                ? previewName
                : path_package.join(photosDir.path, previewName);
            await _deleteFileIfExists(previewPath, label: 'video preview');
          }
        }
        await photoBox.delete(id);
        debugPrint('Deleted photo with id: $id from Hive');
      } else {
        debugPrint('Photo with id: $id not found');
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
    }
  }

  Future<void> _deleteFileIfExists(
    String filePath, {
    required String label,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      debugPrint('Deleted $label file at: $filePath');
    } else {
      debugPrint('$label file does not exist at: $filePath');
    }
  }

  bool _isInsideDirectory(String filePath, String directoryPath) {
    if (filePath.isEmpty) return false;
    return path_package.equals(filePath, directoryPath) ||
        path_package.isWithin(directoryPath, filePath);
  }

  @override
  Future<void> updatePhoto(Photo photo) async {
    await photoBox.put(photo.id, photo);
  }

  @override
  Future<void> clearTemporaryFiles() async {
    final tempDir = await getIosTemporaryDirectory();
    debugPrint('Temporary directory path: ${tempDir.path}');

    if (await tempDir.exists()) {
      try {
        await for (var entity in tempDir.list(recursive: true)) {
          try {
            if (entity is File) {
              await entity.delete();
              debugPrint('Deleted cache file');
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
              debugPrint('Deleted cache directory');
            }
          } catch (e) {
            debugPrint('Error deleting ${entity.path}: $e');
          }
        }
        debugPrint('Temporary files deleted');
      } catch (e) {
        debugPrint('Error while deleting temporary files: $e');
      }
    }
  }
}
