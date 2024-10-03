// lib/src/presentation/screens/folder_screen.dart

import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({Key? key, required this.folder}) : super(key: key);

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _isPinterestLayout = false;

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
    return BlocProvider(
      create: (context) => PhotoBloc(
        photoRepository: PhotoRepositoryImpl(Hive.box('photos')),
      )..add(LoadPhotos()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.folder.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditFolderDialog(context, widget.folder);
              },
            ),
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
          ],
        ),
        body: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            if (photoState is PhotoLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded) {
              final List<Photo> photos = photoState.photos
                  .where((photo) => photo.folderIds.contains(widget.folder.id))
                  .toList();

              if (photos.isEmpty) {
                return const Center(child: Text('No photos in this folder.'));
              }

              return _isPinterestLayout
                  ? MasonryGridView.count(
                      padding: const EdgeInsets.all(4.0),
                      crossAxisCount: 3,
                      mainAxisSpacing: 16.0,
                      crossAxisSpacing: 16.0,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        return PhotoThumbnail(
                          photos: photos,
                          index: index,
                          isPinterestLayout: true,
                        );
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(4.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 4.0,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        return PhotoThumbnail(
                          photos: photos,
                          index: index,
                          isPinterestLayout: false,
                        );
                      },
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

class PhotoThumbnail extends StatelessWidget {
  final List<Photo> photos;
  final int index;
  final bool isPinterestLayout;

  const PhotoThumbnail({
    Key? key,
    required this.photos,
    required this.index,
    required this.isPinterestLayout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photo = photos[index];
    final fullPath = PhotoPathHelper().getFullPath(photo.fileName);

    Widget imageWidget = ExtendedImage.file(
      File(fullPath),
      enableMemoryCache: true,
      clearMemoryCacheIfFailed: true,
      fit: BoxFit.cover,
    );

    if (isPinterestLayout) {
      // В режиме Pinterest используем Image с автоматическим вычислением высоты
      imageWidget = ExtendedImage.file(
        File(fullPath),
        fit: BoxFit.cover,
        cacheWidth: 200,
        enableMemoryCache: true,
        clearMemoryCacheIfFailed: true,
      );
    } else {
      // В стандартном режиме используем фиксированную ширину и высоту
      imageWidget = ExtendedImage.file(
        File(fullPath),
        fit: BoxFit.cover,
        cacheWidth: 200,
        width: double.infinity,
        height: double.infinity,
        enableMemoryCache: true,
        clearMemoryCacheIfFailed: true,
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoViewerScreen(
              photos: photos,
              initialIndex: index,
            ),
          ),
        );
      },
      child: imageWidget,
    );
  }
}
