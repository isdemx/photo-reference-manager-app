import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Минимальный helper (аналог твоего PhotoSaveHelper) — кладёт файл в /videos.
/// TODO: создать сущность Video и добавить в твою БД/Bloc при необходимости.
class VideoSaveHelper {
  static Future<File> saveVideo({
    required String fileName,
    required File file,
    required BuildContext context,
    required String mediaType, // 'video/mp4'
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(p.join(appDir.path, 'videos'));
    if (!videosDir.existsSync()) videosDir.createSync(recursive: true);

    final outPath = p.join(videosDir.path, fileName);
    final saved = await file.copy(outPath);

    // Тут можно дернуть твой репозиторий/Bloc, как делаешь для фото.
    // context.read<VideoBloc>().add(LoadVideos()); — если заведёшь.

    return saved;
  }
}
