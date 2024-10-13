import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_tag_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_tags_view_widget.dart';

class ActionBar extends StatelessWidget {
  final Photo photo;
  final bool isSelectionMode;
  final VoidCallback onShare;
  final VoidCallback onCancel;
  final VoidCallback enableSelectPhotoMode;
  final VoidCallback update;
  final VoidCallback deletePhoto;

  const ActionBar({
    Key? key,
    required this.photo,
    required this.isSelectionMode,
    required this.onShare,
    required this.onCancel,
    required this.enableSelectPhotoMode,
    required this.update,
    required this.deletePhoto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
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
                  ElevatedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 172, 46, 37),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 35, 107, 166),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AddTagWidget(
                      photo: photo,
                      onTagAdded: () {
                        update();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: AddToFolderWidget(
                      photo: photo,
                      onFolderAdded: () {
                        update();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: enableSelectPhotoMode,
                      tooltip: 'Share Photos',
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Color.fromARGB(255, 120, 13, 13)),
                      onPressed: deletePhoto,
                      tooltip: 'Delete Photo',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}