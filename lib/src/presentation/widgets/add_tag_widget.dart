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
  final VoidCallback onTagAdded; // Коллбек для обновления родительского стейта

  const AddTagWidget({
    Key? key,
    required this.photo,
    required this.onTagAdded, // Передаем коллбек из родительского виджета
  }) : super(key: key);

  void _showAddTagDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final tagBloc = context.read<TagBloc>();

    if (tagBloc.state is! TagLoaded) {
      tagBloc.add(LoadTags());
    }

    showDialog(
      context: context,
      builder: (context) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (tagState is TagLoaded) {
              final existingTags = tagState.tags;

              return AlertDialog(
                title: const Text('Add Tag'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Tag Name'),
                      ),
                      const SizedBox(height: 16.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: existingTags.map((tag) {
                          final isSelected = photo.tagIds.contains(tag.id);

                          return ChoiceChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            selectedColor:
                                Color(tag.colorValue).withOpacity(0.5),
                            backgroundColor: Color(tag.colorValue),
                            onSelected: (selected) {
                              if (selected) {
                                if (!photo.tagIds.contains(tag.id)) {
                                  photo.tagIds.add(tag.id);
                                  context.read<PhotoBloc>().add(UpdatePhoto(photo));
                                }
                              } else {
                                if (photo.tagIds.contains(tag.id)) {
                                  photo.tagIds.remove(tag.id);
                                  context.read<PhotoBloc>().add(UpdatePhoto(photo));
                                }
                              }
                              (context as Element).markNeedsBuild();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final String tagName = _controller.text.trim();
                      if (tagName.isNotEmpty) {
                        final existingTag = existingTags.firstWhere(
                          (tag) =>
                              tag.name.toLowerCase() == tagName.toLowerCase(),
                          orElse: () => Tag(
                              id: '', name: '', colorValue: Colors.blue.value),
                        );

                        if (existingTag.id.isNotEmpty) {
                          if (!photo.tagIds.contains(existingTag.id)) {
                            photo.tagIds.add(existingTag.id);
                            context.read<PhotoBloc>().add(UpdatePhoto(photo));
                          }
                        } else {
                          final newTag = Tag(
                            id: const Uuid().v4(),
                            name: tagName,
                            colorValue: Colors.blue.value,
                          );
                          tagBloc.add(AddTag(newTag));
                          photo.tagIds.add(newTag.id);
                          context.read<PhotoBloc>().add(UpdatePhoto(photo));
                        }
                      }

                      Navigator.of(context).pop();
                      onTagAdded(); // Вызываем коллбек для обновления родительского стейта
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            } else if (tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return const Center(child: Text('Failed to load tags.'));
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.label, color: Colors.white),
      onPressed: () => _showAddTagDialog(context),
      tooltip: 'Add Tag',
    );
  }
}
