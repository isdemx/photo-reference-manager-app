import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class AllPhotosScreen extends StatefulWidget {
  const AllPhotosScreen({Key? key}) : super(key: key);

  @override
  _AllPhotosScreenState createState() => _AllPhotosScreenState();
}

class _AllPhotosScreenState extends State<AllPhotosScreen> {
  bool _filterNotRef = true;
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhotoBloc, PhotoState>(
      builder: (context, photoState) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (photoState is PhotoLoading || tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
              final tags = tagState.tags;

              if (photoState.photos.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Images')),
                  body: const Center(child: Text('No images available.')),
                );
              }

              final List<Photo> photosFiltered = _filterNotRef
                  ? photoState.photos.where((photo) {
                      return photo.tagIds.every((tagId) {
                        final tag = tags!.firstWhere((tag) => tag.id == tagId);
                        return tag.name != "Not Ref";
                      });
                    }).toList()
                  : photoState.photos;

              return DropTarget(
                onDragDone: (details) async {
                  for (final xfile in details.files) {
                    final file = File(xfile.path);
                    final bytes = await file.readAsBytes();
                    final fileName = p.basename(file.path);

                    final newPhoto = await PhotoSaveHelper.savePhoto(
                      fileName: fileName,
                      bytes: bytes,
                      context: context,
                    );

                    context.read<PhotoBloc>().add(AddPhoto(newPhoto));
                  }
                },
                onDragEntered: (_) => setState(() => _dragOver = true),
                onDragExited: (_) => setState(() => _dragOver = false),
                child: Scaffold(
                  backgroundColor: _dragOver ? Colors.black12 : null,
                  body: PhotoGridView(
                    title: 'Images',
                    photos: photosFiltered,
                    tags: tags,
                    actionFromParent: GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterNotRef = !_filterNotRef;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: _filterNotRef
                              ? Colors.blueAccent
                              : Colors.transparent,
                          border: Border.all(color: Colors.blueAccent),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          'Ref Only',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: _filterNotRef
                                ? Colors.white
                                : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return const Center(child: Text('Failed to load images.'));
            }
          },
        );
      },
    );
  }
}
