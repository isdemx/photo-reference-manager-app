// lib/src/data/utils/storage_analyzer.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/utils/get_ios_temporary_directory.dart';

/// Запись о файле/директории с размером.
class FileSizeEntry {
  final String path;
  final int sizeBytes;
  final bool isDirectory;

  const FileSizeEntry({
    required this.path,
    required this.sizeBytes,
    required this.isDirectory,
  });

  /// Красивый текстовый размер (KB/MB/GB).
  String get formattedSize => _formatBytes(sizeBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  @override
  String toString() {
    final type = isDirectory ? 'DIR ' : 'FILE';
    return '$type $path — $formattedSize';
  }
}

/// Публичный метод: просканировать хранилище приложения.
///
/// Сканируем:
///  - ApplicationDocumentsDirectory (там у тебя photos/ и Hive)
///  - ApplicationSupportDirectory (если есть)
///  - временную директорию (на iOS — через getIosTemporaryDirectory)
Future<List<FileSizeEntry>> analyzeAppStorage() async {
  final docsDir = await getApplicationDocumentsDirectory();

  Directory? supportDir;
  try {
    supportDir = await getApplicationSupportDirectory();
  } catch (_) {
    supportDir = null;
  }

  Directory? tempDir;
  try {
    if (Platform.isIOS) {
      tempDir = await getIosTemporaryDirectory();
    } else {
      tempDir = await getTemporaryDirectory();
    }
  } catch (_) {
    tempDir = null;
  }

  final rootPaths = <String>{docsDir.path};
  if (supportDir != null) {
    rootPaths.add(supportDir.path);
  }
  if (tempDir != null) {
    rootPaths.add(tempDir.path);
  }

  final rootsList = rootPaths.toList();

  // Выносим в изолят, чтобы не блокировать UI.
  final entries = await compute<List<String>, List<FileSizeEntry>>(
    _scanRootsIsolate,
    rootsList,
  );

  // Сортируем по размеру по убыванию: самые большие сверху.
  entries.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  return entries;
}

/// Функция для compute: синхронный обход файловой системы.
/// ВАЖНО: без async/await, только sync-методы.
List<FileSizeEntry> _scanRootsIsolate(List<String> rootPaths) {
  final result = <FileSizeEntry>[];

  for (final rootPath in rootPaths) {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      continue;
    }

    int rootTotalSize = 0;

    try {
      final entities = rootDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            final size = entity.lengthSync();
            rootTotalSize += size;
            result.add(
              FileSizeEntry(
                path: entity.path,
                sizeBytes: size,
                isDirectory: false,
              ),
            );
          } catch (_) {
            // Игнорируем отдельные файлы с ошибками доступа.
          }
        }
      }
    } catch (_) {
      // Если вдруг не удалось прочитать каталог, просто пропускаем.
    }

    // Запишем сам корневой каталог как отдельную строку (с суммарным размером).
    result.add(
      FileSizeEntry(
        path: rootPath,
        sizeBytes: rootTotalSize,
        isDirectory: true,
      ),
    );
  }

  // На всякий случай ещё раз сортируем.
  result.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  return result;
}
