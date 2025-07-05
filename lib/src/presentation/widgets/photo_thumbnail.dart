import 'dart:io';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoThumbnail extends StatefulWidget {
  final Photo photo;
  final VoidCallback onPhotoTap;
  final VoidCallback onLongPress;
  final bool isPinterestLayout;
  final bool isSelected;

  const PhotoThumbnail({
    Key? key,
    required this.photo,
    required this.onPhotoTap,
    required this.onLongPress,
    required this.isPinterestLayout,
    required this.isSelected, // <-- добавили
  }) : super(key: key);

  @override
  _PhotoThumbnailState createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _showDeleteIcon = false;

  @override
  Widget build(BuildContext context) {
    // Для видео используем videoPreview, для изображений fileName
    final imagePath = widget.photo.mediaType == 'video' &&
            widget.photo.videoPreview != null &&
            widget.photo.videoPreview!.isNotEmpty
        ? PhotoPathHelper().getFullPath(widget.photo.videoPreview!)
        : PhotoPathHelper().getFullPath(widget.photo.fileName);

    // Логирование для отладки
    final file = File(imagePath);
    if (file.existsSync()) {
      final size = file.lengthSync();
      print('Файл миниатюры существует: $imagePath, размер: $size байт');
    } else {
      print('Файл миниатюры НЕ существует: $imagePath');
    }

    // Для режима Pinterest не задаём width/height, чтобы ExtendedImage занял размеры, определённые родителем.
    // ── чем рендерим превью? ────────────────────────────────────────────────
    Widget imageWidget;
    if (widget.photo.mediaType == 'video') {
      // для видео — маленький VideoView (звук 0, без UI)
      imageWidget = Container(
        height: 100,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          widget.photo.fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines:
              3, // или любое другое число, сколько строк максимум разрешено
        ),
      );
    } else {
      // для фото — ExtendedImage, как было
      final imgFile =
          File(PhotoPathHelper().getFullPath(widget.photo.fileName));
      imageWidget = widget.isPinterestLayout
          ? ExtendedImage.file(
              imgFile,
              fit: BoxFit.cover,
              cacheWidth: 200,
              clearMemoryCacheIfFailed: true,
              cacheRawData: true,
            )
          : ExtendedImage.file(
              imgFile,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 200,
              clearMemoryCacheIfFailed: true,
              cacheRawData: true,
            );
    }

    // Если это видео и задана длительность, накладываем её поверх изображения.
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
          setState(() => _showDeleteIcon = false);
        } else {
          widget.onPhotoTap();
        }
      },
      onLongPress: () {
        vibrate();
        widget.onLongPress();
      },
      child: Stack(
        children: [
          // 1️⃣ изображение диктует высоту Masonry-ячейки
          imageWidget,

          // 2️⃣ иконка удаления (если нужна)
          if (_showDeleteIcon)
            Positioned(
              top: 4,
              right: 4,
              child: const Icon(Icons.delete, color: Colors.red),
            ),

          // 3️⃣ рамка выбора, не влияющая на лайаут
          if (widget.isSelected)
            Positioned.fill(
              child: IgnorePointer(
                // не блокируем тапы
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
