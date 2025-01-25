import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({super.key, required this.folder});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value:
          BlocProvider.of<PhotoBloc>(context), // Используем существующий блок
      child: Scaffold(
        body: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (context, tagState) {
                if (photoState is PhotoLoading || tagState is TagLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
                  final List<Photo> photos = photoState.photos
                      .where(
                          (photo) => photo.folderIds.contains(widget.folder.id))
                      .toList();

                  if (photos.isEmpty) {
                    return Scaffold(
                      appBar: AppBar(
                        title: Text(widget.folder.name),
                      ),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 14.0), // Горизонтальный паддинг
                              child: Text(
                                'No images in this folder. You can upload new images or select from the "All Images" section.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/upload',
                                      arguments:
                                          widget.folder, // объект типа Folder
                                    );
                                  },
                                  child: const Text('Upload'),
                                ),
                                const SizedBox(
                                    width: 20), // Отступ между кнопками
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/all_photos');
                                  },
                                  child: const Text('Images'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return PhotoGridView(
                    showFilter: false,
                    tags: tagState.tags, // Передаём список тегов
                    title: '${widget.folder.name} (${photos.length})',
                    showShareBtn: true,
                    photos: photos,
                    actionFromParent: IconButton(
                      icon: const Icon(Iconsax.edit),
                      tooltip: 'Edit folder properties',
                      onPressed: () {
                        FoldersHelpers.showEditFolderDialog(
                            context, widget.folder);
                      },
                    ),
                  );
                } else {
                  return const Center(child: Text('Failed to load images.'));
                }
              },
            );
          },
        ),
      ),
    );
  }
}
