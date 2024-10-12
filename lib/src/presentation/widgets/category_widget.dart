import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/folder_widget.dart';
import 'package:uuid/uuid.dart';

class CategoryWidget extends StatelessWidget {
  final Category category;

  const CategoryWidget({Key? key, required this.category}) : super(key: key);

  void _showAddFolderDialog(BuildContext context) {
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

  void _showEditCategoryDialog(BuildContext context, Category category) {
    final TextEditingController _controller = TextEditingController();
    _controller.text = category.name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Category Name'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Category Name'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог редактирования
                _confirmDeleteCategory(
                    context, category); // Показываем диалог подтверждения
              },
            ),
            TextButton(
              onPressed: () {
                final String newName = _controller.text.trim();
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Закрываем диалог
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category category) {
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
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: const Border(),
      title: GestureDetector(
        onLongPress: () {
          // Открываем диалог редактирования категории
          _showEditCategoryDialog(context, category);
        },
        child: Text(category.name),
      ),
      initiallyExpanded: true,
      trailing: IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          // Открыть диалог добавления папки
          _showAddFolderDialog(context);
        },
      ),
      children: [
        BlocBuilder<FolderBloc, FolderState>(
          builder: (context, folderState) {
            if (folderState is FolderLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (folderState is FolderLoaded) {
              final folders = folderState.folders
                  .where((folder) => folder.categoryId == category.id)
                  .toList();

              if (folders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No folders in this category.'),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: folders.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return FolderWidget(folder: folder);
                },
              );
            } else {
              return const Center(child: Text('Failed to load folders.'));
            }
          },
        ),
      ],
    );
  }
}
