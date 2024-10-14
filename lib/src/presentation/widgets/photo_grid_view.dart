import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_thumbnail.dart';

class PhotoGridView extends StatelessWidget {
  final List<Photo> photos;
  final bool pinterestView;
  final int columnCount;

  const PhotoGridView({
    Key? key,
    required this.photos,
    required this.pinterestView,
    required this.columnCount,
  }) : super(key: key);

  void _onPhotoTap(context, index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _onDeleteTap(context, photo) {
    context.read<PhotoBloc>().add(DeletePhoto(photo.id));
  }

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
                onPhotoTap: () => _onPhotoTap(context, index),
                onDeleteTap: () => _onDeleteTap(context, photo),
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
                  onPhotoTap: () => _onPhotoTap(context, index),
                  onDeleteTap: () => _onDeleteTap(context, photo),
                  isPinterestLayout: false,
                );
              },
              childCount: photos.length,
            ),
          );
  }
}
