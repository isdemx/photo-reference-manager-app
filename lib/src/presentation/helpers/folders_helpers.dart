import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_folder_dialog.dart';
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
    final TextEditingController controller =
        TextEditingController(text: folder.name);
    bool isPrivate = folder.isPrivate ??
        false; // Инициализация на основе текущего значения isPrivate

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Folder Name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Folder Name'),
                  ),
                  const SizedBox(height: 16.0),
                  CheckboxListTile(
                    title: const Text('Is Private (3 taps on logo to show'),
                    value: isPrivate,
                    onChanged: (bool? value) {
                      setState(() {
                        isPrivate = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Iconsax.trash, color: Colors.red),
                  tooltip: 'Delete folder (No media will be lost)',
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Закрываем диалог редактирования
                    deleteFolderAfterConfirmation(
                        context, folder); // Показываем диалог подтверждения
                  },
                ),
                TextButton(
                  onPressed: () {
                    final String newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      // Обновляем имя папки и флаг приватности
                      final updatedFolder = folder.copyWith(
                        name: newName,
                        isPrivate: isPrivate,
                      );
                      context
                          .read<FolderBloc>()
                          .add(UpdateFolder(updatedFolder));
                      Navigator.of(context).pop(); // Закрываем диалог
                    }
                  },
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(), // Закрываем диалог
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
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
            return BlocBuilder<CategoryBloc, CategoryState>(
              builder: (context, categoryState) {
                if (folderState is FolderLoaded &&
                    categoryState is CategoryLoaded) {
                  final folders = folderState.folders;
                  final categories = {
                    for (var category in categoryState.categories)
                      category.id: category.name
                  };

                  final existingFolderIds =
                      folders.map((folder) => folder.id).toSet();

                  final Set<String> commonFolderIds =
                      Set<String>.from(photos.first.folderIds);
                  for (var photo in photos.skip(1)) {
                    commonFolderIds.retainAll(photo.folderIds);
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
                              final categoryName =
                                  categories[folder.categoryId] ?? 'Unknown';

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
                                      : null;

                              return CheckboxListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      folder.name,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      categoryName,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                                value: isSelected,
                                tristate: true,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      for (var photo in photos) {
                                        photo.folderIds.add(folder.id);
                                      }
                                    } else {
                                      for (var photo in photos) {
                                        photo.folderIds.remove(folder.id);
                                      }
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Iconsax.add_circle,
                                color: Colors.blue),
                            tooltip: 'Create New Folder',
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const AddFolderDialog(),
                              );
                              setState(() {});
                            },
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              for (var photo in photos) {
                                photo.folderIds.removeWhere(
                                    (id) => !existingFolderIds.contains(id));
                                context
                                    .read<PhotoBloc>()
                                    .add(UpdatePhoto(photo));
                              }
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                } else if (folderState is FolderLoading ||
                    categoryState is CategoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return const Center(
                      child: Text('Failed to load folders or categories.'));
                }
              },
            );
          },
        );
      },
    ).then((value) => value ?? false);
  }
}
