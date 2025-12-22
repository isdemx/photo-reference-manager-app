import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailCache {
  VideoThumbnailCache._();

  static final VideoThumbnailCache instance = VideoThumbnailCache._();

  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};
  final Queue<String> _queue = Queue<String>();
  int _running = 0;

  // Жёстко ограничиваем параллелизм, чтобы не лагало при скролле.
  final int maxConcurrentJobs = 2;

  /// Возвращает путь к thumbnail-файлу (jpg/webp), создавая его при необходимости.
  /// - videoPath: полный путь к видео на диске
  /// - timeMs: с какого момента брать кадр (например 500 или 1000)
  Future<String?> getOrCreate({
    required String videoPath,
    int timeMs = 800,
    int maxWidth = 360,
    int quality = 75,
    ImageFormat format = ImageFormat.JPEG,
  }) async {
    final file = File(videoPath);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    final key = _buildKey(videoPath, stat.size, stat.modified.millisecondsSinceEpoch, timeMs, maxWidth, quality, format);

    // Если thumbnail уже существует — отдаём сразу
    final outPath = await _expectedOutputPath(key, format);
    if (await File(outPath).exists()) return outPath;

    // Если уже генерируем — возвращаем тот же Future
    final existing = _inFlight[key];
    if (existing != null) return existing;

    // Иначе ставим в очередь
    final completer = Completer<String?>();
    _inFlight[key] = completer.future;

    _queue.add(key);
    _pumpQueue(
      keyToJob: () async {
        final result = await _generateThumbnail(
          videoPath: videoPath,
          outPath: outPath,
          timeMs: timeMs,
          maxWidth: maxWidth,
          quality: quality,
          format: format,
        );
        return result;
      },
      onDone: (res) {
        if (!completer.isCompleted) completer.complete(res);
      },
      onError: (e, st) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }

  void _pumpQueue({
    required Future<String?> Function() keyToJob,
    required void Function(String? result) onDone,
    required void Function(Object error, StackTrace st) onError,
  }) {
    if (_running >= maxConcurrentJobs) return;
    if (_queue.isEmpty) return;

    _running++;
    _queue.removeFirst();

    () async {
      try {
        final res = await keyToJob();
        onDone(res);
      } catch (e, st) {
        onError(e, st);
      } finally {
        _running--;
        // Подхватим следующие задачи
        if (_queue.isNotEmpty) {
          _pumpQueue(keyToJob: keyToJob, onDone: onDone, onError: onError);
        }
      }
    }();
  }

  String _buildKey(
    String videoPath,
    int size,
    int modifiedMs,
    int timeMs,
    int maxWidth,
    int quality,
    ImageFormat format,
  ) {
    final raw = '$videoPath|$size|$modifiedMs|$timeMs|$maxWidth|$quality|${format.name}';
    return md5.convert(raw.codeUnits).toString();
  }

  Future<String> _expectedOutputPath(String key, ImageFormat format) async {
    final dir = await getTemporaryDirectory();
    final sub = Directory(p.join(dir.path, 'refma_video_thumbs'));
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    final ext = _ext(format);
    return p.join(sub.path, '$key.$ext');
  }

  String _ext(ImageFormat f) {
    switch (f) {
      case ImageFormat.PNG:
        return 'png';
      case ImageFormat.WEBP:
        return 'webp';
      case ImageFormat.JPEG:
      default:
        return 'jpg';
    }
  }

  Future<String?> _generateThumbnail({
    required String videoPath,
    required String outPath,
    required int timeMs,
    required int maxWidth,
    required int quality,
    required ImageFormat format,
  }) async {
    final outFile = File(outPath);
    if (await outFile.exists()) return outPath;

    final generated = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: p.dirname(outPath),
      imageFormat: format,
      maxWidth: maxWidth,
      quality: quality,
      timeMs: timeMs,
    );

    if (generated == null) return null;

    // video_thumbnail может вернуть путь в той же папке, но имя может отличаться.
    if (generated != outPath) {
      final gFile = File(generated);
      if (await gFile.exists()) {
        await gFile.copy(outPath);
      }
    }

    return await File(outPath).exists() ? outPath : null;
  }
}
