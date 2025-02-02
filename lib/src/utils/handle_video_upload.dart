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
    // Генерация миниатюры как данных в памяти
    final uint8list = await VideoThumbnail.thumbnailData(
      video: video.path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );
    if (uint8list == null) {
      print('Error: thumbnailData вернул null');
      return null;
    }

    // Получаем каталог документов и путь к каталогу photos
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDocDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
      print('Создана директория для фотографий: ${photosDir.path}');
    }

    // Формируем имя файла для миниатюры (относительное имя)
    final thumbnailFileName = '${video.id}_thumbnail.jpg';
    // Формируем полный путь для записи
    final finalThumbnailPath = p.join(photosDir.path, thumbnailFileName);
    final file = File(finalThumbnailPath);
    await file.writeAsBytes(uint8list);
    print('Миниатюра сохранена по пути: $finalThumbnailPath');

    // Дополнительная проверка: существует ли файл и какой у него размер
    if (!(await file.exists())) {
      print('Ошибка: файл миниатюры не существует после записи');
      return null;
    } else {
      final fileSize = await file.length();
      print('Файл миниатюры существует. Размер: $fileSize байт');
      if (fileSize == 0) {
        print('Ошибка: размер файла миниатюры равен 0');
        return null;
      }
    }

    // Получение длительности видео
    final videoPlayerController = VideoPlayerController.file(File(video.path));
    await videoPlayerController.initialize();
    final duration = videoPlayerController.value.duration;
    videoPlayerController.dispose();

    // Возвращаем только имя файла вместо полного пути
    return {
      'videoPreview': thumbnailFileName,
      'videoDuration': formatDuration(duration),
    };
  } catch (e) {
    print('Ошибка при генерации миниатюры видео: $e');
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
