import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;

/// Класс для получения пути к файлам фотографий.
/// Хранит только относительные пути (имя файла), а абсолютный путь
/// формируется динамически на основе текущего каталога документов.
class PhotoPathHelper {
  static final PhotoPathHelper _instance = PhotoPathHelper._internal();

  factory PhotoPathHelper() => _instance;

  PhotoPathHelper._internal();

  Directory? _photosDir;

  /// Инициализирует каталог `photos` в Documents, если он ещё не создан.
  Future<void> initialize() async {
    if (_photosDir != null) return; // уже инициализировано

    final appDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory(path_package.join(appDir.path, 'photos'));

    if (!await _photosDir!.exists()) {
      await _photosDir!.create(recursive: true);
      print('Создан каталог фотографий: ${_photosDir!.path}');
    } else {
      print('Каталог фотографий уже существует: ${_photosDir!.path}');
    }
  }

  /// Возвращает полный путь к файлу в каталоге photos по имени файла.
  String getFullPath(String fileName) {
    return path_package.join(_photosDir!.path, fileName);
  }
}
