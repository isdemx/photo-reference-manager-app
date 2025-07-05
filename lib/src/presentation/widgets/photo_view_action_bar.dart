import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_tag_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_to_folder_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/map_with_photos.dart';
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
  });

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AddTagWidget(
                      photo: photo,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: AddToFolderWidget(
                      photos: [photo],
                      onFolderAdded: () {},
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // Expanded(
                  //   child: IconButton(
                  //     icon: const Icon(Icons.share, color: Colors.white),
                  //     onPressed: enableSelectPhotoMode,
                  //     tooltip: 'Share Images',
                  //   ),
                  // ),
                  // Expanded(
                  //   child: IconButton(
                  //     icon: Icon(
                  //       Iconsax.location,
                  //       color: photo.geoLocation != null
                  //           ? Colors.blue
                  //           : Colors.grey, // серый, если нет геолокации
                  //     ),
                  //     onPressed: () {
                  //       if (photos.any((photo) => photo.geoLocation != null)) {
                  //         Navigator.push(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => PhotoMapWidget(
                  //               photos: photos,
                  //               activePhoto: photo,
                  //             ),
                  //           ),
                  //         );
                  //       } else {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(
                  //             content: Text(
                  //                 'No location data available for photos.'),
                  //           ),
                  //         );
                  //       }
                  //     },
                  //     tooltip: 'View Photos on Map',
                  //   ),
                  // ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Iconsax.trash,
                          color: Color.fromARGB(255, 120, 13, 13)),
                      onPressed: deletePhoto,
                      tooltip: 'Delete Image',
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
