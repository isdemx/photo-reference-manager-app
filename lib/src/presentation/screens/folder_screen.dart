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
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;

  const FolderScreen({super.key, required this.folder});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _dragOver = false; // Флаг для визуальной индикации (если понадобится)

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: BlocProvider.of<PhotoBloc>(context), // Используем уже существующий PhotoBloc
      child: DropTarget(
        // 1. Оборачиваем Scaffold в DropTarget, чтобы обрабатывать дроп файлов
        onDragDone: (details) async {
          // Перетащили файлы в папку
          for (final xfile in details.files) {
            final file = File(xfile.path);
            final bytes = await file.readAsBytes();
            final fileName = p.basename(file.path);

            // 2. Сохраняем фото (реализация зависит от того, как устроен PhotoSaveHelper)
            final newPhoto = await PhotoSaveHelper.savePhoto(
              fileName: fileName,
              bytes: bytes,
              context: context,
            );

            // 3. Добавляем в текущую папку
            newPhoto.folderIds.add(widget.folder.id);

            // 4. Посылаем событие в PhotoBloc (AddPhoto или UpdatePhoto, в зависимости от логики)
            context.read<PhotoBloc>().add(AddPhoto(newPhoto));
          }
        },
        onDragEntered: (details) {
          // Можно включить эффект подсветки
          setState(() => _dragOver = true);
        },
        onDragExited: (details) {
          setState(() => _dragOver = false);
        },
        // Сам виджет:
        child: Scaffold(
          // При желании `_dragOver` можно использовать для «подсветки»:
          backgroundColor: _dragOver ? Colors.black12 : null,

          appBar: AppBar(
            title: Text(widget.folder.name),
            actions: [
              // Кнопка Upload
              IconButton(
                icon: const Icon(Iconsax.import_1),
                tooltip: 'Upload to this folder',
                onPressed: () {
                  // Та же логика, что и при отсутствии фото
                  Navigator.pushNamed(
                    context,
                    '/upload',
                    arguments: widget.folder,
                  );
                },
              ),
              // Кнопка Edit папки
              IconButton(
                icon: const Icon(Iconsax.edit),
                tooltip: 'Edit folder properties',
                onPressed: () {
                  FoldersHelpers.showEditFolderDialog(context, widget.folder);
                },
              ),
            ],
          ),

          body: BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, photoState) {
              return BlocBuilder<TagBloc, TagState>(
                builder: (context, tagState) {
                  if (photoState is PhotoLoading || tagState is TagLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
                    final List<Photo> photos = photoState.photos
                        .where((photo) => photo.folderIds.contains(widget.folder.id))
                        .toList();

                    if (photos.isEmpty) {
                      // Ситуация, когда в папке нет фото
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14.0),
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

                    // Если в папке есть фото - показываем PhotoGridView
                    return PhotoGridView(
                      showFilter: false,
                      tags: tagState.tags,
                      title: '${widget.folder.name} (${photos.length})',
                      showShareBtn: true,
                      photos: photos,
                      // Вместо отдельной кнопки в grid-e
                      // мы уже добавили иконку в AppBar,
                      // но если нужно — можно оставить:
                      actionFromParent: null,
                    );
                  } else {
                    return const Center(child: Text('Failed to load images.'));
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
