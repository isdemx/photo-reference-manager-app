import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/handle_video_upload.dart';
import 'package:uuid/uuid.dart';

class SharedInboxImportService {
  static const MethodChannel _channel =
      MethodChannel('refma/shared_import');

  Future<List<Map<String, dynamic>>> loadManifest() async {
    if (kIsWeb || !Platform.isIOS) return const [];

    final raw = await _channel.invokeMethod<List<dynamic>>('getManifest');
    if (raw == null || raw.isEmpty) return const [];

    final items = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        items.add(Map<String, dynamic>.from(item));
      }
    }
    return items;
  }

  Future<int> importIfAvailable(PhotoRepositoryImpl repo) async {
    final manifest = await loadManifest();
    if (manifest.isEmpty) return 0;
    return importManifest(manifest, repo);
  }

  Future<int> importManifest(
    List<Map<String, dynamic>> manifest,
    PhotoRepositoryImpl repo, {
    void Function(int current)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isIOS) return 0;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final importedPaths = <String>[];
    int imported = 0;

    const defaultCompressSizeKb = 300;

    onProgress?.call(0);
    var processed = 0;

    for (final item in manifest) {
      final srcPath = item['filePath'] as String?;
      if (srcPath == null || srcPath.isEmpty) {
        processed++;
        onProgress?.call(processed);
        continue;
      }
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) {
        processed++;
        onProgress?.call(processed);
        continue;
      }

      final mediaType = (item['mediaType'] as String?) ??
          _inferMediaType(p.extension(srcPath));
      final shouldCompress = (item['compress'] as bool?) ?? true;
      final tagIdsRaw = item['tagIds'];
      final tagIds = <String>[];
      if (tagIdsRaw is List) {
        for (final id in tagIdsRaw) {
          if (id is String && id.isNotEmpty) {
            tagIds.add(id);
          }
        }
      }
      final folderIdsRaw = item['folderIds'];
      final folderIds = <String>[];
      if (folderIdsRaw is List) {
        for (final id in folderIdsRaw) {
          if (id is String && id.isNotEmpty) {
            folderIds.add(id);
          }
        }
      }
      final originalName = (item['originalName'] as String?) ?? 'shared';
      final comment = (item['comment'] as String?) ?? '';
      final targetName = _resolveUniqueName(
        photosDir.path,
        originalName,
        srcPath,
      );
      final destPath = p.join(photosDir.path, targetName);

      try {
        await srcFile.copy(destPath);
      } catch (_) {
        processed++;
        onProgress?.call(processed);
        continue;
      }

      final photo = Photo(
        id: const Uuid().v4(),
        fileName: targetName,
        path: destPath,
        mediaType: mediaType,
        dateAdded: DateTime.now(),
        folderIds: folderIds,
        comment: comment,
        tagIds: tagIds,
        sortOrder: 0,
        isStoredInApp: true,
        geoLocation: null,
        videoPreview: null,
        videoDuration: null,
        videoWidth: null,
        videoHeight: null,
      );

      final compressSizeKb = (mediaType == 'image' && shouldCompress)
          ? defaultCompressSizeKb
          : 0;
      await repo.addPhoto(photo, compressSizeKb: compressSizeKb);

      if (mediaType == 'video') {
        final videoResult = await generateVideoThumbnail(photo);
        if (videoResult != null) {
          photo.videoPreview = videoResult['videoPreview'] as String?;
          photo.videoDuration = videoResult['videoDuration'] as String?;
          photo.videoWidth =
              (videoResult['videoWidth'] as num?)?.toDouble();
          photo.videoHeight =
              (videoResult['videoHeight'] as num?)?.toDouble();
          await repo.updatePhoto(photo);
        }
      }

      importedPaths.add(srcPath);
      imported++;
      processed++;
      onProgress?.call(processed);
    }

    if (importedPaths.isNotEmpty) {
      await _channel.invokeMethod('deleteSharedFiles', importedPaths);
      await _channel.invokeMethod('clearManifest');
    }

    return imported;
  }

  String _resolveUniqueName(
    String destDir,
    String originalName,
    String srcPath,
  ) {
    final ext = p.extension(originalName).isNotEmpty
        ? p.extension(originalName)
        : p.extension(srcPath);
    final base = p.basenameWithoutExtension(originalName).trim();
    final safeBase = base.isEmpty ? 'shared' : base;

    String candidate = '$safeBase$ext';
    int i = 1;
    while (File(p.join(destDir, candidate)).existsSync()) {
      candidate = '$safeBase ($i)$ext';
      i++;
    }
    return candidate;
  }

  String _inferMediaType(String ext) {
    final lower = ext.toLowerCase();
    const imageExts = [
      '.jpg',
      '.jpeg',
      '.png',
      '.heic',
      '.heif',
      '.gif',
      '.tiff',
      '.bmp',
      '.webp',
    ];
    const videoExts = [
      '.mov',
      '.mp4',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    if (imageExts.contains(lower)) return 'image';
    if (videoExts.contains(lower)) return 'video';
    return 'file';
  }
}
