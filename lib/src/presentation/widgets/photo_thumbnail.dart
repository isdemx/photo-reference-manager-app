import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:video_player/video_player.dart';

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
  String? _videoThumbnailPath; // Путь к превью
  String? _videoDuration; // Длительность видео

  @override
  void initState() {
    super.initState();
    _generateVideoThumbnail();
  }

  Future<void> _generateVideoThumbnail() async {
    if (widget.photo.mediaType == 'video') {
      try {
        final tempDir = await getTemporaryDirectory();
        final videoPath = PhotoPathHelper().getFullPath(widget.photo.fileName);

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
          final videoPlayerController = VideoPlayerController.file(File(videoPath));
          await videoPlayerController.initialize();
          final duration = videoPlayerController.value.duration;
          videoPlayerController.dispose();

          setState(() {
            _videoThumbnailPath = thumbnailPath.path;
            _videoDuration = _formatDuration(duration);
          });
        }
      } catch (e) {
        print('Error generating video thumbnail: $e');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fullPath = PhotoPathHelper().getFullPath(widget.photo.fileName);
    final isVideo = widget.photo.mediaType == 'video';

    Widget mediaWidget;

    if (isVideo) {
      // Если это видео, показываем превью
      mediaWidget = Stack(
        alignment: Alignment.center,
        children: [
          if (_videoThumbnailPath != null)
            Image.file(
              File(_videoThumbnailPath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: Colors.black,
            ),
          if (_videoDuration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(0),
                color: Colors.black.withOpacity(0.5),
                child: Text(
                  _videoDuration!,
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
