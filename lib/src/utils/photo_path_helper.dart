// lib/src/utils/photo_path_helper.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;

class PhotoPathHelper {
  // Синглтон для обеспечения единственного экземпляра
  static final PhotoPathHelper _instance = PhotoPathHelper._internal();

  factory PhotoPathHelper() {
    return _instance;
  }

  PhotoPathHelper._internal();

  late Directory _photosDir;
  bool _initialized = false;

  /// Инициализирует директорию `photos`.
  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory(path_package.join(appDir.path, 'photos'));

    if (!await _photosDir.exists()) {
      await _photosDir.create(recursive: true);
    } else {
      print('Directory already exists: ${_photosDir.path}');
    }

    _initialized = true;
  }

  /// Возвращает полный путь к фотографии на основе имени файла.
  String getFullPath(String fileName) {
    return path_package.join(_photosDir.path, fileName);
  }
}
