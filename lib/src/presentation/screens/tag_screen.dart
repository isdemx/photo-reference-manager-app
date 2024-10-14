import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class TagScreen extends StatefulWidget {
  final Tag tag;

  const TagScreen({Key? key, required this.tag}) : super(key: key);

  @override
  _TagScreenState createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  bool _isPinterestLayout = false;
  int _columnCount = 3; // начальное количество колонок

  @override
  Widget build(BuildContext context) {
    final PhotoShareHelper _shareHelper = PhotoShareHelper();

    return Scaffold(
      appBar: AppBar(
        title: Text('Tag "${widget.tag.name}"'),
        backgroundColor: Color(widget.tag.colorValue),
        actions: [
          IconButton(
            icon: Icon(_isPinterestLayout ? Icons.grid_on : Icons.dashboard),
            onPressed: () {
              setState(() {
                _isPinterestLayout = !_isPinterestLayout;
              });
            },
            tooltip: _isPinterestLayout
                ? 'Switch to Grid View'
                : 'Switch to Pinterest View',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              final photoState = context.read<PhotoBloc>().state;

              if (photoState is PhotoLoaded) {
                final photos = photoState.photos
                    .where((photo) => photo.tagIds.contains(widget.tag.id))
                    .toList();

                if (photos.isNotEmpty) {
                  _shareHelper.shareMultiplePhotos(photos);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No photos for sharing')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, photoState) {
          if (photoState is PhotoLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (photoState is PhotoLoaded) {
            final photos = photoState.photos
                .where((photo) => photo.tagIds.contains(widget.tag.id))
                .toList();

            if (photos.isEmpty) {
              return const Center(child: Text('No photos with this tag.'));
            }

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: PhotoGridView(
                        photos: photos,
                        pinterestView: _isPinterestLayout,
                        columnCount: _columnCount,
                      ),
                    ),
                  ],
                ),
                ColumnSlider(
                  initialCount: _columnCount,
                  columnCount: _columnCount,
                  onChanged: (value) {
                    setState(() {
                      _columnCount = value;
                    });
                  },
                ),
              ],
            );
          } else {
            return const Center(child: Text('Failed to load photos.'));
          }
        },
      ),
    );
  }
}
