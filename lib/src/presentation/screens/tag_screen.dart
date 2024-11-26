import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class TagScreen extends StatefulWidget {
  final Tag tag;

  const TagScreen({Key? key, required this.tag}) : super(key: key);

  @override
  _TagScreenState createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, photoState) {
          return BlocBuilder<TagBloc, TagState>(
            builder: (context, tagState) {
              if (photoState is PhotoLoading || tagState is TagLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
                final photos = photoState.photos
                    .where((photo) => photo.tagIds.contains(widget.tag.id))
                    .toList();

                if (photos.isEmpty) {
                  return const Center(child: Text('No images with this tag.'));
                }

                return PhotoGridView(
                  tags: tagState.tags, // Передаём список тегов
                  photos: photos,
                  title: 'Tag "${widget.tag.name}"',
                  showShareBtn: true,
                );
              } else {
                return const Center(child: Text('Failed to load images.'));
              }
            },
          );
        },
      ),
    );
  }
}
