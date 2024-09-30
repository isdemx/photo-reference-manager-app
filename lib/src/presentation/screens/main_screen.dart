// lib/src/presentation/screens/main_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Открыть диалог добавления категории
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
        ],
      ),
      body: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, categoryState) {
          if (categoryState is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (categoryState is CategoryLoaded) {
            final categories = categoryState.categories;

            return ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return CategoryWidget(category: category);
              },
            );
          } else {
            return const Center(child: Text('No categories available.'));
          }
        },
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(category.name),
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
                  childAspectRatio: 1, // Установите соотношение сторон
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

class FolderWidget extends StatelessWidget {
  final Folder folder;

  const FolderWidget({Key? key, required this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Отображение виджета папки с изображением и названием
    return GestureDetector(
      onTap: () {
        // Переход на экран папки
        Navigator.pushNamed(
          context,
          '/folder',
          arguments: folder,
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 0, 0, 0), // Цвет фона
          borderRadius: BorderRadius.circular(8.0), // Закругленные углы
        ),
        clipBehavior: Clip.hardEdge,  // Обрезка содержимого по границам контейнера
        child: Stack(
          alignment: Alignment.center,
          children: [
            BlocBuilder<PhotoBloc, PhotoState>(
              builder: (context, photoState) {
                if (photoState is PhotoLoaded) {
                  // Получаем фотографии, которые находятся в этой папке
                  final photos = photoState.photos
                      .where((photo) => photo.folderIds.contains(folder.id))
                      .toList();

                  if (photos.isNotEmpty) {
                    // Получаем последнюю фотографию
                    final lastPhoto = photos.last;

                    return Image.file(
                      File(lastPhoto.path),
                      fit: BoxFit.cover,  // Фото заполняет весь контейнер
                      width: double.infinity,
                      height: double.infinity,
                    );
                  } else {
                    // Нет фотографий в папке, показываем иконку папки
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.folder,
                        size: 50,
                        color: Colors.white,
                      ),
                    );
                  }
                } else if (photoState is PhotoLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  // Ошибка загрузки фотографий, показываем иконку папки
                  return Container(
                    color: Colors.grey[800],
                    child: Icon(
                      Icons.folder,
                      size: 50,
                      color: Colors.white,
                    ),
                  );
                }
              },
            ),
            // Отображаем название папки внизу
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  folder.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
