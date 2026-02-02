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
  final bool isSelected;
  final String? fileSizeLabel;

  const PhotoThumbnail({
    Key? key,
    required this.photo,
    required this.onPhotoTap,
    required this.onLongPress,
    required this.isPinterestLayout,
    required this.isSelected,
    this.fileSizeLabel,
  }) : super(key: key);

  @override
  _PhotoThumbnailState createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _showDeleteIcon = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.photo.mediaType == 'video';

    // Видео превью: хранится как относительное имя (в photos/), собираем полный путь.
    final String? previewPath = (isVideo &&
            widget.photo.videoPreview != null &&
            widget.photo.videoPreview!.isNotEmpty)
        ? PhotoPathHelper().getFullPath(widget.photo.videoPreview!)
        : null;

    final bool hasPreview =
        previewPath != null && File(previewPath).existsSync();

    Widget imageWidget;

    if (isVideo) {
      if (hasPreview) {
        // ✅ Видео: показываем превью-картинку
        final previewFile = File(previewPath!);

        final previewImage = widget.isPinterestLayout
            ? ExtendedImage.file(
                previewFile,
                fit: BoxFit.cover,
                cacheWidth: 240,
                clearMemoryCacheIfFailed: true,
                cacheRawData: true,
              )
            : ExtendedImage.file(
                previewFile,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 240,
                clearMemoryCacheIfFailed: true,
                cacheRawData: true,
              );

        imageWidget = Stack(
          fit: StackFit.expand,
          children: [
            previewImage,
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.photo.fileName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      } else {
        // ❌ Нет превью — fallback (оставим твой текстовый вариант + play)
        final title = widget.fileSizeLabel != null
            ? '${widget.photo.fileName} • ${widget.fileSizeLabel}'
            : widget.photo.fileName;

        imageWidget = Stack(
          fit: StackFit.expand,
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withOpacity(0.2),
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }

      // ✅ Накладываем duration/size (если есть) — справа снизу
      final hasDuration = widget.photo.videoDuration != null &&
          widget.photo.videoDuration!.isNotEmpty;
      final hasSize =
          widget.fileSizeLabel != null && widget.fileSizeLabel!.isNotEmpty;
      if (hasDuration || hasSize) {
        final label = hasDuration && hasSize
            ? '${widget.photo.videoDuration!} • ${widget.fileSizeLabel!}'
            : hasDuration
                ? widget.photo.videoDuration!
                : widget.fileSizeLabel!;
        imageWidget = Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        );
      }
    } else {
      // Фото: ExtendedImage + оверлей размера, если есть
      final imgFile = File(PhotoPathHelper().getFullPath(widget.photo.fileName));

      final baseImage = widget.isPinterestLayout
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

      imageWidget = Stack(
        fit: StackFit.expand,
        children: [
          baseImage,
          if (widget.fileSizeLabel != null && widget.fileSizeLabel!.isNotEmpty)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.fileSizeLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
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
          imageWidget,

          if (_showDeleteIcon)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.delete, color: Colors.red),
            ),

          if (widget.isSelected)
            Positioned.fill(
              child: IgnorePointer(
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
