import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
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

            return PhotoGridView(photos: photos, title: 'Tag "${widget.tag.name}"');
          } else {
            return const Center(child: Text('Failed to load photos.'));
          }
        },
      ),
    );
  }
}
