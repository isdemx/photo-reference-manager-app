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
import 'package:shared_preferences/shared_preferences.dart';
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
    BuildContext outerContext,
    List<Photo> photos,
  ) async {
    // Сохраняем исходные folderIds для всех фото
    final Map<Photo, Set<String>> originalFolderIds = {
      for (final p in photos) p: Set<String>.from(p.folderIds),
    };

    final prefs = await SharedPreferences.getInstance();
    bool groupedView = prefs.getBool('groupedView') ?? false;
    String? expandedCategory = prefs.getString('expandedCategory');

    return await showDialog<bool>(
      context: outerContext,
      builder: (dialogContext) {
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

                  Map<String, List<Folder>> categorizedFolders = {};
                  for (var folder in folders) {
                    categorizedFolders
                        .putIfAbsent(folder.categoryId, () => [])
                        .add(folder);
                  }

                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text('Add Photos to Folder'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: groupedView
                              ? ListView(
                                  children: categories.entries.map((entry) {
                                    final categoryId = entry.key;
                                    final categoryName = entry.value;
                                    final categoryFolders =
                                        categorizedFolders[categoryId] ?? [];

                                    return ExpansionTile(
                                      title: Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      initiallyExpanded:
                                          expandedCategory == categoryId,
                                      onExpansionChanged: (expanded) {
                                        expandedCategory =
                                            expanded ? categoryId : null;
                                        prefs.setString(
                                          'expandedCategory',
                                          expandedCategory ?? '',
                                        );
                                        setState(() {
                                          expandedCategory =
                                              expanded ? categoryId : null;
                                        });
                                      },
                                      children: categoryFolders
                                          .map(
                                            (folder) => _buildFolderTile(
                                              folder,
                                              photos,
                                              setState,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  }).toList(),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: folders.length,
                                  itemBuilder: (context, index) {
                                    return _buildFolderTile(
                                      folders[index],
                                      photos,
                                      setState,
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(
                              Iconsax.add_circle,
                              color: Colors.blue,
                            ),
                            tooltip: 'Create New Folder',
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => const AddFolderDialog(),
                              );
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              groupedView ? Iconsax.menu : Iconsax.category,
                            ),
                            tooltip: 'Switch Mode',
                            onPressed: () async {
                              groupedView = !groupedView;
                              await prefs.setBool('groupedView', groupedView);
                              setState(() {});
                            },
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              // 1. Почистим несуществующие папки + обновим фото
                              for (var photo in photos) {
                                photo.folderIds.removeWhere(
                                  (id) => !existingFolderIds.contains(id),
                                );
                                context
                                    .read<PhotoBloc>()
                                    .add(UpdatePhoto(photo));
                              }

                              // 2. Посчитаем, какие папки были ДОБАВЛЕНЫ
                              final Set<String> allNewlyAddedFolderIds = {};

                              for (final photo in photos) {
                                final before =
                                    originalFolderIds[photo] ?? <String>{};
                                final now = Set<String>.from(photo.folderIds);
                                final added = now.difference(before);
                                allNewlyAddedFolderIds.addAll(added);
                              }

                              // 3. Найдём названия добавленных папок
                              final addedFolders = folders
                                  .where(
                                    (f) =>
                                        allNewlyAddedFolderIds.contains(f.id),
                                  )
                                  .toList();

                              if (addedFolders.isNotEmpty) {
                                String message;

                                if (addedFolders.length == 1) {
                                  message =
                                      'Photos added to "${addedFolders.first.name}"';
                                } else {
                                  message = 'Photos added to selected folders';
                                }

                                ScaffoldMessenger.of(outerContext).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    behavior: SnackBarBehavior.floating,
                                    duration:
                                        const Duration(milliseconds: 2200),
                                  ),
                                );
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
                    child: Text('Failed to load folders or categories.'),
                  );
                }
              },
            );
          },
        );
      },
    ).then((value) => value ?? false);
  }

  static Widget _buildFolderTile(
      Folder folder, List<Photo> photos, StateSetter setState) {
    bool allSelected =
        photos.every((photo) => photo.folderIds.contains(folder.id));
    bool noneSelected =
        photos.every((photo) => !photo.folderIds.contains(folder.id));
    var isSelected = allSelected
        ? true
        : noneSelected
            ? false
            : null;

    return CheckboxListTile(
      title: Text(
        folder.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      value: isSelected,
      tristate: true,
      onChanged: (bool? value) {
        setState(() {
          for (var photo in photos) {
            if (value == true) {
              photo.folderIds.add(folder.id);
            } else {
              photo.folderIds.remove(folder.id);
            }
          }
        });
      },
    );
  }
}
