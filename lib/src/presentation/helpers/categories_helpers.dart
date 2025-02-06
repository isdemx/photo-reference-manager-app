import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/add_folder_dialog.dart';
import 'package:photographers_reference_app/src/utils/sort_categories.dart';
import 'package:uuid/uuid.dart';

class CategoriesHelpers {
  static void showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode(); // Добавляем FocusNode

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
            focusNode: focusNode, // Устанавливаем FocusNode
            decoration: const InputDecoration(hintText: 'Category Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String name = controller.text.trim();
                if (name.isNotEmpty) {
                  final Category category = Category(
                    id: const Uuid().v4(),
                    name: name,
                    folderIds: [],
                    sortOrder: 0,
                  );
                  context.read<CategoryBloc>().add(AddCategory(category));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    // Устанавливаем фокус после открытия диалога
    Future.delayed(Duration.zero, () {
      focusNode.requestFocus();
    });
  }

  static void showEditCategoryDialog(BuildContext context, Category category) {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode(); // Добавляем FocusNode
    controller.text = category.name;
    bool isPrivate = category.isPrivate ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    focusNode: focusNode, // Устанавливаем FocusNode
                    decoration:
                        const InputDecoration(hintText: 'Category Name'),
                  ),
                  const SizedBox(height: 16.0),
                  CheckboxListTile(
                    title: const Text('Is Private'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Iconsax.arrow_up_2),
                      tooltip: 'Move folder up',
                      onPressed: () {
                        final categories = context.read<CategoryBloc>().state;
                        if (categories is CategoryLoaded) {
                          final sortedCategories = sortCategories(
                            categories: categories.categories,
                            categoryId: category.id,
                            move: 'up',
                          );
                          for (var updatedCategory in sortedCategories) {
                            context
                                .read<CategoryBloc>()
                                .add(UpdateCategory(updatedCategory));
                          }
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.arrow_down_1),
                      tooltip: 'Move folder down',
                      onPressed: () {
                        final categories = context.read<CategoryBloc>().state;
                        if (categories is CategoryLoaded) {
                          final sortedCategories = sortCategories(
                            categories: categories.categories,
                            categoryId: category.id,
                            move: 'down',
                          );
                          for (var updatedCategory in sortedCategories) {
                            context
                                .read<CategoryBloc>()
                                .add(UpdateCategory(updatedCategory));
                          }
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.trash, color: Colors.red),
                      tooltip:
                          'Delete category and pholders inside (No media will be deleted)',
                      onPressed: () {
                        Navigator.of(context).pop();
                        confirmDeleteCategory(context, category);
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        final String newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          final updatedCategory = category.copyWith(
                            name: newName,
                            isPrivate: isPrivate,
                          );
                          context
                              .read<CategoryBloc>()
                              .add(UpdateCategory(updatedCategory));
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    // Устанавливаем фокус после открытия диалога
    Future.delayed(Duration.zero, () {
      focusNode.requestFocus();
    });
  }

  static void showAddFolderDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddFolderDialog(category: category),
    );
  }

  static void confirmDeleteCategory(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Category"),
          content: const Text(
              "Are you sure you want to delete this category? All folders inside will be deleted as well!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final folderState = context.read<FolderBloc>().state;
                if (folderState is FolderLoaded) {
                  final foldersInCategory = folderState.folders
                      .where((folder) => folder.categoryId == category.id)
                      .toList();

                  for (var folder in foldersInCategory) {
                    context.read<FolderBloc>().add(DeleteFolder(folder.id));
                  }
                }
                context.read<CategoryBloc>().add(DeleteCategory(category.id));
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
