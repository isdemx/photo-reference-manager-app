// lib/src/data/repositories/photo_repository_impl.dart

import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/repositories/photo_repository.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final Box<Photo> photoBox;

  PhotoRepositoryImpl(this.photoBox);

  Future<Directory> _getAppPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos');

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    return photosDir;
  }

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

    return newFile.path;
  }

  @override
  Future<void> addPhoto(Photo photo) async {
    if (photo.isStoredInApp) {
      // Копируем фотографию в директорию приложения
      final newPath = await _copyPhotoToAppDirectory(photo.path);
      photo.path = newPath;
    }

    // Сохраняем фотографию в бокс
    await photoBox.put(photo.id, photo);
  }

  @override
  Future<List<Photo>> getPhotos() async {
    return photoBox.values.toList();
  }

  @override
  Future<void> deletePhoto(String id) async {
    final photo = photoBox.get(id);
    if (photo != null) {
      if (photo.isStoredInApp) {
        // Удаляем файл фотографии из директории приложения
        final file = File(photo.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await photoBox.delete(id);
    }
  }

  @override
  Future<void> updatePhoto(Photo photo) async {
    await photo.save();
  }
}
