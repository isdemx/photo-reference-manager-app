// lib/src/presentation/widgets/add_tag_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:uuid/uuid.dart';

class AddTagWidget extends StatelessWidget {
  final Photo photo;

  const AddTagWidget({Key? key, required this.photo}) : super(key: key);

  void _showAddTagDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final tagBloc = context.read<TagBloc>();

    // Проверяем, загружены ли теги
    if (tagBloc.state is! TagLoaded) {
      tagBloc.add(LoadTags());
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Tag Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = _controller.text.trim();
                if (tagName.isNotEmpty) {
                  final tagState = tagBloc.state;

                  if (tagState is TagLoaded) {
                    final existingTag = tagState.tags.firstWhere(
                      (tag) => tag.name == tagName,
                        orElse: () => Tag(id: '', name: '', colorValue: Colors.blue.value), // Возвращаем пустой объект как "заглушку"
                    );

                    if (existingTag.id.isNotEmpty) {
                      // Тег существует, добавляем его ID в photo.tagIds
                      if (!photo.tagIds.contains(existingTag.id)) {
                        photo.tagIds.add(existingTag.id);
                        context.read<PhotoBloc>().add(UpdatePhoto(photo));
                      }
                    } else {
                      // Создаём новый тег
                      final newTag = Tag(
                        id: const Uuid().v4(),
                        name: tagName,
                        colorValue: Colors.blue.value, // Используем colorValue
                      );
                      tagBloc.add(AddTag(newTag));

                      // Добавляем новый тег к фото
                      photo.tagIds.add(newTag.id);
                      context.read<PhotoBloc>().add(UpdatePhoto(photo));
                    }

                    Navigator.of(context).pop();
                  } else {
                    // Теги ещё не загружены
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tags are loading. Please wait and try again.')),
                    );
                  }
                }
              },
              child: const Text('Add'),
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
      onPressed: () => _showAddTagDialog(context),
      child: const Text('Add Tag'),
    );
  }
}
