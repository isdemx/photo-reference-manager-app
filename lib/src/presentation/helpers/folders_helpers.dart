import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:uuid/uuid.dart';

class FoldersHelpers {
  static void deleteFolderAfterConfirmation(
      BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Folder"),
          content: const Text("Are you sure you want to delete this folder?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Отмена
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<FolderBloc>().add(DeleteFolder(folder.id));
                Navigator.of(context).pop(); // Закрываем диалог подтверждения
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  static void showEditFolderDialog(BuildContext context, Folder folder) {
    final TextEditingController _controller = TextEditingController();
    _controller.text = folder.name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Folder Name'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог редактирования
                deleteFolderAfterConfirmation(
                    context, folder); // Показываем диалог подтверждения
              },
            ),
            TextButton(
              onPressed: () {
                final String newName = _controller.text.trim();
                if (newName.isNotEmpty) {
                  // Обновляем имя папки
                  final updatedFolder = folder.copyWith(name: newName);
                  context.read<FolderBloc>().add(UpdateFolder(updatedFolder));
                  Navigator.of(context).pop(); // Закрываем диалог
                }
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Закрываем диалог
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showAddToFolderDialog(
      BuildContext context, List<Photo> photos) async {
    return await showDialog<bool>(
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
                        onPressed: () {
                          Navigator.of(context)
                              .pop(false); // Возвращаем false при отмене
                        },
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
                          Navigator.of(context)
                              .pop(true); // Возвращаем true при подтверждении
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
    ).then((value) => value ?? false); // Если результат null, возвращаем false
  }
}
