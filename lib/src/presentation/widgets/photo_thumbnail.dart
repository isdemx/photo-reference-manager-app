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
    super.key,
    required this.photo,
    required this.onPhotoTap,
    required this.onLongPress,
    required this.isPinterestLayout,
  });

  @override
  _PhotoThumbnailState createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _showDeleteIcon = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fullPath = PhotoPathHelper().getFullPath(widget.photo.fileName);
    final isVideo = widget.photo.mediaType == 'video';

    Widget mediaWidget;

    if (isVideo) {
      print('widget.photo.videoPreview ${widget.photo.videoPreview}');
      // Если это видео, показываем превью
      mediaWidget = Stack(
        alignment: Alignment.center,
        children: [
          if (widget.photo.videoPreview != null)
            Image.file(
              File(widget.photo.videoPreview!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: Colors.black,
            ),
          if (widget.photo.videoDuration != null)
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
    } else {
      // Если это изображение, используем ExtendedImage
      if (widget.isPinterestLayout) {
        mediaWidget = ExtendedImage.file(
          File(fullPath),
          fit: BoxFit.cover,
          enableMemoryCache: true,
          cacheWidth: 200,
          clearMemoryCacheIfFailed: true,
        );
      } else {
        mediaWidget = ExtendedImage.file(
          File(fullPath),
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 200,
          height: double.infinity,
          enableMemoryCache: true,
          clearMemoryCacheIfFailed: true,
        );
      }
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          mediaWidget,
        ],
      ),
    );
  }
}
