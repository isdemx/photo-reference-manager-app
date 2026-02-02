import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_tag_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_edit_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_tags_view_widget.dart';

class ActionBar extends StatelessWidget {
  final Photo photo;
  final List<Photo> photos;
  final bool isSelectionMode;
  final VoidCallback onShare;
  final VoidCallback onCancel;
  final VoidCallback enableSelectPhotoMode;
  final VoidCallback deletePhoto;
  final VoidCallback onAddToFolder;
  final VoidCallback onAddToFolderMulti;
  final VoidCallback onAddToTag;
  final VoidCallback onAddToCollage;
  final VoidCallback onAddToCollageMulti;

  // ✅ NEW
  final VoidCallback onEdit;

  const ActionBar({
    super.key,
    required this.photo,
    required this.photos,
    required this.isSelectionMode,
    required this.onShare,
    required this.onCancel,
    required this.enableSelectPhotoMode,
    required this.deletePhoto,
    required this.onAddToFolder,
    required this.onAddToFolderMulti,
    required this.onAddToTag,
    required this.onAddToCollage,
    required this.onAddToCollageMulti,
    required this.onEdit, // ✅ NEW
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhotoTagsViewWidget(photo: photo),
            const SizedBox(height: 8.0),
            if (isSelectionMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 172, 46, 37),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child:
                        const Icon(Iconsax.close_circle, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: onAddToTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 30, 136, 82),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Iconsax.tag, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: onAddToFolderMulti,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 37, 96, 155),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Iconsax.folder_add, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: onAddToCollageMulti,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 49, 106, 83),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Iconsax.grid_2, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: onShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 35, 107, 166),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Iconsax.export_1, color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: deletePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 237, 75, 6),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Iconsax.trash, color: Colors.white),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AddTagWidget(photo: photo),
                  AddToFolderWidget(
                    photos: [photo],
                    onFolderAdded: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Iconsax.grid_2,
                      color: Color.fromARGB(255, 29, 104, 77),
                    ),
                    onPressed: onAddToCollage,
                    tooltip: 'Add to collage',
                  ),
                  AddToEditWidget(
                    onEdit: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(
                      Iconsax.trash,
                      color: Color.fromARGB(255, 120, 13, 13),
                    ),
                    onPressed: deletePhoto,
                    tooltip: 'Delete Image',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}



