// lib/src/presentation/widgets/add_to_folder_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class AddToFolderWidget extends StatelessWidget {
  final Photo photo;

  const AddToFolderWidget({Key? key, required this.photo}) : super(key: key);

  void _showAddToFolderDialog(BuildContext context) {
    final selectedFolderIds = Set<String>.from(photo.folderIds);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: BlocBuilder<FolderBloc, FolderState>(
              builder: (context, folderState) {
                if (folderState is FolderLoaded) {
                  final folders = folderState.folders;

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      final isSelected = selectedFolderIds.contains(folder.id);

                      return CheckboxListTile(
                        title: Text(folder.name),
                        value: isSelected,
                        onChanged: (bool? value) {
                          if (value == true) {
                            selectedFolderIds.add(folder.id);
                          } else {
                            selectedFolderIds.remove(folder.id);
                          }
                          // Обновляем состояние диалога
                          (context as Element).markNeedsBuild();
                        },
                      );
                    },
                  );
                } else if (folderState is FolderLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return const Center(child: Text('Failed to load folders.'));
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Удаляем фото из папок, в которых оно больше не должно находиться
                final removedFolders = photo.folderIds
                    .where((folderId) => !selectedFolderIds.contains(folderId))
                    .toList();

                // Обновляем folderIds фотографии: добавляем новые и удаляем лишние
                photo.folderIds
                  ..clear() // Очищаем все текущие папки
                  ..addAll(selectedFolderIds); // Добавляем выбранные папки

                // Обновляем фотографию через PhotoBloc
                context.read<PhotoBloc>().add(UpdatePhoto(photo));
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showAddToFolderDialog(context),
      child: const Text('Add to Folder'),
    );
  }
}
