// lib/helpers/photo_share_helper.dart

import 'package:share_plus/share_plus.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart'; // Убедитесь, что путь корректен
import 'dart:io';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoShareHelper {
  final PhotoPathHelper _pathHelper = PhotoPathHelper();

  /// Шаринг одной фотографии
  Future<void> shareSinglePhoto(Photo photo) async {
    final String fullPath = await _pathHelper.getFullPath(photo.fileName);
    final File file = File(fullPath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out this photo!',
      );
    } else {
      print('File not found: $fullPath');
      // Вы можете показать SnackBar или другое уведомление пользователю
    }
  }

  /// Шаринг нескольких фотографий
  Future<void> shareMultiplePhotos(List<Photo> photos) async {
    List<XFile> xFiles = [];
    for (var photo in photos) {
      final String fullPath = await _pathHelper.getFullPath(photo.fileName);
      final File file = File(fullPath);
      if (await file.exists()) {
        xFiles.add(XFile(file.path));
      } else {
        print('File not found: $fullPath');
        // Вы можете собрать список недоступных файлов и уведомить пользователя
      }
    }
    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(
        xFiles,
        text: 'Check out these photos!',
      );
    } else {
      print('No valid files to share.');
      // Показываем сообщение пользователю, что нет доступных файлов для шаринга
    }
  }
}
