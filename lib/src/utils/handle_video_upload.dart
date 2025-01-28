import 'dart:io';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

/// Генерация превью первого кадра видео и возврат результата в Map:
/// {
///   'videoPreview': <String (путь к превью)>,
///   'videoDuration': <String (в формате mm:ss)>
/// }
Future<Map<String, dynamic>?> generateVideoThumbnail(Photo video) async {
  if (video.mediaType != 'video') return null;

  try {
    // Генерация превью
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: video.path, // Путь к видео
      thumbnailPath:
          (await getTemporaryDirectory()).path, // Временная директория
      imageFormat: ImageFormat.JPEG, // Формат превью
      maxHeight: 200, // Максимальная высота превью
      quality: 75, // Качество превью
    );

    if (thumbnailPath == null) {
      print('Error generating thumbnail: returned null');
      return null;
    }

    // Перемещение превью в постоянную директорию
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDocDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }

    final finalThumbnailPath =
        p.join(photosDir.path, '${video.id}_thumbnail.jpg');
    final thumbnailFile = File(thumbnailPath);
    await thumbnailFile.copy(finalThumbnailPath);

    // Получение длительности видео
    final videoPlayerController = VideoPlayerController.file(File(video.path));
    await videoPlayerController.initialize();
    final duration = videoPlayerController.value.duration;
    videoPlayerController.dispose();

    return {
      'videoPreview': finalThumbnailPath,
      'videoDuration': formatDuration(duration),
    };
  } catch (e) {
    print('Error generating video thumbnail: $e');
    return null;
  }
}

/// Форматируем Duration (простой формат mm:ss)
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}
