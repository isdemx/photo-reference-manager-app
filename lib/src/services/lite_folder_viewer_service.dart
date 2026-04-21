import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/services/macos_file_open_service.dart';
import 'package:photographers_reference_app/src/utils/_determine_media_type.dart';

class LiteViewerItem {
  const LiteViewerItem({
    required this.path,
    required this.name,
    required this.mediaType,
  });

  final String path;
  final String name;
  final String mediaType;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
}

class LiteFolderViewerData {
  const LiteFolderViewerData({
    required this.directoryPath,
    required this.items,
    required this.initialIndex,
  });

  final String directoryPath;
  final List<LiteViewerItem> items;
  final int initialIndex;
}

class LiteFolderViewerService {
  Future<LiteFolderViewerData> load(String initialFilePath) async {
    final source = File(initialFilePath);
    if (!await source.exists()) {
      throw const LiteFolderViewerException('File does not exist anymore.');
    }

    final directory = source.parent;
    late final List<LiteViewerItem> items;
    try {
      items = await _listSupportedItems(directory);
    } on LiteFolderViewerException catch (error) {
      if (!error.canFallbackToSingleFile) rethrow;
      final fallbackItem = _itemForFile(source);
      if (fallbackItem == null) rethrow;
      return LiteFolderViewerData(
        directoryPath: directory.path,
        items: [fallbackItem],
        initialIndex: 0,
      );
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (items.isEmpty) {
      throw const LiteFolderViewerException(
        'No supported image or video files were found in this folder.',
      );
    }

    final resolvedPath = p.normalize(initialFilePath);
    final initialIndex = items.indexWhere(
      (item) => p.normalize(item.path) == resolvedPath,
    );

    if (initialIndex < 0) {
      throw const LiteFolderViewerException(
        'The opened file is not supported by the lite viewer.',
      );
    }

    return LiteFolderViewerData(
      directoryPath: directory.path,
      items: items,
      initialIndex: initialIndex,
    );
  }

  Future<List<LiteViewerItem>> _listSupportedItems(Directory directory) async {
    try {
      return await _readSupportedItems(directory);
    } on FileSystemException {
      final grantedPath =
          await MacOSFileOpenService.requestFolderAccess(directory.path);
      if (grantedPath != null && grantedPath.isNotEmpty) {
        try {
          return await _readSupportedItems(directory);
        } on FileSystemException {
          if (p.normalize(grantedPath) != p.normalize(directory.path)) {
            return _readSupportedItems(Directory(grantedPath));
          }
        }
      }

      throw const LiteFolderViewerException(
        'Folder access was not granted. Choose the photo folder to enable Lite Viewer navigation.',
        canFallbackToSingleFile: true,
      );
    }
  }

  Future<List<LiteViewerItem>> _readSupportedItems(Directory directory) async {
    final items = <LiteViewerItem>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;

      final item = _itemForFile(entity);
      if (item == null) continue;
      items.add(item);
    }
    return items;
  }

  LiteViewerItem? _itemForFile(File file) {
    final mediaType = determineMediaType(file.path);
    if (mediaType == 'unknown') return null;
    return LiteViewerItem(
      path: file.path,
      name: p.basename(file.path),
      mediaType: mediaType,
    );
  }
}

class LiteFolderViewerException implements Exception {
  const LiteFolderViewerException(
    this.message, {
    this.canFallbackToSingleFile = false,
  });

  final String message;
  final bool canFallbackToSingleFile;

  @override
  String toString() => message;
}
