import 'dart:io';

import 'package:path/path.dart' as p;
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
    final items = await _listSupportedItems(directory);

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
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 250),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1400),
    ];

    Object? lastError;

    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      try {
        final items = <LiteViewerItem>[];
        await for (final entity in directory.list()) {
          if (entity is! File) continue;

          final mediaType = determineMediaType(entity.path);
          if (mediaType == 'unknown') continue;

          items.add(
            LiteViewerItem(
              path: entity.path,
              name: p.basename(entity.path),
              mediaType: mediaType,
            ),
          );
        }
        return items;
      } on FileSystemException catch (error) {
        lastError = error;
      }
    }

    if (lastError is FileSystemException) {
      throw LiteFolderViewerException(
        'Unable to access this folder. macOS may still be waiting for folder permission.',
      );
    }

    throw const LiteFolderViewerException(
      'Unable to read files from this folder.',
    );
  }
}

class LiteFolderViewerException implements Exception {
  const LiteFolderViewerException(this.message);

  final String message;

  @override
  String toString() => message;
}
