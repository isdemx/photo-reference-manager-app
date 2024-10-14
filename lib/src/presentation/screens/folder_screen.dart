import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({Key? key, required this.folder}) : super(key: key);

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  void _showEditFolderDialog(BuildContext context, Folder folder) {
    final TextEditingController controller = TextEditingController();
    controller.text = folder.name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Folder Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final updatedFolder = folder.copyWith(name: newName);
                  context.read<FolderBloc>().add(UpdateFolder(updatedFolder));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PhotoShareHelper _shareHelper = PhotoShareHelper();

    return BlocProvider(
      create: (context) => PhotoBloc(
        photoRepository: PhotoRepositoryImpl(Hive.box('photos')),
      )..add(LoadPhotos()),
      child: Scaffold(
        body: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            if (photoState is PhotoLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded) {
              final List<Photo> photos = photoState.photos
                  .where((photo) => photo.folderIds.contains(widget.folder.id))
                  .toList();

              if (photos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No photos in this folder.'),
                      const SizedBox(
                          height: 20), // Отступ между текстом и кнопкой
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/upload');
                        },
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                );
              }

              return PhotoGridView(
                title: '${widget.folder.name} (${photos.length})',
                showShareBtn: true,
                photos: photos,
                actionFromParent: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _showEditFolderDialog(context, widget.folder);
                  },
                ),
              );
            } else {
              return const Center(child: Text('Failed to load photos.'));
            }
          },
        ),
      ),
    );
  }
}
