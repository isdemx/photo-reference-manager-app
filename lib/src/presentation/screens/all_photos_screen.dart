import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
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

              // Создаём индекс тегов для быстрого и безопасного доступа
              final Map<String, Tag> tagIndex = {
                for (final t in tags ?? <Tag>[]) t.id: t,
              };

              final List<Tag> visibleTags = _filterNotRef
                  ? tags.where((tag) => tag.name != 'Not Ref').toList()
                  : tags;

              final List<Photo> photosFiltered = _filterNotRef
                  ? photoState.photos.where((photo) {
                      // Если у фото нет тегов — считаем его проходным (true)
                      if (photo.tagIds.isEmpty) return true;

                      // Проверяем: все ли теги не называются "Not Ref"
                      return photo.tagIds.every((tagId) {
                        final tag = tagIndex[tagId];
                        if (tag == null) {
                          // тег был удалён — безопасно пропускаем
                          // debugPrint(
                          //     '⚠️ Missing tagId $tagId for photo ${photo.id}');
                          return true;
                        }
                        return tag.name != 'Not Ref';
                      });
                    }).toList()
                  : photoState.photos;

              return DropTarget(
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
                      mediaType: mediaType,
                    );
                    // PhotoSaveHelper already persists and triggers LoadPhotos.
                    // Avoid double insert by not dispatching AddPhoto here.
                  }
                },
                onDragEntered: (_) => setState(() => _dragOver = true),
                onDragExited: (_) => setState(() => _dragOver = false),
                child: Scaffold(
                  backgroundColor: _dragOver ? Colors.black12 : null,
                  body: PhotoGridView(
                    title: 'Images',
                    photos: photosFiltered,
                    tags: visibleTags,
                    actionFromParent: RawChip(
                      label: const Text('NOT REF'),
                      selected: !_filterNotRef,
                      showCheckmark: false,
                      avatar: !_filterNotRef
                          ? const Padding(
                              padding: EdgeInsets.only(left: 2, right: 2),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            )
                          : null,
                      onSelected: (_) {
                        setState(() {
                          _filterNotRef = !_filterNotRef;
                        });
                      },
                      selectedColor: Colors.red.shade600,
                      backgroundColor: Colors.red.shade300,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      shape: const StadiumBorder(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      labelPadding: const EdgeInsets.only(right: 6),
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
