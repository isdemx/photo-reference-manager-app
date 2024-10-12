import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class FolderWidget extends StatelessWidget {
  final Folder folder;

  const FolderWidget({Key? key, required this.folder}) : super(key: key);

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
      onLongPress: () {
        // Открываем диалог редактирования папки
        _showEditFolderDialog(context, folder);
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(4.0),
        ),
        clipBehavior: Clip.hardEdge,
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
                    final lastPhoto = photos.first;
                    final fullPath =
                        PhotoPathHelper().getFullPath(lastPhoto.fileName);

                    return Image.file(
                      File(fullPath),
                      fit: BoxFit.cover,
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
                    child: const Icon(
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
              left: 10,
              right: 0,
              child: Container(
                color: const Color.fromARGB(0, 177, 177, 177),
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  folder.name,
                  textAlign: TextAlign.left,
                  style:
                      const TextStyle(color: Color.fromRGBO(210, 209, 209, 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}