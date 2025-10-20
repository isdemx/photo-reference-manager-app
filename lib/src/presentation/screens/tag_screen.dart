// lib/src/presentation/screens/tag_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class TagScreen extends StatefulWidget {
  final Tag tag;

  const TagScreen({super.key, required this.tag});

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
                  showFilter: false,
                  tags: tagState.tags,
                  photos: photos,
                  title:
                      '${widget.tag.name.isNotEmpty ? widget.tag.name[0].toUpperCase() : ''}${widget.tag.name.length > 1 ? widget.tag.name.substring(1) : ''}',
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
