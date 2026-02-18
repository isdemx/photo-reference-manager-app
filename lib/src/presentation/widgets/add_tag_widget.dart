// lib/src/presentation/widgets/add_tag_widget.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

class AddTagWidget extends StatelessWidget {
  final Photo photo;

  const AddTagWidget({
    super.key,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Iconsax.tag_2, color: context.appThemeColors.text),
      onPressed: () => TagsHelpers.showAddTagToImageDialog(context, photo),
      tooltip: 'Add Tag',
    );
  }
}
