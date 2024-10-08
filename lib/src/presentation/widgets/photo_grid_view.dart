import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/screens/all_photos_screen.dart';

class PhotoGridView extends StatelessWidget {
  final List<Photo> photos;
  final bool pinterestView;
  final int columnCount;
  final Function(Photo photo, int index) onPhotoTap;
  final Function(Photo photo) onDeleteTap;

  const PhotoGridView({
    Key? key,
    required this.photos,
    required this.pinterestView,
    required this.columnCount,
    required this.onPhotoTap,
    required this.onDeleteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return pinterestView
        ? SliverMasonryGrid.count(
            crossAxisCount: columnCount,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            childCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return PhotoThumbnail(
                photo: photo,
                onPhotoTap: () => onPhotoTap(photo, index),
                onDeleteTap: () => onDeleteTap(photo),
                isPinterestLayout: true,
              );
            },
          )
        : SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final photo = photos[index];
                return PhotoThumbnail(
                  photo: photo,
                  onPhotoTap: () => onPhotoTap(photo, index),
                  onDeleteTap: () => onDeleteTap(photo),
                  isPinterestLayout: false,
                );
              },
              childCount: photos.length,
            ),
          );
  }
}
