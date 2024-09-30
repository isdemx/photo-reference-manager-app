// lib/src/presentation/screens/all_photos_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class AllPhotosScreen extends StatelessWidget {
  const AllPhotosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Photos'),
      ),
      body: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, photoState) {
          if (photoState is PhotoLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (photoState is PhotoLoaded) {
            final List<Photo> photos = photoState.photos;

            if (photos.isEmpty) {
              return const Center(child: Text('No photos available.'));
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
                final photo = photos[index];
                return PhotoThumbnail(
                  photo: photo,
                  onPhotoTap: () {
                    Navigator.pushNamed(
                      context,
                      '/photo',
                      arguments: {'photos': photos, 'index': index},
                    );
                  },
                );
              },
            );
          } else {
            return const Center(child: Text('Failed to load photos.'));
          }
        },
      ),
    );
  }
}

class PhotoThumbnail extends StatelessWidget {
  final Photo photo;
  final VoidCallback onPhotoTap;

  const PhotoThumbnail({Key? key, required this.photo, required this.onPhotoTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPhotoTap,  // Вызываем callback при нажатии
      child: Image.file(
        File(photo.path),
        fit: BoxFit.cover,
      ),
    );
  }
}
