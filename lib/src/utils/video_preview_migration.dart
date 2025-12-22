import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewMigration {
  /// ⚠️ ЖЁСТКАЯ МИГРАЦИЯ
  /// - ТОЛЬКО видео
  /// - Удаляет СТАРЫЕ превью
  /// - Генерирует новые через FFmpeg
  static Future<void> run(Box<Photo> photoBox) async {
    debugPrint('🟡 VideoPreviewMigration (FORCE) started');

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }

    int regenerated = 0;
    int skipped = 0;
    int deleted = 0;

    for (final photo in photoBox.values) {
      // ❗️ТРОГАЕМ ТОЛЬКО ВИДЕО
      if (photo.mediaType != 'video') {
        skipped++;
        continue;
      }

      try {
        final videoFile = File(photo.path);
        if (!videoFile.existsSync()) {
          debugPrint('⚠️ Video file not found: ${photo.path}');
          continue;
        }

        final previewName = '${photo.id}_thumbnail.jpg';
        final previewPath = p.join(photosDir.path, previewName);

        // 1️⃣ Удаляем старое превью (если было)
        if (photo.videoPreview != null && photo.videoPreview!.isNotEmpty) {
          final oldPath = p.join(photosDir.path, photo.videoPreview!);
          final oldFile = File(oldPath);
          if (oldFile.existsSync()) {
            try {
              await oldFile.delete();
              deleted++;
              debugPrint('🗑 Deleted old preview: $oldPath');
            } catch (e) {
              debugPrint('⚠️ Failed to delete old preview: $oldPath → $e');
            }
          }
        }

        // 2️⃣ Генерируем НОВОЕ превью
        final ok = await _generateThumbnailFFmpeg(
          videoPath: photo.path,
          outPath: previewPath,
        );

        if (!ok) {
          debugPrint('❌ Failed to generate preview for ${photo.fileName}');
          continue;
        }

        // 3️⃣ Читаем длительность
        final duration = await _readVideoDuration(photo.path);

        // 4️⃣ Обновляем Hive-объект
        photo.videoPreview = previewName;
        photo.videoDuration = _formatDuration(duration);
        await photo.save();

        regenerated++;
        debugPrint('✅ Regenerated preview for ${photo.fileName}');
      } catch (e, st) {
        debugPrint('❌ Error processing ${photo.fileName}: $e\n$st');
      }
    }

    debugPrint(
      '🟢 VideoPreviewMigration finished '
      '(regenerated=$regenerated, deleted=$deleted, skipped=$skipped)',
    );
  }

  // ---------- FFmpeg ----------
  static Future<bool> _generateThumbnailFFmpeg({
    required String videoPath,
    required String outPath,
  }) async {
    final cmd = [
      '-ss 0.8',
      '-i "${videoPath.replaceAll('"', r'\"')}"',
      '-frames:v 1',
      '-vf scale=360:-1',
      '-q:v 4',
      '-y "${outPath.replaceAll('"', r'\"')}"',
    ].join(' ');

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();

    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getLogs();
      for (final l in logs) {
        debugPrint('[FFmpeg] ${l.getMessage()}');
      }
      return false;
    }

    final f = File(outPath);
    return f.existsSync() && f.lengthSync() > 0;
  }

  // ---------- Duration ----------
  static Future<Duration> _readVideoDuration(String path) async {
    final c = VideoPlayerController.file(File(path));
    await c.initialize();
    final d = c.value.duration;
    await c.dispose();
    return d;
  }

  static String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
