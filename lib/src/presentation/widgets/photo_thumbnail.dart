import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:vibration/vibration.dart';

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
        vibrate();
        widget.onLongPress();
      },
      child: Stack(
        children: [
          imageWidget
        ],
      ),
    );
  }
}
