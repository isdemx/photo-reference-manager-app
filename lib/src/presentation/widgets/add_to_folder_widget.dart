// lib/src/presentation/widgets/add_to_folder_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class AddToFolderWidget extends StatelessWidget {
  final List<Photo> photos; // Массив фотографий
  final VoidCallback
      onFolderAdded; // Коллбек для обновления родительского стейта

  const AddToFolderWidget({
    Key? key,
    required this.photos, // Передаем массив фотографий
    required this.onFolderAdded, // Коллбек
  }) : super(key: key);

  void _showAddToFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return BlocBuilder<FolderBloc, FolderState>(
          builder: (context, folderState) {
            if (folderState is FolderLoaded) {
              final folders = folderState.folders;

              // Получаем ID существующих папок
              final existingFolderIds =
                  folders.map((folder) => folder.id).toSet();

              // Собираем ID папок для всех фотографий
              final Set<String> commonFolderIds =
                  Set<String>.from(photos.first.folderIds);
              for (var photo in photos.skip(1)) {
                commonFolderIds
                    .retainAll(photo.folderIds); // Оставляем только общие папки
              }

              return StatefulBuilder(
                builder: (context, setState) {
                  return AlertDialog(
                    title: const Text('Add Photos to Folder'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final folder = folders[index];

                          // Проверяем статус для папки: все фото добавлены, частично или ни одно
                          bool allSelected = true;
                          bool noneSelected = true;

                          for (var photo in photos) {
                            if (!photo.folderIds.contains(folder.id)) {
                              allSelected = false;
                            } else {
                              noneSelected = false;
                            }
                          }

                          var isSelected = allSelected
                              ? true
                              : noneSelected
                                  ? false
                                  : null; // null для частичного состояния (тире)

                          return CheckboxListTile(
                            title: Text(folder.name),
                            value: isSelected,
                            tristate:
                                true, // Включаем тире для частичного состояния
                            onChanged: (bool? value) {
                              setState(() {
                                // Если значение true, добавляем фото в папку

                                if (value == true) {
                                  for (var photo in photos) {
                                    photo.folderIds.add(
                                        folder.id); // Добавляем фото в папку
                                  }
                                }
                                // Если false, удаляем фото из папки
                                else {
                                  for (var photo in photos) {
                                    photo.folderIds.remove(
                                        folder.id); // Убираем фото из папки
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Обновляем список папок для каждой фотографии
                          for (var photo in photos) {
                            photo.folderIds.removeWhere(
                                (id) => !existingFolderIds.contains(id));
                            context
                                .read<PhotoBloc>()
                                .add(UpdatePhoto(photo)); // Обновляем фото
                          }
                          Navigator.of(context).pop();
                          onFolderAdded(); // Вызываем коллбек для обновления родительского стейта
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            } else if (folderState is FolderLoading) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return const Center(child: Text('Failed to load folders.'));
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.folder, color: Colors.white),
      onPressed: () => _showAddToFolderDialog(context),
      tooltip: 'Add Photos to Folder',
    );
  }
}
