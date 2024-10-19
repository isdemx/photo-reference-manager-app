import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/utils/sort_categories.dart';
import 'package:uuid/uuid.dart';

class CategoriesHelpers {
  static void showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
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
  }

  static void showEditCategoryDialog(BuildContext context, Category category) {
    final TextEditingController controller = TextEditingController();
    controller.text = category.name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Category Name'),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Кнопка для перемещения категории вверх
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: () {
                    final categories = context.read<CategoryBloc>().state;
                    if (categories is CategoryLoaded) {
                      final sortedCategories = sortCategories(
                        categories: categories.categories,
                        categoryId: category.id,
                        move: 'up',
                      );
                      // Обновляем все категории с новыми сортировками
                      for (var updatedCategory in sortedCategories) {
                        context
                            .read<CategoryBloc>()
                            .add(UpdateCategory(updatedCategory));
                      }
                    }
                    Navigator.of(context).pop();
                  },
                ),
                // Кнопка для перемещения категории вниз
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: () {
                    final categories = context.read<CategoryBloc>().state;
                    if (categories is CategoryLoaded) {
                      final sortedCategories = sortCategories(
                        categories: categories.categories,
                        categoryId: category.id,
                        move: 'down',
                      );
                      // Обновляем все категории с новыми сортировками
                      for (var updatedCategory in sortedCategories) {
                        context
                            .read<CategoryBloc>()
                            .add(UpdateCategory(updatedCategory));
                      }
                    }
                    Navigator.of(context).pop();
                  },
                ),
                // Кнопка для удаления категории
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Закрываем диалог редактирования
                    confirmDeleteCategory(
                        context, category); // Показываем диалог подтверждения
                  },
                ),
                TextButton(
                  onPressed: () {
                    final String newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      // Обновляем имя категории
                      final updatedCategory = category.copyWith(name: newName);
                      context
                          .read<CategoryBloc>()
                          .add(UpdateCategory(updatedCategory));
                      Navigator.of(context).pop(); // Закрываем диалог
                    }
                  },
                  child: const Text('OK'),
                ),
                // TextButton(
                //   onPressed: () =>
                //       Navigator.of(context).pop(), // Закрываем диалог
                //   child: const Text('Cancel'),
                // ),
              ],
            ),
          ],
        );
      },
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
              onPressed: () => Navigator.of(context).pop(), // Отмена
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Получаем все папки в категории
                final folderState = context.read<FolderBloc>().state;
                if (folderState is FolderLoaded) {
                  final foldersInCategory = folderState.folders
                      .where((folder) => folder.categoryId == category.id)
                      .toList();

                  // Удаляем каждую папку
                  for (var folder in foldersInCategory) {
                    context.read<FolderBloc>().add(DeleteFolder(folder.id));
                  }
                }

                // Удаляем категорию
                context.read<CategoryBloc>().add(DeleteCategory(category.id));
                Navigator.of(context).pop(); // Закрываем диалог подтверждения
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  static void showAddFolderDialog(BuildContext context, Category category) {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Folder'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String name = _controller.text.trim();
                if (name.isNotEmpty) {
                  final Folder folder = Folder(
                    id: const Uuid().v4(),
                    name: name,
                    categoryId: category.id,
                    photoIds: [],
                    dateCreated: DateTime.now(),
                    sortOrder: 0,
                  );
                  context.read<FolderBloc>().add(AddFolder(folder));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
