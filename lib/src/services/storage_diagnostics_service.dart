import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';

class StorageDiagnosticsService {
  static const String _videoThumbsCacheDirName = 'refma_video_thumbs';

  static void _log(String message) {
    debugPrint('[SettingsSize] $message');
  }

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
        final appSupportDir =
            Directory(p.join(library.path, 'Application Support'));
        final cacheSize = await _dirSize(cacheDir);
        final prefsSize = await _dirSize(prefsDir);
        final appSupportSize = await _dirSize(appSupportDir);

        debugPrint('[Storage] Library/Caches: ${_formatBytes(cacheSize)}');
        debugPrint('[Storage] Library/Preferences: ${_formatBytes(prefsSize)}');
        debugPrint(
            '[Storage] Library/Application Support: ${_formatBytes(appSupportSize)}');

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
    _log('getCacheSizeBytes start');
    final tmp = await getTemporaryDirectory();
    _log('tmp dir=${tmp.path}');
    final support = await getApplicationSupportDirectory();
    final appId = p.basename(support.path);
    Directory? library;
    try {
      library = await getLibraryDirectory();
      _log('library dir=${library.path}');
    } catch (_) {
      library = null;
      _log('library dir unavailable');
    }
    final cacheDir =
        library == null ? null : Directory(p.join(library.path, 'Caches'));

