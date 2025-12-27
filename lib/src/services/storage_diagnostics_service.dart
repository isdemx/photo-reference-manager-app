import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageDiagnosticsService {
  static Future<void> logStorage() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final tmp = await getTemporaryDirectory();
      final support = await getApplicationSupportDirectory();
      Directory? library;
      try {
        library = await getLibraryDirectory();
      } catch (_) {
        library = null;
      }

      final photosDir = Directory(p.join(docs.path, 'photos'));

      final docsSize = await _dirSize(docs);
      final tmpSize = await _dirSize(tmp);
      final supportSize = await _dirSize(support);
      final librarySize = library == null ? 0 : await _dirSize(library);
      final photosSize = await _dirSize(photosDir);

      debugPrint('[Storage] Documents: ${_formatBytes(docsSize)}');
      debugPrint('[Storage] Documents/photos: ${_formatBytes(photosSize)}');
      debugPrint('[Storage] Library: ${_formatBytes(librarySize)}');
      debugPrint('[Storage] Support: ${_formatBytes(supportSize)}');
      debugPrint('[Storage] Temporary: ${_formatBytes(tmpSize)}');

      if (library != null) {
        final cacheDir = Directory(p.join(library.path, 'Caches'));
        final prefsDir = Directory(p.join(library.path, 'Preferences'));
        final appSupportDir = Directory(p.join(library.path, 'Application Support'));
        final cacheSize = await _dirSize(cacheDir);
        final prefsSize = await _dirSize(prefsDir);
        final appSupportSize = await _dirSize(appSupportDir);

        debugPrint('[Storage] Library/Caches: ${_formatBytes(cacheSize)}');
        debugPrint('[Storage] Library/Preferences: ${_formatBytes(prefsSize)}');
        debugPrint('[Storage] Library/Application Support: ${_formatBytes(appSupportSize)}');

        final cacheChildren = await _listDirSizes(cacheDir, limit: 12);
        if (cacheChildren.isNotEmpty) {
          debugPrint('[Storage] Largest Cache folders:');
          for (final entry in cacheChildren) {
            debugPrint('  ${entry.path}: ${_formatBytes(entry.size)}');
          }
        }
      }

      final docsChildren = await _listDirSizes(docs, limit: 12);
      if (docsChildren.isNotEmpty) {
        debugPrint('[Storage] Largest Documents folders:');
        for (final entry in docsChildren) {
          debugPrint('  ${entry.path}: ${_formatBytes(entry.size)}');
        }
      }

      final hiveSizes = await _listFileSizes(
        docs,
        extensions: const ['.hive', '.lock', '.hive.lock', '.hive.backup'],
        limit: 12,
      );
      if (hiveSizes.isNotEmpty) {
        debugPrint('[Storage] Largest DB files:');
        for (final entry in hiveSizes) {
          debugPrint('  ${entry.path}: ${_formatBytes(entry.size)}');
        }
      }
    } catch (e, st) {
      debugPrint('[Storage] Failed: $e\n$st');
    }
  }

  static Future<int> getCacheSizeBytes() async {
    final tmp = await getTemporaryDirectory();
    Directory? library;
    try {
      library = await getLibraryDirectory();
    } catch (_) {
      library = null;
    }
    final cacheDir = library == null
        ? null
        : Directory(p.join(library.path, 'Caches'));

    final tmpSize = await _dirSize(tmp);
    final cacheSize = cacheDir == null ? 0 : await _dirSize(cacheDir);
    return tmpSize + cacheSize;
  }

  static Future<void> clearCache() async {
    final tmp = await getTemporaryDirectory();
    Directory? library;
    try {
      library = await getLibraryDirectory();
    } catch (_) {
      library = null;
    }
    final cacheDir = library == null
        ? null
        : Directory(p.join(library.path, 'Caches'));

    await _clearDirectory(tmp);
    if (cacheDir != null) {
      await _clearDirectory(cacheDir);
    }
  }

  static String formatBytes(int bytes) => _formatBytes(bytes);

  static Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // ignore unreadable files
        }
      }
    }
    return total;
  }

  static Future<void> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) {
      return;
    }
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // ignore delete errors
      }
    }
  }

  static Future<List<_DirEntry>> _listDirSizes(Directory dir,
      {int limit = 8}) async {
    if (!await dir.exists()) {
      return [];
    }
    final entries = <_DirEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final size = await _dirSize(entity);
        entries.add(_DirEntry(entity.path, size));
      }
    }
    entries.sort((a, b) => b.size.compareTo(a.size));
    return entries.take(limit).toList();
  }

  static Future<List<_DirEntry>> _listFileSizes(
    Directory dir, {
    required List<String> extensions,
    int limit = 8,
  }) async {
    if (!await dir.exists()) {
      return [];
    }
    final entries = <_DirEntry>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (extensions.any((ext) => lower.endsWith(ext))) {
          try {
            entries.add(_DirEntry(entity.path, await entity.length()));
          } catch (_) {
            // ignore
          }
        }
      }
    }
    entries.sort((a, b) => b.size.compareTo(a.size));
    return entries.take(limit).toList();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}

class _DirEntry {
  final String path;
  final int size;

  _DirEntry(this.path, this.size);
}
