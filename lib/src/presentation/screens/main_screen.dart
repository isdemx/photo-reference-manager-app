// lib/src/presentation/screens/main_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/category_widget.dart';
import 'package:photographers_reference_app/src/utils/export_database.dart';
import 'package:photographers_reference_app/src/utils/import_database.dart';
import 'package:uuid/uuid.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Category Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String name = _controller.text.trim();
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

  void _showEditFolderDialog(BuildContext context, Folder folder) {
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
                _confirmDeleteFolder(
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

  void _confirmDeleteFolder(BuildContext context, Folder folder) {
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

  Future<void> _exportDatabase(BuildContext context) async {
    await exportDatabase(context);
  }

  Future<void> _importDatabase(BuildContext context) async {
    try {
      // Import the database
      await importDatabase(context);

      // Update the blocs
      context.read<PhotoBloc>().add(LoadPhotos());
      context.read<TagBloc>().add(LoadTags());
      context.read<CategoryBloc>().add(LoadCategories());
      context.read<FolderBloc>().add(LoadFolders());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database imported successfully')),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import database')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              final packageInfo = snapshot.data!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.end, // Центрируем по нижнему краю
                children: [
                  Image.asset(
                    'assets/refma-logo.png', // Ваш логотип
                    height: 30, // Уменьшенный размер логотипа
                  ),
                  const SizedBox(width: 5), // Отступ между логотипом и версией
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 5.0), // Отступ слева для версии
                    child: Align(
                      alignment:
                          Alignment.bottomLeft, // Выравнивание по нижнему краю
                      child: Text(
                        'v${packageInfo.version}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0, // Маленький шрифт для версии
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Image.asset(
                'assets/refma-logo.png', // Логотип при загрузке версии
                height: 40, // Задайте нужный размер логотипа
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Open add category dialog
              _showAddCategoryDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UploadScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.pushNamed(context, '/all_photos');
            },
          ),
          IconButton(
            icon: const Icon(Icons.label),
            onPressed: () {
              Navigator.pushNamed(context, '/all_tags');
            },
            tooltip: 'All Tags',
          ),
          // Additional icons can be added here if needed
        ],
      ),
      body: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, categoryState) {
          if (categoryState is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (categoryState is CategoryLoaded) {
            var categories = categoryState.categories;
            // categories = [];

            if (categories.isEmpty) {
              // Display instructions when there are no categories
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Welcome to Refma!\n\nTo get started, upload your first photo using the "Upload" button below. You can also create categories and folders to organize your photos efficiently.\n\nUse the "+" button in the app bar to create new category, and within each category, you can add folders to manage your collection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(
                          height: 20), // Отступ между текстом и кнопкой
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/upload');
                        },
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return CategoryWidget(category: category);
              },
            );
          } else {
            // Handle other states if necessary
            return const Center(child: Text('No categories available.'));
          }
        },
      ),
    );
  }
}
