// lib/src/presentation/screens/folder_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';

class FolderScreen extends StatelessWidget {
  final Folder folder;

  const FolderScreen({Key? key, required this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PhotoBloc(
        photoRepository: PhotoRepositoryImpl(Hive.box('photos')),
      )..add(LoadPhotos()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(folder.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Переход на экран загрузки фотографий с передачей folderId
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UploadScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            if (photoState is PhotoLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded) {
              final List<Photo> photos = photoState.photos
                  .where((photo) => photo.folderIds.contains(folder.id))
                  .toList();

              if (photos.isEmpty) {
                return const Center(child: Text('No photos in this folder.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(4.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4.0,
                  crossAxisSpacing: 4.0,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return PhotoThumbnail(photos: photos, index: index);
                },
              );
            } else {
              return const Center(child: Text('Failed to load photos.'));
            }
          },
        ),
      ),
    );
  }
}

class PhotoThumbnail extends StatelessWidget {
  final List<Photo> photos;
  final int index;

  const PhotoThumbnail({Key? key, required this.photos, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photo = photos[index];

    return GestureDetector(
      onTap: () {
        // Переход на экран просмотра фотографий с передачей списка фотографий и текущего индекса
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoViewerScreen(
              photos: photos,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Image.file(
        File(photo.path),
        fit: BoxFit.cover,
      ),
    );
  }
}
