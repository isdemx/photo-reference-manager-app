// lib/helpers/photo_share_helper.dart

import 'dart:ui' show Rect;
import 'package:share_plus/share_plus.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart'; // Убедитесь, что путь корректен
import 'dart:io';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoShareHelper {
  final PhotoPathHelper _pathHelper = PhotoPathHelper();

  Future<String> _resolvePhotoPath(Photo photo) async {
    if (photo.isStoredInApp) {
      await _pathHelper.initialize();
      return _pathHelper.getFullPath(photo.fileName);
    }
    return photo.path;
  }

  /// Шаринг одной фотографии
  Future<bool> shareSinglePhoto(Photo photo, {Rect? sharePositionOrigin}) async {
    final String fullPath = await _resolvePhotoPath(photo);
    final File file = File(fullPath);
    
    if (await file.exists()) {
      try {
        final ShareResult result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Refma: Check out this photo!',
          sharePositionOrigin: sharePositionOrigin,
        );
        return result.status == ShareResultStatus.success;
      } catch (e) {
        print('Error sharing photo: $e');
        return false;
      }
    } else {
      print('File not found: $fullPath');
      return false;
    }
  }

  /// Шаринг нескольких фотографий
  Future<bool> shareMultiplePhotos(List<Photo> photos,
      {Rect? sharePositionOrigin}) async {
    List<XFile> xFiles = [];
    
    for (var photo in photos) {
      final String fullPath = await _resolvePhotoPath(photo);
      final File file = File(fullPath);
      
      if (await file.exists()) {
        xFiles.add(XFile(file.path));
      } else {
        print('File not found: $fullPath');
      }
    }
    
    if (xFiles.isNotEmpty) {
      try {
        final ShareResult result = await Share.shareXFiles(
          xFiles,
          text: 'Refma: Check out these photos!',
          sharePositionOrigin: sharePositionOrigin,
        );
        return result.status == ShareResultStatus.success;
      } catch (e) {
        print('Error sharing photos: $e');
        return false;
      }
    } else {
      print('No valid files to share.');
      return false;
    }
  }
}