    final tmpSize = await _scopedTempSize(tmp, appId: appId);
    final cacheSize =
        cacheDir == null ? 0 : await _scopedCacheSize(cacheDir, appId: appId);
    _log(
      'getCacheSizeBytes done tmp=${_formatBytes(tmpSize)} cache=${_formatBytes(cacheSize)} total=${_formatBytes(tmpSize + cacheSize)}',
    );
    return tmpSize + cacheSize;
  }

  static Future<int> getAppFootprintBytes() async {
    _log('getAppFootprintBytes start');
    final docs = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();
    final support = await getApplicationSupportDirectory();
    final appId = p.basename(support.path);
    _log('docs dir=${docs.path}');
    _log('tmp dir=${tmp.path}');
    _log('support dir=${support.path}');
    Directory? library;
    try {
      library = await getLibraryDirectory();
      _log('library dir=${library.path}');
    } catch (_) {
      library = null;
      _log('library dir unavailable');
    }

    final docsSize = await _managedDocumentsSize(docs);
    final tmpSize = await _scopedTempSize(tmp, appId: appId);
    final supportSize = await _dirSizeSafe(support);

    var cacheSize = 0;
    var prefsSize = 0;
    if (library != null) {
      final cacheDir = Directory(p.join(library.path, 'Caches'));
      final prefsDir = Directory(p.join(library.path, 'Preferences'));
      cacheSize = await _scopedCacheSize(cacheDir, appId: appId);
      prefsSize = await _scopedPrefsSize(prefsDir, appId: appId);
    }

    _log(
      'getAppFootprintBytes done docs=${_formatBytes(docsSize)} tmp=${_formatBytes(tmpSize)} support=${_formatBytes(supportSize)} cache=${_formatBytes(cacheSize)} prefs=${_formatBytes(prefsSize)} total=${_formatBytes(docsSize + tmpSize + supportSize + cacheSize + prefsSize)}',
    );
    return docsSize + tmpSize + supportSize + cacheSize + prefsSize;
  }

  static Future<void> clearCache() async {
    final tmp = await getTemporaryDirectory();
    final support = await getApplicationSupportDirectory();
    final appId = p.basename(support.path);
    Directory? library;
    try {
      library = await getLibraryDirectory();
    } catch (_) {
      library = null;
    }
    final cacheDir =
        library == null ? null : Directory(p.join(library.path, 'Caches'));

    await _clearScopedTemp(tmp, appId: appId);
    if (cacheDir != null) {
      await _clearScopedCache(cacheDir, appId: appId);
    }
    await clearUnreferencedPhotoFiles();
  }

  static Future<int> clearUnreferencedPhotoFiles() async {
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'photos'));
    if (!await photosDir.exists()) return 0;

    final photoBox = Hive.isBoxOpen('photos')
        ? Hive.box<Photo>('photos')
        : await Hive.openBox<Photo>('photos');
    final referencedNames = <String>{};

    for (final photo in photoBox.values) {
      if (photo.fileName.isNotEmpty) {
        referencedNames.add(p.basename(photo.fileName));
      }
      if (photo.path.isNotEmpty &&
          _isInsideDirectory(photo.path, photosDir.path)) {
        referencedNames.add(p.basename(photo.path));
      }
      final preview = photo.videoPreview;
      if (preview != null && preview.isNotEmpty) {
        referencedNames.add(p.basename(preview));
      }
    }

    var deletedBytes = 0;
    await for (final entity in photosDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (referencedNames.contains(name)) continue;
      try {
        final size = await entity.length();
        await entity.delete();
        deletedBytes += size;
        _log('deleted unreferenced photo file $name ${_formatBytes(size)}');
      } catch (e) {
        _log('failed to delete unreferenced photo file ${entity.path}: $e');
      }
    }

    _log('clearUnreferencedPhotoFiles done ${_formatBytes(deletedBytes)}');
    return deletedBytes;
  }

  static String formatBytes(int bytes) => _formatBytes(bytes);

  static Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) {
      _log('dir missing ${dir.path}');
      return 0;
    }
    _log('dir scan start ${dir.path}');
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
    _log('dir scan done ${dir.path} => ${_formatBytes(total)}');
    return total;
  }

  static Future<int> _dirSizeSafe(Directory dir) async {
    if (!await dir.exists()) {
      _log('dir missing ${dir.path}');
      return 0;
    }
    _log('safe dir scan start ${dir.path}');
    var total = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        } else if (entity is Directory) {
          total += await _dirSizeSafe(entity);
        }
      }
    } catch (e) {
      _log('safe dir scan skip ${dir.path} error=$e');
    }
    _log('safe dir scan done ${dir.path} => ${_formatBytes(total)}');
    return total;
  }

  static Future<int> _managedDocumentsSize(Directory docs) async {
    var total = 0;
    final photosDir = Directory(p.join(docs.path, 'photos'));
    total += await _dirSizeSafe(photosDir);

    if (await docs.exists()) {
      await for (final entity in docs.list(followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.hive') ||
            lower.endsWith('.lock') ||
            lower.endsWith('.hive.backup')) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    }
    _log('managed docs size => ${_formatBytes(total)}');
    return total;
  }

  static bool _isManagedTempEntry(String name, {required String appId}) {
    return name.startsWith('backup_') ||
        name == 'backup_build' ||
        name == 'backup_restore' ||
        name == 'backup_fallback' ||
        name == _videoThumbsCacheDirName ||
        name.contains(appId) ||
        name == 'hive_backup.zip';
  }

  static bool _isInsideDirectory(String filePath, String directoryPath) {
    if (filePath.isEmpty) return false;
    return p.equals(filePath, directoryPath) ||
        p.isWithin(directoryPath, filePath);
  }

  static Future<int> _scopedTempSize(
    Directory tmp, {
    required String appId,
  }) async {
    if (!await tmp.exists()) return 0;
    var total = 0;
    await for (final entity in tmp.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_isManagedTempEntry(name, appId: appId)) continue;
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      } else if (entity is Directory) {
        total += await _dirSizeSafe(entity);
      }
    }
    _log('scoped temp size => ${_formatBytes(total)}');
    return total;
  }

  static Future<int> _scopedCacheSize(
    Directory cacheDir, {
    required String appId,
  }) async {
    if (!await cacheDir.exists()) return 0;
    var total = 0;
    await for (final entity in cacheDir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_isManagedTempEntry(name, appId: appId)) continue;
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      } else if (entity is Directory) {
        total += await _dirSizeSafe(entity);
      }
    }
    _log('scoped cache size => ${_formatBytes(total)}');
    return total;
  }

  static Future<int> _scopedPrefsSize(
    Directory prefsDir, {
    required String appId,
  }) async {
    if (!await prefsDir.exists()) return 0;
    var total = 0;
    await for (final entity in prefsDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.contains(appId)) continue;
      try {
        total += await entity.length();
      } catch (_) {}
    }
    _log('scoped prefs size => ${_formatBytes(total)}');
    return total;
  }

  static Future<void> _clearScopedTemp(
    Directory tmp, {
    required String appId,
  }) async {
    if (!await tmp.exists()) return;
    await for (final entity in tmp.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_isManagedTempEntry(name, appId: appId)) continue;
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<void> _clearScopedCache(
    Directory cacheDir, {
    required String appId,
  }) async {
    if (!await cacheDir.exists()) return;
    await for (final entity in cacheDir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_isManagedTempEntry(name, appId: appId)) continue;
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
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
