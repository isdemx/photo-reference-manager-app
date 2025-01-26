// video_thumbnail_helpers.dart
import 'dart:io';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Генерация превью видео и возврат результата
Future<Map<String, dynamic>?> generateVideoThumbnail(Photo video) async {
  if (video.mediaType == 'video') {
    try {
      final tempDir = await getTemporaryDirectory();
      final videoPath = PhotoPathHelper().getFullPath(video.fileName);

      // Генерация превью
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200, // Высота превью (автоширина для сохранения пропорций)
        quality: 75,
      );

      if (thumbnailPath != null) {
        // Получение длительности видео
        final videoPlayerController =
            VideoPlayerController.file(File(videoPath));
        await videoPlayerController.initialize();
        final duration = videoPlayerController.value.duration;
        videoPlayerController.dispose();

        // Возвращаем данные в формате Map
        return {
          'videoPreview': thumbnailPath,
          'videoDuration': formatDuration(duration),
        };
      }
    } catch (e) {
      print('Error generating video thumbnail: $e');
    }
  }
  return null; // Возвращаем null в случае ошибки
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}
