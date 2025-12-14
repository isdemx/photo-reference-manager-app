import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({super.key, required this.folder});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: BlocProvider.of<PhotoBloc>(context),
      child: DropTarget(
        onDragDone: (details) async {
          for (final xfile in details.files) {
            final file = File(xfile.path);
            final bytes = await file.readAsBytes();
            final fileName = p.basename(file.path);
            final mediaType = getMediaType(file.path);

            final newPhoto = await PhotoSaveHelper.savePhoto(
              fileName: fileName,
              bytes: bytes,
              context: context,
              mediaType: mediaType
            );

            newPhoto.folderIds.add(widget.folder.id);
            context.read<PhotoBloc>().add(AddPhoto(newPhoto));
          }
        },
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        child: BlocBuilder<PhotoBloc, PhotoState>(
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

                  return Scaffold(
                    backgroundColor: _dragOver ? Colors.black12 : null,
                    appBar: photos.isEmpty
                        ? AppBar(
                            title: Text(widget.folder.name),
                            actions: [
                              IconButton(
                                icon: const Icon(Iconsax.import_1),
                                tooltip: 'Upload to this folder',
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/upload',
                                    arguments: widget.folder,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.edit),
                                tooltip: 'Edit folder properties',
                                onPressed: () {
                                  FoldersHelpers.showEditFolderDialog(
                                      context, widget.folder);
                                },
                              ),
                            ],
                          )
                        : null,
                    body: photos.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 14.0),
                                    child: Text(
                                      'No images in this folder. You can upload new images or select from the "All Images" section.\n\n'
                                      'Drag & drop files here to quickly upload them to this folder (on desktop).',
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
                                            arguments: widget.folder,
                                          );
                                        },
                                        child: const Text('Upload'),
                                      ),
                                      const SizedBox(width: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                              context, '/all_photos');
                                        },
                                        child: const Text('Images'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : PhotoGridView(
                            showFilter: false,
                            tags: tagState.tags,
                            title: widget.folder.name,
                            showShareBtn: true,
                            photos: photos,
                            actionFromParent: null,
                          ),
                  );
                } else {
                  return const Scaffold(
                    body: Center(child: Text('Failed to load images.')),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
