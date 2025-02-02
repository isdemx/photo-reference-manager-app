import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:uuid/uuid.dart';

class TagsHelpers {
  static void _addTagToBloc(
      BuildContext context, String tagName, Photo? photo) {
    final tagBloc = context.read<TagBloc>();
    final existingTags = (tagBloc.state as TagLoaded).tags;

    final existingTag = existingTags.firstWhere(
      (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
      orElse: () => Tag(id: '', name: '', colorValue: Colors.blue.value),
    );

    if (existingTag.id.isNotEmpty) {
      // Если тег уже существует, добавляем его к фотографии, если указана
      if (photo != null && !photo.tagIds.contains(existingTag.id)) {
        photo.tagIds.add(existingTag.id);
        context.read<PhotoBloc>().add(UpdatePhoto(photo));
      }
    } else {
      // Если тег не существует, создаем новый и добавляем в TagBloc и PhotoBloc
      final newTag = Tag(
        id: const Uuid().v4(),
        name: tagName,
        colorValue: Colors.blue.value,
      );
      tagBloc.add(AddTag(newTag));
      if (photo != null) {
        photo.tagIds.add(newTag.id);
        context.read<PhotoBloc>().add(UpdatePhoto(photo));
      }
    }
  }

  static void showAddTagDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = controller.text.trim();
                if (tagName.isNotEmpty) {
                  _addTagToBloc(
                      context, tagName, null); // Передаем null для фото
                  Navigator.of(context).pop();
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

  static Future<bool> showAddTagToImageDialog(
      BuildContext context, Photo photo) async {
    final TextEditingController controller = TextEditingController();
    final tagBloc = context.read<TagBloc>();

    if (tagBloc.state is! TagLoaded) {
      tagBloc.add(LoadTags());
    }

    return await showDialog<bool>(
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
                        controller: controller,
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
                                  context
                                      .read<PhotoBloc>()
                                      .add(UpdatePhoto(photo));
                                }
                              } else {
                                if (photo.tagIds.contains(tag.id)) {
                                  photo.tagIds.remove(tag.id);
                                  context
                                      .read<PhotoBloc>()
                                      .add(UpdatePhoto(photo));
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
                    onPressed: () => Navigator.of(context)
                        .pop(false), // Возвращаем false при отмене
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final String tagName = controller.text.trim();
                      if (tagName.isNotEmpty) {
                        _addTagToBloc(context, tagName, photo); // Передаем фото
                      }
                      Navigator.of(context)
                          .pop(true); // Возвращаем true при добавлении тега
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
    ).then((value) => value ?? false); // Если результат null, возвращаем false
  }

  static void showDeleteConfirmationDialog(BuildContext context, Tag tag) {
    final tagBloc = context.read<TagBloc>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete tag'),
          content: Text('Are you sure wnat to delete "${tag.name}" tag?'),
          actions: [
            TextButton(
              onPressed: () {
                tagBloc.add(DeleteTag(tag.id));
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  static void showColorPickerDialog(BuildContext context, Tag tag) {
    Color pickerColor = Color(tag.colorValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Color for "${tag.name}" tag'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final updatedTag = Tag(
                  id: tag.id,
                  name: tag.name,
                  colorValue: pickerColor.value,
                );
                context.read<TagBloc>().add(UpdateTag(updatedTag));
                Navigator.of(context).pop();
              },
              child: const Text('Ok'),
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

  static void showEditTagDialog(BuildContext context, Tag tag) {
    final TextEditingController controller =
        TextEditingController(text: tag.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = controller.text.trim();
                if (tagName.isNotEmpty) {
                  final updatedTag = Tag(
                    id: tag.id,
                    name: tagName,
                    colorValue: tag.colorValue,
                  );
                  context.read<TagBloc>().add(UpdateTag(updatedTag));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Ok'),
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

  static Map<String, int> computeTagPhotoCounts(
      List<Tag> tags, List<Photo> photos) {
    final Map<String, int> counts = {};
    for (var tag in tags) {
      counts[tag.id] = 0;
    }
    for (var photo in photos) {
      for (var tagId in photo.tagIds) {
        if (counts.containsKey(tagId)) {
          counts[tagId] = counts[tagId]! + 1;
        }
      }
    }
    return counts;
  }
}
