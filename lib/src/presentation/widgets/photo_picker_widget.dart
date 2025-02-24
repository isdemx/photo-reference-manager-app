import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoPickerWidget extends StatefulWidget {
  /// Колбэк, который будет вызван при тапе на конкретную фотографию.
  final void Function(Photo)? onPhotoSelected;

  const PhotoPickerWidget({
    Key? key,
    this.onPhotoSelected,
  }) : super(key: key);

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  /// Храним ID текущей выбранной папки, или null, если «All Photos»
  String? _selectedFolderId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, folderState) {
        if (folderState is FolderLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (folderState is FolderLoaded) {
          // Список всех папок
          final allFolders = folderState.folders;

          return BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, photoState) {
              if (photoState is PhotoLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded) {
                // Список всех фото
                final allPhotos = photoState.photos;

                // Формируем пункты для выпадающего списка
                final dropdownItems = <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Photos'),
                  ),
                ];

                for (final folder in allFolders) {
                  dropdownItems.add(
                    DropdownMenuItem<String?>(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                  );
                }

                // Фильтруем список фотографий в зависимости от выбранной папки
                final visiblePhotos = _selectedFolderId == null
                    ? allPhotos
                    : allPhotos
                        .where((photo) => photo.folderIds.contains(_selectedFolderId))
                        .toList();

                return Column(
                  children: [
                    // Панель со списком папок
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Text('Select folder:', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String?>(
                              value: _selectedFolderId,
                              items: dropdownItems,
                              dropdownColor: Colors.grey[900],
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: Colors.white,
                              onChanged: (newValue) {
                                setState(() => _selectedFolderId = newValue);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Сетка с фотографиями
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: visiblePhotos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemBuilder: (_, index) {
                            final photo = visiblePhotos[index];
                            final path = PhotoPathHelper().getFullPath(photo.fileName);

                            return GestureDetector(
                              onTap: () {
                                // Если колбэк задан, сообщаем о выборе фото
                                widget.onPhotoSelected?.call(photo);
                              },
                              child: Image.file(
                                File(path),
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Возможно PhotoError, PhotoInitial и т.д.
                return const Center(child: Text('Error loading photos'));
              }
            },
          );
        } else {
          // Возможно FolderError, FolderInitial и т.д.
          return const Center(child: Text('Error loading folders'));
        }
      },
    );
  }
}
