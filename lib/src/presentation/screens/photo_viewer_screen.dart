// lib/src/presentation/screens/photo_viewer_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_tag_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_tags_view_widget.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showActions = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleActions,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = photos[index];
                return PhotoView(
                  imageProvider: FileImage(File(photo.path)),
                );
              },
            ),
            if (_showActions)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            if (_showActions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ActionBar(photo: photos[_currentIndex]),
              ),
          ],
        ),
      ),
    );
  }
}

class ActionBar extends StatelessWidget {
  final Photo photo;

  const ActionBar({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    // Виджет действий: теги, комментарии, кнопки редактирования
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhotoTagsViewWidget(photo: photo),
            const SizedBox(height: 8.0),
            AddTagWidget(photo: photo),
            const SizedBox(height: 8.0),
            AddToFolderWidget(photo: photo),
            // Виджет комментария
            // Кнопки редактирования изображения
          ],
        ),
      ),
    );
  }
}
