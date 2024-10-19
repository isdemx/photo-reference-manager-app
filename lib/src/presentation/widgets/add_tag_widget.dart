// lib/src/presentation/widgets/add_tag_widget.dart

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';

class AddTagWidget extends StatelessWidget {
  final Photo photo;

  const AddTagWidget({
    super.key,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.label, color: Colors.white),
      onPressed: () => TagsHelpers.showAddTagToImageDialog(context, photo),
      tooltip: 'Add Tag',
    );
  }
}
