import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:vibration/vibration.dart';

class PhotoThumbnail extends StatefulWidget {
  final Photo photo;
  final VoidCallback onPhotoTap;
  final VoidCallback onDeleteTap;
  final bool isPinterestLayout;

  const PhotoThumbnail({
    Key? key,
    required this.photo,
    required this.onPhotoTap,
    required this.onDeleteTap,
    required this.isPinterestLayout,
  }) : super(key: key);

  @override
  _PhotoThumbnailState createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  bool _showDeleteIcon = false;

  @override
  Widget build(BuildContext context) {
    final fullPath = PhotoPathHelper().getFullPath(widget.photo.fileName);

    Widget imageWidget;

    if (widget.isPinterestLayout) {
      // В режиме Pinterest не задаем ограничения по высоте
      imageWidget = ExtendedImage.file(
        File(fullPath),
        fit: BoxFit.cover,
        enableMemoryCache: true,
        cacheWidth: 200,
        clearMemoryCacheIfFailed: true,
      );
    } else {
      // В стандартном режиме устанавливаем фиксированную высоту и ширину
      imageWidget = ExtendedImage.file(
        File(fullPath),
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 200,
        height: double.infinity,
        enableMemoryCache: true,
        clearMemoryCacheIfFailed: true,
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
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(
              duration: 10, pattern: [0, 10], intensities: [0, 255]);
        }

        setState(() {
          _showDeleteIcon = true;
        });
      },
      child: Stack(
        children: [
          imageWidget,
          if (_showDeleteIcon)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onDeleteTap,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}