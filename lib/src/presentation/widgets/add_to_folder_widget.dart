// lib/src/presentation/widgets/add_to_folder_widget.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';

class AddToFolderWidget extends StatelessWidget {
  final List<Photo> photos; // Массив фотографий
  final VoidCallback
      onFolderAdded; // Коллбек для обновления родительского стейта

  const AddToFolderWidget({
    super.key,
    required this.photos, // Передаем массив фотографий
    required this.onFolderAdded, // Коллбек
  });

  Future<void> _showFoldersModal(BuildContext context) async {
    var res = await FoldersHelpers.showAddToFolderDialog(context, photos);
    if (res) {
      onFolderAdded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Iconsax.folder_add  , color: Colors.white),
      onPressed: () => _showFoldersModal(context),
      tooltip: 'Add media to folder',
    );
  }
}
