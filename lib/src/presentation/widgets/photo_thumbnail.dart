import 'dart:io';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoThumbnail extends StatefulWidget {
  final Photo photo;
  final VoidCallback onPhotoTap;
  final VoidCallback onLongPress;
  final bool isPinterestLayout;

  const PhotoThumbnail({
    Key? key,
    required this.photo,
    required this.onPhotoTap,
    required this.onLongPress,
    required this.isPinterestLayout,
  }) : super(key: key);

  @override
  _PhotoThumbnailState createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _showDeleteIcon = false;

  @override
  Widget build(BuildContext context) {
    // Для видео используем относительное имя (videoPreview), преобразованное в абсолютный путь.
    // Для изображений используем fileName, которое тоже должно храниться как относительное имя.
    final imagePath = widget.photo.mediaType == 'video' &&
            widget.photo.videoPreview != null &&
            widget.photo.videoPreview!.isNotEmpty
        ? PhotoPathHelper().getFullPath(widget.photo.videoPreview!)
        : PhotoPathHelper().getFullPath(widget.photo.fileName);

    // Добавляем логирование для отладки
    final file = File(imagePath);
    if (file.existsSync()) {
      final size = file.lengthSync();
      print('Файл миниатюры существует: $imagePath, размер: $size байт');
    } else {
      print('Файл миниатюры НЕ существует: $imagePath');
    }

    // Выбираем виджет для отображения изображения в зависимости от layout
    Widget imageWidget = widget.isPinterestLayout
        ? ExtendedImage.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            enableMemoryCache: false, // отключаем кэширование для диагностики
            cacheWidth: 200,
            clearMemoryCacheIfFailed: true,
          )
        : ExtendedImage.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            enableMemoryCache: false, // отключаем кэширование для диагностики
            cacheWidth: 200,
            clearMemoryCacheIfFailed: true,
          );

    // Если у видео задано время, накладываем его поверх изображения
    if (widget.photo.mediaType == 'video' &&
        widget.photo.videoDuration != null &&
        widget.photo.videoDuration!.isNotEmpty) {
      imageWidget = Stack(
        alignment: Alignment.center,
        children: [
          imageWidget,
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(0),
              color: Colors.black.withOpacity(0.5),
              child: Text(
                widget.photo.videoDuration!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (_showDeleteIcon) {
          setState(() {
            _showDeleteIcon = false;
          });
        } else {
          widget.onPhotoTap();
        }
      },
      onLongPress: () async {
        vibrate();
        widget.onLongPress();
      },
      child: imageWidget,
    );
  }
}
