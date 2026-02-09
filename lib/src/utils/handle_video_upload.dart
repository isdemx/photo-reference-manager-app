import 'dart:io';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ Уже используешь в проекте — добавляем сюда для macOS превью
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

Future<Map<String, dynamic>?> generateVideoThumbnail(Photo video) async {
  if (video.mediaType != 'video') return null;

  try {
    final appDocDir = await getApplicationDocumentsDirectory();

    // Превью храним рядом с медиа в documents/photos
    final photosDir = Directory(p.join(appDocDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // В БД храним только относительное имя файла (как у тебя ожидает PhotoPathHelper)
    final thumbnailFileName = '${video.id}_thumbnail.jpg';
    final finalThumbnailPath = p.join(photosDir.path, thumbnailFileName);

    // 1) Генерация превью
    final String? previewPath = await _createThumbnailFileCrossPlatform(
      videoPath: video.path, // full path
      outPath: finalThumbnailPath,
      outDir: photosDir.path,
    );

    if (previewPath == null) {
      print('[Thumb] Error: previewPath is null');
      return null;
    }

    final outFile = File(finalThumbnailPath);
    if (!await outFile.exists()) {
      print('[Thumb] Error: итоговый thumbnail не существует: $finalThumbnailPath');
      return null;
    }
    final fileSize = await outFile.length();
    if (fileSize == 0) {
      print('[Thumb] Error: thumbnail файл 0 байт: $finalThumbnailPath');
      return null;
    }
    if (!await _isValidJpegFile(outFile)) {
      print('[Thumb] Error: thumbnail невалидный JPEG: $finalThumbnailPath');
      return null;
    }

    // 2) Длительность и размер (video_player)
    final c = VideoPlayerController.file(File(video.path));
    await c.initialize();
    final duration = c.value.duration;
    final videoSize = c.value.size;
    await c.dispose();

    return {
      'videoPreview': thumbnailFileName,
      'videoDuration': formatDuration(duration),
      'videoWidth': videoSize.width,
      'videoHeight': videoSize.height,
    };
  } catch (e, st) {
    print('Ошибка при генерации миниатюры видео: $e\n$st');
    return null;
  }
}

Future<String?> convertVideoToMp4IfNeeded({
  required String inputPath,
  required String outputDir,
}) async {
  if (!Platform.isMacOS) return null;

  final ext = p.extension(inputPath).toLowerCase();
  const needsConvert = ['.avi', '.wmv', '.vmv', '.m4v'];
  if (!needsConvert.contains(ext)) return null;

  final baseName = p.basenameWithoutExtension(inputPath).trim();
  final safeBase = baseName.isEmpty ? 'video' : baseName;
  final outputPath = _uniqueOutputPath(outputDir, safeBase, '.mp4');

  final existing = File(outputPath);
  if (await existing.exists() && await existing.length() > 0) {
    return outputPath;
  }

  final cmd = [
    '-i ${_q(inputPath)}',
    '-c:v libx264',
    '-pix_fmt yuv420p',
    '-c:a aac',
    '-movflags +faststart',
    '-y ${_q(outputPath)}',
  ].join(' ');

  print('[Convert][FFmpeg] $cmd');

  final session = await FFmpegKit.execute(cmd);
  final rc = await session.getReturnCode();

  if (!ReturnCode.isSuccess(rc)) {
    final logs = await session.getLogs();
    for (final l in logs) {
      print('[Convert][FFmpeg] ${l.getMessage()}');
    }
    print('[Convert][FFmpeg] FAILED rc=$rc');
    return null;
  }

  final outFile = File(outputPath);
  if (!await outFile.exists() || await outFile.length() == 0) {
    print('[Convert][FFmpeg] Output invalid: $outputPath');
    return null;
  }

  return outputPath;
}

Future<String?> _createThumbnailFileCrossPlatform({
  required String videoPath,
  required String outPath,
  required String outDir,
}) async {
  final videoFile = File(videoPath);
  if (!await videoFile.exists()) {
    print('[Thumb] Video not found: $videoPath');
    return null;
  }

  // Если уже есть — проверим валидность
  final existing = File(outPath);
  if (await existing.exists()) {
    if (await _isValidJpegFile(existing)) {
      return outPath;
    }
    await existing.delete();
  }

  // ✅ macOS: используем FFmpegKit (стабильно, без “плагина для превью”)
  if (Platform.isMacOS) {
    return await _createThumbnailWithFfmpeg(
      videoPath: videoPath,
      outPath: outPath,
    );
  }

  // ✅ iOS/Android: оставляем video_thumbnail как раньше
  final generatedPath = await VideoThumbnail.thumbnailFile(
    video: videoPath,
    thumbnailPath: outDir,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 360,
    quality: 75,
    timeMs: 800,
  );

  if (generatedPath == null) {
    print('[Thumb] video_thumbnail.thumbnailFile вернул null (platform=${Platform.operatingSystem})');
    return null;
  }

  final genFile = File(generatedPath);
  if (!await genFile.exists()) {
    print('[Thumb] generated thumbnail file not found: $generatedPath');
    return null;
  }
  if (!await _isValidJpegFile(genFile)) {
    print('[Thumb] generated thumbnail invalid JPEG: $generatedPath');
    return null;
  }

  if (generatedPath != outPath) {
    await genFile.copy(outPath);
  }

  return await File(outPath).exists() ? outPath : null;
}

Future<String?> _createThumbnailWithFfmpeg({
  required String videoPath,
  required String outPath,
}) async {
  // time ~0.8s, 1 frame, scale to width 360, keep aspect
  // -y overwrite
  final safeVideo = _q(videoPath);
  final safeOut = _q(outPath);

  final cmd = [
    '-ss 0.8',
    '-i $safeVideo',
    '-frames:v 1',
    '-vf scale=360:-1',
    '-q:v 4',
    '-y $safeOut',
  ].join(' ');

  print('[Thumb][FFmpeg] $cmd');

  final session = await FFmpegKit.execute(cmd);
  final rc = await session.getReturnCode();

  if (!ReturnCode.isSuccess(rc)) {
    final logs = await session.getLogs();
    for (final l in logs) {
      print('[Thumb][FFmpeg] ${l.getMessage()}');
    }
    print('[Thumb][FFmpeg] FAILED rc=$rc');
    return null;
  }

  final outFile = File(outPath);
  if (!await outFile.exists()) {
    print('[Thumb][FFmpeg] Output not found: $outPath');
    return null;
  }
  if (await outFile.length() == 0) {
    print('[Thumb][FFmpeg] Output is 0 bytes: $outPath');
    return null;
  }
  if (!await _isValidJpegFile(outFile)) {
    print('[Thumb][FFmpeg] Output invalid JPEG: $outPath');
    return null;
  }

  return outPath;
}

String _q(String s) => '"${s.replaceAll('"', r'\"')}"';

String _uniqueOutputPath(String dir, String baseName, String ext) {
  String candidate = p.join(dir, '$baseName$ext');
  int i = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$baseName ($i)$ext');
    i++;
  }
  return candidate;
}

Future<bool> _isValidJpegFile(File file) async {
  try {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < 4) return false;
    final raf = await file.open();
    final head = await raf.read(2);
    await raf.setPosition(length - 2);
    final tail = await raf.read(2);
    await raf.close();
    return head.length == 2 &&
        tail.length == 2 &&
        head[0] == 0xFF &&
        head[1] == 0xD8 &&
        tail[0] == 0xFF &&
        tail[1] == 0xD9;
  } catch (_) {
    return false;
  }
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}
