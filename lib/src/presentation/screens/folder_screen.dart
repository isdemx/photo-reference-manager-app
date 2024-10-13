import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({Key? key, required this.folder}) : super(key: key);

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _isPinterestLayout = false;
  int _columnCount = 3; // начальное значение колонок

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
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () async {
                final photoState = context.read<PhotoBloc>().state;
                if (photoState is PhotoLoaded) {
                  final List<Photo> photos = photoState.photos
                      .where(
                          (photo) => photo.folderIds.contains(widget.folder.id))
                      .toList();

                  if (photos.isNotEmpty) {
                    try {
                      await _shareHelper.shareMultiplePhotos(photos);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error while sharing photos: $e')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No photos for share')),
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
              final List<Photo> photos = photoState.photos
                  .where((photo) => photo.folderIds.contains(widget.folder.id))
                  .toList();

              if (photos.isEmpty) {
                return const Center(child: Text('No photos in this folder.'));
              }

              return Stack(children: [
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: PhotoGridView(
                        photos: photos,
                        pinterestView: _isPinterestLayout,
                        columnCount: _columnCount,
                        onPhotoTap: (photo, index) {
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
                        onDeleteTap: (photo) {
                          context.read<PhotoBloc>().add(DeletePhoto(photo.id));
                        },
                      ),
                    ),
                  ],
                ),
                ColumnSlider(
                  initialCount: 4,
                  columnCount: _columnCount,
                  onChanged: (value) {
                    setState(() {
                      _columnCount = value;
                    });
                  },
                ),
              ]);
            } else {
              return const Center(child: Text('Failed to load photos.'));
            }
          },
        ),
      ),
    );
  }
}
