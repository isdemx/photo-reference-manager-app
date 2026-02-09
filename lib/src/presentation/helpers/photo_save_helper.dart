import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:uuid/uuid.dart';

// ✅ добавь импорт на твою функцию превью
import 'package:photographers_reference_app/src/utils/handle_video_upload.dart';
import 'package:photographers_reference_app/src/utils/_determine_media_type.dart';

class PhotoSaveHelper {
  /// Сохраняет файл из байтов [bytes] с именем [fileName] в папку "photos" приложения,
  /// создаёт объект [Photo], добавляет его в базу данных и возвращает.
  /// Если это видео — генерирует videoPreview + videoDuration и обновляет запись.
  static Future<Photo> savePhoto({
    required String fileName,
    required Uint8List bytes,
    required BuildContext context,
    required String mediaType,
    void Function(String status)? onStatus,
  }) async {
    try {
      // 1) Получаем директорию приложения и создаём папку "photos".
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }

      // 2) Создаём путь для сохранения файла.
      final outPath = p.join(photosDir.path, fileName);
      final outFile = File(outPath);

      // 3) Записываем байты в файл.
      onStatus?.call('loading');
      await outFile.writeAsBytes(bytes);

      String finalPath = outPath;
      String finalFileName = fileName;
      final ext = p.extension(outPath).toLowerCase();
      const convertExts = ['.avi', '.wmv', '.vmv', '.m4v'];
      if (Platform.isMacOS && convertExts.contains(ext)) {
        onStatus?.call('converting');
      }
      final convertedPath = await convertVideoToMp4IfNeeded(
        inputPath: outPath,
        outputDir: photosDir.path,
      );
      if (convertedPath != null) {
        finalPath = convertedPath;
        finalFileName = p.basename(convertedPath);
        if (convertedPath != outPath && await outFile.exists()) {
          await outFile.delete();
        }
      }

      final resolvedMediaType = determineMediaType(finalPath);
      final actualMediaType =
          resolvedMediaType == 'unknown' ? mediaType : resolvedMediaType;

      // 4) Создаём объект Photo.
      final newPhoto = Photo(
        id: const Uuid().v4(),
        fileName: finalFileName,
        path: finalPath,
        mediaType: actualMediaType,
        dateAdded: DateTime.now(),
        folderIds: [],
        comment: '',
        tagIds: [],
        sortOrder: 0,
        isStoredInApp: true,
        geoLocation: null,
        videoPreview: null,
        videoDuration: null,
        videoWidth: null,
        videoHeight: null,
      );

      // 5) Добавляем в базу (сразу), чтобы объект был в Hive.
      final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
      await repo.addPhoto(newPhoto);

      // 6) Если это видео — генерируем превью и обновляем запись.
      if (actualMediaType == 'video') {
        final videoResult = await generateVideoThumbnail(newPhoto);
        if (videoResult != null) {
          newPhoto.videoPreview = videoResult['videoPreview'] as String?;
          newPhoto.videoDuration = videoResult['videoDuration'] as String?;
          newPhoto.videoWidth =
              (videoResult['videoWidth'] as num?)?.toDouble();
          newPhoto.videoHeight =
              (videoResult['videoHeight'] as num?)?.toDouble();
          await repo.updatePhoto(newPhoto);
        } else {
          debugPrint('[PhotoSaveHelper] video thumbnail generation returned null');
        }
      }

      // 7) Обновляем список.
      context.read<PhotoBloc>().add(LoadPhotos());

      return newPhoto;
    } catch (e, st) {
      debugPrint('Ошибка сохранения файла: $e\n$st');
      throw Exception('Не удалось сохранить файл');
    }
  }
}
