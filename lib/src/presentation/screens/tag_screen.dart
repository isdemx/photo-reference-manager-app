// lib/src/presentation/screens/tag_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';

class TagScreen extends StatelessWidget {
  final Tag tag;

  const TagScreen({Key? key, required this.tag}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos with tag "${tag.name}"'),
        backgroundColor: Color(tag.colorValue),
      ),
      body: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, photoState) {
          if (photoState is PhotoLoaded) {
            final photos = photoState.photos
                .where((photo) => photo.tagIds.contains(tag.id))
                .toList();

            if (photos.isEmpty) {
              return const Center(child: Text('No photos with this tag.'));
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
                return GestureDetector(
                  onTap: () {
                    // Переход на экран просмотра фотографий
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
              },
            );
          } else if (photoState is PhotoLoading) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text('Failed to load photos.'));
          }
        },
      ),
    );
  }
}
